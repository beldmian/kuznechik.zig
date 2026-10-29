const std = @import("std");
const t = std.testing;
const B = @Vector(16, u8);
const K = @import("kuznechik.zig");
const mgm = @import("modes/mgm.zig");
const AP = @import("modes/acpkm.zig");
const Classic = @import("modes/classic.zig");

// Review-only oracle: raw permutation calls, no production mode/scalar-reference helpers.
fn Oracle(comptime C: type) type {
    return struct {
        const kb = @typeInfo(@TypeOf(@as(C, undefined).k)).vector.len;
        fn e(c: C, x: [16]u8) [16]u8 {
            var v: B align(16) = x;
            c.encrypt(&v);
            return v;
        }
        fn next(c: C) C {
            var out: [kb]u8 = undefined;
            var offset: usize = 0;
            while (offset < kb) : (offset += 16) {
                var x: [16]u8 = undefined;
                for (&x, 0..) |*b, j| b.* = @intCast(128 + offset + j);
                const y = e(c, x);
                const n = @min(16, kb - offset);
                @memcpy(out[offset..][0..n], y[0..n]);
            }
            return C.init(out);
        }
        fn material(initial: C, lifetime: usize, out: []u8) void {
            var c = initial;
            var offset: usize = 0;
            while (offset < out.len) : (offset += 16) {
                if (offset != 0 and offset % lifetime == 0) c = next(c);
                var x: [16]u8 = @splat(0xff);
                std.mem.writeInt(u64, x[8..16], @intCast(offset / 16), .big);
                const y = e(c, x);
                const n = @min(16, out.len - offset);
                @memcpy(out[offset..][0..n], y[0..n]);
            }
        }
        fn ctr(initial: C, master: bool, section: usize, lifetime: usize, nonce: []const u8, start: usize, data: []u8) void {
            var material_bytes: [16384]u8 = undefined;
            if (master) material(initial, lifetime, material_bytes[0 .. @max(1, (data.len + section - 1) / section) * kb]);
            var c = initial;
            var offset: usize = 0;
            while (offset < data.len) : (offset += 16) {
                if (offset % section == 0) {
                    if (master) c = C.init(material_bytes[offset / section * kb ..][0..kb].*) else if (offset > 0) { c = next(c); }
                }
                var x: [16]u8 = @splat(0);
                @memcpy(x[0..nonce.len], nonce);
                const base = std.mem.readInt(u128, &x, .big);
                std.mem.writeInt(u128, &x, base + start + offset / 16, .big);
                const y = e(c, x);
                for (data[offset..][0..@min(16, data.len - offset)], 0..) |*b, j| b.* ^= y[j];
            }
        }
        fn feedback(initial: C, cbc: bool, section: usize, lifetime: usize, iv: [16]u8, data: []u8) void {
            var material_bytes: [16384]u8 = undefined;
            material(initial, lifetime, material_bytes[0 .. @max(1, (data.len + section - 1) / section) * kb]);
            var previous = iv;
            var offset: usize = 0;
            while (offset < data.len) : (offset += 16) {
                const c = C.init(material_bytes[offset / section * kb ..][0..kb].*);
                const n = @min(16, data.len - offset);
                if (cbc) {
                    for (&previous, data[offset..][0..16]) |*b, p| b.* ^= p;
                    previous = e(c, previous);
                    @memcpy(data[offset..][0..16], &previous);
                } else {
                    const gamma = e(c, previous);
                    for (data[offset..][0..n], 0..) |*b, j| b.* ^= gamma[j];
                    if (n == 16) previous = data[offset..][0..16].*;
                }
            }
        }
        fn omac(initial: C, section: usize, lifetime: usize, data: []const u8) [16]u8 {
            const d = kb + 16;
            const count = @max(1, (data.len + section - 1) / section);
            var material_bytes: [16384]u8 = undefined;
            material(initial, lifetime, material_bytes[0 .. count * d]);
            const blocks = @max(1, (data.len + 15) / 16);
            var state: [16]u8 = @splat(0);
            for (0..blocks) |i| {
                const offset = i * 16;
                const m = material_bytes[offset / section * d ..][0..d];
                const c = C.init(m[0..kb].*);
                const n = @min(16, data.len - offset);
                var x: [16]u8 = @splat(0);
                @memcpy(x[0..n], data[offset..][0..n]);
                if (i == blocks - 1) {
                    var sk = m[kb..][0..16].*;
                    if (n < 16) {
                        x[n] = 128;
                        const carry = sk[0] >> 7;
                        for (0..15) |j| sk[j] = (sk[j] << 1) | (sk[j + 1] >> 7);
                        sk[15] = (sk[15] << 1) ^ (@as(u8, 0x87) * carry);
                    }
                    for (&x, sk) |*b, s| b.* ^= s;
                }
                for (&x, state) |*b, s| b.* ^= s;
                state = e(c, x);
            }
            return state;
        }
        fn gcmTag(initial: C, master: bool, lifetime: usize, nonce: []const u8, aad: []const u8, data: []const u8) [16]u8 {
            var c = initial;
            if (master) {
                var key: [kb]u8 = undefined;
                material(initial, lifetime, &key);
                c = C.init(key);
            }
            const zero: [16]u8 = @splat(0);
            const h = e(c, zero);
            var sum: u128 = 0;
            for ([_][]const u8{ aad, data }) |part| {
                var off: usize = 0;
                while (off < part.len) : (off += 16) {
                    var block: [16]u8 = @splat(0);
                    const n = @min(16, part.len - off);
                    @memcpy(block[0..n], part[off..][0..n]);
                    sum = ghashMul(sum ^ std.mem.readInt(u128, &block, .big), std.mem.readInt(u128, &h, .big));
                }
            }
            var lens: [16]u8 = undefined;
            std.mem.writeInt(u64, lens[0..8], @intCast(aad.len * 8), .big);
            std.mem.writeInt(u64, lens[8..16], @intCast(data.len * 8), .big);
            sum = ghashMul(sum ^ std.mem.readInt(u128, &lens, .big), std.mem.readInt(u128, &h, .big));
            var icb: [16]u8 = @splat(0);
            @memcpy(icb[0..nonce.len], nonce);
            icb[15] = 1;
            const mask = e(c, icb);
            var tag: [16]u8 = undefined;
            std.mem.writeInt(u128, &tag, sum ^ std.mem.readInt(u128, &mask, .big), .big);
            return tag;
        }
    };
}
fn ghashMul(a: u128, b: u128) u128 {
    var v = b;
    var out: u128 = 0;
    for (0..128) |j| {
        if ((a >> @as(u7, @intCast(127 - j))) & 1 != 0) out ^= v;
        const carry = v & 1;
        v >>= 1;
        if (carry != 0) v ^= @as(u128, 0xe1) << 120;
    }
    return out;
}
fn independentCases(comptime C: type, key: anytype) !void {
    const F = AP.Modes(C, Classic.Modes(C));
    const R = Oracle(C);
    const c = C.init(key);
    const kb = @typeInfo(@TypeOf(c.k)).vector.len;
    var rng = std.Random.DefaultPrng.init(0xc114208645);
    var input: [2113]u8 = undefined;
    var aad: [203]u8 = undefined;
    var iv: [16]u8 = undefined;
    var nonce: [8]u8 = undefined;
    rng.random().bytes(&input);
    rng.random().bytes(&aad);
    rng.random().bytes(&iv);
    rng.random().bytes(&nonce);
    for ([_]usize{ 80, 112, 272, 1040 }) |section| {
        for ([_]usize{ 0, 1, 14, 16, 18, 79, 80, 81, 111, 112, 113, 271, 272, 273, 1039, 1040, 1041, 2111 }) |n| {
            inline for (.{ false, true }) |master| {
                const Ctr = if (master) F.CtrAcpkmMaster else F.CtrAcpkm;
                const life = std.math.lcm(@as(usize, 16), kb) * 3;
                var expected = input;
                R.ctr(c, master, section, life, &nonce, 0, expected[1..][0..n]);
                var actual = input;
                var ctx = if (master) try Ctr.init(c, nonce, section, life) else try Ctr.init(c, nonce, section);
                var at: usize = 0;
                while (at < n) {
                    const chunk = @min(n - at, rng.random().intRangeAtMost(usize, 1, 137));
                    try ctx.xor(actual[1 + at ..][0..chunk]);
                    try ctx.xor(actual[at..at]);
                    at += chunk;
                }
                try t.expectEqual(expected, actual);
                const GM = if (master) F.GcmAcpkmMaster(56) else F.GcmAcpkm(56);
                const gm = if (master) try GM.init(c, section, life) else try GM.init(c, section);
                const gn: GM.Nonce = .{ 0x9f, 0xa1, 0xd3, 0x17, 0x99, 0x62, 0x20, 0x7e, 0x3a };
                expected = input;
                R.ctr(c, master, section, life, &gn, 2, expected[1..][0..n]);
                const expected_tag = R.gcmTag(c, master, life, &gn, aad[1..], expected[1..][0..n]);
                actual = input;
                const tag = try gm.seal(gn, aad[1..], actual[1..][0..n]);
                try t.expectEqual(expected, actual);
                try t.expectEqual(expected_tag, tag);
                var bad = tag;
                bad[7] ^= 0x80;
                try t.expectError(error.AuthenticationFailed, gm.open(gn, aad[1..], actual[1..][0..n], bad));
                try t.expectEqual(expected, actual);
                try gm.open(gn, aad[1..], actual[1..][0..n], tag);
                try t.expectEqual(input, actual);
            }
            const life = std.math.lcm(@as(usize, 16), kb) * 5;
            inline for (.{ false, true }) |cbc| {
                if (!cbc or n % 16 == 0) {
                    const FB = if (cbc) F.CbcAcpkmMaster else F.CfbAcpkmMaster;
                    var expected = input;
                    R.feedback(c, cbc, section, life, iv, expected[1..][0..n]);
                    var actual = input;
                    var enc = try FB.init(c, iv, section, life);
                    var dec = try FB.init(c, iv, section, life);
                    var off: usize = 0;
                    while (off < n) {
                        const chunk = @min(n - off, (if (cbc) @as(usize, 16) else 1) * rng.random().intRangeAtMost(usize, 1, 17));
                        try enc.encrypt(actual[off + 1 ..][0..chunk]);
                        off += chunk;
                    }
                    try t.expectEqual(expected, actual);
                    off = 0;
                    while (off < n) {
                        const chunk = @min(n - off, if (cbc) @as(usize, 16) else 7);
                        try dec.decrypt(actual[off + 1 ..][0..chunk]);
                        off += chunk;
                    }
                    try t.expectEqual(input, actual);
                }
            }
            const olife = std.math.lcm(@as(usize, 16), kb + 16) * 3;
            var mac = try F.OmacAcpkmMaster.init(c, section, olife);
            var off: usize = 0;
            while (off < n) {
                const chunk = @min(n - off, rng.random().intRangeAtMost(usize, 1, 71));
                try mac.update(input[1 + off ..][0..chunk]);
                off += chunk;
                try t.expectEqual(R.omac(c, section, olife, input[1..][0..off]), mac.final());
                try mac.verify(&mac.final());
                try mac.update(&.{});
            }
            try t.expectEqual(R.omac(c, section, olife, input[1..][0..n]), mac.final());
        }
    }
}

