//! RFC 9189 KExp15/KImp15 and TLS CTR_OMAC; RFC 9337 CTR-ACPKM-OMAC.
//! These are MAC-then-encrypt constructions with a fixed encrypted 16-byte tag.
//! Cipher must have 128-bit blocks and a 256-bit key. init receives independent,
//! already derived ENC and MAC ciphers. Key derivation and protocol state are
//! the caller's responsibility; see docs/composition-notes.md.
//! All byte buffers may be unaligned. Out-of-place buffers must be disjoint;
//! use the explicit InPlace methods for a shared buffer. All failures preserve
//! every caller buffer. No allocation is performed. Opening verifies private
//! batches before a second pass releases plaintext. It leaves the encrypted tag
//! suffix intact in the InPlace buffer and returns only the plaintext slice.
const std = @import("std");
pub const Error = error{ InvalidLength, InvalidOverlap, InvalidSectionSize, MessageTooLong, CounterExhausted, AuthenticationFailed };
pub const tag_length = 16;
pub const Nonce = [8]u8;

fn overlaps(a: []const u8, b: []const u8) bool {
    if (a.len == 0 or b.len == 0) return false;
    const x = @intFromPtr(a.ptr);
    const y = @intFromPtr(b.ptr);
    return if (x <= y) y - x < a.len else x - y < b.len;
}
fn cipherDimensions(comptime Cipher: type) void {
    const Key = @TypeOf(@as(Cipher, undefined).k);
    if (@typeInfo(Key).vector.len != 32) @compileError("these compositions require a 256-bit key and 128-bit blocks");
}

/// Root integration helper. Acpkm is the RFC8645 Modes(Cipher, Classic) family;
/// only its CtrAcpkm init(cipher, nonce8, section_bytes), validate(len), xor(data)
/// interface is needed. KExp15 can also be instantiated without ACPKM.
pub fn Modes(comptime Cipher: type, comptime Classic: type, comptime Acpkm: type) type {
    return struct {
        pub const KExp15 = KeyWrap(Cipher, Classic);
        pub const TlsCtrOmac = TlsRecord(Cipher, Classic, Acpkm.CtrAcpkm);
        pub const CtrAcpkmOmac = PasswordComposition(Cipher, Classic, Acpkm.CtrAcpkm);
    };
}

/// RFC9189 section8.2.1. Ordinary CTR, NOT CTR-ACPKM. IVs must be unique per
/// key pair. The full MAC authenticates IV || secret, including an empty secret.
pub fn KeyWrap(comptime Cipher: type, comptime Classic: type) type {
    const Engine = Core(Cipher, Classic, Classic.Ctr, false);
    return struct {
        const Self = @This();
        engine: Engine,
        pub const tag_bytes = tag_length;
        pub fn init(encryption: Cipher, authentication: Cipher) Self {
            return .{ .engine = .{ .encryption = encryption, .authentication = authentication } };
        }
        pub fn wrappedLength(secret_len: usize) Error!usize {
            return Engine.expandedLength(secret_len);
        }
        pub fn seal(self: *const Self, iv: Nonce, output: []u8, secret: []const u8) Error!void {
            try self.engine.seal(iv, &iv, output, secret);
        }
        pub fn open(self: *const Self, iv: Nonce, output: []u8, wrapped: []const u8) Error!void {
            try self.engine.open(iv, &iv, output, wrapped);
        }
        /// buffer = secret || 16 writable bytes; the complete buffer is encrypted.
        pub fn sealInPlace(self: *const Self, iv: Nonce, buffer: []u8) Error!void {
            try self.engine.sealInPlace(iv, &iv, buffer);
        }
        pub fn openInPlace(self: *const Self, iv: Nonce, buffer: []u8) Error![]u8 {
            return self.engine.openInPlace(iv, &iv, buffer);
        }
    };
}

/// Exact TLSCompressed metadata authenticated by RFC9189 section4.1.1.
/// Length is inferred from the plaintext, encoded as a big-endian u16. Version
/// and content type are authenticated verbatim; the TLS layer validates them.
pub const Record = struct {
    sequence: u64,
    content_type: u8,
    version: [2]u8 = .{ 3, 3 },
    fn prefix(self: Record, length: usize) Error![13]u8 {
        if (length > max_compressed_length) return error.MessageTooLong;
        var result: [13]u8 = undefined;
        std.mem.writeInt(u64, result[0..8], self.sequence, .big);
        result[8] = self.content_type;
        result[9..11].* = self.version;
        std.mem.writeInt(u16, result[11..13], @intCast(length), .big);
        return result;
    }
};
/// RFC5246 section6.2.2 bound on TLSCompressed.fragment, including compression
/// expansion. With null compression the TLS layer enforces the smaller 2^14.
pub const max_compressed_length = (1 << 14) + 1024;

