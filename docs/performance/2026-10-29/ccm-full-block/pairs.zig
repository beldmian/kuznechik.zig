const std = @import("std");
const builtin = @import("builtin");
const k = @import("cipher");
const Old = k.modes.CcmWithLength(3);
const newlib = @import("new");
const New = newlib.modes.CcmWithLength(3);
const samples = 21;
const Result = struct { ns: u64 };
const Nonce = Old.Nonce;
const aad = "CCM full-block performance associated data";
noinline fn run(comptime M: type, comptime opening: bool, c: anytype, data: []u8, tags: [][16]u8, nonces: []const Nonce, n: usize, stride: usize) !u64 {
    asm volatile ("" ::: .{ .memory = true });
    var timer = try std.time.Timer.start();
    for (tags, nonces, 0..) |*tag, nonce, i| {
        const message = data[i * stride + 1 ..][0..n];
        if (opening) try M.open(c, nonce, aad, message, tag.*) else tag.* = try M.seal(c, nonce, aad, message);
    }
    const ns = timer.read();
    asm volatile ("" ::: .{ .memory = true });
    return ns;
}
fn compare(comptime opening: bool, c: *const k.Cipher, other: *const newlib.Cipher, n: usize, rng: std.Random) !void {
    const alloc = std.heap.page_allocator;
    const count = @max(4, 1048576 / (n + 64));
    const stride = n + 32;
    const initial = try alloc.alloc(u8, count * stride);
    defer alloc.free(initial);
    const encrypted = try alloc.alloc(u8, initial.len);
    defer alloc.free(encrypted);
    const a = try alloc.alloc(u8, initial.len);
    defer alloc.free(a);
    const b = try alloc.alloc(u8, initial.len);
    defer alloc.free(b);
    const ta = try alloc.alloc([16]u8, count);
    defer alloc.free(ta);
    const tb = try alloc.alloc([16]u8, count);
    defer alloc.free(tb);
    const tags = try alloc.alloc([16]u8, count);
    defer alloc.free(tags);
    const nonces = try alloc.alloc(Nonce, count);
    defer alloc.free(nonces);
    rng.bytes(initial);
    for (nonces, 0..) |*v, i| {
        @memset(v, 0);
        std.mem.writeInt(u64, v[0..8], i, .big);
    }
    @memcpy(encrypted, initial);
    _ = try run(Old, false, c, encrypted, tags, nonces, n, stride);
    var ns_a: [samples]u64 = undefined;
    var ns_b: [samples]u64 = undefined;
    var ratios: [samples]f64 = undefined;
    for (0..samples + 3) |j| {
        const input = if (opening) encrypted else initial;
        @memcpy(a, input);
        @memcpy(b, input);
        @memcpy(ta, tags);
        @memcpy(tb, tags);
        const da = if (j % 4 < 2) a else b;
        const db = if (j % 4 < 2) b else a;
        var va: u64 = undefined;
        var vb: u64 = undefined;
        if (rng.boolean()) {
            va = try run(Old, opening, c, da, ta, nonces, n, stride);
            vb = try run(New, opening, other, db, tb, nonces, n, stride);
        } else {
            vb = try run(New, opening, other, db, tb, nonces, n, stride);
            va = try run(Old, opening, c, da, ta, nonces, n, stride);
        }
        const expected = if (opening) initial else encrypted;
        if (!std.mem.eql(u8, expected, a) or !std.mem.eql(u8, expected, b)) return error.OutputOrGuardMismatch;
        if (!std.mem.eql(u8, std.mem.sliceAsBytes(tags), std.mem.sliceAsBytes(ta)) or !std.mem.eql(u8, std.mem.sliceAsBytes(tags), std.mem.sliceAsBytes(tb))) return error.TagMismatch;
        if (j < 3) continue;
        ns_a[j - 3] = va;
        ns_b[j - 3] = vb;
        ratios[j - 3] = @as(f64, @floatFromInt(vb)) / @as(f64, @floatFromInt(va));
    }
    std.mem.sort(f64, &ratios, {}, std.sort.asc(f64));
    std.debug.print("{{\"type\":\"result\",\"operation\":\"{s}\",\"length\":{d},\"reps\":{d},\"pairs\":21,\"ratio_median\":{d:.9},\"ratio_p10\":{d:.9},\"ratio_p90\":{d:.9},\"checksum\":\"{x}\",\"before\":[", .{ if (opening) "open" else "seal", n, count, ratios[samples / 2], ratios[samples / 10], ratios[samples * 9 / 10], std.hash.Wyhash.hash(0, b) });
    for (ns_a, 0..) |ns, i| std.debug.print("{s}{d}", .{ if (i == 0) "" else ",", ns });
    std.debug.print("],\"after\":[", .{});
    for (ns_b, 0..) |ns, i| std.debug.print("{s}{d}", .{ if (i == 0) "" else ",", ns });
    std.debug.print("]}}\n", .{});
}
pub fn main() !void {
    var args = std.process.args();
    _ = args.next();
    const seed = try std.fmt.parseInt(u64, args.next() orelse return error.SeedRequired, 10);
    var prng = std.Random.DefaultPrng.init(seed);
    const rng = prng.random();
    var key: k.key = undefined;
    rng.bytes(std.mem.asBytes(&key));
    const c = k.Cipher.init(key);
    const other = newlib.Cipher.init(key);
    std.debug.print("{{\"type\":\"config\",\"seed\":{d},\"pairs\":21,\"warmup_pairs\":3,\"zig\":\"{s}\",\"cpu\":\"{s}\",\"optimization\":\"{s}\",\"aad_bytes\":{d},\"unaligned\":true,\"rotating_buffers\":true}}\n", .{ seed, builtin.zig_version_string, builtin.cpu.model.name, @tagName(builtin.mode), aad.len });
    std.debug.print("{{\"type\":\"validation\",\"method\":\"released CCM outputs, all bytes and tags, guards on every sample\",\"passed\":true}}\n", .{});
    var widths = [_]usize{ 0, 1, 15, 16, 17, 31, 32, 33, 255, 1023, 1024, 1025, 65536, 1048576 };
    rng.shuffle(usize, &widths);
    for (widths) |n| inline for (.{ false, true }) |opening| try compare(opening, &c, &other, n, rng);
}
