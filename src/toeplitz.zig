//! Sixty-four blocks with a diagonally encoded recursive linear layer.
//! L = Drow^-1 * T * Dcolumn^-1; T has equal recursive diagonal blocks.
//! Position-specific S-boxes absorb the
//! diagonal maps between rounds; keys use the same row encoding.
const defs = @import("definitions.zig");
const transpose = @import("transpose.zig");
const gfni = @import("gfni.zig");
const core = @import("toeplitz_core.zig");
const B = defs.block;
const W = core.W;
fn mul(a_in: u8, b_in: u8) u8 {
    var a = a_in;
    var b = b_in;
    var out: u8 = 0;
    for (0..8) |_| {
        if (b & 1 != 0) out ^= a;
        const carry = a & 0x80 != 0;
        a = (a << 1) ^ @as(u8, if (carry) 0xc3 else 0);
        b >>= 1;
    }
    return out;
}
fn tables(comptime inverse: bool, comptime final: bool) [16][4]W {
    @setEvalBranchQuota(10000000);
    var out: [16][4]W = undefined;
    for (0..16) |i| for (0..256) |v| {
        const pos = if (inverse) 15 - i else i;
        const input = mul(core.row_inverse[pos], @intCast(v));
        const s = if (inverse) defs.pi_inv_table[input] else defs.pi_table[input];
        out[i][v / 64][v % 64] = if (final) s else mul(core.column_inverse[pos], s);
    };
    return out;
}
const enc_s = tables(false, false);
const dec_s = tables(true, false);
const dec_final = tables(true, true);
inline fn perm2(a: W, indices: W, b: W) W {
    return asm ("vpermi2b %[b], %[a], %[indices]"
        : [out] "=v" (-> W),
        : [indices] "0" (indices),
          [a] "v" (a),
          [b] "vm" (b),
    );
}
inline fn sbox(a: W, comptime i: usize, comptime inverse: bool, comptime final: bool) W {
    const table = if (final) dec_final[i] else if (inverse) dec_s[i] else enc_s[i];
    const low = perm2(table[0], a, table[1]);
    const high = perm2(table[2], a, table[3]);
    return @select(u8, a < @as(W, @splat(128)), low, high);
}
inline fn fieldAffine(a: W, comptime inverse: bool) W {
    const m: @Vector(8, u64) = @splat(comptime gfni.affineMatrix(inverse));
    return asm ("vgf2p8affineqb $0, %[m], %[a], %[out]"
        : [out] "=v" (-> W),
        : [a] "v" (a),
          [m] "v" (m),
    );
}
inline fn fieldMul(a: W, b: W) W {
    return asm ("vgf2p8mulb %[b], %[a], %[out]"
        : [out] "=v" (-> W),
        : [a] "v" (a),
          [b] "v" (b),
    );
}
pub fn prepareKeys(keys: *const [10]B, comptime inverse: bool) [10]B {
    @setEvalBranchQuota(1000000);
    const coefficients: W = comptime blk: {
        var c: W = undefined;
        for (0..64) |i| c[i] = gfni.toAes(core.row_scale[if (inverse) 15 - i % 16 else i % 16]);
        break :blk c;
    };
    var out: [10]B = undefined;
    inline for (0..3) |chunk| {
        var input: [4]B = .{@as(B, @splat(0))} ** 4;
        inline for (0..4) |lane| {
            const index = chunk * 4 + lane;
            if (index < 10) input[lane] = keys[index];
        }
        const result: [4]B = @bitCast(fieldAffine(fieldMul(fieldAffine(@bitCast(input), false), coefficients), true));
        inline for (0..4) |lane| {
            const index = chunk * 4 + lane;
            if (index < 10) out[index] = result[lane];
        }
    }
    return out;
}
pub fn encryptPrepared(encoded_keys: *const [10]B, messages: *align(16) [64]B) void {
    @setRuntimeSafety(false);
    var state = transpose.load(messages);
    inline for (0..16) |i| state[i] = core.multiplyConstant(state[i], core.row_scale[i]) ^ @as(W, @splat(encoded_keys[0][i]));
    for (0..9) |round| {
        inline for (0..16) |i| state[i] = sbox(state[i], i, false, false);
        state = core.forwardSeeded(state, encoded_keys[round + 1]);
    }
    inline for (0..16) |i| state[i] = core.multiplyConstant(state[i], core.row_inverse[i]);
    transpose.store(messages, state);
}
pub fn decryptPrepared(keys: *const [10]B, encoded_keys: *const [10]B, messages: *align(16) [64]B) void {
    @setRuntimeSafety(false);
    var state = transpose.load(messages);
    inline for (0..16) |i| state[i] = core.multiplyConstant(state[i], core.column_inverse[15 - i]);
    state = core.inverseSeeded(state, encoded_keys[9]);
    for (0..8) |round| {
        inline for (0..16) |i| state[i] = sbox(state[i], i, true, false);
        state = core.inverseSeeded(state, encoded_keys[8 - round]);
    }
    inline for (0..16) |i| state[i] = sbox(state[i], i, true, true) ^ @as(W, @splat(keys[0][i]));
    transpose.store(messages, state);
}
pub fn selftest() !void {
    const testing = @import("std").testing;
    inline for (0..16) |i| for (0..256) |v| {
        const input: W = @splat(@intCast(v));
        const a = mul(core.row_inverse[i], @intCast(v));
        const b = mul(core.row_inverse[15 - i], @intCast(v));
        try testing.expectEqual(@as(W, @splat(mul(core.column_inverse[i], defs.pi_table[a]))), sbox(input, i, false, false));
        try testing.expectEqual(@as(W, @splat(mul(core.column_inverse[15 - i], defs.pi_inv_table[b]))), sbox(input, i, true, false));
        try testing.expectEqual(@as(W, @splat(defs.pi_inv_table[b])), sbox(input, i, true, true));
    };
    for (0..256) |v| {
        const input: [10]B = .{@as(B, @splat(@intCast(v)))} ** 10;
        const ek = prepareKeys(&input, false);
        const dk = prepareKeys(&input, true);
        for (0..10) |r| for (0..16) |i| {
            try testing.expectEqual(mul(core.row_scale[i], @intCast(v)), ek[r][i]);
            try testing.expectEqual(mul(core.row_scale[15 - i], @intCast(v)), dk[r][i]);
        };
    }
}

