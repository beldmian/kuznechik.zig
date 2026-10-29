const std = @import("std");
const luts = @import("luts.zig");
const definitions = @import("definitions.zig");
const transitions = @import("transitions.zig");
const builtin = @import("builtin");
const scalar = @import("scalar.zig");
const hybrid = @import("hybrid.zig");
const broadwell = @import("broadwell.zig");
const parallel = @import("parallel.zig");
const gfni = @import("gfni.zig");
const sliced = @import("sliced.zig");
const toeplitz = @import("toeplitz.zig");

const use_scalar = builtin.cpu.arch == .x86_64 and std.mem.eql(u8, builtin.cpu.model.name, "znver5");
const use_gfni = gfni.supported;

pub const block = definitions.block;
pub const key = definitions.key;
pub const modes = @import("modes/root.zig").Modes(Cipher);

test {
    std.testing.refAllDecls(modes);
}

const testing = std.testing;

inline fn lsx_trans(a: *align(16) block, k: block) void {
    @setRuntimeSafety(false);
    const x = a.* ^ k;
    var accum: block align(16) = @splat(0);
    inline for (0..16) |i| {
        accum ^= luts.ls_trans_lut[i][x[i]];
    }
    a.* = accum;
}

inline fn ls_inv_trans(a: *align(16) block) void {
    @setRuntimeSafety(false);

    var accum: block align(16) = @splat(0);

    inline for (0..16) |i| {
        accum ^= luts.ls_inv_trans_lut[i][a[i]];
    }

    a.* = accum;
}

fn make_iter_c() [32]block {
    @setEvalBranchQuota(1000000);
    var out: [32]block = [_]block{[_]u8{0} ** 16} ** 32;
    for (0..32) |i| {
        var v = [_]u8{0} ** 16;
        v[15] = @intCast(i + 1);
        out[i] = transitions.l_trans(v);
    }
    return out;
}

inline fn f_trans(k1: block, k2: block, iter_c: block) [2]block {
    var next: block align(16) = k1;
    lsx_trans(&next, iter_c);
    return .{ next ^ k2, k1 };
}

fn make_iter_keys(k: key) [10]block {
    @setEvalBranchQuota(1000000);
    var k1: block = @as([32]u8, k)[0..16].*;
    var k2: block = @as([32]u8, k)[16..32].*;
    var iter_keys: [10]block = [_]block{[_]u8{0} ** 16} ** 10;
    const iter_c = comptime make_iter_c();
    iter_keys[0] = k1;
    iter_keys[1] = k2;
    comptime var i = 0;
    inline while (i < 4) : (i += 1) {
        comptime var j = 0;
        inline while (j < 8) : (j += 1) {
            const res = f_trans(k1, k2, iter_c[j + 8 * i]);
            k1 = res[0];
            k2 = res[1];
        }
        iter_keys[2 * i + 2] = k1;
        iter_keys[2 * i + 3] = k2;
    }
    return iter_keys;
}

