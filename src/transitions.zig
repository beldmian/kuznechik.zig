const std = @import("std");
const definitions = @import("definitions.zig");

const testing = std.testing;
const block = definitions.block;
const key = definitions.key;

pub fn x_trans(a: block, b: block) block {
    return a ^ b;
}

pub inline fn s_trans(a: block) block {
    var out = a;
    for (0..16) |i| {
        out[i] = definitions.pi_table[out[i]];
    }
    return out;
}

pub fn s_inv_trans(a: block) block {
    var out = a;
    for (0..16) |i| {
        out[i] = definitions.pi_inv_table[out[i]];
    }
    return out;
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
