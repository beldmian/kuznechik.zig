//! Transpose 64 independent 16-byte blocks with four lane-local 16x16
//! transposes. Columns intentionally retain lane-permuted block order:
//! columns[position][lane * 16 + row] = messages[row * 4 + lane][position].
//! Cipher rounds broadcast keys by byte position, so this permutation is free.
//! The same register transpose is its own inverse.
pub const Block = @Vector(16, u8);
pub const W = @Vector(64, u8);

inline fn unpack(comptime bits: usize, comptime high: bool, a: W, b: W) W {
    const mnemonic = switch (bits) {
        8 => if (high) "vpunpckhbw" else "vpunpcklbw",
        16 => if (high) "vpunpckhwd" else "vpunpcklwd",
        32 => if (high) "vpunpckhdq" else "vpunpckldq",
        64 => if (high) "vpunpckhqdq" else "vpunpcklqdq",
        else => @compileError("invalid unpack width"),
    };
    return asm (mnemonic ++ " %[b], %[a], %[out]"
        : [out] "=v" (-> W),
        : [a] "v" (a),
          [b] "v" (b),
    );
}

pub inline fn transpose(values: [16]W) [16]W {
    var current = values;
    inline for (.{ 8, 16, 32, 64 }, .{ 2, 4, 8, 16 }) |bits, group_size| {
        var next: [16]W = undefined;
        inline for (0..16 / group_size) |group| {
            const base = group * group_size;
            inline for (0..group_size / 2) |j| {
                next[base + j * 2] = unpack(bits, false, current[base + j], current[base + j + group_size / 2]);
                next[base + j * 2 + 1] = unpack(bits, true, current[base + j], current[base + j + group_size / 2]);
            }
        }
        current = next;
    }
    return current;
}

pub inline fn load(input: *align(16) const [64]Block) [16]W {
    const vectors: *align(16) const [16]W = @ptrCast(input);
    return transpose(vectors.*);
}

pub inline fn store(output: *align(16) [64]Block, columns: [16]W) void {
    const vectors: *align(16) [16]W = @ptrCast(output);
    vectors.* = transpose(columns);
}

test "byte transpose mapping and inverse at every block alignment" {
    if (comptime !@import("gfni.zig").supported) return error.SkipZigTest;
    const std = @import("std");
    var prng = std.Random.DefaultPrng.init(0x7472616e73706f73);
    var input: [68]Block align(64) = undefined;
    prng.random().bytes(std.mem.asBytes(&input));
    for (0..4) |offset| {
        const columns = load(input[offset..][0..64]);
        for (0..16) |position| {
            for (0..4) |lane| {
                for (0..16) |row| {
                    try std.testing.expectEqual(input[offset + row * 4 + lane][position], columns[position][lane * 16 + row]);
                }
            }
        }
        var output = input;
        @memset(output[offset..][0..64], @as(Block, @splat(0)));
        store(output[offset..][0..64], columns);
        try std.testing.expectEqual(input, output);
    }
}
