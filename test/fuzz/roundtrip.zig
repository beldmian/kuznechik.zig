const std = @import("std");
const kuznechik = @import("kuznechik");

const block = kuznechik.block;
const key = kuznechik.key;

/// Fuzz harness for encryption/decryption round-trip property.
///
/// This harness tests that decrypting an encrypted message
/// results in the original plaintext.
///
/// Input format: 48 bytes containing a 32-byte key followed by 16-byte plaintext
///
/// AFL++ harness signature - takes data pointer and size.
export fn LLVMFuzzerTestOneInput(data: [*]const u8, len: usize) i32 {
    // We need exactly 48 bytes: 32-byte key + 16-byte plaintext
    if (len < 48) {
        return 0;
    }

    // Extract key and plaintext from input
    var cipher_key: key align(16) = undefined;
    const key_slice = @as([*]u8, @ptrCast(&cipher_key))[0..32];
    @memcpy(key_slice, data[0..32]);

    var plaintext: block align(16) = undefined;
    const plaintext_slice = @as([*]u8, @ptrCast(&plaintext))[0..16];
    @memcpy(plaintext_slice, data[32..48]);

    // Store original plaintext for comparison
    const original = plaintext;

    // Initialize cipher with the key
    const cipher = kuznechik.Cipher.init(cipher_key);

    // Encrypt the plaintext
    cipher.encrypt(&plaintext);

    // Decrypt the ciphertext
    cipher.decrypt(&plaintext);

    // Assert that we get back the original plaintext
    // This should never fail unless there's a bug in the implementation
    std.debug.assert(std.mem.eql(u8, &@as([16]u8, original), &@as([16]u8, plaintext)));

    return 0;
}

// Entry point for standalone execution (useful for debugging)
pub fn main() !void {
    // Simple test with known vectors from RFC 7801
    const test_key = key{
        0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff,
        0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
        0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10,
        0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef,
    };
    const test_plaintext = block{
        0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x00,
        0xff, 0xee, 0xdd, 0xcc, 0xbb, 0xaa, 0x99, 0x88,
    };

    var test_input: [48]u8 = undefined;
    @memcpy(test_input[0..32], @as([*]const u8, @ptrCast(&test_key))[0..32]);
    @memcpy(test_input[32..48], @as([*]const u8, @ptrCast(&test_plaintext))[0..16]);

    _ = LLVMFuzzerTestOneInput(&test_input, test_input.len);

    std.debug.print("Round-trip fuzz harness: Basic test passed\n", .{});
}
