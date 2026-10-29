//! RFC 9367 / RFC 9227 Kuznyechik cipher-layer profiles. All ciphers passed
//! here MUST already hold the externally derived record/KTREE leaf key.
//! No KDF, handshake, replay window, packet parser or key lifetime state.
const std = @import("std");
const raw = @import("mgm.zig");

pub const TlsVariant = enum { l, s };

/// ESP sequence values are serialized in network order. ESN authenticates the
/// complete 64-bit value (high word before low word), not just the wire word.
pub const EspSequence = union(enum) { sn: u32, esn: u64 };
pub const EspHeader = struct {
    spi: u32,
    sequence: EspSequence,

    pub fn encode(self: EspHeader, out: *[12]u8) []const u8 {
        std.mem.writeInt(u32, out[0..4], self.spi, .big);
        switch (self.sequence) {
            .sn => |n| {
                std.mem.writeInt(u32, out[4..8], n, .big);
                return out[0..8];
            },
            .esn => |n| {
                std.mem.writeInt(u64, out[4..12], n, .big);
                return out;
            },
        }
    }
};

/// RFC 9227 section 4.2. Bounds are checked before narrowing pnum.
pub const KtreeIv = struct {
    i1: u8,
    i2: u16,
    i3: u16,
    pnum: u32,

    pub fn encode(self: KtreeIv) ![8]u8 {
        if (self.pnum > 0xffffff) return error.MessageCounterExhausted;
        var iv: [8]u8 = undefined;
        iv[0] = self.i1;
        std.mem.writeInt(u16, iv[1..3], self.i2, .big);
        std.mem.writeInt(u16, iv[3..5], self.i3, .big);
        std.mem.writeInt(u24, iv[5..8], @intCast(self.pnum), .big);
        return iv;
    }

    pub fn decode(iv: [8]u8) KtreeIv {
        return .{ .i1 = iv[0], .i2 = std.mem.readInt(u16, iv[1..3], .big), .i3 = std.mem.readInt(u16, iv[3..5], .big), .pnum = std.mem.readInt(u24, iv[5..8], .big) };
    }

    pub fn nonce(self: KtreeIv, salt: [12]u8) ![16]u8 {
        const iv = try self.encode();
        return .{0} ++ iv[5..8].* ++ salt;
    }

    /// Exact seeds for the external three-level HMAC-Streebog KDF, paired
    /// with ASCII labels "level1", "level2", "level3" (no NUL).
    pub fn seeds(self: KtreeIv) ![3][2]u8 {
        const iv = try self.encode();
        return .{ .{ 0, self.i1 }, iv[1..3].*, iv[3..5].* };
    }
};

/// Split a 44-octet transform key; root_key MUST NOT be used as a leaf key.
pub const KtreeKeyMaterial = struct {
    root_key: [32]u8,
    salt: [12]u8,
    pub fn split(material: [44]u8) KtreeKeyMaterial {
        return .{ .root_key = material[0..32].*, .salt = material[32..44].* };
    }
};

/// Complete, ordered IKEv2 authenticated prefix, excluding the IV. The caller
/// supplies correctly framed fields, including final wire lengths. Fragment
/// headers include Fragment Number and Total Fragments (RFC 7383).
pub const IkeAad = struct {
    header: [28]u8,
    unencrypted_payloads: []const u8 = &.{},
    encrypted_header: union(enum) { payload: [4]u8, fragment: [8]u8 },

    fn tail(self: *const IkeAad) []const u8 {
        return switch (self.encrypted_header) {
            .payload => |*h| h,
            .fragment => |*h| h,
        };
    }
    pub fn length(self: *const IkeAad) !usize {
        const n = @as(u128, 28) + self.unencrypted_payloads.len + self.tail().len;
        if (n > 65536) return error.MessageTooLong;
        return @intCast(n);
    }
};

