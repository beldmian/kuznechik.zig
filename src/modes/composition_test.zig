const std = @import("std");
const t = std.testing;
const h = @import("test_helpers.zig");
const C = @import("../kuznechik.zig").Cipher;
const classic = @import("classic.zig").Modes(C);
const acpkm = @import("acpkm.zig").Modes(C, classic);
const composition = @import("compositions.zig");
const M = composition.Modes(C, classic, acpkm);
const key = h.hex("7dac56e48a4dc170faa8fcbae20db845450cccc4c6328bdc8d01157cefa2a5f1");
const enc_key = h.hex("1f1cbad8866166f01ffaab0152e24bf4609d5f46a5c899c787900d08b9fcad24");
const nonce = h.hex("214a6a298e99e325");
const kexp = M.KExp15.init(C.init(enc_key), C.init(key));
const record0 = composition.Record{ .sequence = 0, .content_type = 23 };

// This is actual Kuznyechik, not a generic AES example.
test "RFC9189 A.1.3.2 Kuznyechik PMS export and import exact known answer" {
    const secret = h.hex("a5576ce7924a24f58113808dbd9ef856f5bdc3b183ce5dadca36a53aa077651d");
    const expected = h.hex("250d1b67a270ab04d3f65418e1d380b4cb945f0a3dca51500cf3a1bef37f76c07341a9839ccf6cba7189da61eb67176c");
    var wrapped: [48]u8 = undefined;
    try kexp.seal(nonce, &wrapped, &secret);
    try t.expectEqual(expected, wrapped);
    var imported: [32]u8 = undefined;
    try kexp.open(nonce, &imported, &expected);
    try t.expectEqual(secret, imported);
    const tag_copy = wrapped[32..].*;
    const opened = try kexp.openInPlace(nonce, &wrapped);
    try t.expectEqualSlices(u8, &secret, opened);
    try t.expectEqual(tag_copy, wrapped[32..].*);
}

const tls_enc_0 = h.hex("58afbe9a4c3198aaabaa2692c419f1797c9b92deb3cc7446b363577113f0fb56");
const tls_mac_0 = h.hex("19a76ed30f4d6d1f5b7263ec491ad83817c0b57d8a0356127140fb4f7425494d");
const tls_enc_64 = h.hex("64f55afc37a174d9533e708bcd14fa4aeec37bc0e32ba49901b4669e96a63d96");
const tls_mac_64 = h.hex("aebe1ef418713bf044b9fcd9e572d437fb38b5d829567a6f7918396d9f4e096b");
const tls0 = M.TlsCtrOmac.init(C.init(tls_enc_0), C.init(tls_mac_0));

