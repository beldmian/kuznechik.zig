const std = @import("std");
const kuz = @import("src/kuznechik.zig");
const Old = @import("src/modes/classic_before_090.zig").Modes(kuz.Cipher);
const New = kuz.modes.classic;
test "v0.9.0 feedback contexts retain every field offset size and alignment" {
    try std.testing.expectEqual(@as(usize, 352), @sizeOf(kuz.Cipher));
    inline for (.{ 1, 2, 3, 63, 64, 65, 128 }) |width| {
        inline for (.{ false, true }) |cfb| {
            const A = if (cfb) Old.Cfb(width) else Old.Cbc(width);
            const B = if (cfb) New.Cfb(width) else New.Cbc(width);
            try std.testing.expectEqual(@sizeOf(A), @sizeOf(B));
            try std.testing.expectEqual(@alignOf(A), @alignOf(B));
            try std.testing.expectEqual(std.meta.fields(A).len, std.meta.fields(B).len);
            inline for (std.meta.fields(A)) |field| {
                try std.testing.expectEqual(field.type, @FieldType(B, field.name));
                try std.testing.expectEqual(@offsetOf(A, field.name), @offsetOf(B, field.name));
            }
        }
    }
}
