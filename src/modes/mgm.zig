//! RFC 9058 MGM for a 128-bit block cipher. Nonces occupy 16 bytes with
//! the most significant bit clear. A nonce MUST be unique under its key;
//! a protocol MUST fix one tag length (4..16 bytes) rather than negotiate it
//! per message. AAD and payload may be unaligned. Overlapping mutable buffers
//! are rejected before any writes; adjacent slices are allowed.
const std = @import("std");
const builtin = @import("builtin");
const B = @Vector(16, u8);
const use_pclmul = builtin.cpu.arch == .x86_64 and builtin.zig_backend != .stage2_c and
    std.Target.x86.featureSetHas(builtin.cpu.features, .pclmul);

/// Allocation-free, in-place MGM. The cipher must provide encrypt/encryptBlocks
/// for aligned 16-byte vectors. The cipher is borrowed for each operation.
pub fn Mgm(comptime Cipher: type) type {
    return struct {
        /// RFC 9058 requires 0 < |AAD| + |payload| < 2^64 bits.
        /// This bound also prevents reuse within either 64-bit counter sequence.
        pub fn validate(nonce: [16]u8, aad_len: usize, data_len: usize) !void {
            if (nonce[0] & 0x80 != 0) return error.InvalidNonce;
            const total = @as(u128, aad_len) + @as(u128, data_len);
            if (total == 0) return error.EmptyMessage;
            if (total > std.math.maxInt(u64) / 8) return error.MessageTooLong;
        }

        fn validTag(length: usize) !void {
            if (length < 4 or length > 16) return error.InvalidTagLength;
        }

        /// Encrypt data and return the full 128-bit authentication tag.
        pub fn seal(cipher: *const Cipher, nonce: [16]u8, aad: []const u8, data: []u8) ![16]u8 {
            var tag: [16]u8 = undefined;
            try sealDetached(cipher, nonce, aad, data, &tag);
            return tag;
        }

        /// Encrypt data and write the most significant tag_out.len tag bytes.
        /// Validation errors leave both data and tag_out unchanged.
        pub fn sealDetached(cipher: *const Cipher, nonce: [16]u8, aad: []const u8, data: []u8, tag_out: []u8) !void {
            try validTag(tag_out.len);
            try validate(nonce, aad.len, data.len);
            if (overlaps(aad, data) or overlaps(tag_out, data) or overlaps(tag_out, aad)) return error.InvalidOverlap;
            const q = data.len / 16 + @intFromBool(data.len % 16 != 0);
            const h = aad.len / 16 + @intFromBool(aad.len % 16 != 0);
            const tag = if (q * 2 + h + 1 <= 64) try cryptShort(false, cipher, nonce, aad, data, h, q, &.{}) else tag: {
                xor(cipher, nonce, data);
                break :tag authenticate(cipher, nonce, aad, data);
            };
            @memcpy(tag_out, tag[0..tag_out.len]);
        }

        /// Verify the full tag before decrypting; failures preserve ciphertext.
        pub fn open(cipher: *const Cipher, nonce: [16]u8, aad: []const u8, data: []u8, tag: [16]u8) !void {
            try openDetached(cipher, nonce, aad, data, &tag);
        }

        /// Verify a protocol-fixed 4..16-byte tag in constant time before writing
        /// plaintext. Overlap between data and the tag or AAD is rejected.
        pub fn openDetached(cipher: *const Cipher, nonce: [16]u8, aad: []const u8, data: []u8, tag: []const u8) !void {
            try validTag(tag.len);
            try validate(nonce, aad.len, data.len);
            if (overlaps(aad, data) or overlaps(tag, data)) return error.InvalidOverlap;
            const q = data.len / 16 + @intFromBool(data.len % 16 != 0);
            const h = aad.len / 16 + @intFromBool(aad.len % 16 != 0);
            if (q * 2 + h + 1 <= 64) {
                _ = try cryptShort(true, cipher, nonce, aad, data, h, q, tag);
                return;
            }
            const full = authenticate(cipher, nonce, aad, data);
            try verifyTag(full, tag);
            xor(cipher, nonce, data);
        }

        /// Authenticate the concatenation of AAD parts, padding only once at
        /// the end of AAD (never at part boundaries). Allocation-free; useful
        /// for protocol prefixes followed by a discontiguous read-only body.
        /// Old contiguous APIs and their optimized paths are unchanged.
        pub fn sealParts(cipher: *const Cipher, nonce: [16]u8, aad: []const []const u8, data: []u8) ![16]u8 {
            const length = try partsLength(nonce, aad, data.len);
            if (overlaps(std.mem.sliceAsBytes(aad), data)) return error.InvalidOverlap;
            for (aad) |part| if (overlaps(part, data)) return error.InvalidOverlap;
            if (overlaps(std.mem.asBytes(cipher), data)) return error.InvalidOverlap;
            xor(cipher, nonce, data);
            return authenticateParts(cipher, nonce, aad, length, data);
        }

        /// Verify privately before decrypting; invalid input preserves data.
        pub fn openParts(cipher: *const Cipher, nonce: [16]u8, aad: []const []const u8, data: []u8, tag: []const u8) !void {
            try validTag(tag.len);
            const length = try partsLength(nonce, aad, data.len);
            if (overlaps(std.mem.sliceAsBytes(aad), data)) return error.InvalidOverlap;
            for (aad) |part| if (overlaps(part, data)) return error.InvalidOverlap;
            if (overlaps(tag, data) or overlaps(std.mem.asBytes(cipher), data)) return error.InvalidOverlap;
            const full = authenticateParts(cipher, nonce, aad, length, data);
            try verifyTag(full, tag);
            xor(cipher, nonce, data);
        }

        fn partsLength(nonce: [16]u8, aad: []const []const u8, data_len: usize) !usize {
            var length: usize = 0;
            for (aad) |part| {
                length = std.math.add(usize, length, part.len) catch return error.MessageTooLong;
            }
            try validate(nonce, length, data_len);
            return length;
        }

        fn authenticateParts(cipher: *const Cipher, nonce: [16]u8, aad: []const []const u8, length: usize, data: []const u8) [16]u8 {
            var initial: B align(16) = nonce;
            initial[0] |= 0x80;
            cipher.encrypt(&initial);
            var counter: [16]u8 = initial;
            var sum: Product = .{};
            var pending: [16]u8 = @splat(0);
            var used: usize = 0;
            for (aad) |part| {
                var input = part;
                if (used != 0) {
                    const count: usize = @min(16 - used, input.len);
                    @memcpy(pending[used..][0..count], input[0..count]);
                    used += count;
                    input = input[count..];
                    if (used == 16) {
                        add(cipher, &counter, &sum, &pending);
                        pending = @splat(0);
                        used = 0;
                    }
                }
                const complete = input.len / 16 * 16;
                add(cipher, &counter, &sum, input[0..complete]);
                input = input[complete..];
                if (input.len != 0) {
                    @memcpy(pending[0..input.len], input);
                    used = input.len;
                }
            }
            if (used != 0) add(cipher, &counter, &sum, &pending);
            add(cipher, &counter, &sum, data);
            var lengths: [16]u8 = undefined;
            std.mem.writeInt(u64, lengths[0..8], @as(u64, @intCast(length)) * 8, .big);
            std.mem.writeInt(u64, lengths[8..16], @as(u64, @intCast(data.len)) * 8, .big);
            add(cipher, &counter, &sum, &lengths);
            var bytes: [16]u8 = undefined;
            std.mem.writeInt(u128, &bytes, sum.final(), .big);
            var final: B align(16) = bytes;
            cipher.encrypt(&final);
            return final;
        }

        // For short messages, encryption and authentication counters all fit
        // in one independent batch, including the key for the lengths block.
        // Opening precomputes keystream, but forms no plaintext until verification.
        fn cryptShort(comptime opening: bool, cipher: *const Cipher, nonce: [16]u8, aad: []const u8, data: []u8, h: usize, q: usize, tag_in: []const u8) ![16]u8 {
            var domain = nonce;
            domain[0] |= 0x80;
            var seeds: [2]B align(16) = .{ nonce, domain };
            cipher.encryptBlocks(&seeds);
            var y: [16]u8 = seeds[0];
            var z: [16]u8 = seeds[1];
            var blocks: [64]B align(16) = undefined;
            counters(&y, blocks[0..q], false);
            counters(&z, blocks[q..][0 .. h + q + 1], true);
            cipher.encryptBlocks(blocks[0 .. q * 2 + h + 1]);
            if (!opening) xorBatch(data, blocks[0..q]);
            var offset: usize = 0;
            var sum: Product = .{};
            var index = q;
            for ([_][]const u8{ aad, data }) |input| {
                offset = 0;
                while (offset < input.len) {
                    const length = @min(16, input.len - offset);
                    var padded: [16]u8 = @splat(0);
                    @memcpy(padded[0..length], input[offset..][0..length]);
                    const key: [16]u8 = blocks[index];
                    sum.update(std.mem.readInt(u128, &key, .big), std.mem.readInt(u128, &padded, .big));
                    index += 1;
                    offset += length;
                }
            }
            var lengths: [16]u8 = undefined;
            std.mem.writeInt(u64, lengths[0..8], @as(u64, @intCast(aad.len)) * 8, .big);
            std.mem.writeInt(u64, lengths[8..16], @as(u64, @intCast(data.len)) * 8, .big);
            const key: [16]u8 = blocks[index];
            sum.update(std.mem.readInt(u128, &key, .big), std.mem.readInt(u128, &lengths, .big));
            var tag: [16]u8 = undefined;
            std.mem.writeInt(u128, &tag, sum.final(), .big);
            var final: B align(16) = tag;
            cipher.encrypt(&final);
            if (opening) {
                try verifyTag(final, tag_in);
                xorBatch(data, blocks[0..q]);
            }
            return final;
        }

        fn xor(cipher: *const Cipher, nonce: [16]u8, data: []u8) void {
            if (data.len == 0) return;
            var initial: B align(16) = nonce;
            cipher.encrypt(&initial);
            var counter: [16]u8 = initial;
            var blocks: [64]B align(16) = undefined;
            var offset: usize = 0;
            while (offset < data.len) {
                const remaining = data.len - offset;
                const count: usize = @min(64, remaining / 16 + @intFromBool(remaining % 16 != 0));
                counters(&counter, blocks[0..count], false);
                cipher.encryptBlocks(blocks[0..count]);
                const length = @min(remaining, count * 16);
                xorBatch(data[offset..][0..length], blocks[0..count]);
                offset += length;
            }
        }

        fn authenticate(cipher: *const Cipher, nonce: [16]u8, aad: []const u8, ciphertext: []const u8) [16]u8 {
            var domain = nonce;
            domain[0] |= 0x80;
            var initial: B align(16) = domain;
            cipher.encrypt(&initial);
            var counter: [16]u8 = initial;
            var sum: Product = .{};
            add(cipher, &counter, &sum, aad);
            add(cipher, &counter, &sum, ciphertext);
            var lengths: [16]u8 = undefined;
            std.mem.writeInt(u64, lengths[0..8], @as(u64, @intCast(aad.len)) * 8, .big);
            std.mem.writeInt(u64, lengths[8..16], @as(u64, @intCast(ciphertext.len)) * 8, .big);
            var last: B align(16) = counter;
            cipher.encrypt(&last);
            const key: [16]u8 = last;
            sum.update(std.mem.readInt(u128, &key, .big), std.mem.readInt(u128, &lengths, .big));
            var tag: [16]u8 = undefined;
            std.mem.writeInt(u128, &tag, sum.final(), .big);
            var final: B align(16) = tag;
            cipher.encrypt(&final);
            return final;
        }

        fn add(cipher: *const Cipher, counter: *[16]u8, sum: *Product, input: []const u8) void {
            var blocks: [64]B align(16) = undefined;
            var offset: usize = 0;
            while (offset < input.len) {
                const remaining = input.len - offset;
                const count: usize = @min(64, remaining / 16 + @intFromBool(remaining % 16 != 0));
                counters(counter, blocks[0..count], true);
                cipher.encryptBlocks(blocks[0..count]);
                for (blocks[0..count]) |block| {
                    const length = @min(16, input.len - offset);
                    const message = if (length == 16) std.mem.readInt(u128, input[offset..][0..16], .big) else partial: {
                        var padded: [16]u8 = @splat(0);
                        @memcpy(padded[0..length], input[offset..][0..length]);
                        break :partial std.mem.readInt(u128, &padded, .big);
                    };
                    const key: [16]u8 = block;
                    sum.update(std.mem.readInt(u128, &key, .big), message);
                    offset += length;
                }
            }
        }
    };
}