test "review independent RFC8645 Kuznechik new keys sections lifetimes random splits" {
    var key: [32]u8 = undefined;
    for (&key, 0..) |*b, i| b.* = @truncate(197 * i + 231);
    try independentCases(K.Cipher, key);
}

// A programmable permutation-call probe isolates the MGM product/sum output.
const Probe = struct {
    calls: *usize,
    keys: []const u128,
    pub fn encrypt(self: @This(), v: *align(16) B) void {
        const call = self.calls.*;
        self.calls.* += 1;
        if (call < 2) { v.* = @splat(0); return; }
        if (call < 2 + self.keys.len) {
            var bytes: [16]u8 = undefined;
            std.mem.writeInt(u128, &bytes, self.keys[call - 2], .big);
            v.* = bytes;
        } else if (call == 2 + self.keys.len) { v.* = @splat(0); }
    }
    pub fn encryptBlocks(self: @This(), blocks: []align(16) B) void {
        for (blocks) |*b| self.encrypt(b);
    }
};
fn productProbe(keys: []const u128, values: []const u128) !u128 {
    var aad: [32 * 16]u8 = undefined;
    for (values, 0..) |v, i| std.mem.writeInt(u128, aad[i * 16 ..][0..16], v, .big);
    var calls: usize = 0;
    const p: Probe = .{ .calls = &calls, .keys = keys };
    var empty: [0]u8 = .{};
    const tag = try mgm.Mgm(Probe).seal(&p, @splat(0), aad[0 .. values.len * 16], &empty);
    try t.expectEqual(4 + keys.len, calls);
    return std.mem.readInt(u128, &tag, .big);
}
fn monomial(power: usize) u128 {
    var coefficients: [256]bool = @splat(false);
    coefficients[power] = true;
    var p: usize = 255;
    while (p >= 128) : (p -= 1) {
        if (coefficients[p]) {
            for ([_]usize{ 0, 1, 2, 7, 128 }) |term| coefficients[p - 128 + term] = !coefficients[p - 128 + term];
        }
    }
    var out: u128 = 0;
    for (coefficients[0..128], 0..) |v, i| if (v) { out |= @as(u128, 1) << @intCast(i); };
    return out;
}
fn polynomial(a: u128, b: u128) u128 {
    var out: u128 = 0;
    for (0..128) |i| {
        if ((a >> @as(u7, @intCast(i))) & 1 != 0) {
            for (0..128) |j| {
                if ((b >> @as(u7, @intCast(j))) & 1 != 0) out ^= monomial(i + j);
            }
        }
    }
    return out;
}
test "review MGM all 16384 polynomial basis products and unreduced random sums" {
    for (0..128) |i| for (0..128) |j| {
        const a = @as(u128, 1) << @intCast(i);
        const b = @as(u128, 1) << @intCast(j);
        try t.expectEqual(monomial(i + j), try productProbe(&.{a}, &.{b}));
    };
    var rng = std.Random.DefaultPrng.init(0x9058b4515);
    for (0..24) |_| {
        var keys: [7]u128 = undefined;
        var values: [7]u128 = undefined;
        var expected: u128 = 0;
        for (&keys, &values) |*a, *b| {
            a.* = rng.random().int(u128);
            b.* = rng.random().int(u128);
            expected ^= polynomial(a.*, b.*);
        }
        try t.expectEqual(expected, try productProbe(&keys, &values));
    }
}

