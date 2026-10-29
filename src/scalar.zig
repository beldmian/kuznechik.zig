//! Scalar register scheduling tuned and measured on AMD Zen 5. Other CPU
//! targets retain the vector lookup kernel: this layout regresses Broadwell.
const definitions = @import("definitions.zig");
const luts = @import("luts.zig");
const block = definitions.block;

inline fn lookup(comptime inverse: bool, comptime groups: usize, words: [2]u64, seed: [2]u64, comptime first_inverse_round: bool) [2]u64 {
    const table: *const [16][256][2]u64 = @ptrCast(if (inverse) &luts.ls_inv_trans_lut else &luts.ls_trans_lut);
    var accum: [groups][2]u64 = .{.{ 0, 0 }} ** groups;
    // Fold the next key into a partial chain before the final reduction, so
    // key addition does not extend the dependency between consecutive rounds.
    accum[0] = seed;
    inline for (0..groups) |group| {
        inline for (0..16 / groups) |j| {
            const i = group * (16 / groups) + j;
            // Form a byte offset directly, avoiding a separate byte extraction
            // followed by a scale. The substituted byte or mask bounds every
            // load to its 4096-byte row.
            const offset: usize = if (first_inverse_round)
                @as(usize, definitions.pi_table[@as(u8, @truncate(words[i / 8] >> @as(u6, @intCast(i % 8 * 8))))]) << 4
            else if (i % 8 == 0)
                (words[i / 8] << 4) & 0xff0
            else
                (words[i / 8] >> @as(u6, @intCast(i % 8 * 8 - 4))) & 0xff0;
            const entry: *const [2]u64 = @ptrFromInt(@intFromPtr(&table[i]) + offset);
            accum[group][0] ^= entry[0];
            accum[group][1] ^= entry[1];
        }
        if (groups > 1) {
            // These identity constraints emit no instructions. They keep LLVM
            // from reassociating the four short XOR chains into one long chain.
            accum[group][0] = asm (""
                : [out] "=r" (-> u64),
                : [in] "0" (accum[group][0]),
            );
            accum[group][1] = asm (""
                : [out] "=r" (-> u64),
                : [in] "0" (accum[group][1]),
            );
        }
    }
    var out = accum[0];
    inline for (1..groups) |i| {
        out[0] ^= accum[i][0];
        out[1] ^= accum[i][1];
    }
    return out;
}

inline fn substitute(comptime inverse: bool, words: [2]u64) [2]u64 {
    const pi = if (inverse) definitions.pi_inv_table else definitions.pi_table;
    var out: [2]u64 = .{ 0, 0 };
    inline for (0..16) |i| {
        const shift: u6 = @intCast(i % 8 * 8);
        out[i / 8] |= @as(u64, pi[@as(u8, @truncate(words[i / 8] >> shift))]) << shift;
    }
    return out;
}

pub fn encrypt(keys: *const [10]block, msg: *align(16) block) void {
    @setRuntimeSafety(false);
    var state: [2]u64 = @bitCast(msg.* ^ keys[0]);
    inline for (0..9) |i| {
        state = lookup(false, 4, state, @bitCast(keys[i + 1]), false);
    }
    msg.* = @bitCast(state);
}

pub fn decrypt(keys: *const [10]block, inverse_keys: *const [10]block, msg: *align(16) block) void {
    @setRuntimeSafety(false);
    // Fuse the initial S directly into the first inverse lookup indices.
    var state: [2]u64 = @bitCast(msg.*);
    inline for (0..9) |i| {
        state = lookup(true, 4, state, @bitCast(inverse_keys[9 - i]), i == 0);
    }
    msg.* = @as(block, @bitCast(substitute(true, state))) ^ keys[0];
}
