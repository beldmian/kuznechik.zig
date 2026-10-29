const std = @import("std");
const t = std.testing;
const h = @import("test_helpers.zig");
const C = @import("../kuznechik.zig").Cipher;
const P = @import("mgm_profiles.zig");
const M = P.Profiles(C);
const Raw = @import("mgm.zig").Mgm(C);
const v = @import("mgm_profiles_vectors.zig");
const key = h.hex("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f");
const nonce = h.hex("000102030405060708090a0b0c0d0e0f");
const salt = h.hex("808182838485868788898a8b");
const iv = P.KtreeIv{ .i1 = 0x91, .i2 = 0x2345, .i3 = 0x6789, .pnum = 0xabcdef };
const esp = P.EspHeader{ .spi = 0x12345678, .sequence = .{ .sn = 0x90abcdef } };
const esn = P.EspHeader{ .spi = 0x12345678, .sequence = .{ .esn = 0x1122334490abcdef } };

fn fill(out: []u8, multiplier: usize, offset: usize) void {
    for (out, 0..) |*b, i| b.* = @truncate(i * multiplier + offset);
}

test "RFC9367 A.1 all17 Kuznyechik records use published leaf keys and match every published byte" {
    try t.expectEqual(@as(usize, 17), v.tls.len);
    for (v.tls) |case| {
        const c = C.init(case.key);
        var storage: [16387]u8 = @splat(0xa5);
        const data = storage[1..][0..case.plaintext.len];
        @memcpy(data, case.plaintext);
        const tag = try M.Tls13MgmS.seal(&c, case.iv, case.sequence, data);
        try t.expectEqualSlices(u8, case.ciphertext_tag[0..data.len], data);
        try t.expectEqualSlices(u8, case.ciphertext_tag[data.len..], &tag);
        try t.expectEqual(@as(u8, 0xa5), storage[0]);
        try t.expectEqual(@as(u8, 0xa5), storage[data.len + 1]);
        try M.Tls13MgmS.open(&c, case.iv, case.sequence, data, &tag);
        try t.expectEqualSlices(u8, case.plaintext, data);
        // Cipher algorithm for L is identical when its caller supplies the
        // same leaf key; this is NOT a claim that L and S derive equal keys.
        const tag_l = try M.Tls13MgmL.seal(&c, case.iv, case.sequence, data);
        try t.expectEqual(tag, tag_l);
        try t.expectEqualSlices(u8, case.ciphertext_tag[0..data.len], data);
    }
}

test "RFC9227 Appendix A all4 Kuznyechik AEAD and MAC-only official examples" {
    try t.expectEqual(@as(usize, 4), v.esp.len);
    for (v.esp) |case| {
        const c = C.init(case.key);
        const material = P.KtreeKeyMaterial.split(case.material);
        try t.expectEqualSlices(u8, case.material[0..32], &material.root_key);
        const parsed = P.KtreeIv.decode(case.iv);
        try t.expectEqual(case.iv, try parsed.encode());
        try t.expectEqual(case.nonce, try parsed.nonce(material.salt));
        const header = P.EspHeader{ .spi = std.mem.readInt(u32, case.aad[0..4], .big), .sequence = .{ .sn = std.mem.readInt(u32, case.aad[4..8], .big) } };
        if (case.mac_only) {
            const body = case.aad[16..];
            const tag = try M.EspMgmMacKtree.seal(&c, material.salt, parsed, header, body);
            try t.expectEqual(case.tag, tag);
            try M.EspMgmMacKtree.open(&c, material.salt, parsed, header, body, &tag);
            var encoded: [12]u8 = undefined;
            try t.expectEqualSlices(u8, case.aad[0..8], header.encode(&encoded));
        } else {
            var buffer: [66]u8 = @splat(0x5a);
            const data = buffer[1..65];
            @memcpy(data, case.plaintext);
            const tag = try M.EspMgmKtree.seal(&c, material.salt, parsed, header, data);
            try t.expectEqual(case.tag, tag);
            try t.expectEqualSlices(u8, case.ciphertext, data);
            try M.EspMgmKtree.open(&c, material.salt, parsed, header, data, &tag);
            try t.expectEqualSlices(u8, case.plaintext, data);
            try t.expectEqual(@as(u8, 0x5a), buffer[0]);
            try t.expectEqual(@as(u8, 0x5a), buffer[65]);
        }
    }
}