pub const Cipher = struct {
    k: key align(16),
    ik: [10]block align(16),
    ik_inv: [10]block align(16),

    pub fn init(k: key) Cipher {
        @prefetch(&luts.ls_trans_lut, .{});
        @prefetch(&luts.ls_inv_trans_lut, .{});
        const ik = make_iter_keys(k);
        var ik_inv: [10]block align(16) = undefined;

        for (0..10) |i| {
            // The inverse S in the lookup cancels this S, leaving L^-1.
            ik_inv[i] = transitions.s_trans(ik[i]);
            ls_inv_trans(&ik_inv[i]);
        }

        return .{
            .k = k,
            .ik = ik,
            .ik_inv = ik_inv,
        };
    }

    pub fn encrypt(self: Cipher, msg: *align(16) block) void {
        @setRuntimeSafety(false);
        if (comptime use_scalar and hybrid.supported) return hybrid.encrypt(&self.ik, msg);
        if (comptime use_scalar) return scalar.encrypt(&self.ik, msg);
        if (comptime builtin.cpu.arch == .x86_64 and std.mem.eql(u8, builtin.cpu.model.name, "broadwell")) return broadwell.encrypt(&self.ik, msg);

        var state = msg.*;
        inline for (0..9) |i| {
            lsx_trans(&state, self.ik[i]);
        }
        state ^= self.ik[9];
        msg.* = state;
    }

    pub fn decrypt(self: Cipher, msg: *align(16) block) void {
        @setRuntimeSafety(false);
        if (comptime use_scalar and hybrid.supported) return hybrid.decrypt(&self.ik, &self.ik_inv, msg);
        if (comptime use_scalar) return scalar.decrypt(&self.ik, &self.ik_inv, msg);

        var state = msg.*;

        transitions.s_trans_inplace(&state);

        inline for (0..9) |i| {
            var accum: block align(16) = @splat(0);

            inline for (0..16) |j| {
                accum ^= luts.ls_inv_trans_lut[j][state[j]];
            }

            state = accum ^ self.ik_inv[9 - i];
        }

        transitions.s_inv_trans_inplace(&state);

        // XOR with first round key and store result
        state ^= self.ik[0];
        msg.* = state;
    }

    /// Encrypt independent raw blocks in place. This is not a cipher mode;
    /// callers remain responsible for mode construction and authentication.
    pub fn encryptBlocks(self: Cipher, messages: []align(16) block) void {
        if (messages.len <= 1) {
            if (messages.len == 1) self.encrypt(&messages[0]);
            return;
        }
        var remaining = messages;
        if (comptime use_gfni) {
            if (comptime use_scalar) {
                if (remaining.len >= 64) {
                    const encoded_keys = toeplitz.prepareKeys(&self.ik, false);
                    while (remaining.len >= 64) {
                        cryptToeplitzBatch(false, &self, &encoded_keys, remaining[0..64]);
                        remaining = remaining[64..];
                    }
                    return cryptToeplitzTail(false, &self, &encoded_keys, remaining);
                }
            }
            while (remaining.len >= 64) {
                sliced.encrypt(&self.ik, remaining[0..64]);
                remaining = remaining[64..];
            }
            return cryptGfniTail(false, &self, remaining);
        } else {
            while (remaining.len >= 8) {
                parallel.encrypt(8, &self.ik, remaining[0..8]);
                remaining = remaining[8..];
            }
            inline for (.{ 4, 2 }) |width| {
                if (remaining.len >= width) {
                    parallel.encrypt(width, &self.ik, remaining[0..width]);
                    remaining = remaining[width..];
                }
            }
        }
        for (remaining) |*msg| self.encrypt(msg);
    }

    /// Decrypt independent raw blocks in place; accepts empty slices and tails.
    pub fn decryptBlocks(self: Cipher, messages: []align(16) block) void {
        if (messages.len <= 1) {
            if (messages.len == 1) self.decrypt(&messages[0]);
            return;
        }
        var remaining = messages;
        if (comptime use_gfni) {
            if (comptime use_scalar) {
                if (remaining.len >= 64) {
                    const encoded_keys = toeplitz.prepareKeys(&self.ik_inv, true);
                    while (remaining.len >= 64) {
                        cryptToeplitzBatch(true, &self, &encoded_keys, remaining[0..64]);
                        remaining = remaining[64..];
                    }
                    return cryptToeplitzTail(true, &self, &encoded_keys, remaining);
                }
            }
            while (remaining.len >= 64) {
                sliced.decrypt(&self.ik, remaining[0..64]);
                remaining = remaining[64..];
            }
            return cryptGfniTail(true, &self, remaining);
        } else {
            while (remaining.len >= 8) {
                parallel.decrypt(8, &self.ik, &self.ik_inv, remaining[0..8]);
                remaining = remaining[8..];
            }
            inline for (.{ 4, 2 }) |width| {
                if (remaining.len >= width) {
                    parallel.decrypt(width, &self.ik, &self.ik_inv, remaining[0..width]);
                    remaining = remaining[width..];
                }
            }
        }
        for (remaining) |*msg| self.decrypt(msg);
    }
};

