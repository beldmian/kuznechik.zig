const std = @import("std");
const kuz = @import("../kuznechik.zig");
const Kind = enum { gcm, ccm, mgm, acpkm, master };
fn Operation(comptime kind: Kind) type {
    return struct {
        const Nonce = [if (kind == .mgm) 16 else 12]u8;
        inline fn seal(cipher: *const kuz.Cipher, nonce: Nonce, data: []u8) ![16]u8 {
            return switch (kind) {
                .gcm => kuz.modes.Gcm.seal(cipher, nonce, &.{1}, data),
                .ccm => kuz.modes.Ccm.seal(cipher, nonce, &.{1}, data),
                .mgm => kuz.modes.Mgm.seal(cipher, nonce, &.{1}, data),
                .acpkm => (try kuz.modes.GcmAcpkm.init(cipher.*, 1024)).seal(nonce, &.{1}, data),
                .master => (try kuz.modes.GcmAcpkmMaster.init(cipher.*, 1024, 6144)).seal(nonce, &.{1}, data),
            };
        }
        inline fn open(cipher: *const kuz.Cipher, nonce: Nonce, data: []u8, tag: [16]u8) !void {
            return switch (kind) {
                .gcm => kuz.modes.Gcm.open(cipher, nonce, &.{1}, data, tag),
                .ccm => kuz.modes.Ccm.open(cipher, nonce, &.{1}, data, tag),
                .mgm => kuz.modes.Mgm.open(cipher, nonce, &.{1}, data, tag),
                .acpkm => (try kuz.modes.GcmAcpkm.init(cipher.*, 1024)).open(nonce, &.{1}, data, tag),
                .master => (try kuz.modes.GcmAcpkmMaster.init(cipher.*, 1024, 6144)).open(nonce, &.{1}, data, tag),
            };
        }
        inline fn sealDetached(cipher: *const kuz.Cipher, nonce: Nonce, data: []u8, tag: []u8) !void {
            return switch (kind) {
                .gcm => kuz.modes.Gcm.sealDetached(cipher, nonce, &.{1}, data, tag),
                .ccm => kuz.modes.Ccm.sealDetached(cipher, nonce, &.{1}, data, tag),
                .mgm => kuz.modes.Mgm.sealDetached(cipher, nonce, &.{1}, data, tag),
                .acpkm => (try kuz.modes.GcmAcpkm.init(cipher.*, 1024)).sealDetached(nonce, &.{1}, data, tag),
                .master => (try kuz.modes.GcmAcpkmMaster.init(cipher.*, 1024, 6144)).sealDetached(nonce, &.{1}, data, tag),
            };
        }
        inline fn openDetached(cipher: *const kuz.Cipher, nonce: Nonce, data: []u8, tag: []const u8) !void {
            return switch (kind) {
                .gcm => kuz.modes.Gcm.openDetached(cipher, nonce, &.{1}, data, tag),
                .ccm => kuz.modes.Ccm.openDetached(cipher, nonce, &.{1}, data, tag),
                .mgm => kuz.modes.Mgm.openDetached(cipher, nonce, &.{1}, data, tag),
                .acpkm => (try kuz.modes.GcmAcpkm.init(cipher.*, 1024)).openDetached(nonce, &.{1}, data, tag),
                .master => (try kuz.modes.GcmAcpkmMaster.init(cipher.*, 1024, 6144)).openDetached(nonce, &.{1}, data, tag),
            };
        }
    };
}
fn check(comptime kind: Kind) !void {
    const M = Operation(kind);
    const cipher = kuz.Cipher.init(@splat(0x71));
    const nonce: M.Nonce = @splat(0x4b);
    for ([_]usize{ 64, 512, 1024, 1025, 2049 }) |n| {
        for ([_]usize{ 0, 1, 7, 15 }) |offset| {
            var reference: [2081]u8 = @splat(0xa5);
            var aliased = reference;
            const a = reference[offset..][0..n];
            const b = aliased[offset..][0..n];
            @memset(a, 0x4b);
            @memset(b, 0x4b);
            // Make the accepted value metadata's backing bytes opaque to LLVM.
            asm volatile (""
                :
                : [p] "r" (b.ptr),
                : .{ .memory = true });
            const tag = try M.seal(&cipher, nonce, a);
            const actual = try M.seal(&cipher, b[0..nonce.len].*, b);
            try std.testing.expectEqual(tag, actual);
            try std.testing.expectEqual(reference, aliased);
            @memset(b, 0x4b);
            var detached: [16]u8 = undefined;
            asm volatile (""
                :
                : [p] "r" (b.ptr),
                : .{ .memory = true });
            try M.sealDetached(&cipher, b[0..nonce.len].*, b, &detached);
            try std.testing.expectEqual(tag, detached);
            try std.testing.expectEqual(reference, aliased);

            // These modes XOR a counter stream. Prepare valid ciphertext whose
            // initial bytes equal the nonce, then open using that value alias.
            var gamma: [2049]u8 = @splat(0);
            _ = try M.seal(&cipher, nonce, gamma[0..n]);
            var plain: [2049]u8 = undefined;
            for (plain[0..n], gamma[0..n]) |*v, g| v.* = g ^ 0x4b;
            @memcpy(a, plain[0..n]);
            const opening_tag = try M.seal(&cipher, nonce, a);
            for (a) |v| try std.testing.expectEqual(@as(u8, 0x4b), v);
            @memcpy(b, a);
            const saved = aliased;
            var bad = opening_tag;
            bad[0] ^= 1;
            try std.testing.expectError(error.AuthenticationFailed, M.open(&cipher, b[0..nonce.len].*, b, bad));
            try std.testing.expectEqual(saved, aliased);
            asm volatile (""
                :
                : [p] "r" (b.ptr),
                : .{ .memory = true });
            try M.open(&cipher, b[0..nonce.len].*, b, opening_tag);
            @memcpy(a, plain[0..n]);
            try std.testing.expectEqual(reference, aliased);
            @memset(b, 0x4b);
            asm volatile (""
                :
                : [p] "r" (b.ptr),
                : .{ .memory = true });
            try M.openDetached(&cipher, b[0..nonce.len].*, b, &opening_tag);
            try std.testing.expectEqual(reference, aliased);
        }
    }
}
test "GCM value nonce metadata may originate in the mutable payload" {
    try check(.gcm);
}
test "CCM value nonce metadata may originate in the mutable payload" {
    try check(.ccm);
}
test "MGM value nonce metadata may originate in the mutable payload" {
    try check(.mgm);
}
test "GCM ACPKM value nonce metadata may originate in the mutable payload" {
    try check(.acpkm);
}
test "GCM ACPKM Master value nonce metadata may originate in the mutable payload" {
    try check(.master);
}
