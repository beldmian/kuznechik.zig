const std = @import("std");
const kuz = @import("src/kuznechik.zig");
const Old = @import("src/modes/classic_before_093.zig").Modes(kuz.Cipher);
const New = kuz.modes.classic;
// Compatibility even when callers change direction on the same context. The
// baseline inverse fast path deliberately leaves stream/feedback untouched.
fn compare(a: anytype, b: anytype) !void {
    inline for (std.meta.fields(@TypeOf(a))) |field| {
        try std.testing.expect(std.meta.eql(@field(a, field.name), @field(b, field.name)));
    }
}
test "feedback state continuation agrees with v0.9.3 across direction changes" {
    @setEvalBranchQuota(100000);
    var rng = std.Random.DefaultPrng.init(0x436f6e74696e7565);
    var key: kuz.key = undefined;
    rng.random().bytes(std.mem.asBytes(&key));
    const cipher = kuz.Cipher.init(key);
    inline for (.{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 128 }) |width| {
        var iv: [width * 16]u8 = undefined;
        rng.random().bytes(&iv);
        inline for (.{ false, true }) |cfb| {
            var a = if (cfb) Old.Cfb(width).init(cipher, iv) else Old.Cbc(width).init(cipher, iv);
            var b = if (cfb) New.Cfb(width).init(cipher, iv) else New.Cbc(width).init(cipher, iv);
            for (0..256) |i| {
                var x: [2160]u8 = undefined;
                rng.random().bytes(&x);
                var y = x;
                const n = if (cfb) rng.random().uintLessThan(usize, x.len + 1) else rng.random().uintLessThan(usize, x.len / 16 + 1) * 16;
                if (cfb) {
                    if (i % 3 == 0) {
                        a.decrypt(x[0..n]);
                        b.decrypt(y[0..n]);
                    } else {
                        a.encrypt(x[0..n]);
                        b.encrypt(y[0..n]);
                    }
                } else {
                    if (i % 3 == 0) {
                        try a.decrypt(x[0..n]);
                        try b.decrypt(y[0..n]);
                    } else {
                        try a.encrypt(x[0..n]);
                        try b.encrypt(y[0..n]);
                    }
                }
                try std.testing.expectEqualSlices(u8, &x, &y);
                try compare(a, b);
            }
        }
    }
}
