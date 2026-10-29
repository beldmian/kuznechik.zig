//! RFC 8645 sections 6.2 and 6.3 for 128-bit block ciphers.
//! All section sizes N and master lifetimes T* in this API are BYTES, not bits.
//! N must be positive and divisible by 16. T* must be positive and divisible
//! by 16 and the section key material size (key bytes, or key bytes + 16 for
//! OMAC). Nonces must be unique per initial key; IV selection is the caller's
//! responsibility. CBC does not add padding. Contexts own expanded keys.
//! CTR supports byte-aligned 32..96-bit counters (64 by default); GCM supports
//! 32..64-bit counters. Non-master modes reserve the upper half of the counter
//! space; master modes use the full range, subject to the derivation budget.
//! Every fallible operation validates its complete input before writing data.
const std = @import("std");
const B = @Vector(16, u8);
pub const Error = error{ InvalidSectionSize, InvalidMasterLifetime, InvalidMaterialSize, InvalidLength, CounterExhausted, KeyMaterialExhausted, MessageTooLong, InvalidTagLength, AuthenticationFailed, InvalidOverlap };
const material_limit: u128 = @as(u128, 16) << 63;
fn sectionSize(bytes: usize) Error!void {
    if (bytes == 0 or bytes % 16 != 0) return error.InvalidSectionSize;
}
fn lifetimeSize(bytes: usize, material_bytes: usize) Error!void {
    if (material_bytes == 0) return error.InvalidMaterialSize;
    if (bytes == 0 or bytes % 16 != 0 or bytes % material_bytes != 0) return error.InvalidMasterLifetime;
}
fn sectionBudget(total: u128, section_bytes: usize, material_bytes: usize) Error!void {
    const sections = total / section_bytes + @intFromBool(total % section_bytes != 0);
    if (@max(1, sections) > material_limit / material_bytes) return error.KeyMaterialExhausted;
}
fn tagLength(length: usize) Error!void {
    // GCM's permitted byte-aligned tag sizes (SP 800-38D section 5.2.1.2).
    if (length != 4 and length != 8 and (length < 12 or length > 16)) return error.InvalidTagLength;
}
fn overlaps(a: []const u8, b: []const u8) bool {
    if (a.len == 0 or b.len == 0) return false;
    const ap = @intFromPtr(a.ptr);
    const bp = @intFromPtr(b.ptr);
    return if (ap <= bp) bp - ap < a.len else ap - bp < b.len;
}
fn verifyTag(full: [16]u8, tag: []const u8) Error!void {
    var expected: [16]u8 = @splat(0);
    var actual: [16]u8 = @splat(0);
    @memcpy(expected[0..tag.len], full[0..tag.len]);
    @memcpy(actual[0..tag.len], tag);
    if (!std.crypto.timing_safe.eql([16]u8, expected, actual)) return error.AuthenticationFailed;
}
fn doubled(value: B) B {
    var bytes: [16]u8 = value;
    const n = std.mem.readInt(u128, &bytes, .big);
    std.mem.writeInt(u128, &bytes, (n << 1) ^ (@as(u128, 0x87) * (n >> 127)), .big);
    return bytes;
}