/// RFC9189 sections4.1.1,4.3.2,4.3.3. Takes per-record TLSTREE-derived ENC/MAC
/// ciphers, not connection root keys. The section size is exactly 4096 bytes.
/// base_iv is sender_write_IV; nonce = (base_iv + sequence) mod 2^64 (big endian).
/// The returned ciphertext is TLSCiphertext.fragment; no 5-byte wire header is
/// read or written. This packet-specific API prevents arbitrary-AAD ambiguity.
pub fn TlsRecord(comptime Cipher: type, comptime Classic: type, comptime CtrAcpkm: type) type {
    const Engine = Core(Cipher, Classic, CtrAcpkm, true);
    return struct {
        const Self = @This();
        engine: Engine,
        pub const tag_bytes = tag_length;
        pub const section_bytes = 4096;
        pub fn init(encryption: Cipher, authentication: Cipher) Self {
            return .{ .engine = .{ .encryption = encryption, .authentication = authentication, .section_bytes = section_bytes } };
        }
        pub fn protectedLength(plaintext_len: usize) Error!usize {
            _ = try (Record{ .sequence = 0, .content_type = 0 }).prefix(plaintext_len);
            return Engine.expandedLength(plaintext_len);
        }
        pub fn recordIv(base_iv: Nonce, sequence: u64) Nonce {
            var iv: Nonce = undefined;
            std.mem.writeInt(u64, &iv, std.mem.readInt(u64, &base_iv, .big) +% sequence, .big);
            return iv;
        }
        pub fn seal(self: *const Self, base_iv: Nonce, record: Record, output: []u8, plaintext: []const u8) Error!void {
            const prefix = try record.prefix(plaintext.len);
            try self.engine.seal(recordIv(base_iv, record.sequence), &prefix, output, plaintext);
        }
        pub fn open(self: *const Self, base_iv: Nonce, record: Record, output: []u8, ciphertext: []const u8) Error!void {
            const length = try Engine.plaintextLength(ciphertext.len);
            const prefix = try record.prefix(length);
            try self.engine.open(recordIv(base_iv, record.sequence), &prefix, output, ciphertext);
        }
        pub fn sealInPlace(self: *const Self, base_iv: Nonce, record: Record, buffer: []u8) Error!void {
            const length = try Engine.plaintextLength(buffer.len);
            const prefix = try record.prefix(length);
            try self.engine.sealInPlace(recordIv(base_iv, record.sequence), &prefix, buffer);
        }
        pub fn openInPlace(self: *const Self, base_iv: Nonce, record: Record, buffer: []u8) Error![]u8 {
            const length = try Engine.plaintextLength(buffer.len);
            const prefix = try record.prefix(length);
            return self.engine.openInPlace(recordIv(base_iv, record.sequence), &prefix, buffer);
        }
    };
}

/// Cipher layer of RFC9337 sections5.1.1/5.1.2 (OMAC variant), NOT PBES2 itself.
/// Supply K(1) as encryption and K(2) as authentication, already independently
/// derived using KDF_TREE_GOSTR3411_2012_256(DK, "kdf tree", ukm[8..16], R=1).
/// nonce is ukm[0..8]. Only plaintext is MACed; the full tag is then encrypted
/// together with the plaintext. The protocol fixes section_bytes at init.
pub fn PasswordComposition(comptime Cipher: type, comptime Classic: type, comptime CtrAcpkm: type) type {
    const Engine = Core(Cipher, Classic, CtrAcpkm, true);
    return struct {
        const Self = @This();
        engine: Engine,
        pub const tag_bytes = tag_length;
        pub fn init(encryption: Cipher, authentication: Cipher, section_bytes: usize) Error!Self {
            if (section_bytes == 0 or section_bytes % 16 != 0) return error.InvalidSectionSize;
            return .{ .engine = .{ .encryption = encryption, .authentication = authentication, .section_bytes = section_bytes } };
        }
        pub fn nonceFromUkm(ukm: [16]u8) Nonce {
            return ukm[0..8].*;
        }
        pub fn protectedLength(plaintext_len: usize) Error!usize {
            return Engine.expandedLength(plaintext_len);
        }
        pub fn seal(self: *const Self, nonce: Nonce, output: []u8, plaintext: []const u8) Error!void {
            try self.engine.seal(nonce, &.{}, output, plaintext);
        }
        pub fn open(self: *const Self, nonce: Nonce, output: []u8, ciphertext: []const u8) Error!void {
            try self.engine.open(nonce, &.{}, output, ciphertext);
        }
        pub fn sealInPlace(self: *const Self, nonce: Nonce, buffer: []u8) Error!void {
            try self.engine.sealInPlace(nonce, &.{}, buffer);
        }
        pub fn openInPlace(self: *const Self, nonce: Nonce, buffer: []u8) Error![]u8 {
            return self.engine.openInPlace(nonce, &.{}, buffer);
        }
    };
}

