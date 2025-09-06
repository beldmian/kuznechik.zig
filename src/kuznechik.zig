const std = @import("std");
const luts = @import("luts.zig");
const definitions = @import("definitions.zig");
const transitions = @import("transitions.zig");

pub const block = definitions.block;
pub const key = definitions.key;

const testing = std.testing;

inline fn lsx_trans(a: *align(16) block, k: block) void {
    @setRuntimeSafety(false);
    const x = a.* ^ k;
    var accum: block align(16) = @splat(0);
    
    // Unroll in groups of 4 for better instruction-level parallelism
    comptime var i = 0;
    inline while (i < 16) : (i += 4) {
        accum ^= luts.ls_trans_lut[i][x[i]];
        accum ^= luts.ls_trans_lut[i + 1][x[i + 1]];
        accum ^= luts.ls_trans_lut[i + 2][x[i + 2]];
        accum ^= luts.ls_trans_lut[i + 3][x[i + 3]];
    }
    a.* = accum;
}

inline fn ls_inv_trans(a: *align(16) block) void {
    @setRuntimeSafety(false);

    var accum: block align(16) = @splat(0);

    // Prefetch critical LUT entries for better cache performance
    @prefetch(&luts.ls_inv_trans_lut[0][a[0]], .{});
    @prefetch(&luts.ls_inv_trans_lut[4][a[4]], .{});
    @prefetch(&luts.ls_inv_trans_lut[8][a[8]], .{});
    @prefetch(&luts.ls_inv_trans_lut[12][a[12]], .{});

    // Unroll completely for maximum performance - process all 16 bytes
    // Group into 4x4 pattern for optimal instruction scheduling
    accum ^= luts.ls_inv_trans_lut[0][a[0]];
    accum ^= luts.ls_inv_trans_lut[1][a[1]];
    accum ^= luts.ls_inv_trans_lut[2][a[2]];
    accum ^= luts.ls_inv_trans_lut[3][a[3]];
    
    accum ^= luts.ls_inv_trans_lut[4][a[4]];
    accum ^= luts.ls_inv_trans_lut[5][a[5]];
    accum ^= luts.ls_inv_trans_lut[6][a[6]];
    accum ^= luts.ls_inv_trans_lut[7][a[7]];
    
    accum ^= luts.ls_inv_trans_lut[8][a[8]];
    accum ^= luts.ls_inv_trans_lut[9][a[9]];
    accum ^= luts.ls_inv_trans_lut[10][a[10]];
    accum ^= luts.ls_inv_trans_lut[11][a[11]];
    
    accum ^= luts.ls_inv_trans_lut[12][a[12]];
    accum ^= luts.ls_inv_trans_lut[13][a[13]];
    accum ^= luts.ls_inv_trans_lut[14][a[14]];
    accum ^= luts.ls_inv_trans_lut[15][a[15]];

    a.* = accum;
}

fn make_iter_c() [32]block {
    var out: [32]block = [_]block{[_]u8{0} ** 16} ** 32;
    for (0..32) |i| {
        var v = [_]u8{0} ** 16;
        v[15] = @intCast(i + 1);
        out[i] = transitions.l_trans(v);
    }
    return out;
}

inline fn f_trans(k1: block, k2: block, iter_c: block) [2]block {
    return [2]block{ transitions.x_trans(transitions.l_trans(transitions.s_trans(transitions.x_trans(k1, iter_c))), k2), k1 };
}

fn make_iter_keys(k: key) [10]block {
    @setEvalBranchQuota(1000000);
    var k1: block = @as([32]u8, k)[0..16].*;
    var k2: block = @as([32]u8, k)[16..32].*;
    var iter_keys: [10]block = [_]block{[_]u8{0} ** 16} ** 10;
    const iter_c = comptime make_iter_c();
    iter_keys[0] = k1;
    iter_keys[1] = k2;
    comptime var i = 0;
    inline while (i < 4) : (i += 1) {
        comptime var j = 0;
        inline while (j < 8) : (j += 1) {
            const res = f_trans(k1, k2, iter_c[j + 8 * i]);
            k1 = res[0];
            k2 = res[1];
        }
        iter_keys[2 * i + 2] = k1;
        iter_keys[2 * i + 3] = k2;
    }
    return iter_keys;
}

