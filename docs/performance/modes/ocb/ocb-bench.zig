const std = @import("std");
const C = @import("kuznechik.zig").Cipher;
const ocb = @import("modes/ocb.zig");
const B = @Vector(16, u8);
const Scalar = struct {
    cipher: C,
    pub fn encrypt(self: @This(), b: *align(16) B) void {
        self.cipher.encrypt(b);
    }
    pub fn decrypt(self: @This(), b: *align(16) B) void {
        self.cipher.decrypt(b);
    }
    pub fn encryptBlocks(self: @This(), blocks: []align(16) B) void {
        for (blocks) |*b| self.encrypt(b);
    }
    pub fn decryptBlocks(self: @This(), blocks: []align(16) B) void {
        for (blocks) |*b| self.decrypt(b);
    }
};
var data: [1048576]u8 align(64) = @splat(0);
var saved: [1048576]u8 align(64) = undefined;
var digest: u8 = 0;
var sequence: u64 = 0;
fn trial(comptime Cipher: type, cipher: *const Cipher, n: usize, opening: bool) !u64 {
    const M = ocb.Ocb(Cipher);
    const aad: [256]u8 = @splat(0x35);
    var nonce: [12]u8 = @splat(0);
    var tag: [16]u8 = undefined;
    if (opening) {
        sequence += 1;
        std.mem.writeInt(u64, nonce[4..12], sequence, .big);
        tag = try M.seal(cipher, &nonce, &aad, data[0..n]);
        @memcpy(saved[0..n], data[0..n]);
    }
    const iterations = @max(4, 4194304 / n);
    var timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        if (opening) {
            // Include the ciphertext reset copy, identically in both paths.
            @memcpy(data[0..n], saved[0..n]);
            try M.open(cipher, &nonce, &aad, data[0..n], tag);
            digest +%= data[0];
        } else {
            sequence += 1;
            std.mem.writeInt(u64, nonce[4..12], sequence, .big);
            tag = try M.seal(cipher, &nonce, &aad, data[0..n]);
            digest +%= tag[0];
        }
    }
    const ns = timer.read();
    std.mem.doNotOptimizeAway(&data);
    return ns;
}
pub fn main() !void {
    const c = C.init(@splat(0x42));
    const scalar = Scalar{ .cipher = c };
    std.debug.print("size,operation,pair,order,serial_ns,batch_ns,bytes\n", .{});
    for ([_]usize{ 1024, 16384, 1048576 }) |n| {
        for ([_]bool{ false, true }) |opening| {
            _ = try trial(C, &c, n, opening);
            _ = try trial(Scalar, &scalar, n, opening);
            for (0..7) |pair| {
                var a: u64 = undefined;
                var b: u64 = undefined;
                if (pair % 2 == 0) {
                    a = try trial(Scalar, &scalar, n, opening);
                    b = try trial(C, &c, n, opening);
                } else {
                    b = try trial(C, &c, n, opening);
                    a = try trial(Scalar, &scalar, n, opening);
                }
                std.debug.print("{d},{s},{d},{s},{d},{d},{d}\n", .{ n, if (opening) "open_with_copy" else "seal", pair, if (pair % 2 == 0) "serial_first" else "batch_first", a, b, @max(4, 4194304 / n) * n });
            }
        }
    }
    std.debug.print("digest={d}\n", .{digest});
}
