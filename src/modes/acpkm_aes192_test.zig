//! Test-only AES-192: FIPS197 key expansion and the standard library's AES rounds.
const std = @import("std");
const B = @Vector(16, u8);
const Block = std.crypto.core.aes.Block;
pub const Aes192 = struct {
    k: @Vector(24, u8),
    round_keys: [13]Block,
    fn mul(a0: u8, b0: u8) u8 {
        var a = a0;
        var b = b0;
        var x: u8 = 0;
        for (0..8) |_| {
            if (b & 1 != 0) x ^= a;
            a = (a << 1) ^ (if (a & 0x80 != 0) @as(u8, 0x1b) else 0);
            b >>= 1;
        }
        return x;
    }
    fn sbox(a: u8) u8 {
        var inverse: u8 = 1;
        for (0..254) |_| inverse = mul(inverse, a);
        return inverse ^ std.math.rotl(u8, inverse, 1) ^ std.math.rotl(u8, inverse, 2) ^ std.math.rotl(u8, inverse, 3) ^ std.math.rotl(u8, inverse, 4) ^ 0x63;
    }
    const s = blk: {
        @setEvalBranchQuota(2000000);
        var table: [256]u8 = undefined;
        for (&table, 0..) |*x, i| x.* = sbox(@intCast(i));
        break :blk table;
    };
    // Keep the input as bytes: Zig 0.15.2 AArch64 LLVM ReleaseSafe corrupts
    // the tail of the 24-lane vector argument during in-context ACPKM rekeying.
    // The .k field remains a vector for the generic mode's key-size metadata.
    pub fn init(k: [24]u8) Aes192 {
        var expanded: [208]u8 = undefined;
        expanded[0..24].* = k;
        var rcon: u8 = 1;
        for (6..52) |word| {
            var temp = expanded[(word - 1) * 4 ..][0..4].*;
            if (word % 6 == 0) {
                const previous = temp;
                temp = .{ s[previous[1]] ^ rcon, s[previous[2]], s[previous[3]], s[previous[0]] };
                rcon = mul(rcon, 2);
            }
            for (0..4) |j| expanded[word * 4 + j] = expanded[(word - 6) * 4 + j] ^ temp[j];
        }
        var self = Aes192{ .k = k, .round_keys = undefined };
        for (&self.round_keys, 0..) |*rk, i| rk.* = Block.fromBytes(expanded[i * 16 ..][0..16]);
        return self;
    }
    pub fn encrypt(self: Aes192, value: *align(16) B) void {
        const input: [16]u8 = value.*;
        var block = Block.fromBytes(&input).xorBlocks(self.round_keys[0]);
        for (1..12) |i| block = block.encrypt(self.round_keys[i]);
        value.* = block.encryptLast(self.round_keys[12]).toBytes();
    }
    pub fn encryptBlocks(self: Aes192, blocks: []align(16) B) void {
        for (blocks) |*block| self.encrypt(block);
    }
};
test "test-only AES192 matches FIPS197 C.2" {
    const h = @import("test_helpers.zig");
    const cipher = Aes192.init(h.hex("000102030405060708090a0b0c0d0e0f1011121314151617"));
    var block: B = h.hex("00112233445566778899aabbccddeeff");
    cipher.encrypt(&block);
    try std.testing.expectEqual(h.hex("dda97ca4864cdfe06eaf70a0ec0d7191"), @as([16]u8, block));
}
