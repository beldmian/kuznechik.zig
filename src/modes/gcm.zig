//! GCM with the counter/nonce dimensions and message bounds in RFC8645.
const std = @import("std");
const B = @Vector(16, u8);
fn overlaps(a: []const u8, b: []const u8) bool {
    if (a.len == 0 or b.len == 0) return false;
    const x = @intFromPtr(a.ptr);
    const y = @intFromPtr(b.ptr);
    return if (x <= y) y - x < a.len else x - y < b.len;
}
pub fn Gcm(comptime Cipher: type, comptime counter_bits: u7) type {
    if (counter_bits < 32 or counter_bits > 64 or counter_bits % 8 != 0) @compileError("GCM counter must be32..64 bits in whole bytes");
    const Ctr = @import("classic.zig").Modes(Cipher).CtrWithCounter(counter_bits);
    return struct {
        pub const Nonce = Ctr.Nonce;
        pub fn validate(aad_len: usize, data_len: usize) !void {
            if (@as(u128, aad_len) * 8 > std.math.maxInt(u64) or @as(u128, data_len) * 8 > std.math.maxInt(u64)) return error.MessageTooLong;
            const blocks = @as(u128, data_len) / 16 + @intFromBool(data_len % 16 != 0);
            if (blocks > (@as(u128, 1) << (counter_bits - 1)) - 2) return error.MessageTooLong;
        }
        fn validTag(length: usize) !void {
            if (length != 4 and length != 8 and (length < 12 or length > 16)) return error.InvalidTagLength;
        }
        pub fn authenticate(cipher: *const Cipher, nonce: Nonce, aad: []const u8, ciphertext: []const u8) ![16]u8 {
            try validate(aad.len, ciphertext.len);
            var h: B = @splat(0);
            cipher.encrypt(&h);
            const hash_key: [16]u8 = h;
            const count = (aad.len / 16 + @intFromBool(aad.len % 16 != 0)) + (ciphertext.len / 16 + @intFromBool(ciphertext.len % 16 != 0)) + 1;
            var mac = std.crypto.onetimeauth.Ghash.initForBlockCount(&hash_key, count);
            mac.update(aad);
            mac.pad();
            mac.update(ciphertext);
            mac.pad();
            var lengths: [16]u8 = undefined;
            std.mem.writeInt(u64, lengths[0..8], @as(u64, @intCast(aad.len)) * 8, .big);
            std.mem.writeInt(u64, lengths[8..16], @as(u64, @intCast(ciphertext.len)) * 8, .big);
            mac.update(&lengths);
            var tag: [16]u8 = undefined;
            mac.final(&tag);
            var initial: [16]u8 = @splat(0);
            @memcpy(initial[0..nonce.len], &nonce);
            initial[15] = 1;
            var mask: B = initial;
            cipher.encrypt(&mask);
            const bytes: [16]u8 = mask;
            for (&tag, bytes) |*a, b| a.* ^= b;
            return tag;
        }
        pub fn seal(cipher: *const Cipher, nonce: Nonce, aad: []const u8, data: []u8) ![16]u8 {
            var tag: [16]u8 = undefined;
            try sealDetached(cipher, nonce, aad, data, &tag);
            return tag;
        }
        pub fn sealDetached(cipher: *const Cipher, nonce: Nonce, aad: []const u8, data: []u8, tag: []u8) !void {
            try validTag(tag.len);
            try validate(aad.len, data.len);
            if (overlaps(aad, data) or overlaps(tag, data) or overlaps(tag, aad)) return error.InvalidOverlap;
            var ctr = Ctr.init(cipher.*, nonce);
            ctr.blocks = 2;
            try ctr.xor(data);
            const full = try authenticate(cipher, nonce, aad, data);
            @memcpy(tag, full[0..tag.len]);
        }
        pub fn open(cipher: *const Cipher, nonce: Nonce, aad: []const u8, data: []u8, tag: [16]u8) !void {
            try openDetached(cipher, nonce, aad, data, &tag);
        }
        pub fn openDetached(cipher: *const Cipher, nonce: Nonce, aad: []const u8, data: []u8, tag: []const u8) !void {
            try validTag(tag.len);
            try validate(aad.len, data.len);
            if (overlaps(aad, data) or overlaps(tag, data)) return error.InvalidOverlap;
            const full = try authenticate(cipher, nonce, aad, data);
            var expected: [16]u8 = @splat(0);
            var actual: [16]u8 = @splat(0);
            @memcpy(expected[0..tag.len], full[0..tag.len]);
            @memcpy(actual[0..tag.len], tag);
            if (!std.crypto.timing_safe.eql([16]u8, expected, actual)) return error.AuthenticationFailed;
            var ctr = Ctr.init(cipher.*, nonce);
            ctr.blocks = 2;
            try ctr.xor(data);
        }
    };
}

