const std = @import("std");
const t = std.testing;
const h = @import("test_helpers.zig");
const vectors = @import("acpkm_vectors.zig");
const factory = @import("acpkm.zig").Modes;
fn family(comptime Cipher: type) type {
    return factory(Cipher, @import("classic.zig").Modes(Cipher));
}
const M = family(h.Aes256);
const nonce = h.hex("1234567890abcef0");
const iv = h.hex("1234567890abcef0a1b2c3d4e5f00112");

test "RFC8645 A.2.1 CTR-ACPKM AES256 all section keys and ciphertext" {
    const v = vectors.v0;
    var cipher = h.Aes256.init(v.key);
    try t.expectEqual(@as([32]u8, cipher.k), v.key1);
    cipher = M.acpkm(cipher);
    try t.expectEqual(@as([32]u8, cipher.k), v.key2);
    cipher = M.acpkm(cipher);
    try t.expectEqual(@as([32]u8, cipher.k), v.key3);
    cipher = M.acpkm(cipher);
    try t.expectEqual(@as([32]u8, cipher.k), v.key4);
    var ctr = try M.CtrAcpkm.init(h.Aes256.init(v.key), nonce, 32);
    var data = v.plain;
    try ctr.xor(&data);
    try t.expectEqual(v.ciphertext, data);
}

test "RFC8645 A.2.1 GCM-ACPKM AES128 initial authentication key and rekey" {
    const v = vectors.v1;
    const F = family(h.Aes128);
    const cipher = h.Aes128.init(v.key);
    const next = F.acpkm(cipher);
    try t.expectEqual(@as([16]u8, next.k), v.key2);
    const mode = try F.GcmAcpkm(32).init(cipher, 32);
    var data = v.plain;
    const tag = try mode.seal(@splat(0), &h.hex("112233"), &data);
    try t.expectEqual(v.ciphertext, data);
    try t.expectEqual(v.tag, tag);
    try mode.open(@splat(0), &h.hex("112233"), &data, tag);
    try t.expectEqual(v.plain, data);
}

test "RFC8645 A.2.2 ACPKM-Master keys CTR CBC CFB OMAC AES256" {
    const cipher = h.Aes256.init(vectors.v2.key);
    var derivation = try M.AcpkmMaster.init(cipher, 64, 32);
    var material: [128]u8 = undefined;
    try derivation.derive(material[0..32]);
    try derivation.derive(material[32..96]);
    try derivation.derive(material[96..]);
    try t.expectEqual(vectors.v2.material, material);
    var ctr = try M.CtrAcpkmMaster.init(cipher, nonce, 32, 64);
    var data = vectors.v2.plain;
    try ctr.xor(&data);
    try t.expectEqual(vectors.v2.ciphertext, data);
    var cbc = try M.CbcAcpkmMaster.init(cipher, iv, 32, 64);
    data = vectors.v4.plain;
    try cbc.encrypt(&data);
    try t.expectEqual(vectors.v4.ciphertext, data);
    var cbc_dec = try M.CbcAcpkmMaster.init(cipher, iv, 32, 64);
    try cbc_dec.decrypt(&data);
    try t.expectEqual(vectors.v4.plain, data);
    var cfb = try M.CfbAcpkmMaster.init(cipher, iv, 32, 64);
    var short = vectors.v5.plain;
    try cfb.encrypt(&short);
    try t.expectEqual(vectors.v5.ciphertext, short);
    var cfb_dec = try M.CfbAcpkmMaster.init(cipher, iv, 32, 64);
    try cfb_dec.decrypt(&short);
    try t.expectEqual(vectors.v5.plain, short);
    var omac_derivation = try M.AcpkmMaster.init(cipher, 96, 48);
    var omac_material: [144]u8 = undefined;
    try omac_derivation.derive(&omac_material);
    try t.expectEqual(vectors.v6.material, omac_material);
    var omac = try M.OmacAcpkmMaster.init(cipher, 32, 96);
    try omac.update(&vectors.v6.plain);
    try t.expectEqual(vectors.v6.tag, omac.final());
    try omac.verify(&vectors.v6.tag);
}