test "RFC9189 A.1.2.2 Kuznyechik TLS records 0 63 64 including meshing" {
    var data: [8208]u8 = @splat(0);
    try tls0.sealInPlace(@splat(0), record0, data[0..31]);
    try t.expectEqual(h.hex("4d1a305236573bffc14e46dcbe746db6c99a175a81c4711e2f84c392c5407c"), data[0..31].*);
    var mac = classic.Cmac.init(C.init(tls_mac_0));
    mac.update(&h.hex("0000000000000000170303000f"));
    mac.update(&@as([15]u8, @splat(0)));
    try t.expectEqual(h.hex("fd1719dd950837eb7c7bb8f500379981"), mac.final());
    _ = try tls0.openInPlace(@splat(0), record0, data[0..31]);
    try t.expectEqual(@as([15]u8, @splat(0)), data[0..15].*);

    // RFC prints a 48-byte prefix and 53-byte suffix of the complete TLS wire
    // record, with the middle elided. Compare every available byte, excluding
    // the five-byte header, and separately its unencrypted MAC intermediate.
    inline for (.{ false, true }) |second| {
        const length: usize = if (second) 8192 else 4096;
        const seq: u64 = if (second) 64 else 63;
        const tls = if (second) M.TlsCtrOmac.init(C.init(tls_enc_64), C.init(tls_mac_64)) else tls0;
        const record = composition.Record{ .sequence = seq, .content_type = 23 };
        const prefix = if (second) h.hex("e666bb98ac5b0f3931d8551b93368596eef0eba8269cb8bdaae7eb80c830d75ab7d46c2506dc8b83e1f2d3") else h.hex("129351d26e140713a21b376824a22317cdc0d88e01cfa3fe21415f5c5e05869ccf38a51bc2e0ed689446a8");
        const suffix = if (second) h.hex("b302672ccb0286cd4048fbd5381a655526112551014fa8edf5c21b7d1db39d6badec0d7c0705348b5c556c4d5081691aa9ec36f8b5") else h.hex("19ad998c062521e67b6359a4f5c816f9476ba7132682bba8ce0bedad65e420a297b6e2c61fa406d9b8ca36fd9fcd3aee2478f4d196");
        @memset(&data, 0);
        try tls.sealInPlace(@splat(0), record, data[0 .. length + 16]);
        try t.expectEqualSlices(u8, &prefix, data[0..prefix.len]);
        // Printed suffix begins at wire offset length-32, hence fragment
        // offset length-37, and runs through the encrypted full tag.
        try t.expectEqualSlices(u8, &suffix, data[length - 37 .. length + 16]);
        var header: [13]u8 = undefined;
        std.mem.writeInt(u64, header[0..8], seq, .big);
        header[8..11].* = .{ 23, 3, 3 };
        std.mem.writeInt(u16, header[11..13], @intCast(length), .big);
        mac = classic.Cmac.init(C.init(if (second) tls_mac_64 else tls_mac_0));
        mac.update(&header);
        const zeroes: [8192]u8 = @splat(0);
        mac.update(zeroes[0..length]);
        try t.expectEqual(if (second) h.hex("eac39787842b1dbd6080cc3fbfae5c2f") else h.hex("98462761d026244a2c0b7d1bcccbe7b0"), mac.final());
        const plaintext = try tls.openInPlace(@splat(0), record, data[0 .. length + 16]);
        try t.expectEqualSlices(u8, zeroes[0..length], plaintext);
    }
}

fn fixtureSeal(kind: @import("composition_oracle.zig").Kind, section: usize, output: []u8, input: []const u8) !void {
    const enc = C.init(@as([32]u8, @import("composition_oracle.zig").encryption_key));
    const auth = C.init(@as([32]u8, @import("composition_oracle.zig").authentication_key));
    const iv = h.hex("0001020304050607");
    switch (kind) {
        .kexp => try M.KExp15.init(enc, auth).seal(iv, output, input),
        .tls => try M.TlsCtrOmac.init(enc, auth).seal(iv, .{ .sequence = std.math.maxInt(u64), .content_type = 23 }, output, input),
        .password => try (try M.CtrAcpkmOmac.init(enc, auth, section)).seal(iv, output, input),
    }
}
fn fixtureOpen(kind: @import("composition_oracle.zig").Kind, section: usize, output: []u8, input: []const u8) !void {
    const enc = C.init(@as([32]u8, @import("composition_oracle.zig").encryption_key));
    const auth = C.init(@as([32]u8, @import("composition_oracle.zig").authentication_key));
    const iv = h.hex("0001020304050607");
    switch (kind) {
        .kexp => try M.KExp15.init(enc, auth).open(iv, output, input),
        .tls => try M.TlsCtrOmac.init(enc, auth).open(iv, .{ .sequence = std.math.maxInt(u64), .content_type = 23 }, output, input),
        .password => try (try M.CtrAcpkmOmac.init(enc, auth, section)).open(iv, output, input),
    }
}
fn fixtureInPlace(kind: @import("composition_oracle.zig").Kind, section: usize, buffer: []u8, seal: bool) !void {
    const enc = C.init(@as([32]u8, @import("composition_oracle.zig").encryption_key));
    const auth = C.init(@as([32]u8, @import("composition_oracle.zig").authentication_key));
    const iv = h.hex("0001020304050607");
    switch (kind) {
        .kexp => {
            const mode = M.KExp15.init(enc, auth);
            if (seal) try mode.sealInPlace(iv, buffer) else _ = try mode.openInPlace(iv, buffer);
        },
        .tls => {
            const mode = M.TlsCtrOmac.init(enc, auth);
            const record = composition.Record{ .sequence = std.math.maxInt(u64), .content_type = 23 };
            if (seal) try mode.sealInPlace(iv, record, buffer) else _ = try mode.openInPlace(iv, record, buffer);
        },
        .password => {
            const mode = try M.CtrAcpkmOmac.init(enc, auth, section);
            if (seal) try mode.sealInPlace(iv, buffer) else _ = try mode.openInPlace(iv, buffer);
        },
    }
}
fn guards(buffer: []const u8, offset: usize, length: usize) !void {
    try t.expect(std.mem.allEqual(u8, buffer[0..offset], 0xa5));
    try t.expect(std.mem.allEqual(u8, buffer[offset + length ..], 0xa5));
}

