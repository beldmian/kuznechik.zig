const std = @import("std");
const kuz = @import("src/kuznechik.zig");
const Old = @import("src/modes/classic_before_092.zig").Modes(kuz.Cipher);
const New = kuz.modes.classic;
test "v0.9.2 feedback contexts retain every field offset size and alignment" {
    try std.testing.expectEqual(@as(usize, 352), @sizeOf(kuz.Cipher));
    inline for (.{ 1, 2, 3, 4, 8, 16, 24, 31, 32, 63, 64, 65, 128 }) |width| {
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
