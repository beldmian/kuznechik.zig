const std = @import("std");
const kuz = @import("kuznechik.zig");
const B = kuz.block;
fn Adapter(comptime batch: bool) type {
    return struct {
        k: kuz.key,
        inner: kuz.Cipher,
        pub fn init(key: kuz.key) @This() {
            return .{ .k = key, .inner = kuz.Cipher.init(key) };
        }
        pub fn encrypt(self: @This(), b: *align(16) B) void {
            self.inner.encrypt(b);
        }
        pub fn decrypt(self: @This(), b: *align(16) B) void {
            self.inner.decrypt(b);
        }
        pub fn encryptBlocks(self: @This(), b: []align(16) B) void {
            if (batch) self.inner.encryptBlocks(b) else for (b) |*v| self.inner.encrypt(v);
        }
        pub fn decryptBlocks(self: @This(), b: []align(16) B) void {
            if (batch) self.inner.decryptBlocks(b) else for (b) |*v| self.inner.decrypt(v);
        }
    };
}
const Old = Adapter(false);
const New = Adapter(true);
const Result = struct { ns: u64, tag: [16]u8 };
noinline fn run(comptime kind: usize, comptime C: type, cipher: C, data: []u8) !Result {
    const M = @import("modes/acpkm.zig").Modes(C, @import("modes/classic.zig").Modes(C));
    asm volatile ("" ::: .{ .memory = true });
    var timer = try std.time.Timer.start();
    var tag: [16]u8 = @splat(0);
    if (kind == 0) {
        var m = try M.CtrAcpkm.init(cipher, @splat(0x12), 4096);
        try m.xor(data);
    } else if (kind == 1) {
        const m = try M.GcmAcpkm(32).init(cipher, 4096);
        tag = try m.seal(@splat(0x12), "paired ACPKM benchmark AAD", data);
    } else if (kind == 2) {
        var m = try M.CtrAcpkmMaster.init(cipher, @splat(0x12), 4096, 6144);
        try m.xor(data);
    } else if (kind == 3) {
        const m = try M.GcmAcpkmMaster(32).init(cipher, 4096, 6144);
        tag = try m.seal(@splat(0x12), "paired ACPKM benchmark AAD", data);
    } else if (kind == 4) {
        var m = try M.CbcAcpkmMaster.init(cipher, @splat(0x12), 4096, 6144);
        try m.encrypt(data);
    } else if (kind == 5) {
        var m = try M.CfbAcpkmMaster.init(cipher, @splat(0x12), 4096, 6144);
        try m.encrypt(data);
    } else if (kind == 6) {
        var m = try M.OmacAcpkmMaster.init(cipher, 4096, 6144);
        try m.update(data);
        tag = m.final();
    } else if (kind == 7) {
        var m = try M.CbcAcpkmMaster.init(cipher, @splat(0x12), 4096, 6144);
        try m.decrypt(data);
    } else if (kind == 8) {
        var m = try M.CfbAcpkmMaster.init(cipher, @splat(0x12), 4096, 6144);
        try m.decrypt(data);
    }
    const ns = timer.read();
    std.mem.doNotOptimizeAway(data.ptr);
    return .{ .ns = ns, .tag = tag };
}
pub fn main() !void {
    var args = std.process.args();
    _ = args.next();
    const seed = if (args.next()) |s| try std.fmt.parseInt(u64, s, 10) else 123;
    var rng = std.Random.DefaultPrng.init(seed);
    var key: kuz.key = undefined;
    rng.random().bytes(std.mem.asBytes(&key));
    const old = Old.init(key);
    const new = New.init(key);
    const initial = try std.heap.page_allocator.alloc(u8, 1048576);
    defer std.heap.page_allocator.free(initial);
    const a = try std.heap.page_allocator.alloc(u8, initial.len);
    defer std.heap.page_allocator.free(a);
    const b = try std.heap.page_allocator.alloc(u8, initial.len);
    defer std.heap.page_allocator.free(b);
    rng.random().bytes(initial);
    const names = [_][]const u8{ "CTR-ACPKM", "GCM-ACPKM-seal", "CTR-ACPKM-Master", "GCM-ACPKM-Master-seal", "CBC-Master-encrypt", "CFB-Master-encrypt", "OMAC-Master", "CBC-Master-decrypt", "CFB-Master-decrypt" };
    inline for (0..names.len) |kind| {
        for ([_]usize{ 64, 1024, 16384, 1048576 }) |n| {
            var before: [9]u64 = undefined;
            var after: [9]u64 = undefined;
            var ratios: [9]f64 = undefined;
            var checksum: u64 = 0;
            for (0..11) |j| {
                @memcpy(a[0..n], initial[0..n]);
                @memcpy(b[0..n], initial[0..n]);
                var x: Result = undefined;
                var y: Result = undefined;
                if (j % 2 == 0) {
                    x = try run(kind, Old, old, a[0..n]);
                    y = try run(kind, New, new, b[0..n]);
                } else {
                    y = try run(kind, New, new, b[0..n]);
                    x = try run(kind, Old, old, a[0..n]);
                }
                if (!std.mem.eql(u8, a[0..n], b[0..n]) or !std.meta.eql(x.tag, y.tag)) return error.Mismatch;
                checksum +%= std.hash.Wyhash.hash(j, b[0..n]);
                checksum +%= std.hash.Wyhash.hash(j, &y.tag);
                if (j < 2) continue;
                before[j - 2] = x.ns;
                after[j - 2] = y.ns;
                ratios[j - 2] = @as(f64, @floatFromInt(y.ns)) / @as(f64, @floatFromInt(x.ns));
            }
            var sorted = ratios;
            std.mem.sort(f64, &sorted, {}, std.sort.asc(f64));
            std.debug.print("{{\"mode\":\"{s}\",\"bytes\":{d},\"seed\":{d},\"section_bytes\":4096,\"lifetime_bytes\":6144,\"pairs\":9,\"warmup_pairs\":2,\"median_paired_ratio\":{d:.6},\"checksum\":{d},\"before\":[", .{ names[kind], n, seed, sorted[4], checksum });
            for (before, 0..) |v, i| std.debug.print("{s}{d}", .{ if (i == 0) "" else ",", v });
            std.debug.print("],\"after\":[", .{});
            for (after, 0..) |v, i| std.debug.print("{s}{d}", .{ if (i == 0) "" else ",", v });
            std.debug.print("]}}\n", .{});
        }
    }
}
