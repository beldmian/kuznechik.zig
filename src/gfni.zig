//! AVX-512 VBMI/GFNI batch kernel. The caller must check target features.
//! Four independent blocks occupy the four 128-bit lanes of each vector.
const definitions = @import("definitions.zig");
const transitions = @import("transitions.zig");
const B = definitions.block;
const W = @Vector(64, u8);
// Zig 0.15's self-hosted x86 Debug backend does not implement the AVX-512
// register constraints. Keep its portable path, even on capable hardware.
// Zig 0.15.1 LLVM also cannot allocate these vector operands with AVX2
// disabled, even if the AVX-512 features remain enabled in the target.
pub const supported = @import("builtin").zig_backend == .stage2_llvm and @import("builtin").cpu.arch == .x86_64 and
    @import("std").Target.x86.featureSetHasAll(@import("builtin").cpu.features, &.{ .avx2, .gfni, .avx512f, .avx512bw, .avx512vbmi, .evex512 });

fn aesMul(a_in: u8, b_in: u8) u8 {
    var a = a_in;
    var b = b_in;
    var out: u8 = 0;
    for (0..8) |_| {
        if (b & 1 != 0) out ^= a;
        const high = a & 0x80 != 0;
        a = (a << 1) ^ @as(u8, if (high) 0x1b else 0);
        b >>= 1;
    }
    return out;
}

// 0x30 is a root of x^8+x^7+x^6+x+1 in the AES field.
// Substitution x -> 0x30 maps Kuznechik's field into GFNI's field.
const basis = blk: {
    var b: [8]u8 = undefined;
    b[0] = 1;
    for (1..8) |i| b[i] = aesMul(b[i - 1], 0x30);
    break :blk b;
};
pub fn toAes(x: u8) u8 {
    var out: u8 = 0;
    for (0..8) |i| if ((x >> @intCast(i)) & 1 != 0) {
        out ^= basis[i];
    };
    return out;
}
const inverse_map = blk: {
    @setEvalBranchQuota(100000);
    var table: [256]u8 = undefined;
    for (0..256) |i| table[toAes(@intCast(i))] = @intCast(i);
    break :blk table;
};
pub fn affineMatrix(comptime inverse: bool) u64 {
    @setEvalBranchQuota(100000);
    var matrix: u64 = 0;
    for (0..8) |output_bit| {
        var row: u8 = 0;
        for (0..8) |input_bit| {
            const x = @as(u8, 1) << @intCast(input_bit);
            const y = if (inverse) inverse_map[x] else toAes(x);
            row |= ((y >> @intCast(output_bit)) & 1) << @intCast(input_bit);
        }
        matrix |= @as(u64, row) << @intCast((7 - output_bit) * 8);
    }
    return matrix;
}
fn substitution(comptime inverse: bool) [4]W {
    @setEvalBranchQuota(100000);
    var table: [256]u8 = undefined;
    for (0..256) |i| {
        const p = if (inverse) definitions.pi_inv_table[i] else definitions.pi_table[i];
        table[toAes(@intCast(i))] = toAes(p);
    }
    var out: [4]W = undefined;
    for (0..4) |i| out[i] = table[i * 64 ..][0..64].*;
    return out;
}
fn diagonalColumns(comptime inverse: bool) [16]W {
    @setEvalBranchQuota(1000000);
    var basis_columns: [16]B = undefined;
    for (0..16) |i| {
        var v: B = @splat(0);
        v[i] = 1;
        basis_columns[i] = if (inverse) transitions.l_inv_trans(v) else transitions.l_trans(v);
    }
    var table: [16]W = undefined;
    for (0..16) |rotation| {
        for (0..64) |j| {
            const output = j % 16;
            table[rotation][j] = toAes(basis_columns[(output + rotation) % 16][output]);
        }
    }
    return table;
}
const enc_s = substitution(false);
const dec_s = substitution(true);
const enc_diag = diagonalColumns(false);
const dec_diag = diagonalColumns(true);

// PALIGNR rotates each 128-bit block independently; the coefficients are the
// corresponding cyclic diagonals of L. Rotation zero needs no instruction.
inline fn rotate(a: W, comptime i: usize) W {
    if (i == 0) return a;
    return asm ("vpalignr %[i], %[a], %[a], %[out]"
        : [out] "=v" (-> W),
        : [a] "v" (a),
          [i] "n" (i),
    );
}
inline fn affine(a: W, comptime inverse: bool) W {
    const matrix: @Vector(8, u64) = @splat(comptime affineMatrix(inverse));
    return asm ("vgf2p8affineqb $0, %[matrix], %[a], %[out]"
        : [out] "=v" (-> W),
        : [a] "v" (a),
          [matrix] "vm" (matrix),
    );
}
inline fn perm2(a: W, idx: W, b: W) W {
    return asm ("vpermi2b %[b], %[a], %[idx]"
        : [out] "=v" (-> W),
        : [idx] "0" (idx),
          [a] "v" (a),
          [b] "vm" (b),
    );
}
inline fn sbox(a: W, comptime inverse: bool) W {
    const table = if (inverse) dec_s else enc_s;
    const lo = perm2(table[0], a, table[1]);
    const hi = perm2(table[2], a, table[3]);
    return @select(u8, a < @as(W, @splat(128)), lo, hi);
}
inline fn mul(a: W, b: W) W {
    return asm ("vgf2p8mulb %[b], %[a], %[out]"
        : [out] "=v" (-> W),
        : [a] "v" (a),
          [b] "vm" (b),
    );
}
inline fn linear(a: W, comptime inverse: bool) W {
    const table = if (inverse) dec_diag else enc_diag;
    var out: [16]W = undefined;
    inline for (0..16) |i| out[i] = mul(rotate(a, i), table[i]);
    inline for (.{ 1, 2, 4, 8 }) |step| {
        inline for (0..16 / (step * 2)) |j| {
            const i = j * step * 2;
            out[i] ^= out[i + step];
        }
    }
    return out[0];
}
inline fn linearGroup(comptime n: usize, states: *[n]W, comptime base: usize, comptime count: usize, comptime inverse: bool) void {
    const table = if (inverse) dec_diag else enc_diag;
    var accum: [count]W = @splat(@splat(0));
    inline for (0..16) |r| {
        inline for (0..count) |i| accum[i] ^= mul(rotate(states[base + i], r), table[r]);
    }
    inline for (0..count) |i| states[base + i] = accum[i];
}