test "MGM multipart independent Python fixtures every split including empty parts and tails" {
    const c = C.init(key);
    var aad: [1059]u8 = @splat(0x5a);
    var original: [2083]u8 = @splat(0xa5);
    fill(aad[1..], 17, 3);
    fill(original[1..], 29, 7);
    for (v.independent) |case| {
        const a = aad[1..][0..case.aad_len];
        // All possible splits for small AAD; critical block/batch splits for
        // larger AAD. An empty part inside an unfinished block must not pad.
        const splits = [_]usize{ 0, 1, 2, 7, 8, 12, 15, 16, 17, 20, 31, 32, 33, 63, 64, 65, 1007, 1008, 1023, 1024, 1025 };
        for (splits) |split| {
            if (split > a.len) continue;
            var data = original;
            const d = data[1..][0..case.length];
            const parts = [_][]const u8{ a[0..split], &.{}, a[split..] };
            const tag = try Raw.sealParts(&c, nonce, &parts, d);
            try t.expectEqual(case.tag, tag);
            try t.expectEqualSlices(u8, case.encrypted, d);
            try Raw.openParts(&c, nonce, &parts, d, &tag);
            try t.expectEqual(original, data);
        }
        var contiguous = original;
        const tag = try Raw.seal(&c, nonce, a, contiguous[1..][0..case.length]);
        try t.expectEqual(case.tag, tag);
        try t.expectEqualSlices(u8, case.encrypted, contiguous[1..][0..case.length]);
    }
    // Every byte is a separate part: checks repeated fills of one pending
    // block as well as the large input batch path.
    var parts: [1057][]const u8 = undefined;
    for (&parts, 0..) |*part, i| part.* = aad[1 + i ..][0..1];
    const expected = v.independent[v.independent.len - 1];
    var data = original;
    const tag = try Raw.sealParts(&c, nonce, &parts, data[1..2082]);
    try t.expectEqual(expected.tag, tag);
    try t.expectEqualSlices(u8, expected.encrypted, data[1..2082]);
}

test "TLS nonce masks only the high bit after full-width big-endian XOR and RawMgm stays strict" {
    const original = h.hex("ffeeddccbbaa99887766554433221100");
    try t.expectEqual(h.hex("7feeddccbbaa99887664564036241608"), try M.Tls13MgmL.nonce(original, 0x0102030405060708));
    try t.expectEqual(h.hex("7feeddccbbaa99888899aabbccddeeff"), try M.Tls13MgmL.nonce(original, std.math.maxInt(u64)));
    try t.expectError(error.InvalidNonce, Raw.validate(original, 5, 1));
    const c = C.init(key);
    var data = [_]u8{1};
    try t.expectError(error.InvalidNonce, Raw.seal(&c, original, &.{1}, &data));
    try t.expectEqual(@as(u8, 1), data[0]);
}

