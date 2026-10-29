//! Portable lookup-table kernels with independent blocks interleaved by round.
const definitions = @import("definitions.zig");
const transitions = @import("transitions.zig");
const luts = @import("luts.zig");
const block = definitions.block;

inline fn round(comptime inverse: bool, comptime width: usize, key: block, states: *[width]block) void {
    inline for (0..width) |lane| {
        if (!inverse) states[lane] ^= key;
        var accum: block = @splat(0);
        inline for (0..16) |j| {
            const table = if (inverse) &luts.ls_inv_trans_lut else &luts.ls_trans_lut;
            accum ^= table[j][states[lane][j]];
        }
        states[lane] = if (inverse) accum ^ key else accum;
    }
}

pub fn encrypt(comptime width: usize, keys: *const [10]block, messages: *[width]block) void {
    @setRuntimeSafety(false);
    @setEvalBranchQuota(100000);
    var states = messages.*;
    // Keeping the round loop reduces instruction footprint and register spills
    // on the measured Broadwell target.
    for (0..9) |i| round(false, width, keys[i], &states);
    inline for (0..width) |lane| states[lane] ^= keys[9];
    messages.* = states;
}

pub fn decrypt(comptime width: usize, keys: *const [10]block, inverse_keys: *const [10]block, messages: *[width]block) void {
    @setRuntimeSafety(false);
    @setEvalBranchQuota(100000);
    var states = messages.*;
    inline for (0..width) |lane| states[lane] = transitions.s_trans(states[lane]);
    inline for (0..9) |i| round(true, width, inverse_keys[9 - i], &states);
    inline for (0..width) |lane| states[lane] = transitions.s_inv_trans(states[lane]) ^ keys[0];
    messages.* = states;
}
