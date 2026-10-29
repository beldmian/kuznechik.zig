const std = @import("std");
const C = @import("kuznechik.zig").Cipher;
const B = @Vector(16, u8);
const Scalar = struct {
    k: @Vector(32, u8),
    cipher: C,
    pub fn init(k: @Vector(32, u8)) @This() {
        return .{ .k = k, .cipher = C.init(k) };
    }
    pub fn encrypt(s: @This(), b: *align(16) B) void {
        s.cipher.encrypt(b);
    }
    pub fn decrypt(s: @This(), b: *align(16) B) void {
        s.cipher.decrypt(b);
    }
    pub fn encryptBlocks(s: @This(), b: []align(16) B) void {
        for (b) |*v| s.encrypt(v);
    }
    pub fn decryptBlocks(s: @This(), b: []align(16) B) void {
        for (b) |*v| s.decrypt(v);
    }
};
var sink: u8 = 0;
fn run(comptime Cipher: type, comptime kind: usize, data: []u8, iterations: usize) !u64 {
    const M = @import("modes/acpkm.zig").Modes(Cipher, @import("modes/classic.zig").Modes(Cipher));
    const cipher = Cipher.init(@splat(0x32));
    var timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        if (kind == 0) {
            var m = try M.CtrAcpkm.init(cipher, @splat(0x12), 4096);
            try m.xor(data);
        }
        if (kind == 1) {
            const m = try M.GcmAcpkm(32).init(cipher, 4096);
            const tag = try m.seal(@splat(0x12), &.{}, data);
            sink ^= tag[0];
        }
        if (kind == 2) {
            var m = try M.CtrAcpkmMaster.init(cipher, @splat(0x12), 4096, 6144);
            try m.xor(data);
        }
        if (kind == 3) {
            const m = try M.GcmAcpkmMaster(32).init(cipher, 4096, 6144);
            const tag = try m.seal(@splat(0x12), &.{}, data);
            sink ^= tag[0];
        }
        if (kind == 4) {
            var m = try M.CbcAcpkmMaster.init(cipher, @splat(0x12), 4096, 6144);
            try m.encrypt(data);
        }
        if (kind == 5) {
            var m = try M.CfbAcpkmMaster.init(cipher, @splat(0x12), 4096, 6144);
            try m.encrypt(data);
        }
        if (kind == 6) {
            var m = try M.OmacAcpkmMaster.init(cipher, 4096, 6144);
            try m.update(data);
            const tag = m.final();
            sink ^= tag[0];
        }
        if (kind == 7) {
            var m = try M.CbcAcpkmMaster.init(cipher, @splat(0x12), 4096, 6144);
            try m.decrypt(data);
        }
        if (kind == 8) {
            var m = try M.CfbAcpkmMaster.init(cipher, @splat(0x12), 4096, 6144);
            try m.decrypt(data);
        }
        std.mem.doNotOptimizeAway(data.ptr);
        sink ^= data[0];
    }
    return timer.read();
}
pub fn main() !void {
    const data = try std.heap.page_allocator.alloc(u8, 1048576);
    defer std.heap.page_allocator.free(data);
    @memset(data, 0x64);
    const names = [_][]const u8{ "ctr", "gcm", "ctr-master", "gcm-master", "cbc-master-encrypt", "cfb-master-encrypt", "omac-master", "cbc-master-decrypt", "cfb-master-decrypt" };
    inline for (0..9) |kind| {
        for ([_]usize{ 64, 1024, 16384, 1048576 }) |n| {
            inline for (.{ C, Scalar }) |Cipher| {
                var iterations: usize = 1;
                while (try run(Cipher, kind, data[0..n], iterations) < 20000000) iterations *= 2;
                var times: [5]u64 = undefined;
                for (&times) |*elapsed| elapsed.* = try run(Cipher, kind, data[0..n], iterations);
                std.mem.sort(u64, &times, {}, std.sort.asc(u64));
                const mib_s = @as(f64, @floatFromInt(n * iterations)) * 1e9 / (@as(f64, @floatFromInt(times[2])) * 1048576);
                std.debug.print("{{\"mode\":\"{s}\",\"bytes\":{d},\"batch\":{},\"iterations\":{d},\"median_ns\":{d},\"mib_s\":{d:.3}}}\n", .{ names[kind], n, Cipher == C, iterations, times[2], mib_s });
            }
        }
    }
    std.debug.print("checksum={d}\n", .{sink});
}
