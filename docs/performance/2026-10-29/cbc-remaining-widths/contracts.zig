const std = @import("std");
const kuz = @import("src/kuznechik.zig");
const Old = @import("src/modes/classic_before_093.zig").Modes(kuz.Cipher);
const New = kuz.modes.classic;
test "v0.9.3 feedback contexts retain every field offset size and alignment" {
    @setEvalBranchQuota(100000);
    try std.testing.expectEqual(@as(usize, 352), @sizeOf(kuz.Cipher));
    inline for (.{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 128 }) |width| {
        inline for (.{ false, true }) |cfb| {
            const A = if (cfb) Old.Cfb(width) else Old.Cbc(width);
            const B = if (cfb) New.Cfb(width) else New.Cbc(width);
            try std.testing.expectEqual(@sizeOf(A), @sizeOf(B));
            try std.testing.expectEqual(@alignOf(A), @alignOf(B));
            try std.testing.expectEqual(std.meta.fields(A).len, std.meta.fields(B).len);
            if (!cfb) {
                var ctx = B.init(kuz.Cipher.init(@splat(0x73)), @splat(0x51));
                var data: [256]u8 = @splat(0xa7);
                try ctx.encrypt(data[0..16]);
                const saved = ctx;
                const saved_data = data;
                for ([_]usize{ 1, 15, 17, 47, 49, 63, 65, 127, 129, 255 }) |n| {
                    try std.testing.expectError(error.InvalidLength, ctx.encrypt(data[0..n]));
                    try std.testing.expect(std.meta.eql(saved, ctx));
                    try std.testing.expectEqual(saved_data, data);
                }
            }
            inline for (std.meta.fields(A)) |field| {
                try std.testing.expectEqual(field.type, @FieldType(B, field.name));
                try std.testing.expectEqual(@offsetOf(A, field.name), @offsetOf(B, field.name));
            }
        }
    }
}