test "GCM rejects overlapping buffers atomically and accepts adjacent slices" {
    const h = @import("test_helpers.zig");
    const testing = std.testing;
    const c = h.Aes128.init(@splat(0));
    const M = Gcm(h.Aes128, 32);
    var storage: [112]u8 = @splat(0x51);
    const original = storage;
    var tag: [16]u8 = @splat(0x67);
    const original_tag = tag;
    try testing.expectError(error.InvalidOverlap, M.sealDetached(&c, @splat(0), storage[0..32], storage[16..48], &tag));
    try testing.expectEqual(original, storage);
    try testing.expectEqual(original_tag, tag);
    try testing.expectError(error.InvalidOverlap, M.sealDetached(&c, @splat(0), &.{}, storage[0..32], storage[16..32]));
    try testing.expectError(error.InvalidOverlap, M.sealDetached(&c, @splat(0), storage[0..32], storage[32..64], storage[16..32]));
    try testing.expectError(error.InvalidOverlap, M.openDetached(&c, @splat(0), storage[0..32], storage[16..48], &tag));
    try testing.expectError(error.InvalidOverlap, M.openDetached(&c, @splat(0), &.{}, storage[0..32], storage[16..32]));
    try testing.expectEqual(original, storage);
    try M.sealDetached(&c, @splat(0), storage[0..32], storage[32..96], storage[96..112]);
    try M.openDetached(&c, @splat(0), storage[0..32], storage[32..96], storage[96..112]);
    try testing.expectEqualSlices(u8, original[0..96], storage[0..96]);
}

test "GCM known-answer vectors and standard-library differential cases" {
    const h = @import("test_helpers.zig");
    const testing = std.testing;
    const cipher = h.Aes128.init(@splat(0));
    const M = Gcm(h.Aes128, 32);
    var empty: [0]u8 = .{};
    const empty_tag = try M.seal(&cipher, @splat(0), &.{}, &empty);
    try testing.expectEqual(h.hex("58e2fccefa7e3061367f1d57a4e7455a"), empty_tag);
    var zero: [16]u8 = @splat(0);
    const tag = try M.seal(&cipher, @splat(0), &.{}, &zero);
    try testing.expectEqual(h.hex("0388dace60b6a392f328c2b971b2fe78"), zero);
    try testing.expectEqual(h.hex("ab6e47d42cec13bdf53a67b21257bddf"), tag);
    var rng = std.Random.DefaultPrng.init(0x47434d524643);
    const random = rng.random();
    var key: [16]u8 = undefined;
    random.bytes(&key);
    const c = h.Aes128.init(key);
    var nonce: [12]u8 = undefined;
    random.bytes(&nonce);
    var aad: [33]u8 = undefined;
    random.bytes(&aad);
    var input: [1057]u8 = undefined;
    random.bytes(&input);
    for ([_]usize{ 0, 1, 15, 16, 17, 1023, 1024, 1057 }) |n| {
        var expected = input;
        var expected_tag: [16]u8 = undefined;
        std.crypto.aead.aes_gcm.Aes128Gcm.encrypt(expected[0..n], &expected_tag, input[0..n], &aad, nonce, key);
        var actual = input;
        const actual_tag = try M.seal(&c, nonce, &aad, actual[0..n]);
        try testing.expectEqualSlices(u8, expected[0..n], actual[0..n]);
        try testing.expectEqual(expected_tag, actual_tag);
        const preserved = actual;
        var bad = actual_tag;
        bad[0] ^= 1;
        try testing.expectError(error.AuthenticationFailed, M.open(&c, nonce, &aad, actual[0..n], bad));
        try testing.expectEqual(preserved, actual);
        try M.open(&c, nonce, &aad, actual[0..n], actual_tag);
        try testing.expectEqual(input, actual);
    }
    for ([_]usize{ 4, 8, 12, 13, 14, 15, 16 }) |tag_len| {
        var msg = input;
        var truncated: [16]u8 = undefined;
        try M.sealDetached(&c, nonce, &aad, &msg, truncated[0..tag_len]);
        try M.openDetached(&c, nonce, &aad, &msg, truncated[0..tag_len]);
        try testing.expectEqual(input, msg);
    }
    var unchanged = input;
    var invalid: [5]u8 = undefined;
    try testing.expectError(error.InvalidTagLength, M.sealDetached(&c, nonce, &aad, &unchanged, &invalid));
    try testing.expectEqual(input, unchanged);
}
