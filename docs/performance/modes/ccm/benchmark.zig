const std = @import("std");
const k = @import("kuznechik.zig");
const factory = @import("modes/ccm.zig").Ccm;
const B = k.block;
fn Adapter(comptime batch: bool) type {
    return struct {
        const S = @This();
        inner: k.Cipher,
        pub fn encrypt(s: S, b: *align(16) B) void {
            s.inner.encrypt(b);
        }
        pub fn encryptBlocks(s: S, b: []align(16) B) void {
            if (batch) s.inner.encryptBlocks(b) else for (b) |*v| s.inner.encrypt(v);
        }
    };
}
const A = Adapter(false);
const C = Adapter(true);
const Old = factory(A, 3);
const New = factory(C, 3);
const samples = 9;
noinline fn seal(comptime mode: type, c: anytype, data: []u8) !struct { ns: u64, tag: [16]u8 } {
    asm volatile ("" ::: .{ .memory = true });
    var timer = try std.time.Timer.start();
    const tag = try mode.seal(c, @splat(0), "CCM performance associated data", data);
    const ns = timer.read();
    std.mem.doNotOptimizeAway(data.ptr);
    return .{ .ns = ns, .tag = tag };
}
noinline fn open(comptime mode: type, c: anytype, data: []u8, tag: [16]u8) !u64 {
    asm volatile ("" ::: .{ .memory = true });
    var timer = try std.time.Timer.start();
    try mode.open(c, @splat(0), "CCM performance associated data", data, tag);
    const ns = timer.read();
    std.mem.doNotOptimizeAway(data.ptr);
    return ns;
}
pub fn main() !void {
    var args = std.process.args();
    _ = args.next();
    const seed = if (args.next()) |s| try std.fmt.parseInt(u64, s, 10) else 123;
    var rng = std.Random.DefaultPrng.init(seed);
    var key: k.key = undefined;
    rng.random().bytes(std.mem.asBytes(&key));
    const cipher = k.Cipher.init(key);
    const old = A{ .inner = cipher };
    const new = C{ .inner = cipher };
    const initial = try std.heap.page_allocator.alloc(u8, 1048576);
    defer std.heap.page_allocator.free(initial);
    rng.random().bytes(initial);
    for ([_]usize{ 1024, 65536, 1048576 }) |n| {
        const a = try std.heap.page_allocator.alloc(u8, n);
        defer std.heap.page_allocator.free(a);
        const b = try std.heap.page_allocator.alloc(u8, n);
        defer std.heap.page_allocator.free(b);
        const encrypted = try std.heap.page_allocator.alloc(u8, n);
        defer std.heap.page_allocator.free(encrypted);
        @memcpy(encrypted, initial[0..n]);
        const authenticated = try seal(New, &new, encrypted);
        inline for (.{ false, true }) |opening| {
            var before: [samples]u64 = undefined;
            var after: [samples]u64 = undefined;
            var ratios: [samples]f64 = undefined;
            for (0..samples + 2) |j| {
                const input = if (opening) encrypted else initial[0..n];
                @memcpy(a, input);
                @memcpy(b, input);
                var x: struct { ns: u64, tag: [16]u8 } = undefined;
                var y: @TypeOf(x) = undefined;
                const i = j;
                if (opening) {
                    if (i % 2 == 0) {
                        x = .{ .ns = try open(Old, &old, a, authenticated.tag), .tag = authenticated.tag };
                        y = .{ .ns = try open(New, &new, b, authenticated.tag), .tag = authenticated.tag };
                    } else {
                        y = .{ .ns = try open(New, &new, b, authenticated.tag), .tag = authenticated.tag };
                        x = .{ .ns = try open(Old, &old, a, authenticated.tag), .tag = authenticated.tag };
                    }
                } else {
                    if (i % 2 == 0) {
                        const v = try seal(Old, &old, a);
                        x = .{ .ns = v.ns, .tag = v.tag };
                        const w = try seal(New, &new, b);
                        y = .{ .ns = w.ns, .tag = w.tag };
                    } else {
                        const w = try seal(New, &new, b);
                        y = .{ .ns = w.ns, .tag = w.tag };
                        const v = try seal(Old, &old, a);
                        x = .{ .ns = v.ns, .tag = v.tag };
                    }
                }
                if (!std.mem.eql(u8, a, b) or !std.meta.eql(x.tag, y.tag)) return error.Mismatch;
                if (opening and !std.mem.eql(u8, a, initial[0..n])) return error.PlaintextMismatch;
                if (j < 2) continue;
                before[j - 2] = x.ns;
                after[j - 2] = y.ns;
                ratios[j - 2] = @as(f64, @floatFromInt(y.ns)) / @as(f64, @floatFromInt(x.ns));
            }
            var sorted = ratios;
            std.mem.sort(f64, &sorted, {}, std.sort.asc(f64));
            std.debug.print("{{\"mode\":\"CCM\",\"operation\":\"{s}\",\"seed\":{d},\"bytes\":{d},\"pairs\":9,\"warmup_pairs\":2,\"median_paired_ratio\":{d:.6},\"before\":[", .{ if (opening) "open" else "seal", seed, n, sorted[4] });
            for (before, 0..) |v, i| std.debug.print("{s}{d}", .{ if (i == 0) "" else ",", v });
            std.debug.print("],\"after\":[", .{});
            for (after, 0..) |v, i| std.debug.print("{s}{d}", .{ if (i == 0) "" else ",", v });
            std.debug.print("]}}\n", .{});
        }
    }
}