// Reversible toy ciphers isolate arbitrary key widths/material stream packing.
fn Wide(comptime width: usize) type {
    return struct {
        k: @Vector(width, u8),
        pub fn init(k: @Vector(width, u8)) @This() { return .{ .k = k }; }
        pub fn encrypt(self: @This(), block: *align(16) B) void {
            for (0..width) |i| block.*[i % 16] ^= self.k[i] ^ @as(u8, @truncate(i * 29));
        }
        pub const decrypt = encrypt;
        pub fn encryptBlocks(self: @This(), blocks: []align(16) B) void { for (blocks) |*b| self.encrypt(b); }
        pub const decryptBlocks = encryptBlocks;
    };
}
test "review key widths 128 192 264 384 512 and unusual material widths" {
    inline for (.{ 16, 24, 33, 48, 64 }) |width| {
        const C = Wide(width);
        var key: [width]u8 = undefined;
        for (&key, 0..) |*b, i| b.* = @truncate(31 * i + 7);
        try independentCases(C, key);
        const F = AP.Modes(C, Classic.Modes(C));
        const c = C.init(key);
        for ([_]usize{ 1, 3, 17, 24, 33, 65 }) |d| {
            const lifetime = std.math.lcm(@as(usize, 16), d) * 3;
            var actual: [2080]u8 = @splat(0);
            var expected: [2080]u8 = @splat(0);
            const len = actual.len / d * d;
            Oracle(C).material(c, lifetime, expected[0..len]);
            var stream = try F.AcpkmMaster.init(c, lifetime, d);
            var at: usize = 0;
            while (at < len) {
                const n = @min(len - at, d * 3);
                try stream.derive(actual[at..][0..n]);
                at += n;
            }
            try t.expectEqual(expected, actual);
        }
    }
}

