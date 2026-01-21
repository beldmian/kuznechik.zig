const std = @import("std");
const kuznechik = @import("kuznechik");

const block = kuznechik.block;

/// Fuzz harness for LS transformation round-trip property.
///
/// This harness tests that applying LS transformation followed by
/// inverse LS transformation results in the original block.
///
/// Input format: 16 bytes representing a block
///
/// AFL++ harness signature - takes data pointer and size.
export fn LLVMFuzzerTestOneInput(data: [*]const u8, len: usize) i32 {
    // We need exactly 16 bytes for a block
    if (len < 16) {
        return 0;
    }

    // Create a copy of the input block
    var original: block align(16) = undefined;
    const original_slice = @as([*]u8, @ptrCast(&original))[0..16];
    @memcpy(original_slice, data[0..16]);

    // Create working copy for transformation
    var working: block align(16) = undefined;
    const working_slice = @as([*]u8, @ptrCast(&working))[0..16];
    @memcpy(working_slice, data[0..16]);

    // Apply LS transformation with zero key (pure LS operation)
    const zero_key: block = @splat(@as(u8, 0));
    kuznechik.testLsBasic(&working, zero_key);

    // Apply proper inverse LS transformation with key XOR
    // The inverse of LS(a, k) is: a = S^-1(L^-1(a)) ^ k
    kuznechik.testLsInvBasic(&working, zero_key);

    // Assert that we get back the original block
    // This should never fail unless there's a bug in the implementation
    std.debug.assert(std.mem.eql(u8, &@as([16]u8, original), &@as([16]u8, working)));

    return 0;
}

// Entry point for standalone execution (useful for debugging)
pub fn main() !void {
    // Simple test with known vectors
    const test_input = [_]u8{ 0x64, 0xa5, 0x94, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };

    _ = LLVMFuzzerTestOneInput(&test_input, 16);

    std.debug.print("LS round-trip fuzz harness: Basic test passed\n", .{});
}