test "TLS L S checked lengths sequence endpoints masks and exact header" {
    try M.Tls13MgmL.validate(std.math.maxInt(u64), 16385);
    try M.Tls13MgmS.validate((1 << 42) - 1, 16385);
    try t.expectError(error.SequenceExhausted, M.Tls13MgmS.validate(1 << 42, 1));
    try t.expectError(error.SequenceExhausted, M.Tls13MgmS.nonce(nonce, 1 << 42));
    try t.expectError(error.SequenceExhausted, M.Tls13MgmS.seeds(1 << 42));
    try t.expectError(error.InvalidLength, M.Tls13MgmS.validate(0, 0));
    try t.expectError(error.MessageTooLong, M.Tls13MgmL.validate(0, 16386));
    try t.expectError(error.MessageTooLong, M.Tls13MgmL.validate(0, std.math.maxInt(usize)));
    try t.expectEqual(h.hex("1703034011"), try M.Tls13MgmS.header(16385));
    try t.expectEqual(h.hex("1703030011"), try M.Tls13MgmL.header(1));
    inline for (.{ M.Tls13MgmL, M.Tls13MgmS }) |TLS| {
        const seq = TLS.max_sequence;
        const seeds = try TLS.seeds(seq);
        for (seeds, TLS.tree_masks) |seed, mask| try t.expectEqual(seq & mask, std.mem.readInt(u64, &seed, .big));
    }
    try t.expectEqual([3][8]u8{ @splat(0), @splat(0), h.hex("0000000000000008") }, try M.Tls13MgmS.seeds(8));
}

test "KTREE IV seeds nonce maxima and pnum overflow are checked without narrowing" {
    const encoded = try iv.encode();
    try t.expectEqual(h.hex("9123456789abcdef"), encoded);
    try t.expectEqual(iv, P.KtreeIv.decode(encoded));
    try t.expectEqual(h.hex("00abcdef808182838485868788898a8b"), try iv.nonce(salt));
    try t.expectEqual([3][2]u8{ h.hex("0091"), h.hex("2345"), h.hex("6789") }, try iv.seeds());
    const maximum = P.KtreeIv.decode(@splat(255));
    try t.expectEqual(@as(u32, 0xffffff), maximum.pnum);
    try t.expectEqual(@as([8]u8, @splat(255)), try maximum.encode());
    var invalid = maximum;
    invalid.pnum = 0x1000000;
    try t.expectError(error.MessageCounterExhausted, invalid.encode());
    try t.expectError(error.MessageCounterExhausted, invalid.nonce(salt));
    try t.expectError(error.MessageCounterExhausted, invalid.seeds());
}

test "ESP SN ESN AAD exact order and MAC-only concatenation without boundary padding" {
    const c = C.init(key);
    var encoded: [12]u8 = undefined;
    try t.expectEqualSlices(u8, &h.hex("1234567890abcdef"), esp.encode(&encoded));
    try t.expectEqualSlices(u8, &h.hex("123456781122334490abcdef"), esn.encode(&encoded));
    var original: [2082]u8 = undefined;
    fill(&original, 29, 7);
    for ([_]P.EspHeader{ esp, esn }) |header| {
        for ([_]usize{ 0, 1, 3, 4, 15, 16, 17, 31, 32, 33, 479, 480, 481, 1023, 1024, 1025, 2081 }) |n| {
            var data = original;
            const body = data[1..][0..n];
            const tag = try M.EspMgmKtree.seal(&c, salt, iv, header, body);
            var expected = original;
            const raw_tag = try Raw.seal(&c, try iv.nonce(salt), header.encode(&encoded), expected[1..][0..n]);
            try t.expectEqual(expected, data);
            try t.expectEqualSlices(u8, raw_tag[0..12], &tag);
            try M.EspMgmKtree.open(&c, salt, iv, header, body, &tag);
            try t.expectEqual(original, data);
            // Independent of segmented helper: join the exact fields here and
            // compare the existing contiguous MGM path.
            var joined: [2102]u8 = undefined;
            const prefix = header.encode(&encoded);
            @memcpy(joined[0..prefix.len], prefix);
            @memcpy(joined[prefix.len..][0..8], &try iv.encode());
            @memcpy(joined[prefix.len + 8 ..][0..n], body);
            var empty: [0]u8 = .{};
            const raw_mac = try Raw.seal(&c, try iv.nonce(salt), joined[0 .. prefix.len + 8 + n], &empty);
            const mac = try M.EspMgmMacKtree.seal(&c, salt, iv, header, body);
            try t.expectEqualSlices(u8, raw_mac[0..12], &mac);
            try M.EspMgmMacKtree.open(&c, salt, iv, header, body, &mac);
            try t.expectEqual(original, data);
        }
    }
}