test "review exact material exhaustion deferred final blocks cached gamma and synthetic preflight" {
    const c = K.Cipher.init(@splat(0xa9));
    const F = K.modes;
    const budget = @as(u128, 1) << 67;
    const n: usize = 80;
    const max_ctr = budget / 32 * n;
    var ctr = try F.CtrAcpkmMasterWithCounter(96).init(c, @splat(0), n, 96);
    ctr.total = max_ctr - 1;
    ctr.section_used = n - 1;
    ctr.blocks = max_ctr / 16;
    ctr.used = 15;
    ctr.stream = @splat(0x83);
    ctr.keys.derivation.stream.blocks = @as(u128, 1) << 63;
    var b = [_]u8{0x12};
    try ctr.xor(&b);
    try t.expectEqual(@as(u8, 0x91), b[0]);
    const saved_ctr = ctr;
    try ctr.xor(&.{});
    try t.expectEqualDeep(saved_ctr, ctr);
    try t.expectError(error.KeyMaterialExhausted, ctr.xor(&b));
    try t.expectEqualDeep(saved_ctr, ctr);
    var mac = try F.OmacAcpkmMaster.init(c, n, 144);
    mac.total = budget / 48 * n - 1;
    mac.section_used = n - 16;
    mac.used = 15;
    mac.keys.derivation.stream.blocks = budget / 48 * 48 / 16;
    try mac.update(&b);
    const saved_mac = mac;
    try mac.verify(&mac.final());
    try t.expectEqualDeep(saved_mac, mac);
    try mac.update(&.{});
    try t.expectEqualDeep(saved_mac, mac);
    try t.expectError(error.KeyMaterialExhausted, mac.update(&b));
    try t.expectEqualDeep(saved_mac, mac);
    var cfb = try F.CfbAcpkmMaster.init(c, @splat(0), n, 96);
    cfb.total = max_ctr;
    const saved_cfb = cfb;
    try t.expectError(error.KeyMaterialExhausted, cfb.encrypt(&b));
    try t.expectEqualDeep(saved_cfb, cfb);
    var derivation = try F.AcpkmMaster.init(c, 144, 48);
    const sections = budget / 48;
    const bytes = sections * 48;
    // Last complete material occupies the final three permitted blocks, leaving
    // 32 otherwise permitted derivation bytes that cannot form a material.
    derivation.stream.blocks = bytes / 16 - 3;
    derivation.stream.total = bytes - 48;
    derivation.stream.section_used = @intCast((bytes - 48) % 144);
    var material_bytes: [48]u8 = undefined;
    try derivation.derive(&material_bytes);
    const saved_derivation = derivation;
    try t.expectError(error.CounterExhausted, derivation.derive(&material_bytes));
    try t.expectEqualDeep(saved_derivation, derivation);
    // Huge slices are passed only to operations independently known to reject.
    var sentinel: [17]u8 = @splat(0x36);
    var tag: [16]u8 = @splat(0xc7);
    const original = sentinel;
    const original_tag = tag;
    const too_many: usize = @intCast((@as(u128, 1) << 31) * 16 + 1);
    const bogus: []u8 = @as([*]u8, @ptrCast(&sentinel))[0..too_many];
    inline for (.{ false, true }) |master| {
        const G = if (master) F.GcmAcpkmMaster else F.GcmAcpkm;
        const gm = if (master) try G.init(c, n, 96) else try G.init(c, n);
        const huge_len: usize = @intCast(((@as(u128, 1) << @as(u7, if (master) 32 else 31)) - 2) * 16 + 1);
        const huge: []u8 = @as([*]u8, @ptrCast(&sentinel))[0..huge_len];
        try t.expectError(error.MessageTooLong, gm.sealDetached(@splat(0), &.{}, huge, &tag));
        try t.expectError(error.MessageTooLong, gm.openDetached(@splat(0), &.{}, huge, &tag));
    }
    var small_ctr = try F.CtrAcpkmWithCounter(32).init(c, @splat(0), n);
    try t.expectError(error.CounterExhausted, small_ctr.xor(bogus));
    try t.expectEqual(original, sentinel);
    try t.expectEqual(original_tag, tag);
}

