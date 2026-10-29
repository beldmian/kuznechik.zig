const definitions = @import("definitions.zig");
const transitions = @import("transitions.zig");

const block = definitions.block;

// L is linear over GF(2): build each byte's 256 contributions from eight
// basis vectors instead of evaluating the full L transform 256 times. This
// changes only compilation work, not the resulting lookup tables.
fn makeLsLut(comptime inverse: bool) [16][256]block {
    @setEvalBranchQuota(100000000);
    var lut: [16][256]block = undefined;
    const pi = if (inverse) definitions.pi_inv_table else definitions.pi_table;
    for (0..16) |i| {
        var linear: [256]block = undefined;
        linear[0] = @splat(0);
        for (0..8) |bit| {
            const base = @as(usize, 1) << @intCast(bit);
            var unit: block = @splat(0);
            unit[i] = @intCast(base);
            const basis = if (inverse) transitions.l_inv_trans(unit) else transitions.l_trans(unit);
            for (0..base) |v| linear[base + v] = linear[v] ^ basis;
        }
        for (0..256) |v| {
            lut[i][v] = linear[pi[v]];
        }
    }
    return lut;
}

pub const ls_trans_lut = makeLsLut(false);
pub const ls_inv_trans_lut = makeLsLut(true);

test "generated lookup tables match basic transformations exhaustively" {
    const testing = @import("std").testing;
    for (0..16) |i| {
        for (0..256) |v| {
            var forward: block = @splat(0);
            forward[i] = definitions.pi_table[v];
            try testing.expectEqual(transitions.l_trans(forward), ls_trans_lut[i][v]);
            var inverse: block = @splat(0);
            inverse[i] = definitions.pi_inv_table[v];
            try testing.expectEqual(transitions.l_inv_trans(inverse), ls_inv_trans_lut[i][v]);
        }
    }
}
