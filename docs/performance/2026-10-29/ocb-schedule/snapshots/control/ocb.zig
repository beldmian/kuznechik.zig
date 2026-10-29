//! RFC7253 (OCB3), byte strings, generic 128-bit block cipher and inverse.
//! Ocb defaults to tag16; OcbWithTag fixes a tag of 1..16 bytes in the type.
//! Generic RFC section4 nonces have 0..15 bytes. The named AES profiles in
//! section3.1 restrict this to 1..15; they do not register a Kuznechik profile.
//! Nonces MUST be unique for encryption under a key. Keep one tag length per
//! key, and account for the RFC section5 lifetime budget (2^48 blocks including
//! AAD) externally. validate enforces that same budget on each call, counting
//! ceil(AAD/16)+ceil(payload/16); it cannot track use of a key across messages.
//!
//! Cipher must provide encrypt/decrypt(*align(16) @Vector(16,u8)) and
//! encryptBlocks/decryptBlocks([]align(16) @Vector(16,u8)). No allocator or
//! message-sized storage: independent work uses at most64 blocks per batch.
//! Payload may be unaligned. Writable data must not overlap AAD, nonce, tag,
//! or Cipher storage. A seal tag must also be disjoint from all read inputs.
//! Read-only inputs may overlap each other on open. Empty and adjacent slices
//! are permitted. All dimensions and aliases are checked before writes.
//! Opening authenticates private plaintext, then decrypts again into data;
//! authentication failure leaves the ciphertext untouched. The caller must
//! prevent concurrent mutation of inputs between the two passes.
//! This is a generic Kuznechik instantiation, not an AES registry assignment.
const std = @import("std");
const B = @Vector(16, u8);

fn overlaps(a: []const u8, b: []const u8) bool {
    if (a.len == 0 or b.len == 0) return false;
    const x = @intFromPtr(a.ptr);
    const y = @intFromPtr(b.ptr);
    return if (x <= y) y - x < a.len else x - y < b.len;
}

fn double(value: B) B {
    const bytes: [16]u8 = value;
    var out: [16]u8 = undefined;
    for (0..15) |i| out[i] = (bytes[i] << 1) | (bytes[i + 1] >> 7);
    out[15] = (bytes[15] << 1) ^ ((0 -% (bytes[0] >> 7)) & 0x87);
    return out;
}

pub fn Ocb(comptime Cipher: type) type {
    return OcbWithTag(Cipher, 16);
}