fn ikeAad(fragmented: bool, prefix: []const u8) P.IkeAad {
    var head: [28]u8 = undefined;
    fill(&head, 7, 5);
    return .{ .header = head, .unencrypted_payloads = prefix, .encrypted_header = if (fragmented) .{ .fragment = h.hex("2e00008000010002") } else .{ .payload = h.hex("2e000080") } };
}

test "IKE ordinary and fragmented ordered AAD matches contiguous MGM across all tails" {
    const c = C.init(key);
    var original: [1058]u8 = undefined;
    fill(&original, 29, 7);
    const prefix = h.hex("112233445566778899aabbccddeeff001122334455667788");
    for ([_]bool{ false, true }) |frag| {
        for (0..prefix.len + 1) |p| {
            const aad = ikeAad(frag, prefix[0..p]);
            var joined: [64]u8 = undefined;
            @memcpy(joined[0..28], &aad.header);
            @memcpy(joined[28..][0..p], prefix[0..p]);
            const tail: []const u8 = switch (aad.encrypted_header) {
                .payload => |*x| x,
                .fragment => |*x| x,
            };
            @memcpy(joined[28 + p ..][0..tail.len], tail);
            const length = try aad.length();
            try t.expectEqual(28 + p + tail.len, length);
            for ([_]usize{ 0, 1, 15, 16, 17, 479, 480, 481, 1023, 1024, 1025, 1057 }) |n| {
                var data = original;
                var expected = original;
                const tag = try M.IkeMgmKtree.seal(&c, salt, iv, aad, data[1..][0..n]);
                const raw_tag = try Raw.seal(&c, try iv.nonce(salt), joined[0..length], expected[1..][0..n]);
                try t.expectEqual(expected, data);
                try t.expectEqualSlices(u8, raw_tag[0..12], &tag);
                try M.IkeMgmKtree.open(&c, salt, iv, aad, data[1..][0..n], &tag);
                try t.expectEqual(original, data);
            }
        }
    }
}

test "Profile wire caps account for AAD IV tag and ESN high word not sent on wire" {
    try M.EspMgmKtree.validateLength(65536 - 28);
    try M.EspMgmMacKtree.validateLength(65536 - 28);
    try t.expectError(error.MessageTooLong, M.EspMgmKtree.validateLength(65536 - 27));
    try t.expectError(error.MessageTooLong, M.EspMgmMacKtree.validateLength(std.math.maxInt(usize)));
    try M.IkeMgmKtree.validateLengths(32, 65536 - 52);
    try M.IkeMgmKtree.validateLengths(36, 65536 - 56);
    try t.expectError(error.MessageTooLong, M.IkeMgmKtree.validateLengths(32, 65536 - 51));
    try t.expectError(error.MessageTooLong, M.IkeMgmKtree.validateLengths(std.math.maxInt(usize), std.math.maxInt(usize)));
}