pub fn Profiles(comptime Cipher: type) type {
    return struct {
        pub const Tls13MgmL = Tls13Mgm(Cipher, .l);
        pub const Tls13MgmS = Tls13Mgm(Cipher, .s);
        pub const EspMgmKtree = EspMgm(Cipher, false);
        pub const EspMgmMacKtree = EspMgm(Cipher, true);
        pub const IkeMgmKtree = IkeMgm(Cipher);
    };
}

pub fn Tls13Mgm(comptime Cipher: type, comptime variant: TlsVariant) type {
    return struct {
        const M = raw.Mgm(Cipher);
        pub const tag_length = 16;
        pub const max_sequence: u64 = if (variant == .l) std.math.maxInt(u64) else (1 << 42) - 1;
        pub const max_plaintext = 16385;
        pub const tree_masks: [3]u64 = if (variant == .l)
            .{ 0xf800000000000000, 0xfffffff000000000, 0xffffffffffffe000 }
        else
            .{ 0xffffffffe0000000, 0xffffffffffff0000, 0xfffffffffffffff8 };

        pub fn validate(sequence: u64, plaintext_len: usize) !void {
            if (sequence > max_sequence) return error.SequenceExhausted;
            if (plaintext_len == 0) return error.InvalidLength;
            if (plaintext_len > max_plaintext) return error.MessageTooLong;
        }

        /// XOR a zero-padded big-endian sequence into the full write IV, then
        /// mask the top bit as required by RFC 9367 section 4.1.1.
        pub fn nonce(write_iv: [16]u8, sequence: u64) ![16]u8 {
            if (sequence > max_sequence) return error.SequenceExhausted;
            var result = write_iv;
            var seq: [8]u8 = undefined;
            std.mem.writeInt(u64, &seq, sequence, .big);
            for (result[8..], seq) |*b, s| b.* ^= s;
            result[0] &= 0x7f;
            return result;
        }

        pub fn seeds(sequence: u64) ![3][8]u8 {
            if (sequence > max_sequence) return error.SequenceExhausted;
            var result: [3][8]u8 = undefined;
            for (&result, tree_masks) |*seed, mask| std.mem.writeInt(u64, seed, sequence & mask, .big);
            return result;
        }

        pub fn header(plaintext_len: usize) ![5]u8 {
            try validate(0, plaintext_len);
            var result = [5]u8{ 23, 3, 3, 0, 0 };
            std.mem.writeInt(u16, result[3..5], @intCast(plaintext_len + tag_length), .big);
            return result;
        }

        /// data is the complete TLSInnerPlaintext, including type and padding.
        pub fn seal(cipher: *const Cipher, write_iv: [16]u8, sequence: u64, data: []u8) ![16]u8 {
            try validate(sequence, data.len);
            try writable(Cipher, cipher, data);
            return M.seal(cipher, try nonce(write_iv, sequence), &try header(data.len), data);
        }
        pub fn open(cipher: *const Cipher, write_iv: [16]u8, sequence: u64, data: []u8, tag: []const u8) !void {
            if (tag.len != tag_length) return error.InvalidTagLength;
            try validate(sequence, data.len);
            try writable(Cipher, cipher, data);
            try M.openDetached(cipher, try nonce(write_iv, sequence), &try header(data.len), data, tag);
        }
    };
}

