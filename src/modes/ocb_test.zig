const std = @import("std");
const ocb = @import("ocb.zig");
const h = @import("test_helpers.zig");
const t = std.testing;

test "RFC7253 Appendix A all sixteen AES128 tuples and tag96 tuple" {
    const M = ocb.Ocb(h.Aes128);
    const cipher = h.Aes128.init(h.hex("000102030405060708090a0b0c0d0e0f"));
    const answers = [_][]const u8{
        "785407bfffc8ad9edcc5520ac9111ee6",
        "6820b3657b6f615a5725bda0d3b4eb3a257c9af1f8f03009",
        "81017f8203f081277152fade694a0a00",
        "45dd69f8f5aae72414054cd1f35d82760b2cd00d2f99bfa9",
        "571d535b60b277188be5147170a9a22c3ad7a4ff3835b8c5701c1ccec8fc3358",
        "8cf761b6902ef764462ad86498ca6b97",
        "5ce88ec2e0692706a915c00aeb8b2396f40e1c743f52436bdf06d8fa1eca343d",
        "1ca2207308c87c010756104d8840ce1952f09673a448a122c92c62241051f57356d7f3c90bb0e07f",
        "6dc225a071fc1b9f7c69f93b0f1e10de",
        "221bd0de7fa6fe993eccd769460a0af2d6cded0c395b1c3ce725f32494b9f914d85c0b1eb38357ff",
        "bd6f6c496201c69296c11efd138a467abd3c707924b964deaffc40319af5a48540fbba186c5553c68ad9f592a79a4240",
        "fe80690bee8a485d11f32965bc9d2a32",
        "2942bfc773bda23cabc6acfd9bfd5835bd300f0973792ef46040c53f1432bcdfb5e1dde3bc18a5f840b52e653444d5df",
        "d5ca91748410c1751ff8a2f618255b68a0a12e093ff454606e59f9c1d0ddc54b65e8628e568bad7aed07ba06a4a69483a7035490c5769e60",
        "c5cd9d1850c141e358649994ee701b68",
        "4412923493c57d5de0d700f753cce0d1d2d95060122e9f15a5ddbfc5787e50b5cc55ee507bcb084e479ad363ac366b95a98ca5f3000b1479",
    };
    var plain: [40]u8 = undefined;
    for (&plain, 0..) |*v, i| v.* = @intCast(i);
    var nonce = h.hex("bbaa99887766554433221100");
    for (answers, 0..) |answer, index| {
        nonce[11] = @intCast(index);
        const n = (index + 2) / 3 * 8;
        const a_len = if (index % 3 == 0) 0 else n;
        const p_len = if (index % 3 == 2) 0 else n;
        var data = plain;
        const tag = try M.seal(&cipher, &nonce, plain[0..a_len], data[0..p_len]);
        var expected: [56]u8 = undefined;
        _ = try std.fmt.hexToBytes(expected[0 .. p_len + 16], answer);
        try t.expectEqualSlices(u8, expected[0..p_len], data[0..p_len]);
        try t.expectEqualSlices(u8, expected[p_len..][0..16], &tag);
        try M.open(&cipher, &nonce, plain[0..a_len], data[0..p_len], tag);
        try t.expectEqual(plain, data);
    }
    const Short = ocb.OcbWithTag(h.Aes128, 12);
    const other = h.Aes128.init(h.hex("0f0e0d0c0b0a09080706050403020100"));
    nonce[11] = 13;
    var data = plain;
    const tag = try Short.seal(&other, &nonce, &plain, &data);
    const expected = h.hex("1792a4e31e0755fb03e31b22116e6c2ddf9efd6e33d536f1a0124b0a55bae884ed93481529c76b6ad0c515f4d1cdd4fdac4f02aa");
    try t.expectEqualSlices(u8, expected[0..40], &data);
    try t.expectEqualSlices(u8, expected[40..], &tag);
    try Short.open(&other, &nonce, &plain, &data, tag);
    try t.expectEqual(plain, data);
}

const Aes192 = @import("ocb_aes192_test.zig").Aes192;

