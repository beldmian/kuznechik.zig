//! Scoped repeatable cipher-profile timings. Reused nonces/keys in this
//! timing-only harness are NOT an example of secure protocol operation.
const std = @import("std");
const C = @import("kuznechik.zig").Cipher;
const P = @import("modes/mgm_profiles.zig");
const M = P.Profiles(C);
const Raw = @import("modes/mgm.zig").Mgm(C);
var data: [65536]u8 align(64) = @splat(0x5a);
const iv = P.KtreeIv{ .i1 = 0, .i2 = 0, .i3 = 0, .pnum = 0 };
const esp = P.EspHeader{ .spi = 0x12345678, .sequence = .{ .esn = 0x0102030405060708 } };
const aad = P.IkeAad{ .header = @splat(0x11), .unencrypted_payloads = &.{ 0x22, 0x33, 0x44 }, .encrypted_header = .{ .fragment = @splat(0x55) } };
const salt: [12]u8 = @splat(0x66);
const nonce: [16]u8 = @splat(0x11);
const Kind = enum { raw, tls, esp_aead, esp_mac, ike_fragment };
fn operation(comptime kind: Kind, c: *const C, length: usize) !void {
    switch (kind) {
        .raw => std.mem.doNotOptimizeAway(try Raw.seal(c, nonce, &@as([5]u8, @splat(0x22)), data[1..][0..length])),
        .tls => std.mem.doNotOptimizeAway(try M.Tls13MgmS.seal(c, nonce, 0, data[1..][0..length])),
        .esp_aead => std.mem.doNotOptimizeAway(try M.EspMgmKtree.seal(c, salt, iv, esp, data[1..][0..length])),
        .esp_mac => std.mem.doNotOptimizeAway(try M.EspMgmMacKtree.seal(c, salt, iv, esp, data[1..][0..length])),
        .ike_fragment => std.mem.doNotOptimizeAway(try M.IkeMgmKtree.seal(c, salt, iv, aad, data[1..][0..length])),
    }
}
pub fn main() !void {
    const c = C.init(@splat(0x77));
    inline for (.{ Kind.raw, Kind.tls, Kind.esp_aead, Kind.esp_mac, Kind.ike_fragment }) |kind| {
        for ([_]usize{ 64, 1024, 16385 }) |length| {
            const count = @max(16, 262144 / length);
            for (0..@max(4, count / 8)) |_| try operation(kind, &c, length);
            for (0..7) |sample| {
                @memset(&data, 0x5a);
                var timer = try std.time.Timer.start();
                for (0..count) |_| try operation(kind, &c, length);
                const ns = timer.read();
                std.mem.doNotOptimizeAway(data);
                std.debug.print("{{\"kind\":\"{s}\",\"length\":{d},\"iterations\":{d},\"sample\":{d},\"ns\":{d}}}\n", .{ @tagName(kind), length, count, sample, ns });
            }
        }
    }
}
