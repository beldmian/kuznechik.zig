//! Single-block lookup/GFNI kernel tuned on Zen 5. Compute the first five
//! contributions with GFNI, leaving eleven 4 KiB lookup rows active.
//! Keep the remaining lookup chains in GPRs so they overlap SIMD arithmetic.
//! The caller selects this backend only when its CPU features are supported.
const std = @import("std");
const defs = @import("definitions.zig");
const trans = @import("transitions.zig");
const luts = @import("luts.zig");
const field = @import("gfni.zig");
const B = defs.block;
const toAes = field.toAes;
pub const supported = field.supported and std.Target.x86.featureSetHasAll(
    @import("builtin").cpu.features,
    &.{ .avx2, .avx512vl },
);

fn encodedSubstitution(comptime inverse: bool) [256]u8 {
    @setEvalBranchQuota(100000);
    const pi = if (inverse) defs.pi_inv_table else defs.pi_table;
    var out: [256]u8 = undefined;
    for (0..256) |i| out[i] = toAes(pi[i]);
    return out;
}
const encoded_forward = encodedSubstitution(false);
const encoded_inverse = encodedSubstitution(true);
const encoded_raw = blk: {
    @setEvalBranchQuota(100000);
    var out: [256]u8 = undefined;
    for (0..256) |i| out[i] = toAes(@intCast(i));
    break :blk out;
};

fn columns(comptime inverse: bool) [5]B {
    @setEvalBranchQuota(1000000);
    var out: [5]B = undefined;
    for (0..5) |i| {
        var unit: B = @splat(0);
        unit[i] = 1;
        const col = if (inverse) trans.l_inv_trans(unit) else trans.l_trans(unit);
        for (0..16) |j| out[i][j] = toAes(col[j]);
    }
    return out;
}
const forward_columns = columns(false);
const inverse_columns = columns(true);

inline fn mul(a: B, b: B) B {
    return asm ("vgf2p8mulb %[b], %[a], %[out]"
        : [out] "=v" (-> B),
        : [a] "v" (a),
          [b] "vm" (b),
    );
}
inline fn inverseAffine(a: B) B {
    const matrix: @Vector(2, u64) = @splat(comptime field.affineMatrix(true));
    return asm ("vgf2p8affineqb $0, %[matrix], %[a], %[out]"
        : [out] "=v" (-> B),
        : [a] "v" (a),
          [matrix] "vm" (matrix),
    );
}
inline fn gpIdentity(a: u64) u64 {
    // Preserve the short GPR chains and keep LLVM from vectorizing them.
    return asm (""
        : [out] "=r" (-> u64),
        : [in] "0" (a),
    );
}

inline fn roundWords(comptime inverse: bool, comptime first: bool, words: [2]u64, seed: [2]u64) [2]u64 {
    const pi = if (first) encoded_raw else if (inverse) encoded_inverse else encoded_forward;
    const cols = if (inverse) inverse_columns else forward_columns;
    var aes: B = @splat(0);
    inline for (0..5) |i| {
        const index: u8 = @truncate(words[i / 8] >> @as(u6, @intCast(i % 8 * 8)));
        aes ^= mul(@splat(pi[index]), cols[i]);
    }
    var accum: [3][2]u64 = .{.{ 0, 0 }} ** 3;
    // Fold the next round key into an independent lookup chain.
    accum[0] = seed;
    inline for (0..3) |group| {
        inline for (5..16) |i| {
            if ((i - 5) % 3 == group) {
                // On the first inverse round S cancels the table's S^-1:
                // compressed bytes use F(x), while table indices use Pi(x).
                const offset: usize = if (first)
                    @as(usize, defs.pi_table[@as(u8, @truncate(words[i / 8] >> @as(u6, @intCast(i % 8 * 8))))]) << 4
                else if (i % 8 == 0)
                    (words[i / 8] << 4) & 0xff0
                else
                    (words[i / 8] >> @as(u6, @intCast(i % 8 * 8 - 4))) & 0xff0;
                const row = if (inverse) &luts.ls_inv_trans_lut[i] else &luts.ls_trans_lut[i];
                const entry: *const [2]u64 = @ptrFromInt(@intFromPtr(row) + offset);
                accum[group][0] ^= entry[0];
                accum[group][1] ^= entry[1];
            }
        }
        accum[group][0] = gpIdentity(accum[group][0]);
        accum[group][1] = gpIdentity(accum[group][1]);
    }
    const low = gpIdentity(accum[0][0] ^ accum[1][0] ^ accum[2][0]);
    const high = gpIdentity(accum[0][1] ^ accum[1][1] ^ accum[2][1]);
    const partial: [2]u64 = @bitCast(inverseAffine(aes));
    return .{ gpIdentity(low ^ partial[0]), gpIdentity(high ^ partial[1]) };
}

const W = @Vector(64, u8);
inline fn permute2(a: W, indices: W, b: W) W {
    return asm ("vpermi2b %[b], %[a], %[indices]"
        : [out] "=v" (-> W),
        : [indices] "0" (indices),
          [a] "v" (a),
          [b] "vm" (b),
    );
}
inline fn inverseSubstitute(a: B) B {
    const table = defs.pi_inv_table;
    // All permutation input lanes are defined; only low sixteen outputs are used.
    const indices: W = @shuffle(u8, a, @as(B, @splat(0)), [_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 } ++ ([_]i32{-1} ** 48));
    const low = permute2(table[0..64].*, indices, table[64..128].*);
    const high = permute2(table[128..192].*, indices, table[192..256].*);
    const result = @select(u8, indices < @as(W, @splat(128)), low, high);
    return @as([4]B, @bitCast(result))[0];
}

pub fn encrypt(keys: *const [10]B, msg: *align(16) B) void {
    @setRuntimeSafety(false);
    var words: [2]u64 = @bitCast(msg.* ^ keys[0]);
    inline for (0..9) |r| words = roundWords(false, false, words, @bitCast(keys[r + 1]));
    msg.* = @bitCast(words);
}
pub fn decrypt(keys: *const [10]B, inverse_keys: *const [10]B, msg: *align(16) B) void {
    @setRuntimeSafety(false);
    var words: [2]u64 = @bitCast(msg.*);
    inline for (0..9) |r| words = roundWords(true, r == 0, words, @bitCast(inverse_keys[9 - r]));
    msg.* = inverseSubstitute(@bitCast(words)) ^ keys[0];
}

test "hybrid contributions and endpoint match every byte" {
    if (comptime !supported) return error.SkipZigTest;
    const testing = std.testing;
    inline for (0..5) |position| {
        for (0..256) |v| {
            const value: u8 = @intCast(v);
            const forward = inverseAffine(mul(@splat(encoded_forward[v]), forward_columns[position]));
            const inverse = inverseAffine(mul(@splat(encoded_inverse[v]), inverse_columns[position]));
            const raw_inverse = inverseAffine(mul(@splat(encoded_raw[v]), inverse_columns[position]));
            var unit: B = @splat(0);
            unit[position] = value;
            try testing.expectEqual(luts.ls_trans_lut[position][v], forward);
            try testing.expectEqual(luts.ls_inv_trans_lut[position][v], inverse);
            try testing.expectEqual(trans.l_inv_trans(unit), raw_inverse);
        }
    }
    for (0..16) |chunk| {
        var input: B = undefined;
        for (0..16) |i| input[i] = @intCast(chunk * 16 + i);
        const output = inverseSubstitute(input);
        for (0..16) |i| try testing.expectEqual(defs.pi_inv_table[input[i]], output[i]);
    }
}