// Compare differences rather than computing end addresses, avoiding addition
// overflow even for caller-provided large lengths. Empty ranges never overlap.
fn overlaps(a: []const u8, b: []const u8) bool {
    if (a.len == 0 or b.len == 0) return false;
    const x = @intFromPtr(a.ptr);
    const y = @intFromPtr(b.ptr);
    return if (x <= y) y - x < a.len else x - y < b.len;
}

fn verifyTag(full: [16]u8, tag: []const u8) !void {
    var expected: [16]u8 = @splat(0);
    var actual: [16]u8 = @splat(0);
    @memcpy(expected[0..tag.len], full[0..tag.len]);
    @memcpy(actual[0..tag.len], tag);
    if (!std.crypto.timing_safe.eql([16]u8, expected, actual)) return error.AuthenticationFailed;
}

fn xorBatch(data: []u8, blocks: []const B) void {
    var offset: usize = 0;
    for (blocks) |block| {
        const length = @min(16, data.len - offset);
        if (length == 16) {
            const plain: B = data[offset..][0..16].*;
            const bytes: [16]u8 = plain ^ block;
            @memcpy(data[offset..][0..16], &bytes);
        } else {
            for (data[offset..][0..length], 0..) |*byte, i| byte.* ^= block[i];
        }
        offset += length;
    }
}