test "RFC7253 Appendix A all nine aggregate checksums" {
    const expected = .{
        .{ "67e944d23256c5e0b6c61fa22fdf1ea2", "77a3d8e73589158d25d01209", "192c9b7bd90ba06a" },
        .{ "f673f2c3e7174aae7bae986ca9f29e17", "05d56ead2752c86be6932c5e", "0066bc6e0ef34e24" },
        .{ "d90eb8e9c977c88b79dd793d7ffa161c", "5458359ac23b0cba9e6330dd", "7d4ea5d445501cbe" },
    };
    inline for (.{ h.Aes128, Aes192, h.Aes256 }, 0..) |C, ci| {
        inline for (.{ 16, 12, 8 }, 0..) |tag_len, ti| {
            const M = ocb.OcbWithTag(C, tag_len);
            const key_len = .{ 16, 24, 32 }[ci];
            var key: [key_len]u8 = @splat(0);
            key[key_len - 1] = tag_len * 8;
            const cipher = C.init(key);
            var combined: [22400]u8 = undefined;
            var at: usize = 0;
            var nonce: [12]u8 = @splat(0);
            for (0..128) |i| {
                for (0..3) |j| {
                    std.mem.writeInt(u32, nonce[8..12], @intCast(3 * i + j + 1), .big);
                    var data: [127]u8 = @splat(0);
                    const aad: [127]u8 = @splat(0);
                    const a_len = if (j == 1) 0 else i;
                    const p_len = if (j == 2) 0 else i;
                    const tag = try M.seal(&cipher, &nonce, aad[0..a_len], data[0..p_len]);
                    @memcpy(combined[at..][0..p_len], data[0..p_len]);
                    at += p_len;
                    @memcpy(combined[at..][0..tag_len], &tag);
                    at += tag_len;
                    try M.open(&cipher, &nonce, aad[0..a_len], data[0..p_len], tag);
                    try t.expectEqualSlices(u8, aad[0..p_len], data[0..p_len]);
                }
            }
            try t.expectEqual(@as(usize, 16256 + 384 * tag_len), at);
            std.mem.writeInt(u32, nonce[8..12], 385, .big);
            var empty: [0]u8 = .{};
            const tag = try M.seal(&cipher, &nonce, combined[0..at], &empty);
            try t.expectEqual(h.hex(expected[ci][ti]), tag);
            try M.open(&cipher, &nonce, combined[0..at], &empty, tag);
        }
    }
}