test "independent Python Kuznyechik oracle full outputs all alignments and 64-block section boundaries" {
    const fixtures = @import("composition_oracle.zig");
    var input: [composition.max_compressed_length + 32]u8 = undefined;
    var output: [input.len + 16]u8 = undefined;
    var opened: [input.len]u8 = undefined;
    var in_place: [output.len]u8 = undefined;
    for (fixtures.cases) |case| {
        const expected = fixtures.data[case.offset..][0..case.size];
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(expected, &digest, .{});
        try t.expectEqual(case.sha256, digest);
        for (0..16) |offset| {
            @memset(&input, 0xa5);
            const data = input[offset..][0..case.length];
            for (data, 0..) |*byte, i| byte.* = @truncate(i * 29 + 7);
            @memset(&output, 0xa5);
            const ciphertext = output[offset..][0..case.size];
            try fixtureSeal(case.kind, case.section, ciphertext, data);
            try t.expectEqualSlices(u8, expected, ciphertext);
            try guards(&input, offset, data.len);
            try guards(&output, offset, ciphertext.len);
            @memset(&opened, 0xa5);
            try fixtureOpen(case.kind, case.section, opened[offset..][0..case.length], ciphertext);
            try t.expectEqualSlices(u8, data, opened[offset..][0..case.length]);
            try t.expectEqualSlices(u8, expected, ciphertext);
            try guards(&opened, offset, case.length);
            @memset(&in_place, 0xa5);
            const buffer = in_place[offset..][0..case.size];
            @memcpy(buffer[0..case.length], data);
            try fixtureInPlace(case.kind, case.section, buffer, true);
            try t.expectEqualSlices(u8, expected, buffer);
            try fixtureInPlace(case.kind, case.section, buffer, false);
            try t.expectEqualSlices(u8, data, buffer[0..case.length]);
            try t.expectEqualSlices(u8, expected[case.length..], buffer[case.length..]);
            try guards(&in_place, offset, buffer.len);
        }
    }
}