test "review public mode aliases and private authentication at offsets 0 through 31" {
    const F = K.modes;
    const c = K.Cipher.init(@splat(0x8f));
    _ = F.acpkm(c);
    var stream = try F.AcpkmMaster.init(c, 288, 48);
    var material_bytes: [48]u8 = undefined;
    try stream.derive(&material_bytes);
    inline for (.{ false, true }) |master| {
        const G = if (master) F.GcmAcpkmMaster else F.GcmAcpkm;
        const gm = if (master) try G.init(c, 80, 96) else try G.init(c, 80);
        for (0..32) |offset| {
            var data: [128]u8 = @splat(0xa1);
            const before = data;
            const aad = data[offset..][0..17];
            const payload = data[offset + 17 ..][0..33];
            const tag = data[offset + 50 ..][0..13];
            try gm.sealDetached(@splat(0x29), aad, payload, tag);
            const encrypted = data;
            for (0..tag.len) |j| {
                tag[j] ^= 0x10;
                try t.expectError(error.AuthenticationFailed, gm.openDetached(@splat(0x29), aad, payload, tag));
                tag[j] ^= 0x10;
                try t.expectEqual(encrypted, data);
            }
            try gm.openDetached(@splat(0x29), aad, payload, tag);
            try t.expectEqualSlices(u8, before[0 .. offset + 50], data[0 .. offset + 50]);
        }
    }
    for (0..32) |offset| {
        var data: [1121]u8 = @splat(0x62);
        const before = data;
        const aad = data[offset..][0..19];
        const payload = data[offset + 19 ..][0..1041];
        const tag = data[offset + 1060 ..][0..7];
        try F.Mgm.sealDetached(&c, @splat(0x21), aad, payload, tag);
        const encrypted = data;
        tag[4] ^= 0x88;
        try t.expectError(error.AuthenticationFailed, F.Mgm.openDetached(&c, @splat(0x21), aad, payload, tag));
        tag[4] ^= 0x88;
        try t.expectEqual(encrypted, data);
        try F.Mgm.openDetached(&c, @splat(0x21), aad, payload, tag);
        try t.expectEqualSlices(u8, before[0 .. offset + 1060], data[0 .. offset + 1060]);
    }
    var ctr = try F.CtrAcpkm.init(c, @splat(0), 80);
    var master_ctr = try F.CtrAcpkmMaster.init(c, @splat(0), 80, 96);
    var cbc = try F.CbcAcpkmMaster.init(c, @splat(0), 80, 96);
    var cfb = try F.CfbAcpkmMaster.init(c, @splat(0), 80, 96);
    var omac = try F.OmacAcpkmMaster.init(c, 80, 144);
    var x: [16]u8 = @splat(0);
    try ctr.xor(&x);
    try master_ctr.xor(&x);
    try cbc.encrypt(&x);
    try cfb.encrypt(&x);
    try omac.update(&x);
    try omac.verify(&omac.final());
}

