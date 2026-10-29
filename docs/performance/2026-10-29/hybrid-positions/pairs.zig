//! Public API comparison. Every timing includes dispatch, padding, copies and
//! per-call encoded key preparation. JSONL on stderr; no allocation in timing.
const std = @import("std");
const builtin = @import("builtin");
const baseline = @import("baseline");
const candidate = @import("candidate");
const B = baseline.block;
const max_pairs = 41;
noinline fn apply(comptime direct: bool, comptime inverse: bool, c: anytype, data: []align(16) B) void {
    asm volatile ("" ::: .{ .memory = true });
    if (direct) {
        if (inverse) c.decrypt(&data[0]) else c.encrypt(&data[0]);
    } else {
        if (inverse) c.decryptBlocks(data) else c.encryptBlocks(data);
    }
}
noinline fn run(comptime direct: bool, comptime inverse: bool, c: anytype, data: []align(16) B, reps: usize) !u64 {
    var t = try std.time.Timer.start();
    for (0..reps) |_| apply(direct, inverse, c, data);
    const ns = t.read();
    asm volatile ("" ::: .{ .memory = true });
    std.mem.doNotOptimizeAway(data.ptr);
    return ns;
}
fn hash(data: []const B) u64 {
    var h: u64 = 0xcbf29ce484222325;
    for (std.mem.sliceAsBytes(data)) |v| h = (h ^ v) *% 0x100000001b3;
    return h;
}
fn validate(rng: std.Random) !void {
    if (@sizeOf(baseline.Cipher) != 352 or @sizeOf(candidate.Cipher) != 352) return error.LayoutChanged;
    for (0..3) |ki| {
        var key: baseline.key = undefined;
        rng.bytes(std.mem.asBytes(&key));
        if (ki == 0) key = @splat(0);
        if (ki == 1) key = @splat(255);
        const a = baseline.Cipher.init(key);
        const b = candidate.Cipher.init(key);
        for (0..128) |len| for (0..4) |offset| {
            var input: [132]B align(64) = undefined;
            rng.bytes(std.mem.asBytes(&input));
            inline for (.{ false, true }) |inv| {
                var expected = input;
                for (expected[offset..][0..len]) |*v| {
                    if (inv) a.decrypt(v) else a.encrypt(v);
                }
                var before = input;
                var after = input;
                apply(false, inv, &a, before[offset..][0..len]);
                apply(false, inv, &b, after[offset..][0..len]);
                if (!std.mem.eql(B, &before, &expected) or !std.mem.eql(B, &after, &expected)) return error.OutputOrGuardMismatch;
            }
        };
    }
    std.debug.print("{{\"type\":\"validation\",\"keys\":3,\"lengths\":128,\"offsets\":4,\"directions\":2,\"guards\":true,\"passed\":true}}\n", .{});
}
fn compare(comptime direct: bool, comptime inv: bool, a: *const baseline.Cipher, b: *const candidate.Cipher, input: []const B, pairs: usize, reps: usize) !void {
    var left: [16392]B align(64) = undefined;
    var right: [16392]B align(64) = undefined;
    const guard: B = @splat(0x93);
    var ns_a: [max_pairs]u64 = undefined;
    var ns_b: [max_pairs]u64 = undefined;
    var ratios: [max_pairs]f64 = undefined;
    for (0..pairs + 3) |j| {
        @memset(&left, guard);
        @memset(&right, guard);
        const offset = 1 + j % 4;
        const x = left[offset..][0..input.len];
        const y = right[offset..][0..input.len];
        @memcpy(x, input);
        @memcpy(y, input);
        const da = if (j % 4 < 2) x else y;
        const db = if (j % 4 < 2) y else x;
        var va: u64 = undefined;
        var vb: u64 = undefined;
        if (j % 2 == 0) {
            va = try run(direct, inv, a, da, reps);
            vb = try run(direct, inv, b, db, reps);
        } else {
            vb = try run(direct, inv, b, db, reps);
            va = try run(direct, inv, a, da, reps);
        }
        if (!std.mem.eql(B, &left, &right)) return error.OutputMismatch;
        for (left[0..offset]) |v| if (!std.meta.eql(v, guard)) return error.GuardMismatch;
        for (left[offset + input.len..]) |v| if (!std.meta.eql(v, guard)) return error.GuardMismatch;
        if (j < 3) continue;
        ns_a[j - 3] = va;
        ns_b[j - 3] = vb;
        ratios[j - 3] = @as(f64, @floatFromInt(vb)) / @as(f64, @floatFromInt(va));
    }
    std.mem.sort(f64, ratios[0..pairs], {}, std.sort.asc(f64));
    std.debug.print("{{\"type\":\"result\",\"operation\":\"{s}\",\"api\":\"{s}\",\"length\":{d},\"reps\":{d},\"pairs\":{d},\"ratio_median\":{d:.9},\"ratio_p10\":{d:.9},\"ratio_p90\":{d:.9},\"checksum\":\"{x}\",\"before\":[", .{ if (inv) "decrypt" else "encrypt", if (direct) "block" else "blocks", input.len, reps, pairs, ratios[pairs / 2], ratios[pairs / 10], ratios[pairs * 9 / 10], hash(&left) });
    for (ns_a[0..pairs], 0..) |ns, i| std.debug.print("{s}{d}", .{ if (i == 0) "" else ",", ns });
    std.debug.print("],\"after\":[", .{});
    for (ns_b[0..pairs], 0..) |ns, i| std.debug.print("{s}{d}", .{ if (i == 0) "" else ",", ns });
    std.debug.print("]}}\n", .{});
}
pub fn main() !void {
    var args = std.process.args();
    _ = args.next();
    const seed = try std.fmt.parseInt(u64, args.next() orelse return error.SeedRequired, 10);
    const pairs = try std.fmt.parseInt(usize, args.next() orelse "15", 10);
    const target_blocks = try std.fmt.parseInt(usize, args.next() orelse "1048576", 10);
    const lo = try std.fmt.parseInt(usize, args.next() orelse "1", 10);
    const hi = try std.fmt.parseInt(usize, args.next() orelse "16384", 10);
    if (pairs < 9 or pairs > max_pairs or hi > 16384 or lo > hi) return error.InvalidArgument;
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();
    std.debug.print("{{\"type\":\"config\",\"seed\":{d},\"pairs\":{d},\"target_blocks\":{d},\"warmup_pairs\":3,\"zig\":\"{s}\",\"cpu\":\"{s}\",\"optimization\":\"{s}\",\"order\":\"shuffled widths and alternating pair order, rotated buffers\"}}\n", .{ seed, pairs, target_blocks, builtin.zig_version_string, builtin.cpu.model.name, @tagName(builtin.mode) });
    try validate(random);
    var key: baseline.key = undefined;
    random.bytes(std.mem.asBytes(&key));
    const a = baseline.Cipher.init(key);
    const b = candidate.Cipher.init(key);
    var initial: [16384]B align(64) = undefined;
    random.bytes(std.mem.asBytes(&initial));
    var widths = [_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 31, 32, 47, 63, 64, 65, 127, 128, 129, 255, 256, 257, 1024, 1025, 4096, 16384 };
    random.shuffle(usize, &widths);
    for (widths) |n| {
        if (n < lo or n > hi) continue;
        const len = @max(1, n);
        const reps: usize = @max(100, target_blocks / len);
        inline for (.{ false, true }) |inv| {
            if (n == 0) try compare(true, inv, &a, &b, initial[0..1], pairs, reps)
            else try compare(false, inv, &a, &b, initial[0..n], pairs, reps);
        }
    }
}