fn cryptToeplitzBatch(comptime inverse: bool, cipher: *const Cipher, encoded_keys: *const [10]block, messages: *align(16) [64]block) void {
    if (inverse) toeplitz.decryptPrepared(&cipher.ik, encoded_keys, messages) else toeplitz.encryptPrepared(encoded_keys, messages);
}
fn cryptToeplitzTail(comptime inverse: bool, cipher: *const Cipher, encoded_keys: *const [10]block, messages: []align(16) block) void {
    if (messages.len <= 24) return cryptGfniTail(inverse, cipher, messages);
    var padded: [64]block align(16) = @splat(@as(block, @splat(0)));
    @memcpy(padded[0..messages.len], messages);
    cryptToeplitzBatch(inverse, cipher, encoded_keys, &padded);
    @memcpy(messages, padded[0..messages.len]);
}

// The batch kernels are stateless, so unused lanes can be zero-padded and
// discarded. On the measured Zen 5 targets this avoids expensive combinations
// of small kernels and scalar tail calls without changing Cipher's layout.
fn cryptGfniBatch(comptime inverse: bool, comptime width: usize, cipher: *const Cipher, messages: *align(16) [width]block) void {
    if (width == 64) {
        if (comptime use_scalar) {
            const encoded_keys = toeplitz.prepareKeys(if (inverse) &cipher.ik_inv else &cipher.ik, inverse);
            return cryptToeplitzBatch(inverse, cipher, &encoded_keys, messages);
        }
        if (inverse) sliced.decrypt(&cipher.ik, messages) else sliced.encrypt(&cipher.ik, messages);
    } else {
        if (inverse) gfni.decrypt(width / 4, &cipher.ik, messages) else gfni.encrypt(width / 4, &cipher.ik, messages);
    }
}

fn cryptGfniPadded(comptime inverse: bool, comptime width: usize, cipher: *const Cipher, messages: []align(16) block) void {
    var padded: [width]block align(16) = @splat(@as(block, @splat(0)));
    @memcpy(padded[0..messages.len], messages);
    cryptGfniBatch(inverse, width, cipher, &padded);
    @memcpy(messages, padded[0..messages.len]);
}

fn cryptGfniTail(comptime inverse: bool, cipher: *const Cipher, messages: []align(16) block) void {
    if (messages.len == 0) return;
    if (messages.len == 1) {
        if (inverse) cipher.decrypt(&messages[0]) else cipher.encrypt(&messages[0]);
        return;
    }
    // Paired measurements of every tail 1..63 include all padding/copy costs.
    // Up to 24 blocks, one matrix kernel rounded to four lanes beats combining
    // smaller calls. Larger tails favor one padded 64-block recurrence kernel.
    if (messages.len > 24) return cryptGfniPadded(inverse, 64, cipher, messages);
    inline for (.{ 4, 8, 12, 16, 20, 24 }) |width| {
        if (messages.len <= width) {
            if (messages.len == width) {
                cryptGfniBatch(inverse, width, cipher, messages[0..width]);
            } else {
                cryptGfniPadded(inverse, width, cipher, messages);
            }
            return;
        }
    }
}

