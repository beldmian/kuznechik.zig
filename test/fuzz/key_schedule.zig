const std = @import("std");
const kuznechik = @import("kuznechik");

const key = kuznechik.key;

/// Fuzz harness for key schedule validation.
///
/// Compares every encryption and inverse linear round key with a scalar
/// RFC 7801 reference. This checks equality, not constant-time behavior.
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

    const reference = @import("key_reference.zig");
    const expected = reference.expand(key_slice[0..32].*);
    for (expected, 0..) |round_key, i| {
        if (!std.mem.eql(u8, &round_key, &@as([16]u8, cipher.ik[i]))) @panic("round key mismatch");
        const inverse = reference.inverseLinear(round_key);
        if (!std.mem.eql(u8, &inverse, &@as([16]u8, cipher.ik_inv[i]))) @panic("inverse key mismatch");
    }

    for (0..4) |group| {
        const previous = reference.previousPair(@as([16]u8, cipher.ik[2 + group * 2]), @as([16]u8, cipher.ik[3 + group * 2]), group);
        for (previous, 0..) |round_key, i| {
            if (!std.mem.eql(u8, &round_key, &@as([16]u8, cipher.ik[group * 2 + i]))) @panic("reverse schedule mismatch");
        }
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

    try @import("standalone.zig").run(&LLVMFuzzerTestOneInput, &@as([32]u8, test_key));
}
