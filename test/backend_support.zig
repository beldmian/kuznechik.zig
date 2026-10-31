//! Minimum vector ABI required by Cipher and the byte-oriented mode factories.
//! This is a compiler capability probe, not a cipher correctness test.
export fn vector_xor(a: @Vector(16, u8), b: @Vector(16, u8)) @Vector(16, u8) {
    return a ^ b;
}

export fn vector_key(k: @Vector(32, u8)) @Vector(16, u8) {
    return @as([32]u8, k)[0..16].*;
}