fn ordinaryMul(a: u128, b: u128) u128 {
    var coefficients: [256]bool = @splat(false);
    for (0..128) |i| {
        if ((a >> @as(u7, @intCast(i))) & 1 != 0) {
            for (0..128) |j| {
                if ((b >> @as(u7, @intCast(j))) & 1 != 0) coefficients[i + j] = !coefficients[i + j];
            }
        }
    }
    var power: usize = 254;
    while (power >= 128) : (power -= 1) {
        if (coefficients[power]) {
            for ([_]usize{ 0, 1, 2, 7, 128 }) |term| coefficients[power - 128 + term] = !coefficients[power - 128 + term];
        }
    }
    var result: u128 = 0;
    for (coefficients[0..128], 0..) |bit, i| if (bit) { result |= @as(u128, 1) << @intCast(i); };
    return result;
}
fn increment(bytes: []u8) void {
    var i = bytes.len;
    while (i > 0) {
        i -= 1;
        bytes[i] +%= 1;
        if (bytes[i] != 0) break;
    }
}
fn independentMgm(c: K.Cipher, nonce: [16]u8, aad: []const u8, data: []u8) [16]u8 {
    const R = Oracle(K.Cipher);
    var y = R.e(c, nonce);
    var offset: usize = 0;
    while (offset < data.len) : (offset += 16) {
        const gamma = R.e(c, y);
        for (data[offset..][0..@min(16, data.len - offset)], 0..) |*b, j| b.* ^= gamma[j];
        increment(y[8..16]);
    }
    var domain = nonce;
    domain[0] |= 0x80;
    var z = R.e(c, domain);
    var lengths: [16]u8 = undefined;
    std.mem.writeInt(u64, lengths[0..8], @intCast(aad.len * 8), .big);
    std.mem.writeInt(u64, lengths[8..16], @intCast(data.len * 8), .big);
    var result: u128 = 0;
    for ([_][]const u8{ aad, data, &lengths }) |part| {
        offset = 0;
        while (offset < part.len) : (offset += 16) {
            const h = R.e(c, z);
            var padded: [16]u8 = @splat(0);
            const n = @min(16, part.len - offset);
            @memcpy(padded[0..n], part[offset..][0..n]);
            result ^= ordinaryMul(std.mem.readInt(u128, &h, .big), std.mem.readInt(u128, &padded, .big));
            increment(z[0..8]);
        }
    }
    var bytes: [16]u8 = undefined;
    std.mem.writeInt(u128, &bytes, result, .big);
    return R.e(c, bytes);
}
test "review fresh MGM keys and both sides of short combined batch threshold" {
    const cases = [_][2]usize{
        .{ 0, 1 }, .{ 1, 0 }, .{ 15, 17 }, .{ 31, 33 }, .{ 496, 256 }, .{ 496, 257 },
        .{ 480, 256 }, .{ 497, 256 }, .{ 1023, 1 }, .{ 1024, 1 }, .{ 1025, 1 },
        .{ 1, 1023 }, .{ 1, 1024 }, .{ 1, 1025 }, .{ 1057, 1041 },
    };
    var rng = std.Random.DefaultPrng.init(0x90588645ca11);
    for (0..4) |_| {
        var key: [32]u8 = undefined;
        var nonce: [16]u8 = undefined;
        var aad: [1089]u8 = undefined;
        var input: [1089]u8 = undefined;
        rng.random().bytes(&key);
        rng.random().bytes(&nonce);
        nonce[0] &= 0x7f;
        rng.random().bytes(&aad);
        rng.random().bytes(&input);
        const c = K.Cipher.init(key);
        for (cases) |case| {
            var expected = input;
            var actual = input;
            const expected_tag = independentMgm(c, nonce, aad[1..][0..case[0]], expected[1..][0..case[1]]);
            const actual_tag = try K.modes.Mgm.seal(&c, nonce, aad[1..][0..case[0]], actual[1..][0..case[1]]);
            try t.expectEqual(expected, actual);
            try t.expectEqual(expected_tag, actual_tag);
            try K.modes.Mgm.open(&c, nonce, aad[1..][0..case[0]], actual[1..][0..case[1]], expected_tag);
            try t.expectEqual(input, actual);
        }
    }
}

