const std = @import("std");
const kuz = @import("src/kuznechik.zig");
const Before = @import("src/modes/classic_before_093.zig").Modes(kuz.Cipher);
const After = kuz.modes.classic;
const B = @Vector(16, u8);
// Runtime inputs; key expansion and allocation precede timing. Every repetition
// includes plaintext copy, public init (Cipher + IV copy), and public encryption.
noinline fn run(comptime M: type, comptime width: usize, cipher: kuz.Cipher, iv: [width * 16]u8, plain: []const u8, data: []u8, reps: usize, split: bool) !u64 {
    asm volatile ("" ::: .{ .memory = true });
    var timer = try std.time.Timer.start();
    for (0..reps) |_| {
        @memcpy(data, plain);
        var ctx = M.Cbc(width).init(cipher, iv);
        if (split) try ctx.encrypt(data[0..16]);
        try ctx.encrypt(data[if (split) @as(usize, 16) else 0..]);
        std.mem.doNotOptimizeAway(data.ptr);
        asm volatile ("" ::: .{ .memory = true });
    }
    return timer.read();
}
fn reference(comptime width: usize, cipher: kuz.Cipher, iv: [width * 16]u8, data: []u8) void {
    var register = iv;
    var at: usize = 0;
    while (at < data.len) : (at += 16) {
        var bytes: [16]u8 = undefined;
        for (&bytes, data[at..][0..16], register[0..16]) |*o, p, r| o.* = p ^ r;
        var value: B = bytes;
        cipher.encrypt(&value);
        bytes = value;
        @memcpy(data[at..][0..16], &bytes);
        std.mem.copyForwards(u8, register[0 .. register.len - 16], register[16..]);
        @memcpy(register[register.len - 16 ..], &bytes);
    }
}
fn guards(mem: []const u8, off: usize, n: usize) !void {
    for (mem[0..off]) |b| if (b != 0xa5) return error.PrefixGuard;
    for (mem[off + n ..][0..16]) |b| if (b != 0xa5) return error.SuffixGuard;
}
pub fn main() !void {
    var args = std.process.args();
    _ = args.next();
    const seed = if (args.next()) |s| try std.fmt.parseInt(u64, s, 10) else 123;
    const budget = if (args.next()) |s| try std.fmt.parseInt(usize, s, 10) else 65536;
    const layout = if (args.next()) |s| try std.fmt.parseInt(usize, s, 10) else 0;
    const only = if (args.next()) |s| try std.fmt.parseInt(usize, s, 10) else 0;
    var rng = std.Random.DefaultPrng.init(seed);
    var key: kuz.key = undefined;
    rng.random().bytes(std.mem.asBytes(&key));
    const cipher = kuz.Cipher.init(key);
    const initial = try std.heap.page_allocator.alloc(u8, 65568);
    const a_mem = try std.heap.page_allocator.alloc(u8, initial.len);
    const b_mem = try std.heap.page_allocator.alloc(u8, initial.len);
    const expected = try std.heap.page_allocator.alloc(u8, initial.len);
    rng.random().bytes(initial);
    inline for (0..66) |wi| {
        const width = if (wi == 65) 128 else wi + 1;
        if (only == 0 or only == width) {
            var iv: [width * 16]u8 = undefined;
            rng.random().bytes(&iv);
            for ([_]usize{ 16, 32, 48, 64, 80, 112, 128, 144, width * 16 - 16, width * 16, width * 16 + 16, width * 32 - 16, width * 32 + 16, 1024, 2048, 16384 }) |n| {
                if (n == 0) continue;
                for ([_]bool{ false, true }) |split| {
                    const off = 16 + layout % 2;
                    const a_full = if (layout < 2) a_mem else b_mem;
                    const b_full = if (layout < 2) b_mem else a_mem;
                    @memset(a_full, 0xa5);
                    @memset(b_full, 0xa5);
                    const a = a_full[off..][0..n];
                    const b = b_full[off..][0..n];
                    const plain = initial[off..][0..n];
                    @memcpy(expected[0..n], plain);
                    reference(width, cipher, iv, expected[0..n]);
                    const reps = @max(8, budget / n);
                    var before: [9]u64 = undefined;
                    var after: [9]u64 = undefined;
                    var checksum: u64 = 0;
                    for (0..11) |j| {
                        var x: u64 = undefined;
                        var y: u64 = undefined;
                        if ((j + seed) % 2 == 0) {
                            x = try run(Before, width, cipher, iv, plain, a, reps, split);
                            y = try run(After, width, cipher, iv, plain, b, reps, split);
                        } else {
                            y = try run(After, width, cipher, iv, plain, b, reps, split);
                            x = try run(Before, width, cipher, iv, plain, a, reps, split);
                        }
                        if (!std.mem.eql(u8, a, expected[0..n]) or !std.mem.eql(u8, b, expected[0..n])) return error.FullReferenceMismatch;
                        try guards(a_full, off, n);
                        try guards(b_full, off, n);
                        checksum +%= std.hash.Wyhash.hash(j, a);
                        checksum +%= std.hash.Wyhash.hash(j, b);
                        if (j < 2) continue;
                        before[j - 2] = x;
                        after[j - 2] = y;
                    }
                    std.debug.print("{{\"mode\":\"CBC-encrypt\",\"m\":{d},\"bytes\":{d},\"split1\":{},\"layout\":{d},\"offset\":{d},\"seed\":{d},\"reps\":{d},\"checksum\":{d},\"before\":[", .{ width, n, split, layout, off, seed, reps, checksum });
                    for (before, 0..) |v, i| std.debug.print("{s}{d}", .{ if (i == 0) "" else ",", v });
                    std.debug.print("],\"after\":[", .{});
                    for (after, 0..) |v, i| std.debug.print("{s}{d}", .{ if (i == 0) "" else ",", v });
                    std.debug.print("]}}\n", .{});
                }
            }
        }
    }
}