pub fn Modes(comptime Cipher: type, comptime Classic: type) type {
    const Key = @TypeOf(@as(Cipher, undefined).k);
    const key_bytes = @typeInfo(Key).vector.len;
    if (key_bytes < 16 or key_bytes > 64) @compileError("RFC8645 requires a 128..512 bit key");
    return struct {
        /// ACPKM(K): encrypt 80..9f (and subsequent bytes for longer keys)
        /// under the current cipher and return the next expanded section key.
        pub fn acpkm(cipher: Cipher) Cipher {
            const count = (key_bytes + 15) / 16;
            var blocks: [count]B = undefined;
            for (&blocks, 0..) |*block, j| {
                var bytes: [16]u8 = undefined;
                for (&bytes, 0..) |*byte, i| byte.* = @intCast(0x80 + j * 16 + i);
                block.* = bytes;
            }
            cipher.encryptBlocks(&blocks);
            var key: [key_bytes]u8 = undefined;
            for (0..count) |j| {
                const bytes: [16]u8 = blocks[j];
                const n = @min(16, key_bytes - j * 16);
                @memcpy(key[j * 16 ..][0..n], bytes[0..n]);
            }
            return Cipher.init(key);
        }

        pub const CtrAcpkm = CtrAcpkmWithCounter(64);
        pub fn CtrAcpkmWithCounter(comptime counter_bits: u7) type {
            return CounterMode(false, counter_bits);
        }
        pub const CtrAcpkmMaster = CtrAcpkmMasterWithCounter(64);
        pub fn CtrAcpkmMasterWithCounter(comptime counter_bits: u7) type {
            return CounterMode(true, counter_bits);
        }

        /// Stateful ACPKM-Master(T*, K, d, l). derive() emits complete d-byte
        /// section materials in order, preserving partial cipher blocks (AES-192).
        pub const AcpkmMaster = struct {
            const Self = @This();
            stream: CtrAcpkm,
            material_bytes: usize,
            pub fn init(cipher: Cipher, lifetime_bytes: usize, material_bytes: usize) Error!Self {
                try lifetimeSize(lifetime_bytes, material_bytes);
                return .{ .stream = try CtrAcpkm.init(cipher, @splat(0xff), lifetime_bytes), .material_bytes = material_bytes };
            }
            pub fn derive(self: *Self, output: []u8) Error!void {
                if (output.len % self.material_bytes != 0) return error.InvalidLength;
                try self.stream.validate(output.len);
                @memset(output, 0);
                self.stream.xor(output) catch unreachable; // Same preflight, no intervening state change.
            }
        };

        fn SectionKeys(comptime master: bool, comptime material_bytes: usize) type {
            return struct {
                const Self = @This();
                cipher: Cipher,
                subkey: B = @splat(0),
                derivation: if (master) AcpkmMaster else void,
                fn init(cipher: Cipher, lifetime_bytes: usize) Error!Self {
                    var self = Self{ .cipher = cipher, .derivation = if (master) try AcpkmMaster.init(cipher, lifetime_bytes, material_bytes) else {} };
                    if (master) self.next();
                    return self;
                }
                fn next(self: *Self) void {
                    if (master) {
                        var bytes: [material_bytes]u8 = undefined;
                        // All callers preflight the complete message's section budget.
                        self.derivation.derive(&bytes) catch unreachable;
                        self.cipher = Cipher.init(bytes[0..key_bytes].*);
                        if (material_bytes > key_bytes) self.subkey = bytes[key_bytes..][0..16].*;
                    } else self.cipher = acpkm(self.cipher);
                }
            };
        }

        fn CounterMode(comptime master: bool, comptime counter_bits: u7) type {
            if (counter_bits < 32 or counter_bits > 96 or counter_bits % 8 != 0) @compileError("CTR-ACPKM counter must be 32..96 bits in whole bytes");
            return struct {
                const Self = @This();
                pub const Nonce = [(@as(usize, 128) - counter_bits) / 8]u8;
                keys: SectionKeys(master, key_bytes),
                section_bytes: usize,
                section_used: usize = 0,
                total: u128 = 0,
                prefix: u128,
                blocks: u128 = 0,
                stream: B = @splat(0),
                used: usize = 16,
                /// init(cipher, nonce, section_bytes) for ACPKM;
                /// init(cipher, nonce, section_bytes, lifetime_bytes) for Master.
                pub const init = if (master) initMaster else initPlain;
                fn initPlain(cipher: Cipher, nonce: Nonce, section_bytes: usize) Error!Self {
                    return setup(cipher, nonce, section_bytes, 0);
                }
                fn initMaster(cipher: Cipher, nonce: Nonce, section_bytes: usize, lifetime_bytes: usize) Error!Self {
                    return setup(cipher, nonce, section_bytes, lifetime_bytes);
                }
                fn setup(cipher: Cipher, nonce: Nonce, section_bytes: usize, lifetime_bytes: usize) Error!Self {
                    try sectionSize(section_bytes);
                    var prefix: [16]u8 = @splat(0);
                    @memcpy(prefix[0..nonce.len], &nonce);
                    return .{ .keys = try SectionKeys(master, key_bytes).init(cipher, lifetime_bytes), .section_bytes = section_bytes, .prefix = std.mem.readInt(u128, &prefix, .big) };
                }
                pub fn validate(self: *const Self, length: usize) Error!void {
                    const missing = length - @min(length, 16 - self.used);
                    const needed: u128 = @as(u128, missing) / 16 + @intFromBool(missing % 16 != 0);
                    const limit = @as(u128, 1) << (counter_bits - @as(u7, if (master) 0 else 1));
                    if (self.blocks > limit or needed > limit - self.blocks) return error.CounterExhausted;
                    if (master) {
                        const total = std.math.add(u128, self.total, length) catch return error.KeyMaterialExhausted;
                        try sectionBudget(total, self.section_bytes, key_bytes);
                    }
                }
                pub fn xor(self: *Self, data: []u8) Error!void {
                    try self.validate(data.len);
                    var at: usize = 0;
                    while (at < data.len) {
                        if (self.section_used == self.section_bytes) {
                            self.keys.next();
                            self.section_used = 0;
                        }
                        const remaining = @min(data.len - at, self.section_bytes - self.section_used);
                        if (self.used == 16 and remaining >= 16) {
                            const count: usize = @min(64, remaining / 16);
                            var counters: [64]B = undefined;
                            for (0..count) |j| {
                                var bytes: [16]u8 = undefined;
                                std.mem.writeInt(u128, &bytes, self.prefix | (self.blocks + j), .big);
                                counters[j] = bytes;
                            }
                            self.keys.cipher.encryptBlocks(counters[0..count]);
                            for (0..count) |j| {
                                const input: B = data[at + j * 16 ..][0..16].*;
                                data[at + j * 16 ..][0..16].* = input ^ counters[j];
                            }
                            self.blocks += count;
                            self.section_used += count * 16;
                            at += count * 16;
                        } else {
                            if (self.used == 16) {
                                var bytes: [16]u8 = undefined;
                                std.mem.writeInt(u128, &bytes, self.prefix | self.blocks, .big);
                                self.stream = bytes;
                                self.keys.cipher.encrypt(&self.stream);
                                self.blocks += 1;
                                self.used = 0;
                            }
                            const n = @min(remaining, 16 - self.used);
                            const bytes: [16]u8 = self.stream;
                            for (data[at..][0..n], bytes[self.used..][0..n]) |*byte, mask| byte.* ^= mask;
                            self.used += n;
                            self.section_used += n;
                            at += n;
                        }
                    }
                    self.total += data.len;
                }
            };
        }

        pub fn GcmAcpkm(comptime counter_bits: u7) type {
            return AuthenticatedMode(false, counter_bits);
        }
        pub fn GcmAcpkmMaster(comptime counter_bits: u7) type {
            return AuthenticatedMode(true, counter_bits);
        }
        fn AuthenticatedMode(comptime master: bool, comptime counter_bits: u7) type {
            if (counter_bits < 32 or counter_bits > 64 or counter_bits % 8 != 0) @compileError("GCM-ACPKM counter must be 32..64 bits in whole bytes");
            const Ctr = CounterMode(master, counter_bits);
            return struct {
                const Self = @This();
                pub const Nonce = Ctr.Nonce;
                /// Configuration is reusable for independent messages with unique nonces.
                initial: Cipher,
                section_bytes: usize,
                lifetime_bytes: usize,
                pub const init = if (master) initMaster else initPlain;
                fn initPlain(cipher: Cipher, section_bytes: usize) Error!Self {
                    return setup(cipher, section_bytes, 0);
                }
                fn initMaster(cipher: Cipher, section_bytes: usize, lifetime_bytes: usize) Error!Self {
                    return setup(cipher, section_bytes, lifetime_bytes);
                }
                fn setup(cipher: Cipher, section_bytes: usize, lifetime_bytes: usize) Error!Self {
                    try sectionSize(section_bytes);
                    if (master) try lifetimeSize(lifetime_bytes, key_bytes);
                    return .{ .initial = cipher, .section_bytes = section_bytes, .lifetime_bytes = lifetime_bytes };
                }
                pub fn validate(self: *const Self, aad_len: usize, data_len: usize) Error!void {
                    if (@as(u128, aad_len) * 8 > std.math.maxInt(u64) or @as(u128, data_len) * 8 > std.math.maxInt(u64)) return error.MessageTooLong;
                    const blocks = @as(u128, data_len) / 16 + @intFromBool(data_len % 16 != 0);
                    const limit = (@as(u128, 1) << (counter_bits - @as(u7, if (master) 0 else 1))) - 2;
                    if (blocks > limit) return error.MessageTooLong;
                    if (master) try sectionBudget(data_len, self.section_bytes, key_bytes);
                }
                fn counter(self: *const Self, nonce: Nonce) Error!Ctr {
                    var ctr = try Ctr.setup(self.initial, nonce, self.section_bytes, self.lifetime_bytes);
                    ctr.blocks = 2; // Payload starts at ICN || 2; section offsets start at zero.
                    return ctr;
                }
                /// seal(nonce, aad, in_place_plaintext) returns the full 16-byte tag.
                /// AAD and data must be disjoint; detached output tags must also be
                /// disjoint from both. Adjacent slices and empty slices are valid.
                pub fn seal(self: *const Self, nonce: Nonce, aad: []const u8, data: []u8) Error![16]u8 {
                    var tag: [16]u8 = undefined;
                    try self.sealDetached(nonce, aad, data, &tag);
                    return tag;
                }
                pub fn sealDetached(self: *const Self, nonce: Nonce, aad: []const u8, data: []u8, tag: []u8) Error!void {
                    try tagLength(tag.len);
                    try self.validate(aad.len, data.len);
                    if (overlaps(aad, data) or overlaps(tag, data) or overlaps(tag, aad)) return error.InvalidOverlap;
                    var ctr = try self.counter(nonce);
                    const authentication_cipher = ctr.keys.cipher;
                    try ctr.xor(data);
                    const full = authenticate(authentication_cipher, nonce, aad, data);
                    @memcpy(tag, full[0..tag.len]);
                }
                /// Authentication is checked before any plaintext is written.
                /// AAD and input tags must be disjoint from the data being opened.
                pub fn open(self: *const Self, nonce: Nonce, aad: []const u8, data: []u8, tag: [16]u8) Error!void {
                    try self.openDetached(nonce, aad, data, &tag);
                }
                pub fn openDetached(self: *const Self, nonce: Nonce, aad: []const u8, data: []u8, tag: []const u8) Error!void {
                    try tagLength(tag.len);
                    try self.validate(aad.len, data.len);
                    if (overlaps(aad, data) or overlaps(tag, data)) return error.InvalidOverlap;
                    var ctr = try self.counter(nonce);
                    try ctr.validate(data.len);
                    try verifyTag(authenticate(ctr.keys.cipher, nonce, aad, data), tag);
                    ctr.xor(data) catch unreachable;
                }
                // Use the initial section key for H and the mask throughout the message.
                // A local hash routine permits Master's full counter range; plain GCM's
                // public validate() deliberately enforces the narrower non-master bound.
                fn authenticate(cipher: Cipher, nonce: Nonce, aad: []const u8, ciphertext: []const u8) [16]u8 {
                    var h: B = @splat(0);
                    cipher.encrypt(&h);
                    const hash_key: [16]u8 = h;
                    const count = aad.len / 16 + @intFromBool(aad.len % 16 != 0) + ciphertext.len / 16 + @intFromBool(ciphertext.len % 16 != 0) + 1;
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
            };
        }

        pub const CbcAcpkmMaster = FeedbackMaster(true);
        pub const CfbAcpkmMaster = FeedbackMaster(false);
        fn FeedbackMaster(comptime cbc: bool) type {
            const Base = if (cbc) Classic.Cbc(1) else Classic.Cfb(1);
            return struct {
                const Self = @This();
                keys: SectionKeys(true, key_bytes),
                base: Base,
                section_bytes: usize,
                section_used: usize = 0,
                total: u128 = 0,
                /// init(master_cipher, iv16, section_bytes, lifetime_bytes).
                pub fn init(cipher: Cipher, iv: [16]u8, section_bytes: usize, lifetime_bytes: usize) Error!Self {
                    try sectionSize(section_bytes);
                    const keys = try SectionKeys(true, key_bytes).init(cipher, lifetime_bytes);
                    return .{ .keys = keys, .base = Base.init(keys.cipher, iv), .section_bytes = section_bytes };
                }
                pub fn validate(self: *const Self, length: usize) Error!void {
                    if (cbc and length % 16 != 0) return error.InvalidLength;
                    const total = std.math.add(u128, self.total, length) catch return error.KeyMaterialExhausted;
                    try sectionBudget(total, self.section_bytes, key_bytes);
                }
                pub fn encrypt(self: *Self, data: []u8) Error!void {
                    try self.crypt(false, data);
                }
                pub fn decrypt(self: *Self, data: []u8) Error!void {
                    try self.crypt(true, data);
                }
                fn crypt(self: *Self, comptime inverse: bool, data: []u8) Error!void {
                    try self.validate(data.len);
                    var at: usize = 0;
                    while (at < data.len) {
                        if (self.section_used == self.section_bytes) {
                            self.keys.next();
                            self.base.cipher = self.keys.cipher;
                            self.section_used = 0;
                        }
                        const n = @min(data.len - at, self.section_bytes - self.section_used);
                        if (cbc) {
                            if (inverse) try self.base.decrypt(data[at..][0..n]) else try self.base.encrypt(data[at..][0..n]);
                        } else {
                            if (inverse) {
                                self.base.decrypt(data[at..][0..n]);
                            } else {
                                // A full CFB block is one dependent encryption and one vector
                                // xor. Preserve Classic's partial-block state for chunked calls.
                                var done: usize = 0;
                                if (self.base.used == 16) {
                                    while (n - done >= 16) : (done += 16) {
                                        var gamma = self.base.register[0];
                                        self.base.cipher.encrypt(&gamma);
                                        const block = @as(B, data[at + done ..][0..16].*) ^ gamma;
                                        data[at + done ..][0..16].* = block;
                                        self.base.register[0] = block;
                                        self.base.stream = gamma;
                                        self.base.feedback = block;
                                    }
                                }
                                self.base.encrypt(data[at + done ..][0 .. n - done]);
                            }
                        }
                        self.section_used += n;
                        at += n;
                    }
                    self.total += data.len;
                }
            };
        }

        pub const OmacAcpkmMaster = struct {
            const Self = @This();
            keys: SectionKeys(true, key_bytes + 16),
            section_bytes: usize,
            section_used: usize = 0,
            total: u128 = 0,
            state: B = @splat(0),
            pending: [16]u8 = @splat(0),
            used: usize = 0,
            /// init(master_cipher, section_bytes, lifetime_bytes).
            pub fn init(cipher: Cipher, section_bytes: usize, lifetime_bytes: usize) Error!Self {
                try sectionSize(section_bytes);
                return .{ .keys = try SectionKeys(true, key_bytes + 16).init(cipher, lifetime_bytes), .section_bytes = section_bytes };
            }
            pub fn validate(self: *const Self, length: usize) Error!void {
                const total = std.math.add(u128, self.total, length) catch return error.KeyMaterialExhausted;
                try sectionBudget(total, self.section_bytes, key_bytes + 16);
            }
            pub fn update(self: *Self, input: []const u8) Error!void {
                try self.validate(input.len);
                var data = input;
                while (data.len > 0) {
                    if (self.used == 16) {
                        self.state ^= @as(B, self.pending);
                        self.keys.cipher.encrypt(&self.state);
                        self.section_used += 16;
                        self.used = 0;
                        if (self.section_used == self.section_bytes) {
                            self.keys.next();
                            self.section_used = 0;
                        }
                    }
                    const n = @min(16 - self.used, data.len);
                    @memcpy(self.pending[self.used..][0..n], data[0..n]);
                    self.used += n;
                    data = data[n..];
                }
                self.total += input.len;
            }
            /// Snapshot finalization: repeated calls are stable and update may follow.
            /// Empty messages use one padded block under the first section material.
            pub fn final(self: Self) [16]u8 {
                var last = self.pending;
                if (self.used < 16) {
                    @memset(last[self.used..], 0);
                    last[self.used] = 0x80;
                }
                const sk = if (self.used == 16) self.keys.subkey else doubled(self.keys.subkey);
                var tag = self.state ^ @as(B, last) ^ sk;
                self.keys.cipher.encrypt(&tag);
                return tag;
            }
            pub fn verify(self: Self, tag: []const u8) Error!void {
                if (tag.len == 0 or tag.len > 16) return error.InvalidTagLength;
                try verifyTag(self.final(), tag);
            }
        };
    };
}

test {
    _ = @import("acpkm_test.zig");
}