// Shared mechanics only: each public construction supplies its exact MAC prefix.
fn Core(comptime Cipher: type, comptime Classic: type, comptime Stream: type, comptime acpkm: bool) type {
    cipherDimensions(Cipher);
    return struct {
        const Self = @This();
        encryption: Cipher,
        authentication: Cipher,
        section_bytes: usize = 0,
        fn expandedLength(length: usize) Error!usize {
            const total = std.math.add(usize, length, tag_length) catch return error.MessageTooLong;
            // Inherit the library's conservative ordinary-CTR / non-master
            // CTR-ACPKM half-counter budget. The encrypted tag consumes it too.
            const blocks = @as(u128, total) / 16 + @intFromBool(total % 16 != 0);
            if (blocks > (@as(u128, 1) << 63)) return error.CounterExhausted;
            return total;
        }
        fn plaintextLength(length: usize) Error!usize {
            if (length < tag_length) return error.InvalidLength;
            _ = try expandedLength(length - tag_length);
            return length - tag_length;
        }
        fn stream(self: *const Self, nonce: Nonce, total: usize) Error!Stream {
            if (acpkm) {
                const ctx = Stream.init(self.encryption, nonce, self.section_bytes) catch |err| switch (err) {
                    error.InvalidSectionSize => return error.InvalidSectionSize,
                    else => unreachable, // Non-master init only validates N.
                };
                ctx.validate(total) catch |err| switch (err) {
                    error.CounterExhausted => return error.CounterExhausted,
                    else => unreachable, // Non-master validate only checks the counter.
                };
                return ctx;
            }
            return Stream.init(self.encryption, nonce);
        }
        fn writable(self: *const Self, output: []u8) Error!void {
            if (overlaps(std.mem.asBytes(self), output)) return error.InvalidOverlap;
        }
        fn seal(self: *const Self, nonce: Nonce, prefix: []const u8, output: []u8, plaintext: []const u8) Error!void {
            if (output.len != try expandedLength(plaintext.len)) return error.InvalidLength;
            try self.writable(output);
            if (overlaps(output, plaintext)) return error.InvalidOverlap;
            var ctr = try self.stream(nonce, output.len);
            var mac = Classic.Cmac.init(self.authentication);
            mac.update(prefix);
            mac.update(plaintext);
            const tag = mac.final();
            @memcpy(output[0..plaintext.len], plaintext);
            output[plaintext.len..][0..16].* = tag;
            ctr.xor(output) catch unreachable; // Complete preflight above.
        }
        fn sealInPlace(self: *const Self, nonce: Nonce, prefix: []const u8, buffer: []u8) Error!void {
            const length = try plaintextLength(buffer.len);
            try self.writable(buffer);
            var ctr = try self.stream(nonce, buffer.len);
            var mac = Classic.Cmac.init(self.authentication);
            mac.update(prefix);
            mac.update(buffer[0..length]);
            buffer[length..][0..16].* = mac.final();
            ctr.xor(buffer) catch unreachable;
        }
        fn authenticate(self: *const Self, nonce: Nonce, prefix: []const u8, ciphertext: []const u8) Error!void {
            const length = try plaintextLength(ciphertext.len);
            var ctr = try self.stream(nonce, ciphertext.len);
            var mac = Classic.Cmac.init(self.authentication);
            mac.update(prefix);
            var scratch: [1024]u8 = undefined;
            defer std.crypto.secureZero(u8, &scratch);
            var at: usize = 0;
            while (at < length) {
                const n = @min(scratch.len, length - at);
                @memcpy(scratch[0..n], ciphertext[at..][0..n]);
                ctr.xor(scratch[0..n]) catch unreachable;
                mac.update(scratch[0..n]);
                at += n;
            }
            var received = ciphertext[length..][0..16].*;
            defer std.crypto.secureZero(u8, &received);
            ctr.xor(&received) catch unreachable;
            const expected = mac.final();
            if (!std.crypto.timing_safe.eql([16]u8, expected, received)) return error.AuthenticationFailed;
        }
        fn open(self: *const Self, nonce: Nonce, prefix: []const u8, output: []u8, ciphertext: []const u8) Error!void {
            const length = try plaintextLength(ciphertext.len);
            if (output.len != length) return error.InvalidLength;
            try self.writable(output);
            if (overlaps(output, ciphertext)) return error.InvalidOverlap;
            var ctr = try self.stream(nonce, ciphertext.len);
            try self.authenticate(nonce, prefix, ciphertext);
            @memcpy(output, ciphertext[0..length]);
            ctr.xor(output) catch unreachable;
        }
        fn openInPlace(self: *const Self, nonce: Nonce, prefix: []const u8, buffer: []u8) Error![]u8 {
            const length = try plaintextLength(buffer.len);
            try self.writable(buffer);
            var ctr = try self.stream(nonce, buffer.len);
            try self.authenticate(nonce, prefix, buffer);
            ctr.xor(buffer[0..length]) catch unreachable;
            return buffer[0..length];
        }
    };
}

test {
    _ = @import("composition_test.zig");
}
