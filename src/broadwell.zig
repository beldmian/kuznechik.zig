//! Encryption scheduling measured on Intel Broadwell. The caller selects this
//! kernel only for that CPU model; decryption keeps its existing vector kernel.
const definitions = @import("definitions.zig");
const luts = @import("luts.zig");
const block = definitions.block;

inline fn lookup(state: block) block {
    const raw: [2]u64 = @bitCast(state);
    // Keep byte extraction in integer registers instead of repeatedly moving
    // individual bytes from a SIMD register. The constraints emit no code.
    const words = [2]u64{
        asm (""
            : [out] "=r" (-> u64),
            : [in] "0" (raw[0]),
        ),
        asm (""
            : [out] "=r" (-> u64),
            : [in] "0" (raw[1]),
        ),
    };
    var accum: [2]block = .{ @splat(0), @splat(0) };
    inline for (0..2) |group| {
        inline for (group * 8..(group + 1) * 8) |i| {
            // Each masked byte offset stays within its 4096-byte lookup row.
            const offset: usize = if (i % 8 == 0)
                (words[i / 8] << 4) & 0xff0
            else
                (words[i / 8] >> @as(u6, @intCast(i % 8 * 8 - 4))) & 0xff0;
            const entry: *align(16) const block = @ptrFromInt(@intFromPtr(&luts.ls_trans_lut[i]) + offset);
            accum[group] ^= entry.*;
        }
        // Preserve two independent XOR chains through LLVM reassociation.
        accum[group] = asm (""
            : [out] "=x" (-> block),
            : [in] "0" (accum[group]),
        );
    }
    return accum[0] ^ accum[1];
}

pub fn encrypt(keys: *const [10]block, msg: *align(16) block) void {
    @setRuntimeSafety(false);
    var state = msg.*;
    inline for (0..9) |i| {
        state = lookup(state ^ keys[i]);
    }
    msg.* = state ^ keys[9];
}