pub const Cipher = struct {
    k: key align(16),
    ik: [10]block align(16),
    ik_inv: [10]block align(16),

    pub fn init(k: key) Cipher {
        // Prefetch lookup tables early and more aggressively
        @prefetch(&luts.ls_trans_lut, .{ .locality = 3 });
        @prefetch(&luts.ls_inv_trans_lut, .{ .locality = 3 });
        
        const ik = make_iter_keys(k);
        var ik_inv: [10]block align(16) = undefined;

        // Prefetch key schedule data
        @prefetch(&ik[0], .{});
        @prefetch(&ik[5], .{});

        // Optimize key inversion loop with better cache usage
        comptime var i = 0;
        inline while (i < 10) : (i += 1) {
            ik_inv[i] = transitions.l_inv_trans(ik[i]);
        }

        return .{
            .k = k,
            .ik = ik,
            .ik_inv = ik_inv,
        };
    }

    pub inline fn encrypt(self: Cipher, msg: *align(16) block) void {
        @setRuntimeSafety(false);

        // Prefetch lookup table and round keys
        @prefetch(&luts.ls_trans_lut, .{});
        @prefetch(&self.ik[0], .{});
        @prefetch(&self.ik[4], .{});
        @prefetch(&self.ik[8], .{});

        var state = msg.*;
        
        // Unroll first few rounds for better pipeline utilization
        lsx_trans(&state, self.ik[0]);
        lsx_trans(&state, self.ik[1]);
        lsx_trans(&state, self.ik[2]);
        lsx_trans(&state, self.ik[3]);
        
        // Process remaining rounds
        inline for (4..9) |i| {
            lsx_trans(&state, self.ik[i]);
        }
        
        state ^= self.ik[9];
        msg.* = state;
    }

    pub inline fn decrypt(self: Cipher, msg: *align(16) block) void {
        @setRuntimeSafety(false);

        // Prefetch critical lookup tables and keys early
        @prefetch(&definitions.pi_table, .{});
        @prefetch(&definitions.pi_inv_table, .{});
        @prefetch(&luts.ls_inv_trans_lut, .{});
        @prefetch(&self.ik_inv[9], .{});
        @prefetch(&self.ik_inv[5], .{});
        @prefetch(&self.ik_inv[0], .{});

        var state = msg.*;

        // Apply S-transformation using optimized unrolled lookup (Pi)
        // Process in groups of 8 for better pipeline utilization
        const pi = definitions.pi_table;
        state[0] = pi[state[0]];
        state[1] = pi[state[1]];
        state[2] = pi[state[2]];
        state[3] = pi[state[3]];
        state[4] = pi[state[4]];
        state[5] = pi[state[5]];
        state[6] = pi[state[6]];
        state[7] = pi[state[7]];
        state[8] = pi[state[8]];
        state[9] = pi[state[9]];
        state[10] = pi[state[10]];
        state[11] = pi[state[11]];
        state[12] = pi[state[12]];
        state[13] = pi[state[13]];
        state[14] = pi[state[14]];
        state[15] = pi[state[15]];

        // Optimized inverse rounds with better memory access pattern
        // Process in two phases for better cache locality
        inline for (0..5) |i| {
            ls_inv_trans(&state);
            state ^= self.ik_inv[9 - i];
        }

        inline for (5..9) |i| {
            ls_inv_trans(&state);
            state ^= self.ik_inv[9 - i];
        }

        // Final S-inverse transformation (unrolled with local copy)
        const pi_inv = definitions.pi_inv_table;
        state[0] = pi_inv[state[0]];
        state[1] = pi_inv[state[1]];
        state[2] = pi_inv[state[2]];
        state[3] = pi_inv[state[3]];
        state[4] = pi_inv[state[4]];
        state[5] = pi_inv[state[5]];
        state[6] = pi_inv[state[6]];
        state[7] = pi_inv[state[7]];
        state[8] = pi_inv[state[8]];
        state[9] = pi_inv[state[9]];
        state[10] = pi_inv[state[10]];
        state[11] = pi_inv[state[11]];
        state[12] = pi_inv[state[12]];
        state[13] = pi_inv[state[13]];
        state[14] = pi_inv[state[14]];
        state[15] = pi_inv[state[15]];

        // XOR with first round key and store result
        state ^= self.ik[0];
        msg.* = state;
    }
};

