//! RFC3610 CCM. Opening authenticates a private batch before modifying data.
const std = @import("std");
const B = @Vector(16, u8);
fn overlaps(a: []const u8, b: []const u8) bool {
    if (a.len == 0 or b.len == 0) return false;
    const x = @intFromPtr(a.ptr);
    const y = @intFromPtr(b.ptr);
    return if (x <= y) y - x < a.len else x - y < b.len;
}
pub fn Ccm(comptime Cipher: type, comptime length_bytes: u4) type {
    if (length_bytes < 2 or length_bytes > 8) @compileError("CCM length field must have 2..8 bytes");
    return struct {
        const Self = @This();
        pub const Nonce = [15 - @as(usize, length_bytes)]u8;
        const Mac = struct {
            cipher: *const Cipher,
            state: B = @splat(0),
            buffer: [16]u8 = @splat(0),
            used: usize = 0,
            fn flush(self: *@This()) void {
                self.state ^= @as(B, self.buffer);
                self.cipher.encrypt(&self.state);
                self.used = 0;
            }
            fn update(self: *@This(), input: []const u8) void {
                var data = input;
                while (data.len > 0) {
                    const n = @min(16 - self.used, data.len);
                    @memcpy(self.buffer[self.used..][0..n], data[0..n]);
                    self.used += n;
                    data = data[n..];
                    if (self.used == 16) self.flush();
                }
            }
            fn pad(self: *@This()) void {
                if (self.used != 0) {
                    @memset(self.buffer[self.used..], 0);
                    self.flush();
                }
            }
        };
        pub fn validate(aad_len: usize, data_len: usize, tag_len: usize) !void {
            try validateWithPasses(aad_len, data_len, tag_len, 1);
        }
        pub fn validateOpen(aad_len: usize, data_len: usize, tag_len: usize) !void {
            try validateWithPasses(aad_len, data_len, tag_len, 2);
        }
        fn validateWithPasses(aad_len: usize, data_len: usize, tag_len: usize, counter_passes: u2) !void {
            if (tag_len < 4 or tag_len > 16 or tag_len % 2 != 0) return error.InvalidTagLength;
            if (@as(u128, aad_len) > std.math.maxInt(u64)) return error.MessageTooLong;
            if (@as(u128, data_len) >= (@as(u128, 1) << @intCast(@as(usize, length_bytes) * 8))) return error.MessageTooLong;
            const prefix: usize = if (aad_len == 0) 0 else if (aad_len < 0xff00) 2 else if (aad_len <= std.math.maxInt(u32)) 6 else 10;
            const ab = @as(u128, aad_len) + prefix;
            const aad_blocks = ab / 16 + @intFromBool(ab % 16 != 0);
            const data_blocks = @as(u128, data_len) / 16 + @intFromBool(data_len % 16 != 0);
            if (aad_blocks + (1 + @as(u128, counter_passes)) * data_blocks + 2 > (@as(u128, 1) << 61)) return error.MessageTooLong;
        }
        fn counter(nonce: Nonce, index: u64) B {
            var block: [16]u8 = @splat(0);
            block[0] = length_bytes - 1;
            @memcpy(block[1..][0..nonce.len], &nonce);
            inline for (0..length_bytes) |i| block[15 - i] = @truncate(index >> @as(u6, @intCast(i * 8)));
            return block;
        }
        fn begin(cipher: *const Cipher, nonce: Nonce, aad: []const u8, length: usize, tag_len: usize) Mac {
            var b0: [16]u8 = counter(nonce, @intCast(length));
            b0[0] = @intCast((if (aad.len != 0) @as(usize, 64) else 0) | (((tag_len - 2) / 2) << 3) | (length_bytes - 1));
            var mac = Mac{ .cipher = cipher };
            mac.update(&b0);
            if (aad.len != 0) {
                var prefix: [10]u8 = undefined;
                var n: usize = undefined;
                if (aad.len < 0xff00) {
                    std.mem.writeInt(u16, prefix[0..2], @intCast(aad.len), .big);
                    n = 2;
                } else if (aad.len <= std.math.maxInt(u32)) {
                    prefix[0] = 0xff;
                    prefix[1] = 0xfe;
                    std.mem.writeInt(u32, prefix[2..6], @intCast(aad.len), .big);
                    n = 6;
                } else {
                    prefix[0] = 0xff;
                    prefix[1] = 0xff;
                    std.mem.writeInt(u64, prefix[2..10], @intCast(aad.len), .big);
                    n = 10;
                }
                mac.update(prefix[0..n]);
                mac.update(aad);
                mac.pad();
            }
            return mac;
        }
        fn finish(mac: *Mac, nonce: Nonce) [16]u8 {
            mac.pad();
            var mask = counter(nonce, 0);
            mac.cipher.encrypt(&mask);
            return mac.state ^ mask;
        }
        fn crypt(cipher: *const Cipher, nonce: Nonce, data: []u8) void {
            var at: usize = 0;
            while (at < data.len) {
                const take: usize = @min(1024, data.len - at);
                const count: usize = take / 16 + @intFromBool(take % 16 != 0);
                var gamma: [64]B = undefined;
                for (0..count) |i| gamma[i] = counter(nonce, @intCast(at / 16 + i + 1));
                cipher.encryptBlocks(gamma[0..count]);
                for (0..count) |i| {
                    const n = @min(16, take - i * 16);
                    const bytes: [16]u8 = gamma[i];
                    for (data[at + i * 16 ..][0..n], bytes[0..n]) |*byte, g| byte.* ^= g;
                }
                at += take;
            }
        }
        pub fn seal(cipher: *const Cipher, nonce: Nonce, aad: []const u8, data: []u8) ![16]u8 {
            var tag: [16]u8 = undefined;
            try sealDetached(cipher, nonce, aad, data, &tag);
            return tag;
        }
        pub fn sealDetached(cipher: *const Cipher, nonce: Nonce, aad: []const u8, data: []u8, tag: []u8) !void {
            try validate(aad.len, data.len, tag.len);
            if (overlaps(aad, data) or overlaps(tag, data) or overlaps(tag, aad)) return error.InvalidOverlap;
            var mac = begin(cipher, nonce, aad, data.len, tag.len);
            mac.update(data);
            const full = finish(&mac, nonce);
            crypt(cipher, nonce, data);
            @memcpy(tag, full[0..tag.len]);
        }
        pub fn open(cipher: *const Cipher, nonce: Nonce, aad: []const u8, data: []u8, tag: [16]u8) !void {
            try openDetached(cipher, nonce, aad, data, &tag);
        }
        pub fn openDetached(cipher: *const Cipher, nonce: Nonce, aad: []const u8, data: []u8, tag: []const u8) !void {
            try validateOpen(aad.len, data.len, tag.len);
            if (overlaps(aad, data) or overlaps(tag, data)) return error.InvalidOverlap;
            var mac = begin(cipher, nonce, aad, data.len, tag.len);
            var at: usize = 0;
            while (at < data.len) {
                const take: usize = @min(1024, data.len - at);
                const count: usize = take / 16 + @intFromBool(take % 16 != 0);
                var gamma: [64]B = undefined;
                for (0..count) |i| gamma[i] = counter(nonce, @intCast(at / 16 + i + 1));
                cipher.encryptBlocks(gamma[0..count]);
                for (0..count) |i| {
                    const n = @min(16, take - i * 16);
                    var plain: [16]u8 = @splat(0);
                    @memcpy(plain[0..n], data[at + i * 16 ..][0..n]);
                    plain = @as(B, plain) ^ gamma[i];
                    mac.update(plain[0..n]);
                }
                at += take;
            }
            const full = finish(&mac, nonce);
            var expected: [16]u8 = @splat(0);
            var actual: [16]u8 = @splat(0);
            @memcpy(expected[0..tag.len], full[0..tag.len]);
            @memcpy(actual[0..tag.len], tag);
            if (!std.crypto.timing_safe.eql([16]u8, expected, actual)) return error.AuthenticationFailed;
            crypt(cipher, nonce, data);
        }
    };
}