// RFC incr_l/incr_r are modular additions, including wrap within one half.
fn counters(counter: *[16]u8, out: []align(16) B, comptime left: bool) void {
    const half = if (left) counter[0..8] else counter[8..16];
    var value = std.mem.readInt(u64, half, .big);
    for (out) |*block| {
        std.mem.writeInt(u64, half, value, .big);
        block.* = counter.*;
        value +%= 1;
    }
    std.mem.writeInt(u64, half, value, .big);
}

// MGM's multilinear sum permits adding unreduced products: reduce once after
// all authenticated blocks and the lengths block, rather than for each block.
const Product = struct {
    lo: u128 = 0,
    hi: u128 = 0,
    fn update(self: *Product, a: u128, b: u128) void {
        if (comptime use_pclmul) {
            const low = carryless(a, b, false);
            const high = carryless(a, b, true);
            const cross = carryless(a ^ (a >> 64), b ^ (b >> 64), false) ^ low ^ high;
            self.lo ^= low ^ (cross << 64);
            self.hi ^= high ^ (cross >> 64);
        } else self.lo ^= multiplyPortable(a, b);
    }
    fn final(self: Product) u128 {
        const overflow = (self.hi >> 127) ^ (self.hi >> 126) ^ (self.hi >> 121);
        return self.lo ^ self.hi ^ (self.hi << 1) ^ (self.hi << 2) ^ (self.hi << 7) ^
            overflow ^ (overflow << 1) ^ (overflow << 2) ^ (overflow << 7);
    }
};

// Ordinary polynomial basis: integer bit i is the coefficient of x^i.
// This is deliberately different from GHASH's reflected bit convention.
fn multiply(a: u128, b: u128) u128 {
    var product: Product = .{};
    product.update(a, b);
    return product.final();
}

// Carryless 64x64 product. Only compiled for targets advertising PCLMUL.
fn carryless(a: u128, b: u128, comptime high: bool) u128 {
    const product = asm (if (high) "pclmulqdq $0x11, %[b], %[out]" else "pclmulqdq $0x00, %[b], %[out]"
        : [out] "=x" (-> @Vector(2, u64)),
        : [a] "0" (@as(@Vector(2, u64), @bitCast(a))),
          [b] "x" (@as(@Vector(2, u64), @bitCast(b))),
    );
    return @bitCast(product);
}