test "394 independent Node OpenSSL OCB fixtures all byte nonce and tag lengths all bottom bits" {
    const Case = struct { index: usize, key_bytes: usize, nonce: []const u8, tag_length: usize, plain_length: usize, aad_length: usize, ciphertext: []const u8, tag: []const u8 };
    const Document = struct { cases: []const Case };
    const parsed = try std.json.parseFromSlice(Document, t.allocator, @embedFile("ocb_oracle.json"), .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try t.expectEqual(@as(usize, 394), parsed.value.cases.len);
    inline for (.{ h.Aes128, Aes192, h.Aes256 }, 0..) |C, ci| {
        const key_len = .{ 16, 24, 32 }[ci];
        var key: [key_len]u8 = undefined;
        for (&key, 0..) |*v, i| v.* = @truncate(i * 11 + key_len);
        const cipher = C.init(key);
        inline for (1..17) |tag_len| {
            const M = ocb.OcbWithTag(C, tag_len);
            for (parsed.value.cases) |case| {
                if (case.key_bytes != key_len or case.tag_length != tag_len) continue;
                var nonce: [15]u8 = undefined;
                const n = try std.fmt.hexToBytes(&nonce, case.nonce);
                var aad: [2049]u8 = undefined;
                for (aad[0..case.aad_length], 0..) |*v, i| v.* = @truncate(i * 29 + case.index * 3);
                var plain: [2049]u8 = undefined;
                for (plain[0..case.plain_length], 0..) |*v, i| v.* = @truncate(i * 17 + case.index);
                var data = plain;
                const tag = try M.seal(&cipher, n, aad[0..case.aad_length], data[0..case.plain_length]);
                var expected: [2049]u8 = undefined;
                _ = try std.fmt.hexToBytes(expected[0..case.plain_length], case.ciphertext);
                var expected_tag: M.Tag = undefined;
                _ = try std.fmt.hexToBytes(&expected_tag, case.tag);
                try t.expectEqualSlices(u8, expected[0..case.plain_length], data[0..case.plain_length]);
                try t.expectEqual(expected_tag, tag);
                const before = data;
                var bad = tag;
                bad[0] ^= 1;
                try t.expectError(error.AuthenticationFailed, M.open(&cipher, n, aad[0..case.aad_length], data[0..case.plain_length], bad));
                try t.expectEqualSlices(u8, before[0..case.plain_length], data[0..case.plain_length]);
                try M.open(&cipher, n, aad[0..case.aad_length], data[0..case.plain_length], tag);
                try t.expectEqualSlices(u8, plain[0..case.plain_length], data[0..case.plain_length]);
            }
        }
    }
}

fn Serial(comptime C: type) type {
    return struct {
        cipher: C,
        pub fn encrypt(self: @This(), b: *align(16) @Vector(16, u8)) void {
            self.cipher.encrypt(b);
        }
        pub fn decrypt(self: @This(), b: *align(16) @Vector(16, u8)) void {
            self.cipher.decrypt(b);
        }
        pub fn encryptBlocks(self: @This(), blocks: []align(16) @Vector(16, u8)) void {
            for (blocks) |*b| self.encrypt(b);
        }
        pub fn decryptBlocks(self: @This(), blocks: []align(16) @Vector(16, u8)) void {
            for (blocks) |*b| self.decrypt(b);
        }
    };
}

test "Kuznechik OCB all small tails 64-block boundaries every alignment guards and rejection" {
    const C = @import("../kuznechik.zig").Cipher;
    const M = ocb.Ocb(C);
    const Scalar = Serial(C);
    const SM = ocb.Ocb(Scalar);
    var rng = std.Random.DefaultPrng.init(0x4f43424b555a);
    const random = rng.random();
    var key: @Vector(32, u8) = undefined;
    random.bytes(std.mem.asBytes(&key));
    const cipher = C.init(key);
    const serial = Scalar{ .cipher = cipher };
    var input: [4097]u8 = undefined;
    random.bytes(&input);
    var aad: [1057]u8 = undefined;
    random.bytes(&aad);
    var nonce: [15]u8 = undefined;
    random.bytes(&nonce);
    const lengths = blk: {
        var ns: [65 + 35 + 35 + 3]usize = undefined;
        for (0..65) |i| ns[i] = i;
        for (0..35) |i| ns[65 + i] = 1007 + i;
        for (0..35) |i| ns[100 + i] = 2031 + i;
        ns[135..].* = .{ 4095, 4096, 4097 };
        break :blk ns;
    };
    for (lengths, 0..) |len, index| {
        const a_len = ([_]usize{ 0, 1, 15, 16, 17, 31, 32, 33, 1023, 1024, 1025 })[index % 11];
        const nonce_len = index % 16;
        var reference = input;
        const reference_tag = try SM.seal(&serial, nonce[0..nonce_len], aad[0..a_len], reference[0..len]);
        for (0..16) |alignment| {
            var guarded: [4097 + 32]u8 = @splat(0xa5);
            const data = guarded[alignment..][0..len];
            @memcpy(data, input[0..len]);
            const original = guarded;
            const tag = try M.seal(&cipher, nonce[0..nonce_len], aad[0..a_len], data);
            try t.expectEqualSlices(u8, reference[0..len], data);
            try t.expectEqual(reference_tag, tag);
            try t.expectEqualSlices(u8, original[0..alignment], guarded[0..alignment]);
            try t.expectEqualSlices(u8, original[alignment + len ..], guarded[alignment + len ..]);
            const encrypted = guarded;
            var bad = tag;
            bad[(index + alignment) % 16] ^= 1;
            try t.expectError(error.AuthenticationFailed, M.open(&cipher, nonce[0..nonce_len], aad[0..a_len], data, bad));
            try t.expectEqual(encrypted, guarded);
            if (nonce_len != 0) {
                var bad_nonce = nonce;
                bad_nonce[0] ^= 1;
                try t.expectError(error.AuthenticationFailed, M.open(&cipher, bad_nonce[0..nonce_len], aad[0..a_len], data, tag));
                try t.expectEqual(encrypted, guarded);
            }
            if (a_len != 0) {
                aad[0] ^= 1;
                try t.expectError(error.AuthenticationFailed, M.open(&cipher, nonce[0..nonce_len], aad[0..a_len], data, tag));
                try t.expectEqual(encrypted, guarded);
                aad[0] ^= 1;
            }
            if (len != 0) {
                data[len - 1] ^= 1;
                const corrupted = guarded;
                try t.expectError(error.AuthenticationFailed, M.open(&cipher, nonce[0..nonce_len], aad[0..a_len], data, tag));
                try t.expectEqual(corrupted, guarded);
                data[len - 1] ^= 1;
            }
            try M.open(&cipher, nonce[0..nonce_len], aad[0..a_len], data, tag);
            try t.expectEqual(original, guarded);
        }
    }
}

test "OCB fixed dimensions budget and alias failures preserve output" {
    const M = ocb.Ocb(h.Aes128);
    const cipher = h.Aes128.init(@splat(0));
    const nonce: [15]u8 = @splat(0);
    for (0..18) |n| {
        if (n <= 15) try M.validate(n, 0, 0, 16) else try t.expectError(error.InvalidNonceLength, M.validate(n, 0, 0, 16));
        if (n != 16) try t.expectError(error.InvalidTagLength, M.validate(12, 0, 0, n));
    }
    if (@bitSizeOf(usize) >= 64) {
        const limit: usize = 1 << 52;
        try M.validate(1, 0, limit, 16);
        try M.validate(15, limit, 0, 16);
        try M.validate(12, limit - 16, 16, 16);
        try t.expectError(error.MessageTooLong, M.validate(12, limit + 1, 0, 16));
        try t.expectError(error.MessageTooLong, M.validate(12, 0, limit + 1, 16));
        try t.expectError(error.MessageTooLong, M.validate(12, limit, 1, 16));
        try t.expectError(error.MessageTooLong, M.validate(12, std.math.maxInt(usize), std.math.maxInt(usize), 16));
    }
    var packet: [96]u8 = @splat(0xa5);
    const original = packet;
    var tag: [16]u8 = @splat(0x5a);
    const tag_before = tag;
    try t.expectError(error.InvalidNonceLength, M.sealDetached(&cipher, &([_]u8{0} ** 16), &.{}, packet[16..48], &tag));
    try t.expectError(error.InvalidNonceLength, M.openDetached(&cipher, &([_]u8{0} ** 16), &.{}, packet[16..48], &tag));
    try t.expectError(error.InvalidTagLength, M.sealDetached(&cipher, &nonce, &.{}, packet[16..48], tag[0..15]));
    try t.expectError(error.InvalidTagLength, M.openDetached(&cipher, &nonce, &.{}, packet[16..48], tag[0..15]));
    try t.expectEqual(original, packet);
    try t.expectEqual(tag_before, tag);
    // Equal, containing, contained, and partially overlapping payload/AAD.
    for ([_][2]usize{ .{ 16, 48 }, .{ 0, 64 }, .{ 24, 32 }, .{ 0, 17 }, .{ 47, 64 } }) |range| {
        try t.expectError(error.InvalidOverlap, M.sealDetached(&cipher, &nonce, packet[range[0]..range[1]], packet[16..48], &tag));
        try t.expectError(error.InvalidOverlap, M.openDetached(&cipher, &nonce, packet[range[0]..range[1]], packet[16..48], &tag));
    }
    // Nonce and detached tag are also checked in each writable range.
    try t.expectError(error.InvalidOverlap, M.sealDetached(&cipher, packet[12..24], &.{}, packet[16..48], &tag));
    try t.expectError(error.InvalidOverlap, M.openDetached(&cipher, packet[12..24], &.{}, packet[16..48], &tag));
    try t.expectError(error.InvalidOverlap, M.sealDetached(&cipher, &nonce, &.{}, packet[16..48], packet[40..56]));
    try t.expectError(error.InvalidOverlap, M.openDetached(&cipher, &nonce, &.{}, packet[16..48], packet[40..56]));
    try t.expectError(error.InvalidOverlap, M.sealDetached(&cipher, &nonce, packet[0..16], packet[16..48], packet[8..24]));
    try t.expectError(error.InvalidOverlap, M.sealDetached(&cipher, packet[0..12], &.{}, packet[16..48], packet[0..16]));
    try t.expectEqual(original, packet);
    try t.expectEqual(tag_before, tag);
    // Adjacent packet layout; read-only nonce/AAD sharing on both operations.
    try M.sealDetached(&cipher, packet[0..12], packet[0..16], packet[16..48], packet[48..64]);
    try M.openDetached(&cipher, packet[0..12], packet[0..16], packet[16..48], packet[48..64]);
    try t.expectEqualSlices(u8, original[0..48], packet[0..48]);
    // Empty slices with a pointer in a writable region are not overlaps.
    try M.sealDetached(&cipher, &nonce, packet[24..24], packet[16..48], &tag);
    try M.openDetached(&cipher, &nonce, packet[24..24], packet[16..48], &tag);
    var empty: [0]u8 = .{};
    const empty_tag = try M.seal(&cipher, &nonce, &.{}, &empty);
    try M.open(&cipher, &nonce, &.{}, &empty, empty_tag);
}

test "OCB key storage aliases and read-only sharing" {
    const M = ocb.Ocb(h.Aes128);
    var cipher = h.Aes128.init(@splat(0));
    const before = cipher;
    const storage = std.mem.asBytes(&cipher);
    const nonce: [12]u8 = @splat(0);
    var tag: [16]u8 = @splat(0);
    var data: [32]u8 = @splat(0);
    try t.expectError(error.InvalidOverlap, M.sealDetached(&cipher, &nonce, &.{}, storage[0..16], &tag));
    try t.expectError(error.InvalidOverlap, M.openDetached(&cipher, &nonce, &.{}, storage[0..16], &tag));
    try t.expectError(error.InvalidOverlap, M.sealDetached(&cipher, &nonce, &.{}, &data, storage[0..16]));
    try t.expectEqualSlices(u8, std.mem.asBytes(&before), storage);
    // Read-only sharing does not fail alias validation, even on invalid tags.
    try t.expectError(error.AuthenticationFailed, M.openDetached(&cipher, tag[0..12], &tag, &data, &tag));
    try t.expectEqual([_]u8{0} ** 32, data);
    // A zero-byte payload may point inside the nonce/AAD/tag.
    const empty_tag = try M.seal(&cipher, &nonce, &tag, tag[0..0]);
    try M.open(&cipher, &nonce, &tag, tag[0..0], empty_tag);
}

test "OCB independent work batches stop at64 and open authenticates in a separate pass" {
    const B = @Vector(16, u8);
    const Counters = struct { enc: usize = 0, dec: usize = 0, max: usize = 0 };
    const Counted = struct {
        cipher: h.Aes128,
        counters: *Counters,
        pub fn encrypt(self: @This(), b: *align(16) B) void {
            self.cipher.encrypt(b);
        }
        pub fn decrypt(self: @This(), b: *align(16) B) void {
            self.cipher.decrypt(b);
        }
        pub fn encryptBlocks(self: @This(), blocks: []align(16) B) void {
            self.counters.enc += 1;
            self.counters.max = @max(self.counters.max, blocks.len);
            std.debug.assert(blocks.len <= 64);
            self.cipher.encryptBlocks(blocks);
        }
        pub fn decryptBlocks(self: @This(), blocks: []align(16) B) void {
            self.counters.dec += 1;
            self.counters.max = @max(self.counters.max, blocks.len);
            std.debug.assert(blocks.len <= 64);
            self.cipher.decryptBlocks(blocks);
        }
    };
    const M = ocb.Ocb(Counted);
    var counters: Counters = .{};
    const cipher = Counted{ .cipher = h.Aes128.init(@splat(0)), .counters = &counters };
    var data: [1041]u8 = @splat(0x35);
    const aad: [1041]u8 = @splat(0x42);
    const nonce: [12]u8 = @splat(0);
    const tag = try M.seal(&cipher, &nonce, &aad, &data);
    try t.expectEqual(@as(usize, 4), counters.enc); //2 AAD +2 payload batches
    try t.expectEqual(@as(usize, 64), counters.max);
    const encrypted = data;
    var bad = tag;
    bad[0] ^= 1;
    try t.expectError(error.AuthenticationFailed, M.open(&cipher, &nonce, &aad, &data, bad));
    try t.expectEqual(@as(usize, 2), counters.dec);
    try t.expectEqual(encrypted, data);
    try M.open(&cipher, &nonce, &aad, &data, tag);
    try t.expectEqual(@as(usize, 6), counters.dec); //2 private +2 after authentication
    try t.expectEqual([_]u8{0x35} ** 1041, data);
}

test "generic RFC7253 empty nonce is distinct from named AES profile limits" {
    // Not published RFC vectors and not Node/OpenSSL OCB interoperability:
    // section4.2 empty-input formulas evaluated with independent Node AES-ECB.
    // Formatted nonce ends in 01, hence bottom=1, Ktop=E(tagbits||zeros),
    // Offset0=Stretch[2..129], Tag=E(Offset0 xor double(E(zeros))).
    const cipher = h.Aes128.init(@splat(0));
    const answers = .{ "b8", "b0742ce39b05f593", "d47ec6706c9dc6fc4d86e94e", "58e2fccefa7e3061367f1d57a4e7455a" };
    inline for (.{ 1, 8, 12, 16 }, 0..) |size, i| {
        const M = ocb.OcbWithTag(h.Aes128, size);
        var empty: [0]u8 = .{};
        const tag = try M.seal(&cipher, &.{}, &.{}, &empty);
        try t.expectEqual(h.hex(answers[i]), tag);
        try M.open(&cipher, &.{}, &.{}, &empty, tag);
    }
}

test "OCB bounded schedule independent AAD and payload powers full and partial" {
    const Case = struct { index: usize, p: usize, a: usize, tag_length: usize, sha256: []const u8, tag: []const u8 };
    const Document = struct { cases: []const Case };
    const parsed = try std.json.parseFromSlice(Document, t.allocator, @embedFile("ocb_schedule_oracle.json"), .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try t.expectEqual(@as(usize, 280), parsed.value.cases.len);
    inline for (.{ 1, 8, 12, 16 }) |tag_len| {
        const M = ocb.OcbWithTag(h.Aes128, tag_len);
        for (parsed.value.cases) |case| {
            if (case.tag_length != tag_len) continue;
            var key: [16]u8 = undefined;
            for (&key, 0..) |*v, i| v.* = @truncate(i * 11 + case.index * 7);
            const cipher = h.Aes128.init(key);
            var nonce: [15]u8 = undefined;
            for (&nonce, 0..) |*v, i| v.* = @truncate(i * 37 + case.index);
            const n = nonce[0 .. 1 + case.index % 15];
            var aad: [65567]u8 = undefined;
            for (aad[0..case.a], 0..) |*v, i| v.* = @truncate(i * 29 + case.index * 3);
            var guarded: [65569]u8 = @splat(0xa5);
            const data = guarded[1 .. 1 + case.p];
            for (data, 0..) |*v, i| v.* = @truncate(i * 17 + case.index);
            const tag = try M.seal(&cipher, n, aad[0..case.a], data);
            var expected_hash: [32]u8 = undefined;
            _ = try std.fmt.hexToBytes(&expected_hash, case.sha256);
            var actual_hash: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(data, &actual_hash, .{});
            try t.expectEqual(expected_hash, actual_hash);
            var expected_tag: M.Tag = undefined;
            _ = try std.fmt.hexToBytes(&expected_tag, case.tag);
            try t.expectEqual(expected_tag, tag);
            const before = guarded;
            var bad = tag;
            bad[tag_len - 1] ^= 1;
            try t.expectError(error.AuthenticationFailed, M.open(&cipher, n, aad[0..case.a], data, bad));
            try t.expectEqual(before, guarded);
            try M.open(&cipher, n, aad[0..case.a], data, tag);
            for (data, 0..) |v, i| try t.expectEqual(@as(u8, @truncate(i * 17 + case.index)), v);
            try t.expectEqual(@as(u8, 0xa5), guarded[0]);
            for (guarded[1 + case.p ..]) |v| try t.expectEqual(@as(u8, 0xa5), v);
        }
    }
}