test "TLS failures and fixed tag lengths preserve every ciphertext byte" {
    const c = C.init(key);
    const wrong = C.init(@splat(0));
    var data: [16386]u8 = @splat(0x25);
    const saved = data;
    try t.expectError(error.SequenceExhausted, M.Tls13MgmS.seal(&c, nonce, 1 << 42, data[0..1]));
    try t.expectError(error.MessageTooLong, M.Tls13MgmL.seal(&c, nonce, 0, &data));
    try t.expectEqual(saved, data);
    const tag = try M.Tls13MgmS.seal(&c, nonce, 0, data[1..1058]);
    const encrypted = data;
    var changed = tag;
    changed[7] ^= 1;
    try t.expectError(error.AuthenticationFailed, M.Tls13MgmS.open(&c, nonce, 0, data[1..1058], &changed));
    try t.expectError(error.AuthenticationFailed, M.Tls13MgmS.open(&wrong, nonce, 0, data[1..1058], &tag));
    try t.expectError(error.AuthenticationFailed, M.Tls13MgmS.open(&c, nonce, 1, data[1..1058], &tag));
    try t.expectError(error.InvalidTagLength, M.Tls13MgmS.open(&c, nonce, 0, data[1..1058], tag[0..12]));
    try t.expectError(error.InvalidOverlap, M.Tls13MgmS.open(&c, nonce, 0, data[1..1058], data[2..18]));
    try t.expectEqual(encrypted, data);
    try M.Tls13MgmS.open(&c, nonce, 0, data[1..1058], &tag);
    try t.expectEqual(saved, data);
}

test "ESP AEAD and auth-only reject wrong keys salts sequence prefixes IV and tag without writing" {
    const c = C.init(key);
    const wrong = C.init(@splat(1));
    const bad_salt = @as([12]u8, @splat(1));
    var data: [2083]u8 = undefined;
    fill(&data, 13, 7);
    const original = data;
    inline for (.{ M.EspMgmKtree, M.EspMgmMacKtree }) |E| {
        data = original;
        const tag = try E.seal(&c, salt, iv, esn, data[1..2082]);
        const encrypted = data;
        if (E == M.EspMgmMacKtree) try t.expectEqual(original, data);
        var bad_iv = iv;
        bad_iv.pnum ^= 1;
        var bad_tag = tag;
        bad_tag[11] ^= 1;
        for (0..6) |fault| {
            const cipher = if (fault == 0) &wrong else &c;
            const s = if (fault == 1) bad_salt else salt;
            const i = if (fault == 2) bad_iv else iv;
            const e = if (fault == 3) esp else esn;
            const tg = if (fault == 4) &bad_tag else &tag;
            if (fault == 5) data[17] ^= 1;
            const before = data;
            try t.expectError(error.AuthenticationFailed, E.open(cipher, s, i, e, data[1..2082], tg));
            try t.expectEqual(before, data);
            if (fault == 5) data[17] ^= 1;
        }
        try t.expectError(error.InvalidTagLength, E.open(&c, salt, iv, esn, data[1..2082], tag[0..8]));
        var invalid = iv;
        invalid.pnum = 1 << 24;
        try t.expectError(error.MessageCounterExhausted, E.seal(&c, salt, invalid, esn, data[1..2082]));
        try t.expectEqual(encrypted, data);
        try E.open(&c, salt, iv, esn, data[1..2082], &tag);
        try t.expectEqual(original, data);
    }
    // The leaf index is deliberately not in AEAD's nonce/AAD. Caller MUST
    // select a different derived key. MAC-only additionally authenticates IV.
    var leaf = iv;
    leaf.i2 ^= 1;
    const a = try M.EspMgmMacKtree.seal(&c, salt, iv, esn, &original);
    const b = try M.EspMgmMacKtree.seal(&c, salt, leaf, esn, &original);
    try t.expect(!std.mem.eql(u8, &a, &b));
}

