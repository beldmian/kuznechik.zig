const std = @import("std");
const builtin = @import("builtin");
const kuz = @import("kuz");
pub fn main() void {
    const feature = std.Target.x86.featureSetHas;
    std.debug.print("Zig={s}; CPU={s}; GFNI={}; AVX2={}; AVX512VL={}; Cipher={d} bytes\n", .{
        builtin.zig_version_string,
        builtin.cpu.model.name,
        feature(builtin.cpu.features, .gfni),
        feature(builtin.cpu.features, .avx2),
        feature(builtin.cpu.features, .avx512vl),
        @sizeOf(kuz.Cipher),
    });
}
