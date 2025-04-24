const std = @import("std");
const definitions = @import("definitions.zig");
const transitions = @import("transitions.zig");

const block = definitions.block;
const key = definitions.key;

pub const ls_trans_lut = lut_blk: {
    @setEvalBranchQuota(100000000);
    var lut: [16][256]block align(4096) = [_][256]block{[_]block{[_]u8{0} ** 16} ** 256} ** 16;
    for (0..16) |i| {
        for (0..256) |v| {
            var blk = @as(block, @splat(0));
            blk[i] = definitions.pi_table[v];
            lut[i][v] = transitions.l_trans(blk);
        }
    }
    break :lut_blk lut;
};

pub const ls_inv_trans_lut = lut_blk: {
    @setEvalBranchQuota(100000000);
    var lut: [16][256]block align(4096) = [_][256]block{[_]block{[_]u8{0} ** 16} ** 256} ** 16;
    for (0..16) |i| {
        for (0..256) |v| {
            var blk = @as(block, @splat(0));
            blk[i] = definitions.pi_inv_table[v];
            lut[i][v] = transitions.l_inv_trans(blk);
        }
    }
    break :lut_blk lut;
};
