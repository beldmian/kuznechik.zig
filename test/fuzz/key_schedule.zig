const std = @import("std");
const kuznechik = @import("kuznechik");

const block = kuznechik.block;
const key = kuznechik.key;

/// Fuzz harness for key schedule validation.
///
/// This harness tests properties of the generated round keys:
/// 1. All round keys must be unique (no duplicates)
/// 2. All round keys must not be all zeros
///
/// Input format: 32 bytes representing a key
///
/// AFL++ harness signature - takes data pointer and size.
export fn LLVMFuzzerTestOneInput(data: [*]const u8, len: usize) i32 {
    // We need exactly 32 bytes for a key
    if (len < 32) {
        return 0;
    }

    // Extract key from input
    var cipher_key: key align(16) = undefined;
    const key_slice = @as([*]u8, @ptrCast(&cipher_key))[0..32];
    @memcpy(key_slice, data[0..32]);

    // Initialize cipher with the key (this generates round keys)
    const cipher = kuznechik.Cipher.init(cipher_key);

    // Verify all round keys are unique
    for (0..10) |i| {
        for (i + 1..10) |j| {
            // No two round keys should be equal
            std.debug.assert(!std.mem.eql(u8, &@as([16]u8, cipher.ik[i]), &@as([16]u8, cipher.ik[j])));
        }
    }

    // Verify no round key is all zeros
    const zero_block: block = @splat(0);
    for (cipher.ik) |round_key| {
        std.debug.assert(!std.mem.eql(u8, &@as([16]u8, zero_block), &@as([16]u8, round_key)));
    }

    return 0;
}

// Entry point for standalone execution (useful for debugging)
pub fn main() !void {
    // Simple test with known vector from RFC 7801
    const test_key = key{
        0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff,
        0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
        0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10,
        0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef,
    };

    _ = LLVMFuzzerTestOneInput(@as([*]const u8, @ptrCast(&test_key)), 32);

    std.debug.print("Key schedule fuzz harness: Basic test passed\n", .{});
}