test "RFC8645 A.2.2 GCM-Master vector specifies AES192 despite AES256 heading" {
    const Aes192 = @import("acpkm_aes192_test.zig").Aes192;
    const F = family(Aes192);
    const v = vectors.v3;
    const cipher = Aes192.init(v.key);
    var derivation = try F.AcpkmMaster.init(cipher, 48, 24);
    var material: [72]u8 = undefined;
    try derivation.derive(material[0..24]);
    try derivation.derive(material[24..]);
    try t.expectEqual(v.material, material);
    const mode = try F.GcmAcpkmMaster(32).init(cipher, 32, 48);
    var data = v.plain;
    const tag = try mode.seal(@splat(0), &h.hex("112233"), &data);
    try t.expectEqual(v.ciphertext, data);
    try t.expectEqual(v.tag, tag);
    try mode.open(@splat(0), &h.hex("112233"), &data, tag);
    try t.expectEqual(v.plain, data);
}

fn differential(comptime C: type) !void {
    const F = family(C);
    const Ref = @import("acpkm_reference_test.zig").Reference(C);
    const cipher = C.init(vectors.v0.key);
    var random = std.Random.DefaultPrng.init(0x8645ac001);
    var plain: [1089]u8 = undefined;
    random.random().bytes(&plain);
    const aad = h.hex("112233445566778899aabbccddeeff001234");
    const gn = h.hex("1234567890abcdef12345678");
    var lengths: [83]usize = undefined;
    for (lengths[0..66], 0..) |*len, i| len.* = i;
    lengths[66..].* = .{ 95, 96, 97, 127, 128, 129, 255, 256, 257, 1023, 1024, 1025, 1055, 1056, 1057, 1088, 1089 };
    for ([_]usize{ 16, 32, 48, 1024 }) |section| {
        for (lengths) |n| {
            inline for (.{ false, true }) |master| {
                const Ctr = if (master) F.CtrAcpkmMaster else F.CtrAcpkm;
                var expected = plain;
                Ref.ctr(cipher, master, &nonce, 0, section, 64, expected[0..n]);
                var actual = plain;
                var ctr = if (master) try Ctr.init(cipher, nonce, section, 64) else try Ctr.init(cipher, nonce, section);
                try ctr.xor(actual[0..n]);
                try t.expectEqual(expected, actual);
                // Every split for short messages; representative byte and section splits for long ones.
                const splits = if (n <= 65) n + 1 else 9;
                for (0..splits) |i| {
                    const split = if (n <= 65) i else ([_]usize{ 0, 1, 15, 16, 17, section - 1, section, section + 1, n })[i];
                    if (split > n) continue;
                    var chunked = plain;
                    var stream = if (master) try Ctr.init(cipher, nonce, section, 64) else try Ctr.init(cipher, nonce, section);
                    try stream.xor(chunked[0..split]);
                    try stream.xor(chunked[split..n]);
                    try t.expectEqual(expected, chunked);
                    try t.expectEqual(ctr.keys.cipher.k, stream.keys.cipher.k);
                    try t.expectEqual(ctr.blocks, stream.blocks);
                }
                const Gcm = if (master) F.GcmAcpkmMaster(32) else F.GcmAcpkm(32);
                const gcm = if (master) try Gcm.init(cipher, section, 64) else try Gcm.init(cipher, section);
                expected = plain;
                Ref.ctr(cipher, master, &gn, 2, section, 64, expected[0..n]);
                const tag = Ref.tag(cipher, master, &gn, 64, &aad, expected[0..n]);
                actual = plain;
                const actual_tag = try gcm.seal(gn, &aad, actual[0..n]);
                try t.expectEqual(expected, actual);
                try t.expectEqual(tag, actual_tag);
                try gcm.open(gn, &aad, actual[0..n], tag);
                try t.expectEqual(plain, actual);
            }
            var expected = plain;
            Ref.feedback(cipher, false, iv, section, 64, expected[0..n]);
            var actual = plain;
            var cfb_whole = try F.CfbAcpkmMaster.init(cipher, iv, section, 64);
            try cfb_whole.encrypt(actual[0..n]);
            try t.expectEqual(expected, actual);
            actual = plain;
            var cfb = try F.CfbAcpkmMaster.init(cipher, iv, section, 64);
            for (0..n) |i| try cfb.encrypt(actual[i..][0..1]);
            try t.expectEqual(expected, actual);
            var dec = try F.CfbAcpkmMaster.init(cipher, iv, section, 64);
            const split = n / 2;
            try dec.decrypt(actual[0..split]);
            try dec.decrypt(actual[split..n]);
            try t.expectEqual(plain, actual);
            if (n % 16 == 0) {
                expected = plain;
                Ref.feedback(cipher, true, iv, section, 64, expected[0..n]);
                actual = plain;
                var cbc = try F.CbcAcpkmMaster.init(cipher, iv, section, 64);
                for (0..n / 16) |i| try cbc.encrypt(actual[i * 16 ..][0..16]);
                try t.expectEqual(expected, actual);
                var cbc_dec = try F.CbcAcpkmMaster.init(cipher, iv, section, 64);
                try cbc_dec.decrypt(actual[0..n]);
                try t.expectEqual(plain, actual);
            }
            const expected_mac = Ref.omac(cipher, section, 96, plain[0..n]);
            var omac = try F.OmacAcpkmMaster.init(cipher, section, 96);
            for (0..n) |i| try omac.update(plain[i..][0..1]);
            try t.expectEqual(expected_mac, omac.final());
            try t.expectEqual(expected_mac, omac.final());
            var whole = try F.OmacAcpkmMaster.init(cipher, section, 96);
            try whole.update(plain[0..n]);
            try t.expectEqual(expected_mac, whole.final());
        }
    }
}

