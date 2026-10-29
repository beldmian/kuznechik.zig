//! Differential byte-alignment and auth-before-write checks against v0.5.0.
const std = @import("std");
const old = @import("baseline");
const new = @import("candidate");
test "CCM direct blocks match released outputs at all byte offsets" {
    var rng = std.Random.DefaultPrng.init(0x43434d4449524543);
    const random = rng.random();
    var key: old.key = undefined;
    random.bytes(std.mem.asBytes(&key));
    const a = old.Cipher.init(key);
    const b = new.Cipher.init(key);
    try std.testing.expectEqual(@as(usize, 352), @sizeOf(new.Cipher));
    var plain: [1057]u8 = undefined;
    var aad_bytes: [64]u8 = undefined;
    random.bytes(&plain);
    random.bytes(&aad_bytes);
    inline for (.{ 2, 3, 8 }) |l| {
        const A = old.modes.CcmWithLength(l);
        const B = new.modes.CcmWithLength(l);
        var nonce: A.Nonce = undefined;
        random.bytes(&nonce);
        for (0..16) |offset| {
            for ([_]usize{ 0, 1, 14, 15, 16, 17, 31, 32, 33 }) |aad_len| {
                const aad = aad_bytes[offset..][0..aad_len];
                for ([_]usize{ 0, 1, 15, 16, 17, 31, 32, 33, 1023, 1024, 1025, 1057 }) |n| {
                    var left: [1089]u8 = @splat(0xa5);
                    @memcpy(left[offset..][0..n], plain[0..n]);
                    var right = left;
                    const initial = left;
                    var ta: [16]u8 = @splat(0x93);
                    var tb = ta;
                    const tag_len: usize = switch ((n + aad_len + offset) % 3) {
                        0 => 4,
                        1 => 8,
                        else => 16,
                    };
                    try A.sealDetached(&a, nonce, aad, left[offset..][0..n], ta[0..tag_len]);
                    try B.sealDetached(&b, nonce, aad, right[offset..][0..n], tb[0..tag_len]);
                    try std.testing.expectEqual(left, right);
                    try std.testing.expectEqual(ta, tb);
                    const ciphertext = right;
                    var bad = tb;
                    bad[0] ^= 1;
                    try std.testing.expectError(error.AuthenticationFailed, B.openDetached(&b, nonce, aad, right[offset..][0..n], bad[0..tag_len]));
                    try std.testing.expectEqual(ciphertext, right);
                    try B.openDetached(&b, nonce, aad, right[offset..][0..n], ta[0..tag_len]);
                    try std.testing.expectEqual(initial, right);
                }
            }
        }
    }
}
