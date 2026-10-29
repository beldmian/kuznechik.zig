const core = @import("toeplitz_core.zig");
const toeplitz = @import("toeplitz.zig");
const B = @Vector(16, u8);
export fn linear(input: *const [16]core.W, key: *const B, output: *[16]core.W) void {
    output.* = core.forwardSeeded(input.*, key.*);
}
export fn encrypt(keys: *const [10]B, blocks: *align(16) [64]B) void {
    const encoded = toeplitz.prepareKeys(keys, false);
    toeplitz.encryptPrepared(&encoded, blocks);
}
export fn decrypt(keys: *const [10]B, invkeys: *const [10]B, blocks: *align(16) [64]B) void {
    const encoded = toeplitz.prepareKeys(invkeys, true);
    toeplitz.decryptPrepared(keys, &encoded, blocks);
}