test "IKE failures bind each AAD field and payload and preserve ciphertext" {
    const c = C.init(key);
    const wrong = C.init(@splat(1));
    var data: [1057]u8 = @splat(0x4f);
    const prefix = [_]u8{ 1, 2, 3, 4, 5 };
    const aad = ikeAad(true, &prefix);
    const tag = try M.IkeMgmKtree.seal(&c, salt, iv, aad, &data);
    const before = data;
    for (0..7) |fault| {
        var a = aad;
        var altered = prefix;
        var tg = tag;
        if (fault == 0) a.header[3] ^= 1;
        if (fault == 1) {
            altered[0] ^= 1;
            a.unencrypted_payloads = &altered;
        }
        if (fault == 2) a.encrypted_header.fragment[7] ^= 1;
        if (fault == 3) tg[0] ^= 1;
        if (fault == 4) data[100] ^= 1;
        const saved = data;
        try t.expectError(error.AuthenticationFailed, M.IkeMgmKtree.open(if (fault == 5) &wrong else &c, if (fault == 6) @splat(0) else salt, iv, a, &data, &tg));
        try t.expectEqual(saved, data);
        if (fault == 4) data[100] ^= 1;
    }
    try t.expectError(error.InvalidTagLength, M.IkeMgmKtree.open(&c, salt, iv, aad, &data, &@as([16]u8, @splat(0))));
    try t.expectEqual(before, data);
}

test "MGM multipart failures reject aliases and invalid metadata before any write" {
    var c = C.init(key);
    var data: [65]u8 = @splat(0x42);
    const before = data;
    try t.expectError(error.InvalidOverlap, Raw.sealParts(&c, nonce, &.{data[0..1]}, data[0..32]));
    try t.expectError(error.InvalidOverlap, Raw.openParts(&c, nonce, &.{data[0..1]}, data[0..32], data[32..48]));
    try t.expectError(error.InvalidOverlap, Raw.openParts(&c, nonce, &.{&.{1}}, data[0..32], data[16..32]));
    try t.expectError(error.InvalidTagLength, Raw.openParts(&c, nonce, &.{&.{1}}, data[0..32], data[32..35]));
    try t.expectError(error.EmptyMessage, Raw.sealParts(&c, nonce, &.{ &.{}, &.{} }, data[0..0]));
    var bad = nonce;
    bad[0] |= 128;
    try t.expectError(error.InvalidNonce, Raw.sealParts(&c, bad, &.{&.{1}}, data[0..32]));
    try t.expectEqual(before, data);
    const cipher_bytes = std.mem.asBytes(&c);
    const saved = cipher_bytes.*;
    try t.expectError(error.InvalidOverlap, M.Tls13MgmS.seal(&c, nonce, 0, cipher_bytes[1..18]));
    try t.expectError(error.InvalidOverlap, M.EspMgmKtree.seal(&c, salt, iv, esp, cipher_bytes[0..32]));
    try t.expectError(error.InvalidOverlap, Raw.sealParts(&c, nonce, &.{&.{1}}, cipher_bytes[0..32]));
    try t.expectEqual(saved, cipher_bytes.*);
    const aad = ikeAad(false, data[0..7]);
    try t.expectError(error.InvalidOverlap, M.IkeMgmKtree.seal(&c, salt, iv, aad, data[0..32]));
    try t.expectEqual(before, data);
    // Descriptor metadata itself cannot be overwritten before authentication.
    var parts: [1][]const u8 = .{&.{1}};
    const desc = std.mem.sliceAsBytes(parts[0..]);
    const prior = desc[0..@sizeOf([]const u8)].*;
    try t.expectError(error.InvalidOverlap, Raw.sealParts(&c, nonce, &parts, desc));
    try t.expectEqual(prior, desc[0..@sizeOf([]const u8)].*);
}

