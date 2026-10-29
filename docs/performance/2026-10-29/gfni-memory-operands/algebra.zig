//! Independent actual-GFNI validation. No production test/helper is used as oracle.
const std = @import("std");
const core = @import("toeplitz_core.zig");
const B = @Vector(16, u8);
const coeff = [16]u8{148,32,133,16,194,192,1,251,1,192,194,16,133,32,148,1};
fn mul(a0: u8, b0: u8) u8 {
    var a = a0; var b = b0; var out: u8 = 0;
    for (0..8) |_| { if (b & 1 != 0) out ^= a; a = (a << 1) ^ @as(u8, if (a & 128 != 0) 0xc3 else 0); b >>= 1; }
    return out;
}
fn reference(input: [16]u8, comptime inv: bool) [16]u8 {
    var x = input;
    for (0..16) |_| {
        if (inv) {
            var last = x[0]; for (0..15) |i| last ^= mul(coeff[i],x[i+1]);
            for (0..15) |i| x[i] = x[i+1]; x[15] = last;
        } else {
            var first: u8 = 0; for (0..16) |i| first ^= mul(coeff[i], x[i]);
            var i: usize = 15; while (i != 0) : (i -= 1) x[i] = x[i-1]; x[0] = first;
        }
    }
    return x;
}
fn check(raw: [16]core.W, key: B, comptime inv: bool) !void {
    var state: [16]core.W = undefined;
    var seeded: B = undefined;
    inline for (0..16) |i| {
        const pos = if (inv) 15-i else i;
        for (0..64) |lane| state[i][lane] = mul(raw[i][lane],core.column_inverse[pos]);
        seeded[i] = mul(key[i],core.row_scale[pos]);
    }
    const result = if (inv) core.inverseSeeded(state,seeded) else core.forwardSeeded(state,seeded);
    for (0..64) |lane| {
        var input: [16]u8 = undefined; for (0..16) |i| input[i] = raw[i][lane];
        const expected = reference(input, inv);
        for (0..16) |i| try std.testing.expectEqual(expected[i] ^ key[i],mul(result[i][lane],core.row_inverse[if (inv) 15-i else i]));
    }
}
test "independent GFNI all byte basis both directions and seeded dense recurrence" {
    var prng = std.Random.DefaultPrng.init(0x902970);const rng=prng.random();
    inline for (.{ false,true }) |inv| {
        for (0..16) |pos| for (0..4) |batch| {
            var raw: [16]core.W = @splat(@splat(0));
            for (0..64) |lane| raw[pos][lane] = @intCast(batch*64+lane);
            try check(raw,@splat(0),inv);
        };
        for (0..1024) |_| {
            var raw: [16]core.W = undefined; rng.bytes(std.mem.asBytes(&raw));
            var key: B = undefined; rng.bytes(std.mem.asBytes(&key));
            try check(raw,key,inv);
        }
    }
}