test "Kuznechik every ACPKM construction matches independent scalar reference and chunk splits" {
    try differential(@import("../kuznechik.zig").Cipher);
}

test "ACPKM invalid parameters counters section budgets and transactional failures" {
    const cipher = h.Aes256.init(vectors.v0.key);
    for ([_]usize{ 0, 1, 15, 17, 31 }) |section| {
        try t.expectError(error.InvalidSectionSize, M.CtrAcpkm.init(cipher, nonce, section));
        try t.expectError(error.InvalidSectionSize, M.CtrAcpkmMaster.init(cipher, nonce, section, 64));
        try t.expectError(error.InvalidSectionSize, M.GcmAcpkm(32).init(cipher, section));
        try t.expectError(error.InvalidSectionSize, M.GcmAcpkmMaster(32).init(cipher, section, 64));
        try t.expectError(error.InvalidSectionSize, M.CbcAcpkmMaster.init(cipher, iv, section, 64));
        try t.expectError(error.InvalidSectionSize, M.CfbAcpkmMaster.init(cipher, iv, section, 64));
        try t.expectError(error.InvalidSectionSize, M.OmacAcpkmMaster.init(cipher, section, 96));
    }
    for ([_]usize{ 0, 1, 16, 31, 48, 65 }) |lifetime| {
        try t.expectError(error.InvalidMasterLifetime, M.AcpkmMaster.init(cipher, lifetime, 32));
        try t.expectError(error.InvalidMasterLifetime, M.CtrAcpkmMaster.init(cipher, nonce, 32, lifetime));
        try t.expectError(error.InvalidMasterLifetime, M.GcmAcpkmMaster(32).init(cipher, 32, lifetime));
        try t.expectError(error.InvalidMasterLifetime, M.CbcAcpkmMaster.init(cipher, iv, 32, lifetime));
        try t.expectError(error.InvalidMasterLifetime, M.CfbAcpkmMaster.init(cipher, iv, 32, lifetime));
    }
    for ([_]usize{ 0, 16, 32, 64, 80, 97 }) |lifetime| try t.expectError(error.InvalidMasterLifetime, M.OmacAcpkmMaster.init(cipher, 32, lifetime));
    try t.expectError(error.InvalidMaterialSize, M.AcpkmMaster.init(cipher, 64, 0));
    var data: [33]u8 = @splat(0xaa);
    const saved = data;
    var derivation = try M.AcpkmMaster.init(cipher, 64, 32);
    const derivation_saved = derivation;
    try t.expectError(error.InvalidLength, derivation.derive(&data));
    try t.expectEqual(saved, data);
    try t.expectEqualDeep(derivation_saved, derivation);
    derivation.stream.blocks = @as(u128, 1) << 63;
    try t.expectError(error.CounterExhausted, derivation.derive(data[0..32]));
    try t.expectEqual(saved, data);
    inline for (.{ false, true }) |master| {
        const Ctr = if (master) M.CtrAcpkmMasterWithCounter(32) else M.CtrAcpkmWithCounter(32);
        var ctr = if (master) try Ctr.init(cipher, @splat(0), 16, 32) else try Ctr.init(cipher, @splat(0), 16);
        const limit = @as(u128, 1) << @as(u7, if (master) 32 else 31);
        ctr.blocks = limit - 1;
        const before = ctr;
        try t.expectError(error.CounterExhausted, ctr.xor(data[0..17]));
        try t.expectEqualDeep(before, ctr);
        try t.expectEqual(saved, data);
        try ctr.xor(data[0..1]);
        try ctr.xor(data[1..16]); // Unused bytes in the last permitted block remain available.
        const exhausted = ctr;
        data = saved;
        try t.expectError(error.CounterExhausted, ctr.xor(data[0..1]));
        try t.expectEqualDeep(exhausted, ctr);
        try t.expectEqual(saved, data);
    }
    var ctr = try M.CtrAcpkmMaster.init(cipher, nonce, 16, 32);
    ctr.total = (@as(u128, 16) << 63) / 32 * 16;
    const before_ctr = ctr;
    try t.expectError(error.KeyMaterialExhausted, ctr.xor(data[0..1]));
    try t.expectEqualDeep(before_ctr, ctr);
    var cbc = try M.CbcAcpkmMaster.init(cipher, iv, 16, 32);
    const before_cbc = cbc;
    try t.expectError(error.InvalidLength, cbc.encrypt(&data));
    try t.expectError(error.InvalidLength, cbc.decrypt(&data));
    try t.expectEqualDeep(before_cbc, cbc);
    cbc.total = ctr.total;
    try t.expectError(error.KeyMaterialExhausted, cbc.encrypt(data[0..16]));
    try t.expectError(error.KeyMaterialExhausted, cbc.decrypt(data[0..16]));
    var cfb = try M.CfbAcpkmMaster.init(cipher, iv, 16, 32);
    cfb.total = ctr.total;
    const before_cfb = cfb;
    try t.expectError(error.KeyMaterialExhausted, cfb.encrypt(data[0..1]));
    try t.expectError(error.KeyMaterialExhausted, cfb.decrypt(data[0..1]));
    try t.expectEqualDeep(before_cfb, cfb);
    var omac = try M.OmacAcpkmMaster.init(cipher, 16, 48);
    omac.total = (@as(u128, 16) << 63) / 48 * 16;
    const before_omac = omac;
    try t.expectError(error.KeyMaterialExhausted, omac.update(data[0..1]));
    try t.expectEqualDeep(before_omac, omac);
    // Exercise the exact section budget and arithmetic overflow through allocation-free preflight.
    try t.expectError(error.KeyMaterialExhausted, omac.validate(std.math.maxInt(usize)));
    omac.total = std.math.maxInt(u128);
    try t.expectError(error.KeyMaterialExhausted, omac.update(data[0..1]));
    try t.expectEqual(saved, data);
}