fn multiplyPortable(a: u128, b: u128) u128 {
    var x = a;
    var y = b;
    var z: u128 = 0;
    for (0..128) |_| {
        z ^= x & (@as(u128, 0) -% (y & 1));
        x = (x << 1) ^ (0x87 & (@as(u128, 0) -% (x >> 127)));
        y >>= 1;
    }
    return z;
}

// Test-only long polynomial multiplication and division: independent of the
// shift/reduce portable implementation and any carryless hardware path.
fn referenceMultiply(a: u128, b: u128) u128 {
    var product: u256 = 0;
    for (0..128) |i| {
        if ((b >> @intCast(i)) & 1 != 0) product ^= @as(u256, a) << @intCast(i);
    }
    const modulus = (@as(u256, 1) << 128) | 0x87;
    var i: usize = 256;
    while (i > 128) {
        i -= 1;
        if ((product >> @intCast(i)) & 1 != 0) product ^= modulus << @intCast(i - 128);
    }
    return @truncate(product);
}

// Test-only direct RFC construction with individual block calls and bytewise
// counter addition. No production counter, authentication, or product helper.
fn referenceSeal(comptime Cipher: type, cipher: *const Cipher, nonce: [16]u8, aad: []const u8, data: []u8) [16]u8 {
    var y: B align(16) = nonce;
    cipher.encrypt(&y);
    var y_bytes: [16]u8 = y;
    var offset: usize = 0;
    while (offset < data.len) {
        var block: B align(16) = y_bytes;
        cipher.encrypt(&block);
        const length = @min(16, data.len - offset);
        for (data[offset..][0..length], 0..) |*byte, j| byte.* ^= block[j];
        var j: usize = 16;
        while (j > 8) {
            j -= 1;
            y_bytes[j] +%= 1;
            if (y_bytes[j] != 0) break;
        }
        offset += length;
    }
    var domain = nonce;
    domain[0] |= 0x80;
    var z: B align(16) = domain;
    cipher.encrypt(&z);
    var z_bytes: [16]u8 = z;
    var lengths: [16]u8 = undefined;
    std.mem.writeInt(u64, lengths[0..8], @as(u64, @intCast(aad.len)) * 8, .big);
    std.mem.writeInt(u64, lengths[8..16], @as(u64, @intCast(data.len)) * 8, .big);
    var sum: u128 = 0;
    for ([_][]const u8{ aad, data, &lengths }) |input| {
        offset = 0;
        while (offset < input.len) {
            var key: B align(16) = z_bytes;
            cipher.encrypt(&key);
            const bytes: [16]u8 = key;
            var padded: [16]u8 = @splat(0);
            const length = @min(16, input.len - offset);
            @memcpy(padded[0..length], input[offset..][0..length]);
            sum ^= referenceMultiply(std.mem.readInt(u128, &bytes, .big), std.mem.readInt(u128, &padded, .big));
            var j: usize = 8;
            while (j > 0) {
                j -= 1;
                z_bytes[j] +%= 1;
                if (z_bytes[j] != 0) break;
            }
            offset += length;
        }
    }
    var result: [16]u8 = undefined;
    std.mem.writeInt(u128, &result, sum, .big);
    var tag: B align(16) = result;
    cipher.encrypt(&tag);
    return tag;
}

test "MGM RFC 9058 Appendix A.1 Kuznechik examples 1 and 2" {
    const h = @import("test_helpers.zig");
    const Cipher = @import("../kuznechik.zig").Cipher;
    const M = Mgm(Cipher);
    const cipher = Cipher.init(h.hex("8899aabbccddeeff0011223344556677fedcba98765432100123456789abcdef"));
    const nonce = h.hex("1122334455667700ffeeddccbbaa9988");
    const aad = h.hex("0202020202020202010101010101010104040404040404040303030303030303ea0505050505050505");
    const plaintext = h.hex("1122334455667700ffeeddccbbaa998800112233445566778899aabbcceeff0a112233445566778899aabbcceeff0a002233445566778899aabbcceeff0a0011aabbcc");
    const ciphertext = h.hex("a9757b8147956e9055b8a33de89f42fc8075d2212bf9fd5bd3f7069aadc16b39497ab15915a6ba85936b5d0ea9f6851cc60c14d4d3f883d0ab94420695c76deb2c7552");
    const expected_tag = h.hex("cf5d656f40c34f5c46e8bb0e29fcdb4c");
    var data = plaintext;
    const tag = try M.seal(&cipher, nonce, &aad, &data);
    try std.testing.expectEqual(ciphertext, data);
    try std.testing.expectEqual(expected_tag, tag);
    try M.open(&cipher, nonce, &aad, &data, tag);
    try std.testing.expectEqual(plaintext, data);
    const cipher2 = Cipher.init(h.hex("99aabbccddeeff0011223344556677fedcba98765432100123456789abcdef88"));
    var empty: [0]u8 = .{};
    const tag2 = try M.seal(&cipher2, nonce, &(@as([16]u8, @splat(1))), &empty);
    try std.testing.expectEqual(h.hex("7901e9ea2085cd247ed249695f9f8a85"), tag2);
    try M.open(&cipher2, nonce, &(@as([16]u8, @splat(1))), &empty, tag2);
}