fn EspMgm(comptime Cipher: type, comptime mac_only: bool) type {
    return struct {
        const M = raw.Mgm(Cipher);
        pub const tag_length = 12;

        /// Bounds the ESP portion (8-byte wire header, IV, body, ICV), excluding
        /// outer IP headers. ESN's high word is authenticated but not on wire.
        /// The caller additionally checks the complete network datagram size.
        pub fn validateLength(body_len: usize) !void {
            try wireLength(8, body_len);
        }
        pub const seal = if (mac_only) mac else encrypt;
        pub const open = if (mac_only) verify else decrypt;

        fn encrypt(cipher: *const Cipher, salt: [12]u8, iv: KtreeIv, esp: EspHeader, data: []u8) ![12]u8 {
            try validateLength(data.len);
            const n = try iv.nonce(salt);
            try writable(Cipher, cipher, data);
            var prefix: [12]u8 = undefined;
            const tag = try M.seal(cipher, n, esp.encode(&prefix), data);
            return tag[0..12].*;
        }
        fn decrypt(cipher: *const Cipher, salt: [12]u8, iv: KtreeIv, esp: EspHeader, data: []u8, tag: []const u8) !void {
            if (tag.len != tag_length) return error.InvalidTagLength;
            try validateLength(data.len);
            const n = try iv.nonce(salt);
            try writable(Cipher, cipher, data);
            var prefix: [12]u8 = undefined;
            try M.openDetached(cipher, n, esp.encode(&prefix), data, tag);
        }
        /// Authentication-only: the complete ESP body, including caller-made
        /// padding, Pad Length and Next Header, is AAD. It is never modified.
        fn mac(cipher: *const Cipher, salt: [12]u8, iv: KtreeIv, esp: EspHeader, body: []const u8) ![12]u8 {
            try validateLength(body.len);
            const n = try iv.nonce(salt);
            var prefix: [12]u8 = undefined;
            const encoded = try iv.encode();
            var empty: [0]u8 = .{};
            const tag = try M.sealParts(cipher, n, &.{ esp.encode(&prefix), &encoded, body }, &empty);
            return tag[0..12].*;
        }
        fn verify(cipher: *const Cipher, salt: [12]u8, iv: KtreeIv, esp: EspHeader, body: []const u8, tag: []const u8) !void {
            if (tag.len != tag_length) return error.InvalidTagLength;
            try validateLength(body.len);
            const n = try iv.nonce(salt);
            var prefix: [12]u8 = undefined;
            const encoded = try iv.encode();
            var empty: [0]u8 = .{};
            try M.openParts(cipher, n, &.{ esp.encode(&prefix), &encoded, body }, &empty, tag);
        }
    };
}

fn IkeMgm(comptime Cipher: type) type {
    return struct {
        const M = raw.Mgm(Cipher);
        pub const tag_length = 12;
        pub fn validateLengths(aad_len: usize, data_len: usize) !void {
            try wireLength(aad_len, data_len);
        }
        pub fn seal(cipher: *const Cipher, salt: [12]u8, iv: KtreeIv, aad: IkeAad, data: []u8) ![12]u8 {
            try validateLengths(try aad.length(), data.len);
            const n = try iv.nonce(salt);
            try writable(Cipher, cipher, data);
            const tag = try M.sealParts(cipher, n, &.{ &aad.header, aad.unencrypted_payloads, aad.tail() }, data);
            return tag[0..12].*;
        }
        pub fn open(cipher: *const Cipher, salt: [12]u8, iv: KtreeIv, aad: IkeAad, data: []u8, tag: []const u8) !void {
            if (tag.len != tag_length) return error.InvalidTagLength;
            try validateLengths(try aad.length(), data.len);
            const n = try iv.nonce(salt);
            try writable(Cipher, cipher, data);
            try M.openParts(cipher, n, &.{ &aad.header, aad.unencrypted_payloads, aad.tail() }, data, tag);
        }
    };
}

// Full IKE message / ESP extent includes AAD on wire, the 8-byte IV, payload,
// and 12-byte ICV. Use wide arithmetic for synthetic length checks.
fn wireLength(aad_len: usize, data_len: usize) !void {
    if (@as(u128, aad_len) + data_len + 8 + 12 > 65536) return error.MessageTooLong;
}
fn writable(comptime C: type, cipher: *const C, data: []u8) !void {
    if (overlaps(std.mem.asBytes(cipher), data)) return error.InvalidOverlap;
}

fn overlaps(a: []const u8, b: []const u8) bool {
    if (a.len == 0 or b.len == 0) return false;
    const x = @intFromPtr(a.ptr);
    const y = @intFromPtr(b.ptr);
    return if (x <= y) y - x < a.len else x - y < b.len;
}

test {
    _ = @import("mgm_profiles_test.zig");
}
