const std = @import("std");
const k = @import("kuznechik.zig");
const t = @import("transitions.zig");
fn check(c: k.Cipher, input: k.block) !void {
    var expected = input;
    for (0..9) |r| expected = t.l_trans(t.s_trans(expected ^ c.ik[r]));
    expected ^= c.ik[9];
    var actual: k.block align(16) = input;
    c.encrypt(&actual);
    try std.testing.expectEqual(expected, actual);
    expected = input ^ c.ik[9];
    for (0..9) |r| expected = t.s_inv_trans(t.l_inv_trans(expected)) ^ c.ik[8-r];
    actual = input;
    c.decrypt(&actual);
    try std.testing.expectEqual(expected, actual);
}
test "positions independent basic public API all-byte basis and fresh keys" {
    try std.testing.expectEqual(@as(usize,352), @sizeOf(k.Cipher));
    var rng = std.Random.DefaultPrng.init(0x4197183659);
    for (0..16) |ki| {
        var key: k.key = undefined;
        rng.random().bytes(std.mem.asBytes(&key));
        const c = k.Cipher.init(key);
        if (ki < 2) for (0..16) |pos| { for (0..256) |v| {
            var input: k.block = @splat(0);
            input[pos] = @intCast(v);
            try check(c,input);
        }};
        for (0..256) |_| {
            var input: k.block = undefined;
            rng.random().bytes(std.mem.asBytes(&input));
            try check(c,input);
        }
    }
}