pub fn OcbWithTag(comptime Cipher: type, comptime tag_bytes: usize) type {
    if (tag_bytes < 1 or tag_bytes > 16) @compileError("OCB tag must have 1..16 bytes");
    return struct {
        pub const Tag = [tag_bytes]u8;
        pub const tag_length = tag_bytes;
        pub const max_blocks = @as(u64, 1) << 48;
        const Schedule = struct {
            star: B,
            dollar: B,
            // ntz(2^48) ==48, so the inclusive limit needs L_48.
            l: [49]B,
            fn init(cipher: *const Cipher) @This() {
                var s: @This() = undefined;
                s.star = @splat(0);
                cipher.encrypt(&s.star);
                s.dollar = double(s.star);
                s.l[0] = double(s.dollar);
                for (1..s.l.len) |i| s.l[i] = double(s.l[i - 1]);
                return s;
            }
        };
        pub fn validate(nonce_len: usize, aad_len: usize, data_len: usize, tag_len: usize) !void {
            if (nonce_len > 15) return error.InvalidNonceLength;
            if (tag_len != tag_bytes) return error.InvalidTagLength;
            const a = @as(u128, aad_len) / 16 + @intFromBool(aad_len % 16 != 0);
            const p = @as(u128, data_len) / 16 + @intFromBool(data_len % 16 != 0);
            if (a + p > max_blocks) return error.MessageTooLong;
        }
        fn validateAliases(cipher: *const Cipher, nonce: []const u8, aad: []const u8, data: []u8, tag: []const u8, comptime sealing: bool) !void {
            const key_storage = std.mem.asBytes(cipher);
            if (overlaps(data, aad) or overlaps(data, nonce) or overlaps(data, tag) or overlaps(data, key_storage)) return error.InvalidOverlap;
            if (sealing and (overlaps(tag, aad) or overlaps(tag, nonce) or overlaps(tag, key_storage))) return error.InvalidOverlap;
        }
        fn initialOffset(cipher: *const Cipher, nonce: []const u8) B {
            var formatted: [16]u8 = @splat(0);
            formatted[0] = @intCast((tag_bytes * 8 % 128) << 1);
            formatted[15 - nonce.len] |= 1;
            @memcpy(formatted[16 - nonce.len ..], nonce);
            const bottom = formatted[15] & 63;
            formatted[15] &= 0xc0;
            var ktop: B = formatted;
            cipher.encrypt(&ktop);
            var stretch: [24]u8 = undefined;
            stretch[0..16].* = ktop;
            for (0..8) |i| stretch[16 + i] = stretch[i] ^ stretch[i + 1];
            var offset: [16]u8 = undefined;
            const byte: usize = bottom / 8;
            const shift: u3 = @intCast(bottom % 8);
            for (&offset, 0..) |*v, i| {
                v.* = stretch[byte + i] << shift;
                if (shift != 0) v.* |= stretch[byte + i + 1] >> @as(u3, @intCast(8 - @as(u4, shift)));
            }
            return offset;
        }
        fn hash(cipher: *const Cipher, s: *const Schedule, aad: []const u8) B {
            var sum: B = @splat(0);
            var offset: B = @splat(0);
            var at: usize = 0;
            while (aad.len - at >= 16) {
                const count: usize = @min(64, (aad.len - at) / 16);
                var blocks: [64]B = undefined;
                for (0..count) |i| {
                    offset ^= s.l[@ctz(at / 16 + i + 1)];
                    blocks[i] = @as(B, aad[at + i * 16 ..][0..16].*) ^ offset;
                }
                cipher.encryptBlocks(blocks[0..count]);
                for (blocks[0..count]) |b| sum ^= b;
                at += count * 16;
            }
            if (at != aad.len) {
                const tail = aad.len - at;
                var padded: [16]u8 = @splat(0);
                @memcpy(padded[0..tail], aad[at..]);
                padded[tail] = 0x80;
                var b = @as(B, padded) ^ offset ^ s.star;
                cipher.encrypt(&b);
                sum ^= b;
            }
            return sum;
        }
        const Direction = enum { seal, verify, open };
        const Result = struct { offset: B, checksum: B };
        fn payload(cipher: *const Cipher, s: *const Schedule, initial: B, data: []u8, comptime direction: Direction) Result {
            var offset = initial;
            var checksum: B = @splat(0);
            var at: usize = 0;
            while (data.len - at >= 16) {
                const count: usize = @min(64, (data.len - at) / 16);
                var blocks: [64]B = undefined;
                var offsets: [64]B = undefined;
                for (0..count) |i| {
                    offset ^= s.l[@ctz(at / 16 + i + 1)];
                    offsets[i] = offset;
                    const input: B = data[at + i * 16 ..][0..16].*;
                    if (direction == .seal) checksum ^= input;
                    blocks[i] = input ^ offset;
                }
                if (direction == .seal) cipher.encryptBlocks(blocks[0..count]) else cipher.decryptBlocks(blocks[0..count]);
                for (0..count) |i| {
                    const output = blocks[i] ^ offsets[i];
                    if (direction == .verify) checksum ^= output;
                    if (direction != .verify) data[at + i * 16 ..][0..16].* = output;
                }
                // Private plaintext from the verify pass does not escape.
                if (direction == .verify) std.crypto.secureZero(u8, std.mem.asBytes(&blocks));
                at += count * 16;
            }
            if (at != data.len) {
                offset ^= s.star;
                var pad = offset;
                cipher.encrypt(&pad);
                const pad_bytes: [16]u8 = pad;
                var plain: [16]u8 = @splat(0);
                for (data[at..], 0..) |*v, i| {
                    plain[i] = if (direction == .seal) v.* else v.* ^ pad_bytes[i];
                    if (direction != .verify) v.* ^= pad_bytes[i];
                }
                plain[data.len - at] = 0x80;
                if (direction != .open) checksum ^= @as(B, plain);
                std.crypto.secureZero(u8, &plain);
            }
            return .{ .offset = offset, .checksum = checksum };
        }
        fn finish(cipher: *const Cipher, s: *const Schedule, result: Result, aad_hash: B) Tag {
            var raw = result.checksum ^ result.offset ^ s.dollar;
            cipher.encrypt(&raw);
            const bytes: [16]u8 = raw ^ aad_hash;
            return bytes[0..tag_bytes].*;
        }
        pub fn seal(cipher: *const Cipher, nonce: []const u8, aad: []const u8, data: []u8) !Tag {
            var tag: Tag = undefined;
            try sealDetached(cipher, nonce, aad, data, &tag);
            return tag;
        }
        pub fn sealDetached(cipher: *const Cipher, nonce: []const u8, aad: []const u8, data: []u8, tag: []u8) !void {
            try validate(nonce.len, aad.len, data.len, tag.len);
            try validateAliases(cipher, nonce, aad, data, tag, true);
            const s = Schedule.init(cipher);
            const aad_hash = hash(cipher, &s, aad);
            const result = payload(cipher, &s, initialOffset(cipher, nonce), data, .seal);
            tag[0..tag_bytes].* = finish(cipher, &s, result, aad_hash);
        }
        pub fn open(cipher: *const Cipher, nonce: []const u8, aad: []const u8, data: []u8, tag: Tag) !void {
            try openDetached(cipher, nonce, aad, data, &tag);
        }
        pub fn openDetached(cipher: *const Cipher, nonce: []const u8, aad: []const u8, data: []u8, tag: []const u8) !void {
            try validate(nonce.len, aad.len, data.len, tag.len);
            try validateAliases(cipher, nonce, aad, data, tag, false);
            const s = Schedule.init(cipher);
            const initial = initialOffset(cipher, nonce);
            const result = payload(cipher, &s, initial, data, .verify);
            const expected = finish(cipher, &s, result, hash(cipher, &s, aad));
            if (!std.crypto.timing_safe.eql(Tag, expected, tag[0..tag_bytes].*)) return error.AuthenticationFailed;
            _ = payload(cipher, &s, initial, data, .open);
        }
    };
}

test {
    _ = @import("ocb_test.zig");
}