test "RFC3610 CCM packet vector1 and unchanged ciphertext on rejection" {
    const h = @import("test_helpers.zig");
    const testing = std.testing;
    const M = Ccm(h.Aes128, 2);
    const c = h.Aes128.init(h.hex("c0c1c2c3c4c5c6c7c8c9cacbcccdcecf"));
    const nonce = h.hex("00000003020100a0a1a2a3a4a5");
    const aad = h.hex("0001020304050607");
    const plain = h.hex("08090a0b0c0d0e0f101112131415161718191a1b1c1d1e");
    var data = plain;
    var tag: [8]u8 = undefined;
    try M.sealDetached(&c, nonce, &aad, &data, &tag);
    try testing.expectEqual(h.hex("588c979a61c663d2f066d0c2c0f989806d5f6b61dac384"), data);
    try testing.expectEqual(h.hex("17e8d12cfdf926e0"), tag);
    const ciphertext = data;
    var bad = tag;
    bad[0] ^= 1;
    try testing.expectError(error.AuthenticationFailed, M.openDetached(&c, nonce, &aad, &data, &bad));
    try testing.expectEqual(ciphertext, data);
    try M.openDetached(&c, nonce, &aad, &data, &tag);
    try testing.expectEqual(plain, data);
    try testing.expectError(error.MessageTooLong, M.validate(0, 65536, 8));
    try M.validate(0, 65535, 8);
    try testing.expectError(error.InvalidTagLength, M.validate(0, 0, 5));
}