test "every ciphertext or tag byte corruption and wrong keys nonce metadata preserve all buffers" {
    const fixtures = @import("composition_oracle.zig");
    var ciphertext: [17424]u8 = undefined;
    var destination: [17408]u8 = undefined;
    for (fixtures.cases) |case| {
        // Exhaust every byte for small records; sample batch/section boundaries
        // and both ends of the encrypted tag for the larger records.
        const expected = fixtures.data[case.offset..][0..case.size];
        const trials = if (case.length <= 65) case.size else 10;
        for (0..trials) |trial| {
            const at = if (case.length <= 65) trial else switch (trial) {
                0 => @as(usize, 0),
                1 => case.length - 1,
                2 => case.length,
                3 => case.size - 1,
                4 => @min(1023, case.length - 1),
                5 => @min(1024, case.length - 1),
                6 => @min(4095, case.length - 1),
                7 => @min(4096, case.length - 1),
                8 => @min(63, case.length - 1),
                else => @min(64, case.length - 1),
            };
            const buffer = ciphertext[0..case.size];
            @memcpy(buffer, expected);
            buffer[at] ^= 1;
            @memset(&destination, 0xa5);
            try t.expectError(error.AuthenticationFailed, fixtureOpen(case.kind, case.section, destination[0..case.length], buffer));
            try t.expect(std.mem.allEqual(u8, &destination, 0xa5));
            try t.expectError(error.AuthenticationFailed, fixtureInPlace(case.kind, case.section, buffer, false));
            buffer[at] ^= 1;
            try t.expectEqualSlices(u8, expected, buffer);
        }
    }
    var secret: [33]u8 = @splat(7);
    var wrapped: [49]u8 = undefined;
    try kexp.seal(nonce, &wrapped, &secret);
    const saved = wrapped;
    var wrong_nonce = nonce;
    wrong_nonce[0] ^= 1;
    try t.expectError(error.AuthenticationFailed, kexp.open(wrong_nonce, &secret, &wrapped));
    try t.expect(std.mem.allEqual(u8, &secret, 7));
    inline for (.{ false, true }) |enc_wrong| {
        const wrong = M.KExp15.init(C.init(if (enc_wrong) key else enc_key), C.init(if (enc_wrong) key else enc_key));
        try t.expectError(error.AuthenticationFailed, wrong.openInPlace(nonce, &wrapped));
        try t.expectEqual(saved, wrapped);
    }
    try tls0.sealInPlace(nonce, record0, &wrapped);
    const tls_saved = wrapped;
    inline for (.{
        composition.Record{ .sequence = 1, .content_type = 23 },
        composition.Record{ .sequence = 0, .content_type = 22 },
        composition.Record{ .sequence = 0, .content_type = 23, .version = .{ 3, 2 } },
    }) |wrong_record| {
        try t.expectError(error.AuthenticationFailed, tls0.openInPlace(nonce, wrong_record, &wrapped));
        try t.expectEqual(tls_saved, wrapped);
    }
    // Shortened/extended records imply a different authenticated length and a
    // different tag split. They cannot be accepted as a tag-length downgrade.
    try t.expectError(error.AuthenticationFailed, tls0.openInPlace(nonce, record0, wrapped[0..48]));
    try t.expectEqual(tls_saved, wrapped);
}