test "Toeplitz position substitutions and key encoding match every byte" {
    if (comptime !gfni.supported) return error.SkipZigTest;
    try selftest();
}
test "Toeplitz normalized linear layers match every binary basis vector" {
    @setEvalBranchQuota(1000000);
    if (comptime !gfni.supported) return error.SkipZigTest;
    const testing = @import("std").testing;
    const transitions = @import("transitions.zig");
    for (0..16) |position| for (0..8) |bit| {
        var raw: B = @splat(0);
        raw[position] = @as(u8, 1) << @intCast(bit);
        var a: [16]W = undefined;
        var b: [16]W = undefined;
        inline for (0..16) |i| {
            a[i] = core.multiplyConstant(@splat(raw[i]), core.column_inverse[i]);
            b[i] = core.multiplyConstant(@splat(raw[i]), core.column_inverse[15 - i]);
        }
        a = core.forwardSeeded(a, @splat(0));
        b = core.inverseSeeded(b, @splat(0));
        const forward = transitions.l_trans(raw);
        const inverse = transitions.l_inv_trans(raw);
        inline for (0..16) |i| {
            try testing.expectEqual(@as(W, @splat(forward[i])), core.multiplyConstant(a[i], core.row_inverse[i]));
            try testing.expectEqual(@as(W, @splat(inverse[i])), core.multiplyConstant(b[i], core.row_inverse[15 - i]));
        }
    };
}