test "all24 RFC3610 CCM packet vectors" {
    const h = @import("test_helpers.zig");
    const M = Ccm(h.Aes128, 2);
    const testing = std.testing;
    for (@import("ccm_vectors.zig").cases) |case| {
        const cipher = h.Aes128.init(case.key);
        var buffer: [32]u8 = undefined;
        const data = buffer[0..case.plain.len];
        @memcpy(data, case.plain);
        var tag: [16]u8 = undefined;
        try M.sealDetached(&cipher, case.nonce, case.aad, data, tag[0..case.tag.len]);
        try testing.expectEqualSlices(u8, case.ciphertext, data);
        try testing.expectEqualSlices(u8, case.tag, tag[0..case.tag.len]);
        try M.openDetached(&cipher, case.nonce, case.aad, data, case.tag);
        try testing.expectEqualSlices(u8, case.plain, data);
    }
}

test "CCM all dimensions and AAD prefix boundaries match independent OpenSSL fixtures" {
    const h = @import("test_helpers.zig");
    const testing = std.testing;
    const Case = struct { index: usize, length_bytes: u4, tag_length: usize, plain_length: usize, aad_length: usize, ciphertext: []const u8, tag: []const u8 };
    const Document = struct { key: []const u8, cases: []const Case };
    const parsed = try std.json.parseFromSlice(Document, testing.allocator, @embedFile("ccm_oracle.json"), .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try testing.expectEqual(@as(usize, 49), parsed.value.cases.len);
    const cipher = h.Aes128.init(h.hex("00112233445566778899aabbccddeeff"));
    inline for (2..9) |l| {
        const M = Ccm(h.Aes128, l);
        for (parsed.value.cases) |case| {
            if (case.length_bytes != l) continue;
            var nonce: M.Nonce = undefined;
            for (&nonce, 0..) |*v, i| v.* = @truncate(i * 7 + @as(usize, l) * 13 + case.tag_length * 3);
            var aad: [65535]u8 = undefined;
            for (aad[0..case.aad_length], 0..) |*v, i| v.* = @truncate(i * 29 + case.index * 3);
            var plain: [1025]u8 = undefined;
            for (plain[0..case.plain_length], 0..) |*v, i| v.* = @truncate(i * 17 + case.index);
            var data = plain;
            var tag: [16]u8 = undefined;
            try M.sealDetached(&cipher, nonce, aad[0..case.aad_length], data[0..case.plain_length], tag[0..case.tag_length]);
            var expected: [1025]u8 = undefined;
            _ = try std.fmt.hexToBytes(expected[0..case.plain_length], case.ciphertext);
            var expected_tag: [16]u8 = undefined;
            _ = try std.fmt.hexToBytes(expected_tag[0..case.tag_length], case.tag);
            try testing.expectEqualSlices(u8, expected[0..case.plain_length], data[0..case.plain_length]);
            try testing.expectEqualSlices(u8, expected_tag[0..case.tag_length], tag[0..case.tag_length]);
            const preserved = data;
            var bad = tag;
            bad[0] ^= 1;
            try testing.expectError(error.AuthenticationFailed, M.openDetached(&cipher, nonce, aad[0..case.aad_length], data[0..case.plain_length], bad[0..case.tag_length]));
            try testing.expectEqualSlices(u8, preserved[0..case.plain_length], data[0..case.plain_length]);
            try M.openDetached(&cipher, nonce, aad[0..case.aad_length], data[0..case.plain_length], tag[0..case.tag_length]);
            try testing.expectEqualSlices(u8, plain[0..case.plain_length], data[0..case.plain_length]);
        }
    }
}

test "Kuznechik CCM tails alignment guards and rejected inputs" {
    const C = @import("../kuznechik.zig").Cipher;
    const testing = std.testing;
    var rng = std.Random.DefaultPrng.init(0x43434d4b555a);
    const random = rng.random();
    var key: @Vector(32, u8) = undefined;
    random.bytes(std.mem.asBytes(&key));
    const cipher = C.init(key);
    var input: [1057]u8 = undefined;
    random.bytes(&input);
    var aad: [33]u8 = undefined;
    random.bytes(&aad);
    inline for (.{ 2, 3, 8 }) |l| {
        const M = Ccm(C, l);
        var nonce: M.Nonce = undefined;
        random.bytes(&nonce);
        for ([_]usize{ 0, 1, 15, 16, 17, 31, 32, 33, 1023, 1024, 1025, 1057 }) |n| {
            for ([_]usize{ 4, 8, 16 }) |tag_len| {
                var guarded: [1089]u8 = @splat(0xa5);
                const offset: usize = n % 16;
                @memcpy(guarded[offset..][0..n], input[0..n]);
                const original = guarded;
                var tag: [16]u8 = undefined;
                const data = guarded[offset..][0..n];
                try M.sealDetached(&cipher, nonce, &aad, data, tag[0..tag_len]);
                const ciphertext = guarded;
                var bad = tag;
                bad[0] ^= 1;
                try testing.expectError(error.AuthenticationFailed, M.openDetached(&cipher, nonce, &aad, data, bad[0..tag_len]));
                try testing.expectEqual(ciphertext, guarded);
                try M.openDetached(&cipher, nonce, &aad, data, tag[0..tag_len]);
                try testing.expectEqual(original, guarded);
            }
        }
        var guarded: [64]u8 = @splat(0xa5);
        const before = guarded;
        var tag: [16]u8 = undefined;
        try testing.expectError(error.InvalidOverlap, M.sealDetached(&cipher, nonce, guarded[0..32], guarded[16..48], &tag));
        try testing.expectEqual(before, guarded);
    }
}

test "CCM length budgets tags and overlap reject before mutation" {
    const h = @import("test_helpers.zig");
    const M = Ccm(h.Aes128, 2);
    const testing = std.testing;
    try M.validate(0, 65535, 16);
    try testing.expectError(error.MessageTooLong, M.validate(0, 65536, 16));
    for (0..18) |n| {
        if (n >= 4 and n <= 16 and n % 2 == 0) {
            try M.validate(0, 0, n);
        } else try testing.expectError(error.InvalidTagLength, M.validate(0, 0, n));
    }
    if (@bitSizeOf(usize) >= 64) {
        const Wide = Ccm(h.Aes128, 8);
        const limit: usize = (@as(usize, 1) << 60) - 1;
        try Wide.validate(0, limit * 16, 16);
        try testing.expectError(error.MessageTooLong, Wide.validate(0, limit * 16 + 1, 16));
        try testing.expectError(error.MessageTooLong, Wide.validate(16, limit * 16, 16));
        const open_limit: usize = ((@as(usize, 1) << 61) - 2) / 3;
        try Wide.validateOpen(0, open_limit * 16, 16);
        try testing.expectError(error.MessageTooLong, Wide.validateOpen(0, open_limit * 16 + 1, 16));
    }
    const cipher = h.Aes128.init(@splat(0));
    const nonce: M.Nonce = @splat(0);
    var packet: [80]u8 = @splat(0xa5);
    const original = packet;
    try testing.expectError(error.InvalidOverlap, M.sealDetached(&cipher, nonce, packet[0..16], packet[16..48], packet[8..24]));
    try testing.expectEqual(original, packet);
    try testing.expectError(error.InvalidOverlap, M.sealDetached(&cipher, nonce, packet[0..16], packet[16..48], packet[32..48]));
    try testing.expectEqual(original, packet);
    try testing.expectError(error.InvalidOverlap, M.openDetached(&cipher, nonce, packet[0..16], packet[16..48], packet[32..48]));
    try testing.expectEqual(original, packet);
    try M.sealDetached(&cipher, nonce, packet[0..16], packet[16..48], packet[48..64]);
    const encrypted = packet;
    packet[0] ^= 1;
    try testing.expectError(error.AuthenticationFailed, M.openDetached(&cipher, nonce, packet[0..16], packet[16..48], packet[48..64]));
    try testing.expectEqualSlices(u8, encrypted[16..], packet[16..]);
    packet[0] ^= 1;
    packet[17] ^= 1;
    const corrupted = packet;
    try testing.expectError(error.AuthenticationFailed, M.openDetached(&cipher, nonce, packet[0..16], packet[16..48], packet[48..64]));
    try testing.expectEqual(corrupted, packet);
    packet[17] ^= 1;
    try M.openDetached(&cipher, nonce, packet[0..16], packet[16..48], packet[48..64]);
    try testing.expectEqualSlices(u8, original[0..48], packet[0..48]);
}
