//! Allocation-free byte interfaces. ECB/CBC use complete blocks without padding.
const std = @import("std");
const B = @Vector(16, u8);
fn load(bytes: *const [16]u8) B {
    return bytes.*;
}
fn store(bytes: *[16]u8, value: B) void {
    bytes.* = value;
}
fn xorBytes(data: []u8, stream: []const u8) void {
    for (data, stream[0..data.len]) |*byte, mask| byte.* ^= mask;
}

pub fn Modes(comptime Cipher: type) type {
    return struct {
        pub fn ecbEncrypt(cipher: *const Cipher, data: []u8) !void {
            try ecb(false, cipher, data);
        }
        pub fn ecbDecrypt(cipher: *const Cipher, data: []u8) !void {
            try ecb(true, cipher, data);
        }
        fn ecb(comptime inverse: bool, cipher: *const Cipher, data: []u8) !void {
            if (data.len % 16 != 0) return error.InvalidLength;
            if (data.len == 0) return;
            if (@intFromPtr(data.ptr) % 16 == 0) {
                const blocks: [*]align(16) B = @ptrCast(@alignCast(data.ptr));
                if (inverse) cipher.decryptBlocks(blocks[0 .. data.len / 16]) else cipher.encryptBlocks(blocks[0 .. data.len / 16]);
                return;
            }
            var at: usize = 0;
            while (at < data.len) {
                const count: usize = @min(64, (data.len - at) / 16);
                var blocks: [64]B = undefined;
                for (0..count) |i| blocks[i] = load(data[at + i * 16 ..][0..16]);
                if (inverse) cipher.decryptBlocks(blocks[0..count]) else cipher.encryptBlocks(blocks[0..count]);
                for (0..count) |i| store(data[at + i * 16 ..][0..16], blocks[i]);
                at += count * 16;
            }
        }

        pub const Ctr = CtrWithCounter(64);
        pub fn CtrWithCounter(comptime counter_bits: u7) type {
            if (counter_bits < 32 or counter_bits > 96 or counter_bits % 8 != 0) @compileError("CTR counter must be32..96 bits in whole bytes");
            return struct {
                const Self = @This();
                pub const Nonce = [(@as(usize, 128) - counter_bits) / 8]u8;
                cipher: Cipher,
                prefix: u128,
                blocks: u128 = 0,
                stream: B = @splat(0),
                used: usize = 16,
                pub fn init(cipher: Cipher, nonce: Nonce) Self {
                    var value: [16]u8 = @splat(0);
                    @memcpy(value[0..nonce.len], &nonce);
                    return .{ .cipher = cipher, .prefix = std.mem.readInt(u128, &value, .big) };
                }
                pub fn xor(self: *Self, data: []u8) error{CounterExhausted}!void {
                    const available = 16 - self.used;
                    const missing = data.len - @min(available, data.len);
                    const needed: u128 = @as(u128, missing) / 16 + @intFromBool(missing % 16 != 0);
                    const limit = @as(u128, 1) << (counter_bits - 1);
                    if (self.blocks > limit or needed > limit - self.blocks) return error.CounterExhausted;
                    var at: usize = 0;
                    if (self.used < 16) {
                        const n = @min(available, data.len);
                        const bytes: [16]u8 = self.stream;
                        xorBytes(data[0..n], bytes[self.used..]);
                        self.used += n;
                        at = n;
                    }
                    while (data.len - at >= 16) {
                        const count: usize = @min(64, (data.len - at) / 16);
                        var counters: [64]B = undefined;
                        for (0..count) |i| {
                            var bytes: [16]u8 = undefined;
                            std.mem.writeInt(u128, &bytes, self.prefix | (self.blocks + i), .big);
                            counters[i] = bytes;
                        }
                        self.cipher.encryptBlocks(counters[0..count]);
                        for (0..count) |i| store(data[at + i * 16 ..][0..16], load(data[at + i * 16 ..][0..16]) ^ counters[i]);
                        self.blocks += count;
                        at += count * 16;
                    }
                    if (at < data.len) {
                        var bytes: [16]u8 = undefined;
                        std.mem.writeInt(u128, &bytes, self.prefix | self.blocks, .big);
                        self.stream = bytes;
                        self.cipher.encrypt(&self.stream);
                        self.blocks += 1;
                        const gamma: [16]u8 = self.stream;
                        self.used = data.len - at;
                        xorBytes(data[at..], &gamma);
                    }
                }
            };
        }

        pub fn Cbc(comptime iv_blocks: usize) type {
            if (iv_blocks == 0) @compileError("CBC IV must contain at least one block");
            return struct {
                const Self = @This();
                cipher: Cipher,
                register: [iv_blocks]B,
                head: usize = 0,
                pub fn init(cipher: Cipher, iv: [iv_blocks * 16]u8) Self {
                    var self = Self{ .cipher = cipher, .register = undefined };
                    for (0..iv_blocks) |i| self.register[i] = load(iv[i * 16 ..][0..16]);
                    return self;
                }
                pub fn encrypt(self: *Self, data: []u8) error{InvalidLength}!void {
                    if (data.len % 16 != 0) return error.InvalidLength;
                    var at: usize = 0;
                    while (at < data.len) : (at += 16) {
                        var value = load(data[at..][0..16]) ^ self.register[self.head];
                        self.cipher.encrypt(&value);
                        store(data[at..][0..16], value);
                        self.register[self.head] = value;
                        self.head = (self.head + 1) % iv_blocks;
                    }
                }
                pub fn decrypt(self: *Self, data: []u8) error{InvalidLength}!void {
                    if (data.len % 16 != 0) return error.InvalidLength;
                    var at: usize = 0;
                    while (at < data.len) {
                        const count: usize = @min(64, (data.len - at) / 16);
                        var blocks: [64]B = undefined;
                        for (0..count) |i| blocks[i] = load(data[at + i * 16 ..][0..16]);
                        self.cipher.decryptBlocks(blocks[0..count]);
                        for (0..count) |i| {
                            const ct = load(data[at + i * 16 ..][0..16]);
                            store(data[at + i * 16 ..][0..16], blocks[i] ^ self.register[self.head]);
                            self.register[self.head] = ct;
                            self.head = (self.head + 1) % iv_blocks;
                        }
                        at += count * 16;
                    }
                }
            };
        }

        pub fn Cfb(comptime iv_blocks: usize) type {
            if (iv_blocks == 0) @compileError("CFB IV must contain at least one block");
            return struct {
                const Self = @This();
                cipher: Cipher,
                register: [iv_blocks]B,
                head: usize = 0,
                used: usize = 16,
                stream: B = @splat(0),
                feedback: [16]u8 = @splat(0),
                pub fn init(cipher: Cipher, iv: [iv_blocks * 16]u8) Self {
                    var self = Self{ .cipher = cipher, .register = undefined };
                    for (0..iv_blocks) |i| self.register[i] = load(iv[i * 16 ..][0..16]);
                    return self;
                }
                pub fn encrypt(self: *Self, data: []u8) void {
                    self.crypt(false, data);
                }
                pub fn decrypt(self: *Self, data: []u8) void {
                    self.crypt(true, data);
                }
                fn crypt(self: *Self, comptime inverse: bool, data: []u8) void {
                    var at: usize = 0;
                    while (at < data.len) {
                        if (inverse and self.used == 16 and data.len - at >= 16) {
                            const count: usize = @min(64, (data.len - at) / 16);
                            var gamma: [64]B = undefined;
                            for (0..count) |i| gamma[i] = if (i < iv_blocks) self.register[(self.head + i) % iv_blocks] else load(data[at + (i - iv_blocks) * 16 ..][0..16]);
                            self.cipher.encryptBlocks(gamma[0..count]);
                            for (0..count) |i| {
                                const ct = load(data[at + i * 16 ..][0..16]);
                                store(data[at + i * 16 ..][0..16], ct ^ gamma[i]);
                                self.register[self.head] = ct;
                                self.head = (self.head + 1) % iv_blocks;
                            }
                            at += count * 16;
                            continue;
                        }
                        if (self.used == 16) {
                            self.stream = self.register[self.head];
                            self.cipher.encrypt(&self.stream);
                            self.used = 0;
                        }
                        const n = @min(16 - self.used, data.len - at);
                        const gamma: [16]u8 = self.stream;
                        for (0..n) |i| {
                            const input = data[at + i];
                            const output = input ^ gamma[self.used + i];
                            self.feedback[self.used + i] = if (inverse) input else output;
                            data[at + i] = output;
                        }
                        self.used += n;
                        at += n;
                        if (self.used == 16) {
                            self.register[self.head] = self.feedback;
                            self.head = (self.head + 1) % iv_blocks;
                        }
                    }
                }
            };
        }

        pub fn Ofb(comptime iv_blocks: usize) type {
            if (iv_blocks == 0) @compileError("OFB IV must contain at least one block");
            return struct {
                const Self = @This();
                cipher: Cipher,
                register: [iv_blocks]B,
                head: usize = 0,
                used: usize = 16,
                stream: B = @splat(0),
                pub fn init(cipher: Cipher, iv: [iv_blocks * 16]u8) Self {
                    var self = Self{ .cipher = cipher, .register = undefined };
                    for (0..iv_blocks) |i| self.register[i] = load(iv[i * 16 ..][0..16]);
                    return self;
                }
                pub fn xor(self: *Self, data: []u8) void {
                    var at: usize = 0;
                    while (at < data.len) {
                        if (self.used == 16) {
                            if (self.head == 0) self.cipher.encryptBlocks(&self.register);
                            self.stream = self.register[self.head];
                            self.head = (self.head + 1) % iv_blocks;
                            self.used = 0;
                        }
                        const n = @min(16 - self.used, data.len - at);
                        const gamma: [16]u8 = self.stream;
                        xorBytes(data[at..][0..n], gamma[self.used..]);
                        self.used += n;
                        at += n;
                    }
                }
            };
        }

        pub const Cmac = struct {
            const Self = @This();
            cipher: Cipher,
            state: B = @splat(0),
            pending: [16]u8 = @splat(0),
            used: usize = 0,
            k1: B,
            k2: B,
            pub fn init(cipher: Cipher) Self {
                var l: B = @splat(0);
                cipher.encrypt(&l);
                const k1 = double(l);
                return .{ .cipher = cipher, .k1 = k1, .k2 = double(k1) };
            }
            pub fn update(self: *Self, input: []const u8) void {
                var data = input;
                while (data.len > 0) {
                    if (self.used == 16) {
                        self.state ^= load(&self.pending);
                        self.cipher.encrypt(&self.state);
                        self.used = 0;
                    }
                    const n = @min(16 - self.used, data.len);
                    @memcpy(self.pending[self.used..][0..n], data[0..n]);
                    self.used += n;
                    data = data[n..];
                }
            }
            pub fn final(self: Self) [16]u8 {
                var last = self.pending;
                if (self.used < 16) {
                    @memset(last[self.used..], 0);
                    last[self.used] = 0x80;
                }
                var tag = self.state ^ load(&last) ^ (if (self.used == 16) self.k1 else self.k2);
                self.cipher.encrypt(&tag);
                return tag;
            }
            pub fn verify(self: Self, tag: []const u8) !void {
                if (tag.len == 0 or tag.len > 16) return error.InvalidTagLength;
                const full = self.final();
                var expected: [16]u8 = @splat(0);
                var actual: [16]u8 = @splat(0);
                @memcpy(expected[0..tag.len], full[0..tag.len]);
                @memcpy(actual[0..tag.len], tag);
                if (!std.crypto.timing_safe.eql([16]u8, expected, actual)) return error.AuthenticationFailed;
            }
            fn double(value: B) B {
                var bytes: [16]u8 = value;
                const n = std.mem.readInt(u128, &bytes, .big);
                std.mem.writeInt(u128, &bytes, (n << 1) ^ (@as(u128, 0x87) * (n >> 127)), .big);
                return bytes;
            }
        };
    };
}