test "LS transition test" {
    var vect_l_test = @Vector(16, u8){ 0x64, 0xa5, 0x94, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    const vect_l_test_copy = @Vector(16, u8){ 0x64, 0xa5, 0x94, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    const vect_zero = @Vector(16, u8){ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    lsx_trans(&vect_l_test, vect_zero);
    try testing.expectEqual(transitions.l_trans(transitions.s_trans(vect_l_test_copy)), vect_l_test);
}

test "LS inverse transition test" {
    var vect_l_test = @Vector(16, u8){ 0x64, 0xa5, 0x94, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    const vect_l_test_copy = @Vector(16, u8){ 0x64, 0xa5, 0x94, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    ls_inv_trans(&vect_l_test);
    try testing.expectEqual(transitions.l_inv_trans(transitions.s_inv_trans(vect_l_test_copy)), vect_l_test);
}

test "Iterational constants test" {
    const iter_c_1 = @Vector(16, u8){ 0x6e, 0xa2, 0x76, 0x72, 0x6c, 0x48, 0x7a, 0xb8, 0x5d, 0x27, 0xbd, 0x10, 0xdd, 0x84, 0x94, 0x01 };
    const iter_c_8 = @Vector(16, u8){ 0xf6, 0x59, 0x36, 0x16, 0xe6, 0x05, 0x56, 0x89, 0xad, 0xfb, 0xa1, 0x80, 0x27, 0xaa, 0x2a, 0x08 };
    const iter_c = make_iter_c();
    try testing.expectEqual(iter_c[0], iter_c_1);
    try testing.expectEqual(iter_c[7], iter_c_8);
}

test "Iterational keys test" {
    const k = key{ 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef };
    const iter_keys = make_iter_keys(k);
    const iter_key_1 = block{ 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77 };
    const iter_key_10 = block{ 0x72, 0xe9, 0xdd, 0x74, 0x16, 0xbc, 0xf4, 0x5b, 0x75, 0x5d, 0xba, 0xa8, 0x8e, 0x4a, 0x40, 0x43 };
    try testing.expectEqual(iter_keys[0], iter_key_1);
    try testing.expectEqual(iter_keys[9], iter_key_10);
}

test "lookup key setup matches every basic Feistel and inverse key" {
    var prng = std.Random.DefaultPrng.init(0x6b65797365747570);
    const random = prng.random();
    const constants = comptime make_iter_c();
    for (0..32) |key_index| {
        var bytes: [32]u8 = undefined;
        random.bytes(&bytes);
        if (key_index == 0) @memset(&bytes, 0);
        if (key_index == 1) @memset(&bytes, 0xff);
        const cipher = Cipher.init(bytes);
        try testing.expectEqual(@as(key, bytes), cipher.k);
        var k1: block = bytes[0..16].*;
        var k2: block = bytes[16..32].*;
        try testing.expectEqual(k1, cipher.ik[0]);
        try testing.expectEqual(k2, cipher.ik[1]);
        for (0..4) |group| {
            for (0..8) |round| {
                const next = transitions.l_trans(transitions.s_trans(k1 ^ constants[group * 8 + round])) ^ k2;
                k2 = k1;
                k1 = next;
            }
            try testing.expectEqual(k1, cipher.ik[group * 2 + 2]);
            try testing.expectEqual(k2, cipher.ik[group * 2 + 3]);
        }
        for (0..10) |i| try testing.expectEqual(transitions.l_inv_trans(cipher.ik[i]), cipher.ik_inv[i]);
    }
}

test "Cipher test" {
    const k = key{ 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef };
    const iter_key_1 = block{ 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77 };
    var msg = block{ 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x00, 0xff, 0xee, 0xdd, 0xcc, 0xbb, 0xaa, 0x99, 0x88 };
    const msg_enc = block{ 0x7f, 0x67, 0x9d, 0x90, 0xbe, 0xbc, 0x24, 0x30, 0x5a, 0x46, 0x8d, 0x42, 0xb9, 0xd4, 0xed, 0xcd };
    const msg_dec = block{ 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x00, 0xff, 0xee, 0xdd, 0xcc, 0xbb, 0xaa, 0x99, 0x88 };
    const cipher = Cipher.init(k);
    try testing.expectEqual(cipher.ik[0], iter_key_1);
    try testing.expectEqual(cipher.ik_inv[0], transitions.l_inv_trans(iter_key_1));
    cipher.encrypt(&msg);
    try testing.expectEqual(msg_enc, msg);
    cipher.decrypt(&msg);
    try testing.expectEqual(msg_dec, msg);
}

test "optimized cipher matches basic transformations for independent inputs" {
    var prng = std.Random.DefaultPrng.init(0x4b757a6e65636869);
    const random = prng.random();
    for (0..24) |key_index| {
        var key_bytes: [32]u8 = undefined;
        random.bytes(&key_bytes);
        if (key_index == 0) @memset(&key_bytes, 0);
        if (key_index == 1) @memset(&key_bytes, 0xff);
        const cipher = Cipher.init(key_bytes);

        for (0..12) |block_index| {
            var bytes: [16]u8 = undefined;
            random.bytes(&bytes);
            if (block_index == 0) @memset(&bytes, 0);
            if (block_index == 1) @memset(&bytes, 0xff);
            if (block_index == 2) bytes = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
            const input: block = bytes;

            var expected_encrypted = input;
            for (0..9) |i| {
                expected_encrypted = transitions.l_trans(transitions.s_trans(expected_encrypted ^ cipher.ik[i]));
            }
            expected_encrypted ^= cipher.ik[9];
            var encrypted: block align(16) = input;
            cipher.encrypt(&encrypted);
            try testing.expectEqual(expected_encrypted, encrypted);
            cipher.decrypt(&encrypted);
            try testing.expectEqual(input, encrypted);

            // Treat the input as independent ciphertext too: round trips alone
            // can conceal matching mistakes in encryption and decryption.
            var expected_decrypted = input ^ cipher.ik[9];
            for (0..9) |i| {
                expected_decrypted = transitions.s_inv_trans(transitions.l_inv_trans(expected_decrypted)) ^ cipher.ik[8 - i];
            }
            var decrypted: block align(16) = input;
            cipher.decrypt(&decrypted);
            try testing.expectEqual(expected_decrypted, decrypted);
        }
    }
}

test "bulk operations match independent blocks at every batch and tail boundary" {
    var prng = std.Random.DefaultPrng.init(0x706172616c6c656c);
    const random = prng.random();
    const lengths = [_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 127, 128, 129, 255, 256, 257, 511, 512, 513, 1023, 1024, 1025 };
    for (0..3) |key_index| {
        var key_bytes: [32]u8 = undefined;
        random.bytes(&key_bytes);
        if (key_index == 0) @memset(&key_bytes, 0);
        if (key_index == 1) @memset(&key_bytes, 0xff);
        const cipher = Cipher.init(key_bytes);
        // Shift by whole blocks to exercise every alignment modulo 64 while
        // preserving the public 16-byte alignment contract.
        for (0..4) |offset| {
            for (lengths) |len| {
                var input: [1032]block align(64) = undefined;
                random.bytes(std.mem.asBytes(&input));
                var actual = input;
                var expected = input;
                for (expected[offset..][0..len]) |*msg| cipher.encrypt(msg);
                cipher.encryptBlocks(actual[offset..][0..len]);
                // Compare guards as well as the requested range.
                try testing.expectEqual(expected, actual);
                cipher.decryptBlocks(actual[offset..][0..len]);
                try testing.expectEqual(input, actual);

                actual = input;
                expected = input;
                for (expected[offset..][0..len]) |*msg| cipher.decrypt(msg);
                cipher.decryptBlocks(actual[offset..][0..len]);
                try testing.expectEqual(expected, actual);
            }
        }
    }
}

// Public test helpers for fuzzing
// These expose the internal LS transformation functions for testing purposes

/// Apply LS transformation with XOR key addition (for testing/fuzzing only)
/// This computes: a = L(S(a ^ k))
pub fn testLsx(a: *align(16) block, k: block) void {
    lsx_trans(a, k);
}

/// Apply inverse LS transformation (for testing/fuzzing only)
/// This computes: a = L^-1(S^-1(a))
/// Note: This is NOT a direct inverse of testLsx - it's used internally by decrypt
pub fn testLsInv(a: *align(16) block) void {
    ls_inv_trans(a);
}

/// Apply the proper inverse of testLsx (for testing/fuzzing only)
/// If testLsx(a, k) is called, then testLsInvKey(a, k) will restore the original value
/// This computes: a = L^-1(S^-1(a)) ^ k
pub fn testLsInvKey(a: *align(16) block, k: block) void {
    ls_inv_trans(a);
    a.* ^= k;
}

/// Test helper using basic transformations (not LUT-optimized)
/// This computes LS transformation: a = L(S(a ^ k))
pub fn testLsBasic(a: *align(16) block, k: block) void {
    a.* ^= k;
    a.* = transitions.s_trans(a.*);
    a.* = transitions.l_trans(a.*);
}

/// Test helper using basic inverse transformations
/// This computes inverse LS transformation: a = S^-1(L^-1(a)) ^ k
pub fn testLsInvBasic(a: *align(16) block, k: block) void {
    a.* = transitions.l_inv_trans(a.*);
    a.* = transitions.s_inv_trans(a.*);
    a.* ^= k;
}
