//! Sixty-four independent blocks in byte-sliced registers. GFNI encodes
//! constant multiplications directly in Kuznechik's field; no field mapping.
//! The caller must check gfni.supported before instantiating this kernel.
const definitions = @import("definitions.zig");
const B = definitions.block;
const transpose = @import("transpose.zig");
pub const W = @Vector(64, u8);

// Each field multiplication by a constant is GF(2)-linear. Encode it as a
// GFNI affine matrix directly in Kuznechik's field (polynomial 0x1c3).
fn kuzMul(a_in: u8, b_in: u8) u8 {
    var a = a_in;
    var b = b_in;
    var out: u8 = 0;
    for (0..8) |_| {
        if (b & 1 != 0) out ^= a;
        const high = a & 0x80 != 0;
        a = (a << 1) ^ @as(u8, if (high) 0xc3 else 0);
        b >>= 1;
    }
    return out;
}
fn multiplicationMatrix(comptime coefficient: u8) u64 {
    @setEvalBranchQuota(1000000);
    var matrix: u64 = 0;
    for (0..8) |output_bit| {
        var row: u8 = 0;
        for (0..8) |input_bit| {
            const y = kuzMul(@as(u8, 1) << @intCast(input_bit), coefficient);
            row |= ((y >> @intCast(output_bit)) & 1) << @intCast(input_bit);
        }
        matrix |= @as(u64, row) << @intCast((7 - output_bit) * 8);
    }
    return matrix;
}
fn substitution(comptime inverse: bool) [4]W {
    const table = if (inverse) definitions.pi_inv_table else definitions.pi_table;
    var out: [4]W = undefined;
    for (0..4) |i| out[i] = table[i * 64 ..][0..64].*;
    return out;
}
inline fn multiplyConstant(a: W, comptime coefficient: u8) W {
    const matrix: @Vector(8, u64) = @splat(comptime multiplicationMatrix(coefficient));
    return asm ("vgf2p8affineqb $0, %[matrix], %[a], %[out]"
        : [out] "=v" (-> W),
        : [a] "v" (a),
          [matrix] "v" (matrix),
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
const enc_s = substitution(false);
const dec_s = substitution(true);
inline fn xor3(a: W, b: W, c: W) W {
    return asm ("vpternlogd $0x96, %[c], %[b], %[a]"
        : [out] "=v" (-> W),
        : [a] "0" (a),
          [b] "v" (b),
          [c] "v" (c),
    );
}
inline fn rTransform(state: *[16]W, comptime inverse: bool) void {
    const offset: usize = @intFromBool(inverse);
    const a1 = state[1 + offset] ^ state[13 + offset];
    const a2 = state[2 + offset] ^ state[12 + offset];
    const a3 = state[3 + offset] ^ state[11 + offset];
    const a4 = state[4 + offset] ^ state[10 + offset];
    const a5 = state[5 + offset] ^ state[9 + offset];
    // Isolate the newest feedback so its dependency ends in one final XOR.
    const critical = if (inverse) state[15] else state[0];
    const independent = if (inverse) state[1] else state[14];
    const dependent = multiplyConstant(critical, 148);
    // 148 = 133 ^ 16 ^ 1: rewrite the independent partner to keep
    // seven GFNI operations while shortening the feedback dependency.
    const products = [6]W{
        multiplyConstant(a1, 32),
        multiplyConstant(independent ^ a2, 133),
        multiplyConstant(independent ^ a3, 16),
        multiplyConstant(a4, 194),
        multiplyConstant(a5, 192),
        multiplyConstant(state[7 + offset], 251),
    };
    const unit = (if (inverse) xor3(state[0], state[7], state[9]) else xor3(state[6], state[8], state[15])) ^ independent;
    const partial = xor3(xor3(products[0], products[1], products[2]), xor3(products[3], products[4], products[5]), unit);
    const feedback = dependent ^ partial;
    inline for (0..15) |i| {
        if (inverse) state[i] = state[i + 1] else state[15 - i] = state[14 - i];
    }
    state[if (inverse) 15 else 0] = feedback;
}

fn encryptColumns(keys: *const [10]B, messages: *[16]W) void {
    @setRuntimeSafety(false);
    @setEvalBranchQuota(1000000);
    var states = messages.*;
    for (0..9) |r| {
        inline for (0..16) |i| states[i] = sbox(states[i] ^ @as(W, @splat(keys[r][i])), false);
        inline for (0..16) |_| rTransform(&states, false);
    }
    inline for (0..16) |i| messages[i] = states[i] ^ @as(W, @splat(keys[9][i]));
}
fn decryptColumns(keys: *const [10]B, messages: *[16]W) void {
    @setRuntimeSafety(false);
    @setEvalBranchQuota(1000000);
    var states = messages.*;
    for (0..9) |r| {
        inline for (0..16) |i| states[i] ^= @as(W, @splat(keys[9 - r][i]));
        inline for (0..16) |_| rTransform(&states, true);
        inline for (0..16) |i| states[i] = sbox(states[i], true);
    }
    inline for (0..16) |i| messages[i] = states[i] ^ @as(W, @splat(keys[0][i]));
}

pub fn encrypt(keys: *const [10]B, messages: *align(16) [64]B) void {
    var columns = transpose.load(messages);
    encryptColumns(keys, &columns);
    transpose.store(messages, columns);
}

pub fn decrypt(keys: *const [10]B, messages: *align(16) [64]B) void {
    var columns = transpose.load(messages);
    decryptColumns(keys, &columns);
    transpose.store(messages, columns);
}

test "sliced GFNI constant multipliers and S-boxes match every byte" {
    if (comptime !@import("gfni.zig").supported) return error.SkipZigTest;
    const testing = @import("std").testing;
    for (0..4) |chunk| {
        var input: W = undefined;
        for (0..64) |i| input[i] = @intCast(chunk * 64 + i);
        inline for (.{ 0, 1, 16, 32, 133, 148, 192, 194, 251 }) |coefficient| {
            const actual = multiplyConstant(input, coefficient);
            for (0..64) |i| try testing.expectEqual(kuzMul(input[i], coefficient), actual[i]);
        }
        const forward = sbox(input, false);
        const inverse = sbox(input, true);
        for (0..64) |i| {
            try testing.expectEqual(definitions.pi_table[input[i]], forward[i]);
            try testing.expectEqual(definitions.pi_inv_table[input[i]], inverse[i]);
        }
    }
}

test "sliced linear layers match every binary basis vector" {
    if (comptime !@import("gfni.zig").supported) return error.SkipZigTest;
    @setEvalBranchQuota(1000000);
    const testing = @import("std").testing;
    const transitions = @import("transitions.zig");
    for (0..16) |position| {
        for (0..8) |bit| {
            var unit: B = @splat(0);
            unit[position] = @as(u8, 1) << @intCast(bit);
            var initial: [16]W = undefined;
            for (0..16) |i| initial[i] = @splat(unit[i]);
            var forward = initial;
            var inverse = initial;
            inline for (0..16) |_| {
                rTransform(&forward, false);
                rTransform(&inverse, true);
            }
            const expected_forward = transitions.l_trans(unit);
            const expected_inverse = transitions.l_inv_trans(unit);
            for (0..16) |i| {
                try testing.expectEqual(@as(W, @splat(expected_forward[i])), forward[i]);
                try testing.expectEqual(@as(W, @splat(expected_inverse[i])), inverse[i]);
            }
        }
    }
}