test "MGM polynomial product matches long division and RFC intermediate sum" {
    const h = @import("test_helpers.zig");
    const key = h.hex("8db187d653830ea4bc446476952c300b");
    const input = h.hex("02020202020202020101010101010101");
    const expected = h.hex("4cf427f4adb75cf4c0da39d5ab48cf38");
    try std.testing.expectEqual(std.mem.readInt(u128, &expected, .big), multiplyPortable(std.mem.readInt(u128, &key, .big), std.mem.readInt(u128, &input, .big)));
    var rng = std.Random.DefaultPrng.init(0x4d474d9058);
    for (0..256) |i| {
        const a: u128 = if (i < 128) @as(u128, 1) << @intCast(i) else rng.random().int(u128);
        const b = rng.random().int(u128);
        try std.testing.expectEqual(referenceMultiply(a, b), multiplyPortable(a, b));
        try std.testing.expectEqual(referenceMultiply(a, b), multiply(a, b));
        try std.testing.expectEqual(a, multiply(a, 1));
        try std.testing.expectEqual(@as(u128, 0), multiply(a, 0));
    }
    try std.testing.expectEqual(referenceMultiply(std.math.maxInt(u128), std.math.maxInt(u128)), multiply(std.math.maxInt(u128), std.math.maxInt(u128)));
}

test "MGM independent scalar differential all short remainders and batch boundaries" {
    const Cipher = @import("../kuznechik.zig").Cipher;
    const M = Mgm(Cipher);
    var rng = std.Random.DefaultPrng.init(0x5246439058);
    const random = rng.random();
    var key: [32]u8 = undefined;
    random.bytes(&key);
    const cipher = Cipher.init(key);
    var nonce: [16]u8 = undefined;
    random.bytes(&nonce);
    nonce[0] &= 0x7f;
    var aad: [1057]u8 = undefined;
    random.bytes(&aad);
    var input: [2082]u8 = undefined;
    random.bytes(&input);
    for (0..17) |a| {
        for (0..33) |n| {
            if (a + n == 0) continue;
            var actual = input;
            var expected = input;
            // Deliberately unaligned payload.
            const tag = try M.seal(&cipher, nonce, aad[0..a], actual[1..][0..n]);
            const ref_tag = referenceSeal(Cipher, &cipher, nonce, aad[0..a], expected[1..][0..n]);
            try std.testing.expectEqual(expected, actual);
            try std.testing.expectEqual(ref_tag, tag);
            try M.open(&cipher, nonce, aad[0..a], actual[1..][0..n], tag);
            try std.testing.expectEqual(input, actual);
        }
    }
    const lengths = [_]usize{ 0, 1, 15, 16, 17, 31, 32, 33, 463, 464, 465, 479, 480, 481, 495, 496, 497, 511, 512, 513, 1007, 1008, 1009, 1023, 1024, 1025, 1039, 1040, 1041, 1057 };
    for (lengths) |a| {
        for (lengths ++ [_]usize{ 2047, 2048, 2049, 2081 }) |n| {
            if (a + n == 0) continue;
            var actual = input;
            var expected = input;
            const tag = try M.seal(&cipher, nonce, aad[0..a], actual[1..][0..n]);
            const ref_tag = referenceSeal(Cipher, &cipher, nonce, aad[0..a], expected[1..][0..n]);
            try std.testing.expectEqual(expected, actual);
            try std.testing.expectEqual(ref_tag, tag);
            try M.open(&cipher, nonce, aad[0..a], actual[1..][0..n], tag);
            try std.testing.expectEqual(input, actual);
        }
    }
}

test "MGM all tag lengths and authentication failures preserve ciphertext" {
    const Cipher = @import("../kuznechik.zig").Cipher;
    const M = Mgm(Cipher);
    const cipher = Cipher.init(@splat(42));
    const nonce: [16]u8 = @splat(1);
    const input: [33]u8 = @splat(0xa5);
    const aad: [17]u8 = @splat(0x5a);
    var encrypted = input;
    const full = try M.seal(&cipher, nonce, &aad, &encrypted);
    for (4..17) |n| {
        var actual = input;
        var tag: [16]u8 = @splat(0xcc);
        try M.sealDetached(&cipher, nonce, &aad, &actual, tag[0..n]);
        try std.testing.expectEqual(encrypted, actual);
        try std.testing.expectEqualSlices(u8, full[0..n], tag[0..n]);
        for (tag[n..]) |byte| try std.testing.expectEqual(@as(u8, 0xcc), byte);
        for (0..n) |i| {
            tag[i] ^= 1;
            try std.testing.expectError(error.AuthenticationFailed, M.openDetached(&cipher, nonce, &aad, &actual, tag[0..n]));
            try std.testing.expectEqual(encrypted, actual);
            tag[i] ^= 1;
        }
        for (0..nonce.len) |i| {
            var changed = nonce;
            changed[i] ^= 1;
            try std.testing.expectError(error.AuthenticationFailed, M.openDetached(&cipher, changed, &aad, &actual, tag[0..n]));
            try std.testing.expectEqual(encrypted, actual);
        }
        for (0..aad.len) |i| {
            var changed = aad;
            changed[i] ^= 1;
            try std.testing.expectError(error.AuthenticationFailed, M.openDetached(&cipher, nonce, &changed, &actual, tag[0..n]));
            try std.testing.expectEqual(encrypted, actual);
        }
        for (0..actual.len) |i| {
            actual[i] ^= 1;
            const preserved = actual;
            try std.testing.expectError(error.AuthenticationFailed, M.openDetached(&cipher, nonce, &aad, &actual, tag[0..n]));
            try std.testing.expectEqual(preserved, actual);
            actual[i] ^= 1;
        }
        try M.openDetached(&cipher, nonce, &aad, &actual, tag[0..n]);
        try std.testing.expectEqual(input, actual);
    }
}