test "ACPKM GCM bounds tags authentication failures preserve ciphertext" {
    const cipher = h.Aes256.init(vectors.v0.key);
    const aad = h.hex("112233");
    inline for (.{ false, true }) |master| {
        inline for (.{ 32, 64 }) |bits| {
            const G = if (master) M.GcmAcpkmMaster(bits) else M.GcmAcpkm(bits);
            const g = if (master) try G.init(cipher, 16, 32) else try G.init(cipher, 16);
            const gn: G.Nonce = @splat(0x12);
            const max_bytes: u128 = @min(((@as(u128, 1) << @as(u7, bits - if (master) @as(u7, 0) else 1)) - 2) * 16, std.math.maxInt(u64) / 8);
            try g.validate(0, @intCast(max_bytes));
            try t.expectError(error.MessageTooLong, g.validate(0, @intCast(max_bytes + 1)));
            try t.expectError(error.MessageTooLong, g.validate(std.math.maxInt(u64) / 8 + 1, 0));
            for ([_]usize{ 4, 8, 12, 13, 14, 15, 16 }) |tag_len| {
                var data: [49]u8 = @splat(0x35);
                const plain = data;
                var tag: [16]u8 = @splat(0);
                try g.sealDetached(gn, &aad, &data, tag[0..tag_len]);
                const ciphertext = data;
                tag[tag_len - 1] ^= 1;
                try t.expectError(error.AuthenticationFailed, g.openDetached(gn, &aad, &data, tag[0..tag_len]));
                try t.expectEqual(ciphertext, data);
                tag[tag_len - 1] ^= 1;
                try t.expectError(error.AuthenticationFailed, g.openDetached(gn, &h.hex("112234"), &data, tag[0..tag_len]));
                try t.expectEqual(ciphertext, data);
                var bad_nonce = gn;
                bad_nonce[0] ^= 1;
                try t.expectError(error.AuthenticationFailed, g.openDetached(bad_nonce, &aad, &data, tag[0..tag_len]));
                try t.expectEqual(ciphertext, data);
                data[48] ^= 1;
                const corrupted = data;
                try t.expectError(error.AuthenticationFailed, g.openDetached(gn, &aad, &data, tag[0..tag_len]));
                try t.expectEqual(corrupted, data);
                data = ciphertext;
                try g.openDetached(gn, &aad, &data, tag[0..tag_len]);
                try t.expectEqual(plain, data);
            }
            for ([_]usize{ 0, 1, 3, 5, 7, 9, 10, 11, 17 }) |tag_len| {
                var data: [17]u8 = @splat(0x85);
                const saved = data;
                var tag: [17]u8 = @splat(0x99);
                const saved_tag = tag;
                try t.expectError(error.InvalidTagLength, g.sealDetached(gn, &aad, &data, tag[0..tag_len]));
                try t.expectError(error.InvalidTagLength, g.openDetached(gn, &aad, &data, tag[0..tag_len]));
                try t.expectEqual(saved, data);
                try t.expectEqual(saved_tag, tag);
            }
        }
    }
    var omac = try M.OmacAcpkmMaster.init(cipher, 16, 48);
    const full = omac.final();
    for (1..17) |n| try omac.verify(full[0..n]);
    try t.expectError(error.InvalidTagLength, omac.verify(&.{}));
    try t.expectError(error.InvalidTagLength, omac.verify(&([_]u8{0} ** 17)));
    var bad = full;
    bad[0] ^= 1;
    try t.expectError(error.AuthenticationFailed, omac.verify(&bad));
}