inline fn broadcast(a: B) W {
    return @shuffle(u8, a, undefined, [_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 } ** 4);
}

pub fn encrypt(comptime n: usize, keys: *const [10]B, messages: *align(16) [n * 4]B) void {
    @setRuntimeSafety(false);
    @setEvalBranchQuota(100000);
    const input: *align(16) [n]W = @ptrCast(messages);
    var states: [n]W = undefined;
    inline for (0..n) |i| states[i] = affine(input[i], false);
    for (0..9) |r| {
        const key = affine(broadcast(keys[r]), false);
        inline for (0..n) |i| states[i] = sbox(states[i] ^ key, false);
        inline for (0..(n + 3) / 4) |g| linearGroup(n, &states, g * 4, @min(4, n - g * 4), false);
    }
    const last = affine(broadcast(keys[9]), false);
    inline for (0..n) |i| input[i] = affine(states[i] ^ last, true);
}
pub fn decrypt(comptime n: usize, keys: *const [10]B, messages: *align(16) [n * 4]B) void {
    @setRuntimeSafety(false);
    @setEvalBranchQuota(100000);
    const input: *align(16) [n]W = @ptrCast(messages);
    var states: [n]W = undefined;
    inline for (0..n) |i| states[i] = affine(input[i], false);
    for (0..9) |r| {
        const key = affine(broadcast(keys[9 - r]), false);
        inline for (0..n) |i| states[i] ^= key;
        if (n == 2) {
            // Two independent reduction trees shorten the eight-block inverse
            // path; larger batches benefit from shared coefficient scheduling.
            inline for (0..n) |i| states[i] = linear(states[i], true);
        } else {
            inline for (0..(n + 3) / 4) |g| linearGroup(n, &states, g * 4, @min(4, n - g * 4), true);
        }
        inline for (0..n) |i| states[i] = sbox(states[i], true);
    }
    const last = affine(broadcast(keys[0]), false);
    inline for (0..n) |i| input[i] = affine(states[i] ^ last, true);
}

test "field isomorphism preserves every byte product" {
    const testing = @import("std").testing;
    for (0..256) |a| {
        const aa: u8 = @intCast(a);
        try testing.expectEqual(aa, inverse_map[toAes(aa)]);
        for (0..256) |b| {
            const bb: u8 = @intCast(b);
            var x: u16 = aa;
            var y = bb;
            var product: u8 = 0;
            for (0..8) |_| {
                if (y & 1 != 0) product ^= @intCast(x);
                x <<= 1;
                if (x & 0x100 != 0) x ^= 0x1c3;
                y >>= 1;
            }
            try testing.expectEqual(toAes(product), aesMul(toAes(aa), toAes(bb)));
        }
    }
}

test "GFNI affine and S-box instructions agree for every byte" {
    if (comptime !supported) return error.SkipZigTest;
    const testing = @import("std").testing;
    for (0..4) |chunk| {
        var input: W = undefined;
        for (0..64) |i| input[i] = @intCast(chunk * 64 + i);
        const mapped = affine(input, false);
        try testing.expectEqual(input, affine(mapped, true));
        const forward = affine(sbox(mapped, false), true);
        const inverse = affine(sbox(mapped, true), true);
        for (0..64) |i| {
            try testing.expectEqual(toAes(input[i]), mapped[i]);
            try testing.expectEqual(definitions.pi_table[input[i]], forward[i]);
            try testing.expectEqual(definitions.pi_inv_table[input[i]], inverse[i]);
        }
    }
}

test "GFNI linear layers match every binary basis vector" {
    if (comptime !supported) return error.SkipZigTest;
    const testing = @import("std").testing;
    for (0..16) |position| {
        for (0..8) |bit| {
            var input: [4]B = .{@as(B, @splat(0))} ** 4;
            for (0..4) |lane| input[lane][(position + lane) % 16] = @as(u8, 1) << @intCast((bit + lane) % 8);
            const mapped = affine(@bitCast(input), false);
            const forward: [4]B = @bitCast(affine(linear(mapped, false), true));
            const inverse: [4]B = @bitCast(affine(linear(mapped, true), true));
            for (0..4) |lane| {
                try testing.expectEqual(transitions.l_trans(input[lane]), forward[lane]);
                try testing.expectEqual(transitions.l_inv_trans(input[lane]), inverse[lane]);
            }
        }
    }
}