test "MGM rejects invalid nonce tags empty messages and lengths before mutation" {
    const Cipher = @import("../kuznechik.zig").Cipher;
    const M = Mgm(Cipher);
    const cipher = Cipher.init(@splat(0));
    const nonce: [16]u8 = @splat(0);
    const input: [17]u8 = @splat(0xa5);
    var actual = input;
    var tags: [32]u8 = @splat(0xcc);
    for (0..33) |n| {
        if (n >= 4 and n <= 16) continue;
        try std.testing.expectError(error.InvalidTagLength, M.sealDetached(&cipher, nonce, &.{}, &actual, tags[0..n]));
        try std.testing.expectError(error.InvalidTagLength, M.openDetached(&cipher, nonce, &.{}, &actual, tags[0..n]));
        try std.testing.expectEqual(input, actual);
        try std.testing.expectEqual(@as([32]u8, @splat(0xcc)), tags);
    }
    var invalid = nonce;
    invalid[0] = 0x80;
    try std.testing.expectError(error.InvalidNonce, M.sealDetached(&cipher, invalid, &.{}, &actual, tags[0..16]));
    try std.testing.expectError(error.InvalidNonce, M.openDetached(&cipher, invalid, &.{}, &actual, tags[0..16]));
    try std.testing.expectEqual(input, actual);
    try std.testing.expectEqual(@as([32]u8, @splat(0xcc)), tags);
    var empty: [0]u8 = .{};
    try std.testing.expectError(error.EmptyMessage, M.sealDetached(&cipher, nonce, &.{}, &empty, tags[0..16]));
    try std.testing.expectError(error.EmptyMessage, M.openDetached(&cipher, nonce, &.{}, &empty, tags[0..16]));
    try std.testing.expectEqual(@as([32]u8, @splat(0xcc)), tags);
    try M.validate(nonce, 0, 1);
    try M.validate(nonce, 1, 0);
    if (@bitSizeOf(usize) >= 64) {
        const maximum: usize = std.math.maxInt(u64) / 8;
        try M.validate(nonce, maximum, 0);
        try M.validate(nonce, 0, maximum);
        try M.validate(nonce, maximum - 1, 1);
        try std.testing.expectError(error.MessageTooLong, M.validate(nonce, maximum, 1));
        try std.testing.expectError(error.MessageTooLong, M.validate(nonce, maximum + 1, 0));
        try std.testing.expectError(error.MessageTooLong, M.validate(nonce, 0, maximum + 1));
        try std.testing.expectError(error.MessageTooLong, M.validate(nonce, std.math.maxInt(usize), std.math.maxInt(usize)));
        // Oversized slices are never dereferenced: rejection must precede writes.
        const huge: []u8 = @as([*]u8, @ptrCast(&actual))[0 .. maximum + 1];
        try std.testing.expectError(error.MessageTooLong, M.sealDetached(&cipher, nonce, &.{}, huge, tags[0..16]));
        try std.testing.expectError(error.MessageTooLong, M.openDetached(&cipher, nonce, &.{}, huge, tags[0..16]));
        try std.testing.expectEqual(input, actual);
        try std.testing.expectEqual(@as([32]u8, @splat(0xcc)), tags);
        const huge_aad: []const u8 = @as([*]const u8, @ptrCast(&input))[0..maximum];
        try std.testing.expectError(error.MessageTooLong, M.sealDetached(&cipher, nonce, huge_aad, actual[0..1], tags[0..16]));
        try std.testing.expectError(error.MessageTooLong, M.openDetached(&cipher, nonce, huge_aad, actual[0..1], tags[0..16]));
        try std.testing.expectEqual(input, actual);
        try std.testing.expectEqual(@as([32]u8, @splat(0xcc)), tags);
    }
}

test "MGM modulo half-counter wrap never carries into the other half" {
    for ([_]bool{ false, true }) |left| {
        var counter: [16]u8 = @splat(0xab);
        const half = if (left) counter[0..8] else counter[8..16];
        std.mem.writeInt(u64, half, std.math.maxInt(u64) - 1, .big);
        var out: [4]B align(16) = undefined;
        if (left) counters(&counter, &out, true) else counters(&counter, &out, false);
        for (out, 0..) |block, i| {
            const bytes: [16]u8 = block;
            const value = std.mem.readInt(u64, if (left) bytes[0..8] else bytes[8..16], .big);
            try std.testing.expectEqual((std.math.maxInt(u64) - 1) +% @as(u64, @intCast(i)), value);
            for (if (left) bytes[8..16] else bytes[0..8]) |byte| try std.testing.expectEqual(@as(u8, 0xab), byte);
        }
        try std.testing.expectEqual(@as(u64, 2), std.mem.readInt(u64, half, .big));
    }
}

