const std = @import("std");
const kuz = @import("src/kuznechik.zig");
const Before = @import("src/modes/classic_before_092.zig").Modes(kuz.Cipher);
const After = kuz.modes.classic;
const Result = struct { ns: u64, tag: [16]u8 };
// Each repetition times context initialization, plaintext copy, and the complete
// public encryption API (whole or two updates). Key expansion/allocation excluded.
noinline fn run(comptime M: type, comptime kind: usize, comptime width: usize, cipher: kuz.Cipher, iv: [width * 16]u8, plain: []const u8, data: []u8, reps: usize, split: bool) !Result {
    const tag: [16]u8 = @splat(0);
    asm volatile ("" ::: .{ .memory = true });
    var timer = try std.time.Timer.start();
    for (0..reps) |_| {
        @memcpy(data, plain);
        if (kind == 0) {
            var ctx = M.Cfb(width).init(cipher, iv);
            if (split) ctx.encrypt(data[0..1]);
            ctx.encrypt(data[@intFromBool(split)..]);
        } else {
            var ctx = M.Cbc(width).init(cipher, iv);
            if (split) try ctx.encrypt(data[0..16]);
            try ctx.encrypt(data[if (split) @as(usize, 16) else 0 ..]);
        }
        std.mem.doNotOptimizeAway(data.ptr);
        std.mem.doNotOptimizeAway(&tag);
        asm volatile ("" ::: .{ .memory = true });
    }
    return .{ .ns = timer.read(), .tag = tag };
}
pub fn main() !void {
    var args = std.process.args();
    _ = args.next();
    const seed = if (args.next()) |s| try std.fmt.parseInt(u64, s, 10) else 123;
    const budget = if (args.next()) |s| try std.fmt.parseInt(usize, s, 10) else 262144;
    const only = if (args.next()) |s| try std.fmt.parseInt(usize, s, 10) else 99;
    const layout = if (args.next()) |s| try std.fmt.parseInt(usize, s, 10) else 0;
    var rng = std.Random.DefaultPrng.init(seed);
    var key: kuz.key = undefined;
    rng.random().bytes(std.mem.asBytes(&key));
    const cipher = kuz.Cipher.init(key);
    const initial = try std.heap.page_allocator.alloc(u8, 65536 + 16);
    const a_mem = try std.heap.page_allocator.alloc(u8, initial.len);
    const b_mem = try std.heap.page_allocator.alloc(u8, initial.len);
    rng.random().bytes(initial);
    const names = [_][]const u8{ "CFB-encrypt", "CBC-encrypt" };
    inline for (0..2) |kind| {
        if (only == 99 or only == kind) {
            inline for (.{ 1, 2, 3, 4, 8, 16, 24, 31, 32, 63, 64, 65, 128 }) |width| {
                if (true) {
                    var iv: [width * 16]u8 = undefined;
                    rng.random().bytes(&iv);
                    for ([_]usize{ 1, 15, 16, 32, 47, 48, 49, 63, 64, 65, 80, 112, 127, 128, 129, 144, 256, width * 16 - 16, width * 16, width * 16 + 16, 1008, 1024, 1040, 2048, 16384 }) |n| {
                        if (n == 0 or (kind == 1 and n % 16 != 0)) continue;
                        for ([_]bool{ false, true }) |split| {
                            const off = if (layout % 2 == 0) @as(usize, 0) else 1;
                            // Swap output buffers in the second layout to control address effects.
                            const a = (if (layout < 2) a_mem else b_mem)[off..][0..n];
                            const b = (if (layout < 2) b_mem else a_mem)[off..][0..n];
                            const plain = initial[off..][0..n];
                            const reps = @max(8, budget / n);
                            var before: [9]u64 = undefined;
                            var after: [9]u64 = undefined;
                            var checksum: u64 = 0;
                            for (0..11) |j| {
                                var x: Result = undefined;
                                var y: Result = undefined;
                                if ((j + seed) % 2 == 0) {
                                    x = try run(Before, kind, width, cipher, iv, plain, a, reps, split);
                                    y = try run(After, kind, width, cipher, iv, plain, b, reps, split);
                                } else {
                                    y = try run(After, kind, width, cipher, iv, plain, b, reps, split);
                                    x = try run(Before, kind, width, cipher, iv, plain, a, reps, split);
                                }
                                if (!std.mem.eql(u8, a, b) or !std.meta.eql(x.tag, y.tag)) return error.FullOutputMismatch;
                                checksum +%= std.hash.Wyhash.hash(j, b);
                                checksum +%= std.hash.Wyhash.hash(j, &y.tag);
                                if (j < 2) continue;
                                before[j - 2] = x.ns;
                                after[j - 2] = y.ns;
                            }
                            std.debug.print("{{\"mode\":\"{s}\",\"m\":{d},\"bytes\":{d},\"split1\":{},\"layout\":{d},\"offset\":{d},\"seed\":{d},\"reps\":{d},\"checksum\":{d},\"before\":[", .{ names[kind], width, n, split, layout, off, seed, reps, checksum });
                            for (before, 0..) |value, i| std.debug.print("{s}{d}", .{ if (i == 0) "" else ",", value });
                            std.debug.print("],\"after\":[", .{});
                            for (after, 0..) |value, i| std.debug.print("{s}{d}", .{ if (i == 0) "" else ",", value });
                            std.debug.print("]}}\n", .{});
                        }
                    }
                }
            }
        }
    }
}