test "LS transition test" {
    var vect_l_test = @Vector(16, u8){ 0x64, 0xa5, 0x94, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    const vect_l_test_copy = @Vector(16, u8){ 0x64, 0xa5, 0x94, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    const vect_zero = @Vector(16, u8){ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    lsx_trans(&vect_l_test, vect_zero);
    try testing.expectEqual(transitions.l_trans(transitions.s_trans(vect_l_test_copy)), vect_l_test);
}

test "LS inverse transition test" {
    var vect_l_test = @Vector(16, u8){ 0x64, 0xa5, 0x94, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    const vect_l_test_copy = @Vector(16, u8){ 0x64, 0xa5, 0x94, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    ls_inv_trans(&vect_l_test);
    try testing.expectEqual(transitions.l_inv_trans(transitions.s_inv_trans(vect_l_test_copy)), vect_l_test);
}

test "Iterational constants test" {
    const iter_c_1 = @Vector(16, u8){ 0x6e, 0xa2, 0x76, 0x72, 0x6c, 0x48, 0x7a, 0xb8, 0x5d, 0x27, 0xbd, 0x10, 0xdd, 0x84, 0x94, 0x01 };
    const iter_c_8 = @Vector(16, u8){ 0xf6, 0x59, 0x36, 0x16, 0xe6, 0x05, 0x56, 0x89, 0xad, 0xfb, 0xa1, 0x80, 0x27, 0xaa, 0x2a, 0x08 };
    const iter_c = make_iter_c();
    try testing.expectEqual(iter_c[0], iter_c_1);
    try testing.expectEqual(iter_c[7], iter_c_8);
}

test "Iterational keys test" {
    const k = key{ 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef };
    const iter_keys = make_iter_keys(k);
    const iter_key_1 = block{ 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77 };
    const iter_key_10 = block{ 0x72, 0xe9, 0xdd, 0x74, 0x16, 0xbc, 0xf4, 0x5b, 0x75, 0x5d, 0xba, 0xa8, 0x8e, 0x4a, 0x40, 0x43 };
    try testing.expectEqual(iter_keys[0], iter_key_1);
    try testing.expectEqual(iter_keys[9], iter_key_10);
}

test "Cipher test" {
    const k = key{ 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef };
    const iter_key_1 = block{ 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77 };
    var msg = block{ 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x00, 0xff, 0xee, 0xdd, 0xcc, 0xbb, 0xaa, 0x99, 0x88 };
    const msg_enc = block{ 0x7f, 0x67, 0x9d, 0x90, 0xbe, 0xbc, 0x24, 0x30, 0x5a, 0x46, 0x8d, 0x42, 0xb9, 0xd4, 0xed, 0xcd };
    const msg_dec = block{ 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x00, 0xff, 0xee, 0xdd, 0xcc, 0xbb, 0xaa, 0x99, 0x88 };
    const cipher = Cipher.init(k);
    try testing.expectEqual(cipher.ik[0], iter_key_1);
    try testing.expectEqual(cipher.ik_inv[0], transitions.l_inv_trans(iter_key_1));
    cipher.encrypt(&msg);
    try testing.expectEqual(msg_enc, msg);
    cipher.decrypt(&msg);
    try testing.expectEqual(msg_dec, msg);
}