test "MGM 1688 independent BI.ZONE AES and Kuznechik ciphertext and tag fixtures" {
    // Independently generated using crypto/aes, crypto/gost/gost3412128, and crypto/mgm from
    // https://github.com/bi-zone/ruwireguard-go at commit
    // 0de9ac51051ee7f20430de8dcb5b132b9d062d18. SHA-256 covers each complete
    // Seal output (ciphertext || 16-byte tag), in the loop order below.
    // The external implementation is used only to generate this fixture;
    // its code is neither distributed nor required by this library.
    const h = @import("test_helpers.zig");
    inline for (.{ h.Aes128, @import("../kuznechik.zig").Cipher }) |Cipher| {
        const M = Mgm(Cipher);
        var key: [if (Cipher == h.Aes128) 16 else 32]u8 = undefined;
        var nonce: [16]u8 = undefined;
        for (&key, 0..) |*k, i| k.* = @truncate(7 + 11 * i);
        for (&nonce, 0..) |*n, i| n.* = @truncate(13 + 7 * i);
        const cipher = Cipher.init(key);
        var aad: [1057]u8 = undefined;
        var input: [2081]u8 = undefined;
        for (&aad, 0..) |*b, i| b.* = @truncate(3 + 17 * i);
        for (&input, 0..) |*b, i| b.* = @truncate(5 + 19 * i);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        for (0..17) |a| {
            for (0..33) |n| {
                if (a + n == 0) continue;
                var actual = input;
                const tag = try M.seal(&cipher, nonce, aad[0..a], actual[0..n]);
                hash.update(actual[0..n]);
                hash.update(&tag);
            }
        }
        const lengths = [_]usize{ 0, 1, 15, 16, 17, 1007, 1008, 1009, 1023, 1024, 1025, 1039, 1040, 1041, 1057 };
        for (lengths) |a| {
            for (lengths ++ [_]usize{ 2047, 2048, 2049, 2081 }) |n| {
                if (a + n == 0) continue;
                var actual = input;
                const tag = try M.seal(&cipher, nonce, aad[0..a], actual[0..n]);
                hash.update(actual[0..n]);
                hash.update(&tag);
            }
        }
        const expected = if (Cipher == h.Aes128)
            h.hex("c07cb7a46407e58e42a3baad3390ca88a11800f4db43e90dffb3c923a8875f0f")
        else
            h.hex("3c33445c3a8e7caf2e26c33add625385df14ebabe6548415e6861710f7a1749a");
        try std.testing.expectEqual(expected, hash.finalResult());
    }
}

test "MGM mode counters wrap across batches and empty payload failures preserve input" {
    const Identity = struct {
        pub fn encrypt(_: @This(), _: *align(16) B) void {}
        pub fn encryptBlocks(_: @This(), _: []align(16) B) void {}
    };
    const M = Mgm(Identity);
    const cipher: Identity = .{};
    var nonce: [16]u8 = @splat(0xff);
    nonce[0] = 0x7f;
    var input: [1057]u8 = undefined;
    for (&input, 0..) |*byte, i| byte.* = @truncate(i);
    var actual = input;
    var expected = input;
    const tag = try M.seal(&cipher, nonce, &input, &actual);
    const expected_tag = referenceSeal(Identity, &cipher, nonce, &input, &expected);
    try std.testing.expectEqual(expected, actual);
    try std.testing.expectEqual(expected_tag, tag);
    try M.open(&cipher, nonce, &input, &actual, tag);
    try std.testing.expectEqual(input, actual);
    var empty: [0]u8 = .{};
    var tag_only: [16]u8 = undefined;
    for (4..17) |n| {
        try M.sealDetached(&cipher, nonce, input[0..1], &empty, tag_only[0..n]);
        tag_only[0] ^= 1;
        try std.testing.expectError(error.AuthenticationFailed, M.openDetached(&cipher, nonce, input[0..1], &empty, tag_only[0..n]));
        tag_only[0] ^= 1;
        try M.openDetached(&cipher, nonce, input[0..1], &empty, tag_only[0..n]);
    }
}

test "MGM long messages every final remainder and failed opens" {
    const Cipher = @import("../kuznechik.zig").Cipher;
    const M = Mgm(Cipher);
    const cipher = Cipher.init(@splat(0x42));
    const nonce: [16]u8 = @splat(0x11);
    var input: [1057]u8 = undefined;
    var aad: [1057]u8 = undefined;
    for (&input, &aad, 0..) |*p, *a, i| {
        p.* = @truncate(i * 17 + 5);
        a.* = @truncate(i * 19 + 3);
    }
    for (0..16) |remainder| {
        const length = 1024 + remainder;
        const aad_length = 1039 - remainder;
        var actual = input;
        var expected = input;
        const tag = try M.seal(&cipher, nonce, aad[0..aad_length], actual[0..length]);
        const ref_tag = referenceSeal(Cipher, &cipher, nonce, aad[0..aad_length], expected[0..length]);
        try std.testing.expectEqual(expected, actual);
        try std.testing.expectEqual(ref_tag, tag);
        try M.open(&cipher, nonce, aad[0..aad_length], actual[0..length], tag);
        try std.testing.expectEqual(input, actual);
    }
    var encrypted = input;
    const full = try M.seal(&cipher, nonce, &aad, &encrypted);
    for (4..17) |n| {
        var actual = encrypted;
        var bad_tag = full;
        bad_tag[n - 1] ^= 1;
        try std.testing.expectError(error.AuthenticationFailed, M.openDetached(&cipher, nonce, &aad, &actual, bad_tag[0..n]));
        try std.testing.expectEqual(encrypted, actual);
        var bad_nonce = nonce;
        bad_nonce[15] ^= 1;
        try std.testing.expectError(error.AuthenticationFailed, M.openDetached(&cipher, bad_nonce, &aad, &actual, full[0..n]));
        try std.testing.expectEqual(encrypted, actual);
        var bad_aad = aad;
        bad_aad[1024] ^= 1;
        try std.testing.expectError(error.AuthenticationFailed, M.openDetached(&cipher, nonce, &bad_aad, &actual, full[0..n]));
        try std.testing.expectEqual(encrypted, actual);
        for ([_]usize{ 0, 15, 16, 511, 1023, 1024, 1056 }) |i| {
            actual[i] ^= 1;
            const preserved = actual;
            try std.testing.expectError(error.AuthenticationFailed, M.openDetached(&cipher, nonce, &aad, &actual, full[0..n]));
            try std.testing.expectEqual(preserved, actual);
            actual[i] ^= 1;
        }
        try M.openDetached(&cipher, nonce, &aad, &actual, full[0..n]);
        try std.testing.expectEqual(input, actual);
    }
}