test "composition preflight lengths sections overlap adjacency and TLS IV modulo" {
    try t.expectEqual(@as(usize, 16), try M.KExp15.wrappedLength(0));
    try t.expectEqual(@as(usize, 33), try M.CtrAcpkmOmac.protectedLength(17));
    try t.expectError(error.MessageTooLong, M.KExp15.wrappedLength(std.math.maxInt(usize)));
    try t.expectError(error.MessageTooLong, M.CtrAcpkmOmac.protectedLength(std.math.maxInt(usize) - 15));
    try t.expectEqual(@as(usize, 17424), try M.TlsCtrOmac.protectedLength(17408));
    try t.expectError(error.MessageTooLong, M.TlsCtrOmac.protectedLength(17409));
    inline for (.{ 0, 1, 15, 17, 31 }) |section| try t.expectError(error.InvalidSectionSize, M.CtrAcpkmOmac.init(C.init(enc_key), C.init(key), section));
    const password = try M.CtrAcpkmOmac.init(C.init(enc_key), C.init(key), 1024);
    try t.expectEqual(h.hex("0001020304050607"), M.CtrAcpkmOmac.nonceFromUkm(h.hex("000102030405060708090a0b0c0d0e0f")));
    try t.expectEqual(@as([8]u8, @splat(0)), M.TlsCtrOmac.recordIv(@splat(0xff), 1));
    try t.expectEqual(h.hex("0001020304050606"), M.TlsCtrOmac.recordIv(h.hex("0001020304050607"), std.math.maxInt(u64)));
    var bytes: [128]u8 = @splat(0xa5);
    const original = bytes;
    for (0..16) |len| {
        try t.expectError(error.InvalidLength, kexp.sealInPlace(nonce, bytes[0..len]));
        try t.expectError(error.InvalidLength, kexp.openInPlace(nonce, bytes[0..len]));
        try t.expectError(error.InvalidLength, tls0.sealInPlace(nonce, record0, bytes[0..len]));
        try t.expectError(error.InvalidLength, tls0.openInPlace(nonce, record0, bytes[0..len]));
        try t.expectError(error.InvalidLength, password.sealInPlace(nonce, bytes[0..len]));
        try t.expectError(error.InvalidLength, password.openInPlace(nonce, bytes[0..len]));
    }
    for (0..64) |start| {
        // Exact, forward partial and reverse partial overlap, at every byte.
        if (start < 48) {
            try t.expectError(error.InvalidOverlap, kexp.seal(nonce, bytes[start..][0..48], bytes[16..48]));
            try t.expectError(error.InvalidOverlap, tls0.seal(nonce, record0, bytes[start..][0..48], bytes[16..48]));
            try t.expectError(error.InvalidOverlap, password.seal(nonce, bytes[start..][0..48], bytes[16..48]));
        }
        if (start < 64) {
            try t.expectError(error.InvalidOverlap, kexp.open(nonce, bytes[start..][0..32], bytes[16..64]));
            try t.expectError(error.InvalidOverlap, tls0.open(nonce, record0, bytes[start..][0..32], bytes[16..64]));
            try t.expectError(error.InvalidOverlap, password.open(nonce, bytes[start..][0..32], bytes[16..64]));
        }
    }
    try t.expectError(error.InvalidLength, kexp.seal(nonce, bytes[0..47], bytes[64..96]));
    try t.expectError(error.InvalidLength, kexp.open(nonce, bytes[0..31], bytes[64..112]));
    try t.expectError(error.InvalidLength, password.seal(nonce, bytes[0..49], bytes[64..96]));
    try t.expectError(error.InvalidLength, password.open(nonce, bytes[0..33], bytes[64..112]));
    try t.expectEqual(original, bytes);
    // Adjacent input/output is legal in either address order.
    try kexp.seal(nonce, bytes[32..80], bytes[0..32]);
    try kexp.open(nonce, bytes[0..32], bytes[32..80]);
    try t.expectEqual(original[0..32].*, bytes[0..32].*);
    try password.seal(nonce, bytes[0..48], bytes[48..80]);
    try password.open(nonce, bytes[48..80], bytes[0..48]);
    var oversized: [17425]u8 = @splat(0xa5);
    try t.expectError(error.MessageTooLong, tls0.sealInPlace(nonce, record0, &oversized));
    try t.expectError(error.MessageTooLong, tls0.openInPlace(nonce, record0, &oversized));
    try t.expect(std.mem.allEqual(u8, &oversized, 0xa5));
}

// Models a smaller mode budget without constructing huge/invalid slices. The
// composition must preflight the expanded length (including the encrypted tag)
// before writing either in-place or caller-owned out-of-place buffers.
const BudgetCtr = struct {
    inner: classic.Ctr,
    pub fn init(cipher: C, iv: [8]u8, _: usize) error{InvalidSectionSize}!@This() {
        return .{ .inner = classic.Ctr.init(cipher, iv) };
    }
    pub fn validate(_: *const @This(), length: usize) error{CounterExhausted}!void {
        if (length > 31) return error.CounterExhausted;
    }
    pub fn xor(self: *@This(), data: []u8) !void {
        try self.inner.xor(data);
    }
};
test "expanded mode budget and immutable cipher configuration are checked before writes" {
    const P = composition.PasswordComposition(C, classic, BudgetCtr);
    const mode = try P.init(C.init(enc_key), C.init(key), 1024);
    var output: [32]u8 = @splat(0xa5);
    const source: [16]u8 = @splat(7);
    try t.expectError(error.CounterExhausted, mode.seal(nonce, &output, &source));
    try t.expect(std.mem.allEqual(u8, &output, 0xa5));
    try t.expectError(error.CounterExhausted, mode.sealInPlace(nonce, &output));
    try t.expectError(error.CounterExhausted, mode.openInPlace(nonce, &output));
    var plain: [16]u8 = @splat(0xa5);
    try t.expectError(error.CounterExhausted, mode.open(nonce, &plain, &output));
    try t.expect(std.mem.allEqual(u8, &output, 0xa5));
    try t.expect(std.mem.allEqual(u8, &plain, 0xa5));
    var mutable = kexp;
    const saved = mutable;
    try t.expectError(error.InvalidOverlap, mutable.sealInPlace(nonce, std.mem.asBytes(&mutable)[0..32]));
    try t.expectError(error.InvalidOverlap, mutable.openInPlace(nonce, std.mem.asBytes(&mutable)[0..32]));
    try t.expectEqualSlices(u8, std.mem.asBytes(&saved), std.mem.asBytes(&mutable));
}