test "Profile sequence counter actual endpoints empty bodies and adjacent tag slices" {
    const c = C.init(key);
    inline for (.{ M.Tls13MgmL, M.Tls13MgmS }) |TLS| {
        var data = [_]u8{23};
        const tag = try TLS.seal(&c, nonce, TLS.max_sequence, &data);
        try TLS.open(&c, nonce, TLS.max_sequence, &data, &tag);
        try t.expectEqual(@as(u8, 23), data[0]);
    }
    const last = P.KtreeIv.decode(@splat(255));
    inline for (.{ M.EspMgmKtree, M.EspMgmMacKtree }) |E| {
        var empty: [0]u8 = .{};
        const tag = try E.seal(&c, salt, last, esn, &empty);
        try E.open(&c, salt, last, esn, &empty, &tag);
    }
    var empty: [0]u8 = .{};
    const aad = ikeAad(false, &.{});
    const empty_tag = try M.IkeMgmKtree.seal(&c, salt, last, aad, &empty);
    try M.IkeMgmKtree.open(&c, salt, last, aad, &empty, &empty_tag);
    var buffer: [45]u8 = @splat(7);
    const original = buffer;
    const tag = try M.EspMgmKtree.seal(&c, salt, iv, esn, buffer[0..33]);
    @memcpy(buffer[33..45], &tag);
    try M.EspMgmKtree.open(&c, salt, iv, esn, buffer[0..33], buffer[33..45]);
    try t.expectEqualSlices(u8, original[0..33], buffer[0..33]);
    try t.expectEqualSlices(u8, &tag, buffer[33..45]);
}

test "All small multipart splits and all remainder pairs match unchanged contiguous MGM" {
    const c = C.init(key);
    var a: [34]u8 = undefined;
    var original: [34]u8 = undefined;
    fill(&a, 17, 3);
    fill(&original, 29, 7);
    for (0..34) |alen| {
        for (0..34) |n| {
            if (alen + n == 0) continue;
            var expected = original;
            const tag = try Raw.seal(&c, nonce, a[0..alen], expected[0..n]);
            for (0..alen + 1) |split| {
                var data = original;
                const parts = [_][]const u8{ &.{}, a[0..split], &.{}, a[split..alen], &.{} };
                const actual = try Raw.sealParts(&c, nonce, &parts, data[0..n]);
                try t.expectEqual(tag, actual);
                try t.expectEqual(expected, data);
                try Raw.openParts(&c, nonce, &parts, data[0..n], &actual);
                try t.expectEqual(original, data);
            }
        }
    }
}

test "Every byte alignment across profile short long and batch boundaries leaves guards intact" {
    try t.expectEqual(@as(usize, 352), @sizeOf(C));
    const c = C.init(key);
    const aad = ikeAad(true, &.{ 1, 2, 3 });
    var source: [16417]u8 = undefined;
    fill(&source, 29, 7);
    for (0..16) |offset| {
        for ([_]usize{ 1, 15, 16, 17, 463, 464, 465, 1023, 1024, 1025, 16385 }) |length| {
            var tls = source;
            const data = tls[offset..][0..length];
            const tag = try M.Tls13MgmS.seal(&c, nonce, 8, data);
            try t.expectEqualSlices(u8, source[0..offset], tls[0..offset]);
            try t.expectEqualSlices(u8, source[offset + length ..], tls[offset + length ..]);
            try M.Tls13MgmS.open(&c, nonce, 8, data, &tag);
            try t.expectEqual(source, tls);
            var e = source;
            const etag = try M.EspMgmKtree.seal(&c, salt, iv, esn, e[offset..][0..length]);
            try t.expectEqualSlices(u8, source[0..offset], e[0..offset]);
            try t.expectEqualSlices(u8, source[offset + length ..], e[offset + length ..]);
            try M.EspMgmKtree.open(&c, salt, iv, esn, e[offset..][0..length], &etag);
            try t.expectEqual(source, e);
            var i = source;
            const itag = try M.IkeMgmKtree.seal(&c, salt, iv, aad, i[offset..][0..length]);
            try t.expectEqualSlices(u8, source[0..offset], i[0..offset]);
            try t.expectEqualSlices(u8, source[offset + length ..], i[offset + length ..]);
            try M.IkeMgmKtree.open(&c, salt, iv, aad, i[offset..][0..length], &itag);
            try t.expectEqual(source, i);
            const mac = try M.EspMgmMacKtree.seal(&c, salt, iv, esn, i[offset..][0..length]);
            try M.EspMgmMacKtree.open(&c, salt, iv, esn, i[offset..][0..length], &mac);
            try t.expectEqual(source, i);
        }
    }
}