test "ACPKM whole-byte counter dimensions include full master range and omit nonce carry" {
    const cipher = h.Aes256.init(vectors.v0.key);
    const Ref = @import("acpkm_reference_test.zig").Reference(h.Aes256);
    inline for (.{ 32, 40, 48, 56, 64, 72, 80, 88, 96 }) |bits| {
        inline for (.{ false, true }) |master| {
            const Ctr = if (master) M.CtrAcpkmMasterWithCounter(bits) else M.CtrAcpkmWithCounter(bits);
            const cn: Ctr.Nonce = @splat(0x63);
            var mode = if (master) try Ctr.init(cipher, cn, 32, 64) else try Ctr.init(cipher, cn, 32);
            var data: [81]u8 = @splat(0xa7);
            var expected = data;
            Ref.ctr(cipher, master, &cn, 0, 32, 64, &expected);
            try mode.xor(&data);
            try t.expectEqual(expected, data);
            // Construct the last legal counter directly and verify its bytes.
            var last = if (master) try Ctr.init(cipher, cn, 32, 64) else try Ctr.init(cipher, cn, 32);
            const limit = @as(u128, 1) << @as(u7, bits - if (master) @as(u7, 0) else 1);
            last.blocks = limit - 1;
            var block: [16]u8 = @splat(0);
            var expected_block: [16]u8 = @splat(0);
            @memcpy(expected_block[0..cn.len], &cn);
            const prefix = std.mem.readInt(u128, &expected_block, .big);
            std.mem.writeInt(u128, &expected_block, prefix | (limit - 1), .big);
            var vector: @Vector(16, u8) = expected_block;
            last.keys.cipher.encrypt(&vector);
            expected_block = vector;
            try last.xor(&block);
            try t.expectEqual(expected_block, block);
            try t.expectError(error.CounterExhausted, last.xor(block[0..1]));
        }
    }
    inline for (.{ 32, 40, 48, 56, 64 }) |bits| {
        inline for (.{ false, true }) |master| {
            const G = if (master) M.GcmAcpkmMaster(bits) else M.GcmAcpkm(bits);
            const mode = if (master) try G.init(cipher, 32, 64) else try G.init(cipher, 32);
            const gn: G.Nonce = @splat(0x42);
            var data: [49]u8 = @splat(0xab);
            var expected = data;
            Ref.ctr(cipher, master, &gn, 2, 32, 64, &expected);
            const tag = try mode.seal(gn, &.{}, &data);
            try t.expectEqual(expected, data);
            try t.expectEqual(Ref.tag(cipher, master, &gn, 64, &.{}, &expected), tag);
            try mode.open(gn, &.{}, &data, tag);
            try t.expectEqual([_]u8{0xab} ** 49, data);
        }
    }
}