test "MGM rejects all mutable overlaps before writes and accepts adjacent packet slices" {
    const Cipher = @import("../kuznechik.zig").Cipher;
    const M = Mgm(Cipher);
    const cipher = Cipher.init(@splat(0x42));
    const nonce: [16]u8 = @splat(0x11);
    var original: [128]u8 = undefined;
    for (&original, 0..) |*byte, i| byte.* = @truncate(17 * i + 3);
    // AAD/data intersections, exact aliases, and containment in both directions.
    const ranges = [_][4]usize{
        .{ 0, 32, 16, 48 }, .{ 16, 48, 0, 32 }, .{ 0, 64, 16, 32 },
        .{ 16, 32, 0, 64 }, .{ 0, 16, 0, 16 },  .{ 16, 32, 0, 17 },
    };
    for (ranges) |r| {
        var packet = original;
        try std.testing.expectError(error.InvalidOverlap, M.sealDetached(&cipher, nonce, packet[r[0]..r[1]], packet[r[2]..r[3]], packet[96..112]));
        try std.testing.expectEqual(original, packet);
        try std.testing.expectError(error.InvalidOverlap, M.openDetached(&cipher, nonce, packet[r[0]..r[1]], packet[r[2]..r[3]], packet[96..112]));
        try std.testing.expectEqual(original, packet);
    }
    // Slide tag output across AAD, payload, and their exact adjacent edges.
    // Every accepted layout is also checked against separate-buffer outputs.
    var expected_data = original[32..64].*;
    const expected_tag = try M.seal(&cipher, nonce, original[0..16], &expected_data);
    for (0..113) |offset| {
        var packet = original;
        if (offset < 16 or (offset < 64 and offset + 16 > 32)) {
            try std.testing.expectError(error.InvalidOverlap, M.sealDetached(&cipher, nonce, packet[0..16], packet[32..64], packet[offset..][0..16]));
            try std.testing.expectEqual(original, packet);
        } else {
            try M.sealDetached(&cipher, nonce, packet[0..16], packet[32..64], packet[offset..][0..16]);
            try std.testing.expectEqualSlices(u8, &expected_data, packet[32..64]);
            try std.testing.expectEqualSlices(u8, &expected_tag, packet[offset..][0..16]);
        }
        // Open only needs to reject tag/data overlap. AAD and tag are read-only.
        packet = original;
        if (offset < 64 and offset + 16 > 32) {
            try std.testing.expectError(error.InvalidOverlap, M.openDetached(&cipher, nonce, packet[0..16], packet[32..64], packet[offset..][0..16]));
        } else {
            try std.testing.expectError(error.AuthenticationFailed, M.openDetached(&cipher, nonce, packet[0..16], packet[32..64], packet[offset..][0..16]));
        }
        try std.testing.expectEqual(original, packet);
    }
    // A compact [AAD | unaligned payload | tag] packet round-trips in place.
    var packet = original;
    try M.sealDetached(&cipher, nonce, packet[0..16], packet[16..49], packet[49..65]);
    try M.openDetached(&cipher, nonce, packet[0..16], packet[16..49], packet[49..65]);
    try std.testing.expectEqualSlices(u8, original[0..49], packet[0..49]);
    // Empty slices may point inside another range without constituting overlap.
    packet = original;
    try M.sealDetached(&cipher, nonce, packet[17..17], packet[16..49], packet[49..65]);
    try M.openDetached(&cipher, nonce, packet[17..17], packet[16..49], packet[49..65]);
    try std.testing.expectEqualSlices(u8, original[16..49], packet[16..49]);
    packet = original;
    try M.sealDetached(&cipher, nonce, packet[0..16], packet[1..1], packet[16..32]);
    try M.openDetached(&cipher, nonce, packet[0..16], packet[1..1], packet[16..32]);
    try std.testing.expectEqualSlices(u8, original[0..16], packet[0..16]);
    // Invalid nonce is rejected during preflight even when buffers overlap.
    var invalid = nonce;
    invalid[0] |= 0x80;
    packet = original;
    try std.testing.expectError(error.InvalidNonce, M.sealDetached(&cipher, invalid, packet[0..16], packet[0..32], packet[0..16]));
    try std.testing.expectError(error.InvalidNonce, M.openDetached(&cipher, invalid, packet[0..16], packet[0..32], packet[0..16]));
    try std.testing.expectEqual(original, packet);
}
