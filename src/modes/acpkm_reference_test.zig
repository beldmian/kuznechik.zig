//! Deliberately scalar, one-shot RFC8645 reference. Does not call production
//! mode, rekey, derivation, CMAC or GHASH code; only the raw cipher is shared.
const std = @import("std");
const B = @Vector(16, u8);
pub fn Reference(comptime Cipher: type) type {
    const K = @TypeOf(@as(Cipher, undefined).k);
    const kb = @typeInfo(K).vector.len;
    return struct {
        pub fn rekey(cipher: Cipher) Cipher {
            var key: [kb]u8 = undefined;
            var at: usize = 0;
            while (at < kb) : (at += 16) {
                var bytes: [16]u8 = undefined;
                for (&bytes, 0..) |*x, i| x.* = @intCast(128 + at + i);
                var block: B = bytes;
                cipher.encrypt(&block);
                bytes = block;
                @memcpy(key[at..][0..@min(16, kb - at)], bytes[0..@min(16, kb - at)]);
            }
            return Cipher.init(key);
        }
        pub fn material(initial: Cipher, lifetime: usize, output: []u8) void {
            var cipher = initial;
            var at: usize = 0;
            while (at < output.len) : (at += 16) {
                if (at > 0 and at % lifetime == 0) cipher = rekey(cipher);
                var counter: [16]u8 = @splat(0xff);
                std.mem.writeInt(u64, counter[8..16], @intCast(at / 16), .big);
                var block: B = counter;
                cipher.encrypt(&block);
                const bytes: [16]u8 = block;
                @memcpy(output[at..][0..@min(16, output.len - at)], bytes[0..@min(16, output.len - at)]);
            }
        }
        pub fn ctr(initial: Cipher, master: bool, nonce: []const u8, start: u128, section: usize, lifetime: usize, data: []u8) void {
            var cipher = initial;
            var keys: [8192]u8 = undefined;
            const sections = @max(1, (data.len + section - 1) / section);
            if (master) material(initial, lifetime, keys[0 .. sections * kb]);
            var prefix: [16]u8 = @splat(0);
            @memcpy(prefix[0..nonce.len], nonce);
            const base = std.mem.readInt(u128, &prefix, .big);
            var at: usize = 0;
            while (at < data.len) : (at += 16) {
                if (at % section == 0) {
                    if (master) {
                        const offset = (at / section) * kb;
                        cipher = Cipher.init(keys[offset..][0..kb].*);
                    } else if (at != 0) cipher = rekey(cipher);
                }
                var bytes: [16]u8 = undefined;
                std.mem.writeInt(u128, &bytes, base | (start + at / 16), .big);
                var block: B = bytes;
                cipher.encrypt(&block);
                bytes = block;
                const n = @min(16, data.len - at);
                for (data[at..][0..n], bytes[0..n]) |*x, y| x.* ^= y;
            }
        }
        pub fn feedback(initial: Cipher, cbc: bool, iv: [16]u8, section: usize, lifetime: usize, data: []u8) void {
            var keys: [8192]u8 = undefined;
            material(initial, lifetime, keys[0 .. @max(1, (data.len + section - 1) / section) * kb]);
            var feedback_block: B = iv;
            var at: usize = 0;
            while (at < data.len) : (at += 16) {
                const key_at = at / section * kb;
                const cipher = Cipher.init(keys[key_at..][0..kb].*);
                const n = @min(16, data.len - at);
                var input: [16]u8 = @splat(0);
                @memcpy(input[0..n], data[at..][0..n]);
                var block: B = if (cbc) @as(B, input) ^ feedback_block else feedback_block;
                cipher.encrypt(&block);
                if (!cbc) block ^= @as(B, input);
                const bytes: [16]u8 = block;
                @memcpy(data[at..][0..n], bytes[0..n]);
                feedback_block = block;
            }
        }
        pub fn omac(initial: Cipher, section: usize, lifetime: usize, data: []const u8) [16]u8 {
            const d = kb + 16;
            const sections = @max(1, (data.len + section - 1) / section);
            var keys: [8192]u8 = undefined;
            material(initial, lifetime, keys[0 .. sections * d]);
            const blocks = @max(1, (data.len + 15) / 16);
            var state: B = @splat(0);
            for (0..blocks) |j| {
                const at = j * 16;
                const offset = at / section * d;
                const cipher = Cipher.init(keys[offset..][0..kb].*);
                const n = @min(16, data.len - @min(at, data.len));
                var block: [16]u8 = @splat(0);
                @memcpy(block[0..n], data[@min(at, data.len)..][0..n]);
                if (j + 1 == blocks) {
                    var subkey = keys[offset + kb ..][0..16].*;
                    if (n != 16) {
                        block[n] = 0x80;
                        const high = subkey[0] >> 7;
                        for (0..15) |i| subkey[i] = (subkey[i] << 1) | (subkey[i + 1] >> 7);
                        subkey[15] = (subkey[15] << 1) ^ (@as(u8, 0x87) * high);
                    }
                    for (&block, subkey) |*x, y| x.* ^= y;
                }
                state ^= @as(B, block);
                cipher.encrypt(&state);
            }
            return state;
        }
        fn multiply(x: u128, y: u128) u128 {
            var z: u128 = 0;
            var v = y;
            for (0..128) |i| {
                if ((x >> @as(u7, @intCast(127 - i))) & 1 != 0) z ^= v;
                const bit = v & 1;
                v >>= 1;
                if (bit != 0) v ^= @as(u128, 0xe1) << 120;
            }
            return z;
        }
        fn hash(state: *u128, h: u128, data: []const u8) void {
            var at: usize = 0;
            while (at < data.len) : (at += 16) {
                var block: [16]u8 = @splat(0);
                const n = @min(16, data.len - at);
                @memcpy(block[0..n], data[at..][0..n]);
                state.* = multiply(state.* ^ std.mem.readInt(u128, &block, .big), h);
            }
        }
        pub fn tag(initial: Cipher, master: bool, nonce: []const u8, lifetime: usize, aad: []const u8, ciphertext: []const u8) [16]u8 {
            var cipher = initial;
            if (master) {
                var key: [kb]u8 = undefined;
                material(initial, lifetime, &key);
                cipher = Cipher.init(key);
            }
            var h: B = @splat(0);
            cipher.encrypt(&h);
            const bytes: [16]u8 = h;
            const h_int = std.mem.readInt(u128, &bytes, .big);
            var state: u128 = 0;
            hash(&state, h_int, aad);
            hash(&state, h_int, ciphertext);
            state = multiply(state ^ (@as(u128, aad.len) * 8 << 64) ^ (@as(u128, ciphertext.len) * 8), h_int);
            var initial_block: [16]u8 = @splat(0);
            @memcpy(initial_block[0..nonce.len], nonce);
            initial_block[15] = 1;
            var mask: B = initial_block;
            cipher.encrypt(&mask);
            const mask_bytes: [16]u8 = mask;
            var output: [16]u8 = undefined;
            std.mem.writeInt(u128, &output, state ^ std.mem.readInt(u128, &mask_bytes, .big), .big);
            return output;
        }
    };
}