test "ACPKM OMAC snapshot finalization allows appending at section boundaries" {
    const C = @import("../kuznechik.zig").Cipher;
    const F = family(C);
    const Ref = @import("acpkm_reference_test.zig").Reference(C);
    const cipher = C.init(vectors.v0.key);
    const data = [_]u8{0xda} ** 257;
    for ([_]usize{ 16, 32, 48, 256 }) |section| {
        var omac = try F.OmacAcpkmMaster.init(cipher, section, 48);
        for (0..data.len) |i| {
            const expected = Ref.omac(cipher, section, 48, data[0..i]);
            try t.expectEqual(expected, omac.final());
            try omac.verify(&expected);
            try omac.update(data[i..][0..1]);
        }
        try t.expectEqual(Ref.omac(cipher, section, 48, &data), omac.final());
    }
}

test "ACPKM GCM rejects forbidden aliases before writes and permits adjacent slices" {
    const cipher = h.Aes256.init(vectors.v0.key);
    inline for (.{ false, true }) |master| {
        const G = if (master) M.GcmAcpkmMaster(32) else M.GcmAcpkm(32);
        const mode = if (master) try G.init(cipher, 16, 32) else try G.init(cipher, 16);
        const gn: G.Nonce = @splat(0x38);
        var storage: [128]u8 = @splat(0x73);
        const saved = storage;
        var separate_tag: [16]u8 = @splat(0x91);
        const saved_tag = separate_tag;
        // AAD/data: exact, suffix overlap, prefix overlap and interior overlap.
        for ([_][4]usize{ .{ 0, 32, 0, 32 }, .{ 0, 32, 16, 48 }, .{ 16, 48, 0, 32 }, .{ 0, 48, 16, 32 } }) |ranges| {
            const aad = storage[ranges[0]..ranges[1]];
            const data = storage[ranges[2]..ranges[3]];
            try t.expectError(error.InvalidOverlap, mode.seal(gn, aad, data));
            try t.expectError(error.InvalidOverlap, mode.sealDetached(gn, aad, data, &separate_tag));
            try t.expectError(error.InvalidOverlap, mode.openDetached(gn, aad, data, &separate_tag));
            try t.expectEqual(saved, storage);
            try t.expectEqual(saved_tag, separate_tag);
        }
        // Detached output/input tag overlaps data, in either pointer order.
        for ([_][4]usize{ .{ 0, 32, 0, 16 }, .{ 0, 32, 24, 40 }, .{ 16, 48, 8, 24 } }) |ranges| {
            const data = storage[ranges[0]..ranges[1]];
            const tag = storage[ranges[2]..ranges[3]];
            try t.expectError(error.InvalidOverlap, mode.sealDetached(gn, storage[64..80], data, tag));
            try t.expectError(error.InvalidOverlap, mode.openDetached(gn, storage[64..80], data, tag));
            try t.expectEqual(saved, storage);
        }
        // A detached output tag may not corrupt AAD, even when data is empty.
        for ([_][4]usize{ .{ 0, 32, 0, 16 }, .{ 0, 32, 24, 40 }, .{ 16, 48, 8, 24 } }) |ranges| {
            try t.expectError(error.InvalidOverlap, mode.sealDetached(gn, storage[ranges[0]..ranges[1]], storage[64..80], storage[ranges[2]..ranges[3]]));
            try t.expectError(error.InvalidOverlap, mode.sealDetached(gn, storage[ranges[0]..ranges[1]], storage[64..64], storage[ranges[2]..ranges[3]]));
            try t.expectEqual(saved, storage);
        }
        // All six orders of adjacent AAD/data/tag are valid.
        for ([_][3]usize{ .{ 0, 16, 32 }, .{ 0, 32, 16 }, .{ 16, 0, 32 }, .{ 32, 0, 16 }, .{ 16, 32, 0 }, .{ 32, 16, 0 } }) |offset| {
            storage = saved;
            const aad = storage[offset[0]..][0..16];
            const data = storage[offset[1]..][0..16];
            const tag = storage[offset[2]..][0..16];
            try mode.sealDetached(gn, aad, data, tag);
            try t.expectEqualSlices(u8, saved[offset[0]..][0..16], aad);
            try mode.openDetached(gn, aad, data, tag);
            try t.expectEqualSlices(u8, saved[offset[1]..][0..16], data);
        }
        // An empty AAD/data slice has no storage to overlap.
        storage = saved;
        try mode.sealDetached(gn, storage[0..0], storage[0..0], storage[0..16]);
        try mode.openDetached(gn, storage[0..0], storage[0..0], storage[0..16]);
    }
}