test "composition altered nonce keys section truncation extension preserve caller outputs" {
    var ciphertext: [1089]u8 = @splat(9);
    var output: [1073]u8 = @splat(0xa5);
    const password = try M.CtrAcpkmOmac.init(C.init(enc_key), C.init(key), 1024);
    try password.sealInPlace(nonce, &ciphertext);
    const saved = ciphertext;
    var wrong_nonce = nonce;
    wrong_nonce[7] ^= 1;
    try t.expectError(error.AuthenticationFailed, password.open(wrong_nonce, &output, &ciphertext));
    try t.expectError(error.AuthenticationFailed, password.openInPlace(wrong_nonce, &ciphertext));
    const wrong_section = try M.CtrAcpkmOmac.init(C.init(enc_key), C.init(key), 4096);
    try t.expectError(error.AuthenticationFailed, wrong_section.open(nonce, &output, &ciphertext));
    try t.expectError(error.AuthenticationFailed, wrong_section.openInPlace(nonce, &ciphertext));
    inline for (.{ false, true }) |wrong_enc| {
        const wrong = try M.CtrAcpkmOmac.init(C.init(if (wrong_enc) key else enc_key), C.init(if (wrong_enc) key else enc_key), 1024);
        try t.expectError(error.AuthenticationFailed, wrong.open(nonce, &output, &ciphertext));
        try t.expectError(error.AuthenticationFailed, wrong.openInPlace(nonce, &ciphertext));
    }
    try t.expectEqual(saved, ciphertext);
    try t.expect(std.mem.allEqual(u8, &output, 0xa5));
    try tls0.sealInPlace(nonce, record0, &ciphertext);
    const tls_saved = ciphertext;
    try t.expectError(error.AuthenticationFailed, tls0.open(wrong_nonce, record0, &output, &ciphertext));
    inline for (.{ false, true }) |wrong_enc| {
        const wrong = M.TlsCtrOmac.init(C.init(if (wrong_enc) tls_enc_64 else tls_enc_0), C.init(if (wrong_enc) tls_mac_0 else tls_mac_64));
        try t.expectError(error.AuthenticationFailed, wrong.open(nonce, record0, &output, &ciphertext));
        try t.expectError(error.AuthenticationFailed, wrong.openInPlace(nonce, record0, &ciphertext));
    }
    try t.expectEqual(tls_saved, ciphertext);
    try t.expect(std.mem.allEqual(u8, &output, 0xa5));

    // All three fixed-tag constructions reject removal of 1..16 octets or
    // appending 1..16 octets, including buffers whose total size remains >=16.
    const fixtures = @import("composition_oracle.zig");
    var extended: [65]u8 = undefined;
    var plain: [49]u8 = undefined;
    for (fixtures.cases) |case| {
        if (case.length != 33) continue;
        const expected = fixtures.data[case.offset..][0..case.size];
        for (1..17) |delta| {
            for ([_]usize{ case.size - delta, case.size + delta }) |size| {
                @memset(&extended, 0x5a);
                @memcpy(extended[0..case.size], expected);
                const before = extended;
                @memset(&plain, 0xa5);
                try t.expectError(error.AuthenticationFailed, fixtureOpen(case.kind, case.section, plain[0 .. size - 16], extended[0..size]));
                try t.expectError(error.AuthenticationFailed, fixtureInPlace(case.kind, case.section, extended[0..size], false));
                try t.expectEqual(before, extended);
                try t.expect(std.mem.allEqual(u8, &plain, 0xa5));
            }
        }
    }
}