test "review independent counter range arithmetic all widths and cached offsets" {
    const F = K.modes;
    const c = K.Cipher.init(@splat(0x53));
    inline for (.{ 32, 40, 48, 56, 64, 72, 80, 88, 96 }) |width| {
        inline for (.{ false, true }) |master| {
            const C = if (master) F.CtrAcpkmMasterWithCounter(width) else F.CtrAcpkmWithCounter(width);
            const limit = @as(u128, 1) << @as(u7, if (master) width else width - 1);
            for (0..3) |remaining_blocks| {
                for (0..17) |used| {
                    var ctx = if (master) try C.init(c, @splat(0), 80, 96) else try C.init(c, @splat(0), 80);
                    ctx.blocks = limit - remaining_blocks;
                    ctx.used = used;
                    for (0..50) |length| {
                        const capacity = remaining_blocks * 16 + 16 - used;
                        if (length <= capacity) try ctx.validate(length) else try t.expectError(error.CounterExhausted, ctx.validate(length));
                    }
                }
            }
        }
    }
    inline for (.{ 32, 40, 48, 56, 64 }) |width| {
        inline for (.{ false, true }) |master| {
            const G = if (master) F.GcmAcpkmMasterWithCounter(width) else F.GcmAcpkmWithCounter(width);
            const mode = if (master) try G.init(c, 80, 96) else try G.init(c, 80);
            const bit_length_max: u128 = std.math.maxInt(u64) / 8;
            const max: usize = @intCast(@min(((@as(u128, 1) << @as(u7, if (master) width else width - 1)) - 2) * 16, bit_length_max));
            try mode.validate(@intCast(bit_length_max), max);
            try t.expectError(error.MessageTooLong, mode.validate(0, max + 1));
            try t.expectError(error.MessageTooLong, mode.validate(@intCast(bit_length_max + 1), 0));
        }
    }
}
