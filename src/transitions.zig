const std = @import("std");
const definitions = @import("definitions.zig");

const testing = std.testing;
const block = definitions.block;
const key = definitions.key;

pub fn x_trans(a: block, b: block) block {
    return a ^ b;
}

pub inline fn s_trans(a: block) block {
    @setRuntimeSafety(false);
    var out = a;
    // Unroll completely for better performance
    const pi = definitions.pi_table;
    out[0] = pi[out[0]];
    out[1] = pi[out[1]];
    out[2] = pi[out[2]];
    out[3] = pi[out[3]];
    out[4] = pi[out[4]];
    out[5] = pi[out[5]];
    out[6] = pi[out[6]];
    out[7] = pi[out[7]];
    out[8] = pi[out[8]];
    out[9] = pi[out[9]];
    out[10] = pi[out[10]];
    out[11] = pi[out[11]];
    out[12] = pi[out[12]];
    out[13] = pi[out[13]];
    out[14] = pi[out[14]];
    out[15] = pi[out[15]];
    return out;
}

pub inline fn s_trans_inplace(a: *block) void {
    @setRuntimeSafety(false);
    // Unroll completely for better performance
    const pi = definitions.pi_table;
    a[0] = pi[a[0]];
    a[1] = pi[a[1]];
    a[2] = pi[a[2]];
    a[3] = pi[a[3]];
    a[4] = pi[a[4]];
    a[5] = pi[a[5]];
    a[6] = pi[a[6]];
    a[7] = pi[a[7]];
    a[8] = pi[a[8]];
    a[9] = pi[a[9]];
    a[10] = pi[a[10]];
    a[11] = pi[a[11]];
    a[12] = pi[a[12]];
    a[13] = pi[a[13]];
    a[14] = pi[a[14]];
    a[15] = pi[a[15]];
}

pub fn s_inv_trans(a: block) block {
    @setRuntimeSafety(false);
    var out = a;
    // Unroll completely for better performance  
    const pi_inv = definitions.pi_inv_table;
    out[0] = pi_inv[out[0]];
    out[1] = pi_inv[out[1]];
    out[2] = pi_inv[out[2]];
    out[3] = pi_inv[out[3]];
    out[4] = pi_inv[out[4]];
    out[5] = pi_inv[out[5]];
    out[6] = pi_inv[out[6]];
    out[7] = pi_inv[out[7]];
    out[8] = pi_inv[out[8]];
    out[9] = pi_inv[out[9]];
    out[10] = pi_inv[out[10]];
    out[11] = pi_inv[out[11]];
    out[12] = pi_inv[out[12]];
    out[13] = pi_inv[out[13]];
    out[14] = pi_inv[out[14]];
    out[15] = pi_inv[out[15]];
    return out;
}

pub fn s_inv_trans_inplace(a: *block) void {
    @setRuntimeSafety(false);
    // Unroll completely for better performance
    const pi_inv = definitions.pi_inv_table;
    a[0] = pi_inv[a[0]];
    a[1] = pi_inv[a[1]];
    a[2] = pi_inv[a[2]];
    a[3] = pi_inv[a[3]];
    a[4] = pi_inv[a[4]];
    a[5] = pi_inv[a[5]];
    a[6] = pi_inv[a[6]];
    a[7] = pi_inv[a[7]];
    a[8] = pi_inv[a[8]];
    a[9] = pi_inv[a[9]];
    a[10] = pi_inv[a[10]];
    a[11] = pi_inv[a[11]];
    a[12] = pi_inv[a[12]];
    a[13] = pi_inv[a[13]];
    a[14] = pi_inv[a[14]];
    a[15] = pi_inv[a[15]];
}

fn gf_mul(a_in: u8, b_in: u8) u8 {
    var a: u8 = a_in;
    var b: u8 = b_in;
    var c: u8 = 0;
    for (0..8) |_| {
        if (b & 1 == 1) {
            c = c ^ a;
        }
        if (a & 0x80 == 0x80) {
            a = (a << 1) ^ 0xc3;
        } else {
            a = a << 1;
        }
        b = b >> 1;
    }
    return c;
}

const l_vec: [16]u8 =
    .{ 148, 32, 133, 16, 194, 192, 1, 251, 1, 192, 194, 16, 133, 32, 148, 1 };

pub fn l_trans(a: block) block {
    var out = a;
    for (0..16) |_| {
        var x = out[15];
        for (0..15) |i| {
            out[(14 - i) + 1] = out[14 - i];
            x ^= gf_mul(out[14 - i], l_vec[14 - i]);
        }
        out[0] = x;
    }
    return out;
}

pub fn l_inv_trans(a: block) block {
    var out = a;
    for (0..16) |_| {
        var x = out[0];
        for (0..15) |i| {
            out[i] = out[i + 1];
            x ^= gf_mul(out[i], l_vec[i]);
        }
        out[15] = x;
    }
    return out;
}

test "X transition test" {
    const vect_a = @Vector(16, u8){ 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    const vect_b = @Vector(16, u8){ 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    const vect_out = @Vector(16, u8){ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    try testing.expectEqual(x_trans(vect_a, vect_b), vect_out);
}

test "S and S inverse transition test" {
    const vect_s_test = @Vector(16, u8){ 0xff, 0xee, 0xdd, 0xcc, 0xbb, 0xaa, 0x99, 0x88, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x00 };
    const vect_s_test_out = @Vector(16, u8){ 0xb6, 0x6c, 0xd8, 0x88, 0x7d, 0x38, 0xe8, 0xd7, 0x77, 0x65, 0xae, 0xea, 0x0c, 0x9a, 0x7e, 0xfc };
    try testing.expectEqual(s_trans(vect_s_test), vect_s_test_out);
    try testing.expectEqual(s_inv_trans(vect_s_test_out), vect_s_test);
}

test "L and L inverse transition test" {
    const vect_l_test = @Vector(16, u8){ 0x64, 0xa5, 0x94, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    const vect_l_test_out = @Vector(16, u8){ 0xd4, 0x56, 0x58, 0x4d, 0xd0, 0xe3, 0xe8, 0x4c, 0xc3, 0x16, 0x6e, 0x4b, 0x7f, 0xa2, 0x89, 0x0d };
    try testing.expectEqual(l_trans(vect_l_test), vect_l_test_out);
    try testing.expectEqual(l_inv_trans(vect_l_test_out), vect_l_test);
}
