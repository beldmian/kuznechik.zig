const std = @import("std");
const B = @Vector(16, u8);
pub fn hex(comptime text: []const u8) [text.len / 2]u8 {
    if (text.len % 2 != 0) @compileError("hex fixture has an odd number of digits");
    var bytes: [text.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, text) catch unreachable;
    return bytes;
}
pub fn AesAdapter(comptime Aes: type) type {
    return struct {
        const Self = @This();
        pub const Key = @Vector(Aes.key_bits / 8, u8);
        k: Key,
        enc: std.crypto.core.aes.AesEncryptCtx(Aes),
        dec: std.crypto.core.aes.AesDecryptCtx(Aes),
        pub fn init(key: Key) Self {
            const bytes: [Aes.key_bits / 8]u8 = key;
            return .{ .k = key, .enc = Aes.initEnc(bytes), .dec = Aes.initDec(bytes) };
        }
        pub fn encrypt(self: Self, block: *align(16) B) void {
            const input: [16]u8 = block.*;
            var output: [16]u8 = undefined;
            self.enc.encrypt(&output, &input);
            block.* = output;
        }
        pub fn decrypt(self: Self, block: *align(16) B) void {
            const input: [16]u8 = block.*;
            var output: [16]u8 = undefined;
            self.dec.decrypt(&output, &input);
            block.* = output;
        }
        pub fn encryptBlocks(self: Self, blocks: []align(16) B) void {
            for (blocks) |*block| self.encrypt(block);
        }
        pub fn decryptBlocks(self: Self, blocks: []align(16) B) void {
            for (blocks) |*block| self.decrypt(block);
        }
    };
}
pub const Aes128 = AesAdapter(std.crypto.core.aes.Aes128);
pub const Aes256 = AesAdapter(std.crypto.core.aes.Aes256);
