const std = @import("std");
const definitions = @import("definitions.zig");
const transitions = @import("transitions.zig");

const block = definitions.block;
const key = definitions.key;

pub const ls_trans_lut = lut_blk: {
    @setEvalBranchQuota(100000000);
    // Use cache-optimized alignment (64-byte cache line alignment)
    var lut: [16][256]block align(64) = [_][256]block{[_]block{[_]u8{0} ** 16} ** 256} ** 16;
    comptime var i = 0;
    inline while (i < 16) : (i += 1) {
        comptime var v = 0;
        inline while (v < 256) : (v += 1) {
            var blk = @as(block, @splat(0));
            blk[i] = definitions.pi_table[v];
            lut[i][v] = transitions.l_trans(blk);
        }
    }
    break :lut_blk lut;
};

pub const ls_inv_trans_lut = lut_blk: {
    @setEvalBranchQuota(100000000);
    // Use cache-optimized alignment (64-byte cache line alignment)
    var lut: [16][256]block align(64) = [_][256]block{[_]block{[_]u8{0} ** 16} ** 256} ** 16;
    comptime var i = 0;
    inline while (i < 16) : (i += 1) {
        comptime var v = 0;
        inline while (v < 256) : (v += 1) {
            var blk = @as(block, @splat(0));
            blk[i] = definitions.pi_inv_table[v];
            lut[i][v] = transitions.l_inv_trans(blk);
        }
    }
    break :lut_blk lut;
};
