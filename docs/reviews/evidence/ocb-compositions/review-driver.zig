const std = @import("std");
const t = std.testing;
const h = @import("modes/test_helpers.zig");
const C = @import("kuznechik.zig").Cipher;
const Classic = @import("modes/classic.zig").Modes(C);
const Acpkm = @import("modes/acpkm.zig").Modes(C, Classic);
const M = @import("modes/compositions.zig").Modes(C, Classic, Acpkm);
fn decode(dst: []u8, txt: []const u8) ![]u8 { return try std.fmt.hexToBytes(dst[0..txt.len/2], txt); }
fn parse(comptime T: type, path: []const u8) !std.json.Parsed(T) {
    const raw = try std.fs.cwd().readFileAlloc(t.allocator, path, 16*1024*1024);
    defer t.allocator.free(raw);
    return std.json.parseFromSlice(T, t.allocator, raw, .{ .allocate = .alloc_always });
}
test "review_sol new independent Kuznyechik compositions irregular sections random keys and metadata" {
    const Case = struct { kind: []const u8, section: usize, enc: []const u8, mac: []const u8, iv: []const u8, sequence: u64, content_type: u8, version: []const u8, plain: []const u8, cipher: []const u8 };
    const doc = try parse([]Case, comp_path); defer doc.deinit();
    try t.expectEqual(@as(usize,161), doc.value.len);
    var trial: usize = 0;
    for (doc.value) |case| {
        var ke: [32]u8=undefined; var km: [32]u8=undefined; var iv: [8]u8=undefined; var version: [2]u8=undefined;
        _=try decode(&ke,case.enc); _=try decode(&km,case.mac); _=try decode(&iv,case.iv); _=try decode(&version,case.version);
        const ec=C.init(ke); const mc=C.init(km);
        var plain_store: [5025]u8=undefined; var expected_store: [5025]u8=undefined;
        const plain=try decode(&plain_store,case.plain); const expected=try decode(&expected_store,case.cipher);
        var guarded: [5057]u8=@splat(0xa5); const offset=trial%16+1; trial+=1;
        const buffer=guarded[offset..][0..expected.len];
        @memcpy(buffer[0..plain.len],plain);
        const rec=@import("modes/compositions.zig").Record{ .sequence=case.sequence,.content_type=case.content_type,.version=version };
        if (std.mem.eql(u8,case.kind,"kexp")) {
            const mode=M.KExp15.init(ec,mc); try mode.sealInPlace(iv,buffer);
        } else if (std.mem.eql(u8,case.kind,"tls")) {
            const mode=M.TlsCtrOmac.init(ec,mc); try mode.sealInPlace(iv,rec,buffer);
        } else {
            const mode=try M.CtrAcpkmOmac.init(ec,mc,case.section); try mode.sealInPlace(iv,buffer);
        }
        try t.expectEqualSlices(u8,expected,buffer);
        if (std.mem.eql(u8,case.kind,"kexp")) { _=try M.KExp15.init(ec,mc).openInPlace(iv,buffer); }
        else if (std.mem.eql(u8,case.kind,"tls")) { _=try M.TlsCtrOmac.init(ec,mc).openInPlace(iv,rec,buffer); }
        else { const mode=try M.CtrAcpkmOmac.init(ec,mc,case.section); _=try mode.openInPlace(iv,buffer); }
        try t.expectEqualSlices(u8,plain,buffer[0..plain.len]);
        try t.expectEqualSlices(u8,expected[plain.len..],buffer[plain.len..]);
        try t.expect(std.mem.allEqual(u8,guarded[0..offset],0xa5));
        try t.expect(std.mem.allEqual(u8,guarded[offset+expected.len..],0xa5));
    }
}
test "review_sol additional AES256 OpenSSL OCB independent tuples every tag size" {
    const Case=struct {key:[]const u8,nonce:[]const u8,aad:[]const u8,plain:[]const u8,cipher:[]const u8,tag:[]const u8};
    const doc=try parse([]Case,ocb_path);defer doc.deinit();try t.expectEqual(@as(usize,144),doc.value.len);
    inline for (1..17) |taglen| {
        const O=@import("modes/ocb.zig").OcbWithTag(h.Aes256,taglen);
        for (doc.value) |case| {
            if(case.tag.len!=taglen*2)continue;
            var key:[32]u8=undefined;var ns:[15]u8=undefined;var ad:[5009]u8=undefined;var pl:[5009]u8=undefined;var ct:[5009]u8=undefined;var tag:[taglen]u8=undefined;
            _=try decode(&key,case.key);const nonce=try decode(&ns,case.nonce);const aad=try decode(&ad,case.aad);const plain=try decode(&pl,case.plain);const expected=try decode(&ct,case.cipher);_=try decode(&tag,case.tag);
            const cipher=h.Aes256.init(key);var data:[5009]u8=undefined;@memcpy(data[0..plain.len],plain);
            const actual=try O.seal(&cipher,nonce,aad,data[0..plain.len]);try t.expectEqual(tag,actual);try t.expectEqualSlices(u8,expected,data[0..plain.len]);
            var bad=tag;bad[taglen-1]^=1;try t.expectError(error.AuthenticationFailed,O.open(&cipher,nonce,aad,data[0..plain.len],bad));try t.expectEqualSlices(u8,expected,data[0..plain.len]);
            try O.open(&cipher,nonce,aad,data[0..plain.len],tag);try t.expectEqualSlices(u8,plain,data[0..plain.len]);
        }
    }
}
test "review_sol OCB readonly nonce sharing and exhaustive small writable aliases" {
    const O=@import("modes/ocb.zig").Ocb(h.Aes256);
    var key:[32]u8=undefined;for(&key,0..)|*v,i|v.*=@intCast(i);
    const cipher=h.Aes256.init(key);const storage=std.mem.asBytes(&cipher);
    var reference:[33]u8=@splat(0x63);var actual=reference;
    // Nonce and AAD may share each other and the cipher's read-only key storage.
    const copy_nonce=storage[3..15].*;const copy_aad=storage[0..32].*;
    reference=@splat(0x63);
    const tag=try O.seal(&cipher,&copy_nonce,&copy_aad,&reference);
    const shared_tag=try O.seal(&cipher,storage[3..15],storage[0..32],&actual);
    try t.expectEqual(tag,shared_tag);try t.expectEqual(reference,actual);
    try O.open(&cipher,storage[3..15],storage[0..32],&actual,tag);try t.expect(std.mem.allEqual(u8,&actual,0x63));
    var arena:[96]u8=@splat(0x45);var detached:[16]u8=@splat(0x67);const saved=arena;const tag_before=detached;
    for(0..64)|start| {
        const data=arena[24..57];
        if(start<57 and start+12>24){
            try t.expectError(error.InvalidOverlap,O.sealDetached(&cipher,arena[start..][0..12],&.{},data,&detached));
            try t.expectError(error.InvalidOverlap,O.openDetached(&cipher,arena[start..][0..12],&.{},data,&detached));
        }
        if(start<57 and start+16>24){
            try t.expectError(error.InvalidOverlap,O.sealDetached(&cipher,&copy_nonce,&.{},data,arena[start..][0..16]));
            try t.expectError(error.InvalidOverlap,O.openDetached(&cipher,&copy_nonce,&.{},data,arena[start..][0..16]));
        }
        if(start<57 and start+17>24){
            try t.expectError(error.InvalidOverlap,O.sealDetached(&cipher,&copy_nonce,arena[start..][0..17],data,&detached));
            try t.expectError(error.InvalidOverlap,O.openDetached(&cipher,&copy_nonce,arena[start..][0..17],data,&detached));
        }
        try t.expectEqual(saved,arena);try t.expectEqual(tag_before,detached);
    }
}

const comp_path = "/tmp/kuz-review-sol-awD48G/new-composition.json";
const ocb_path = "/tmp/kuz-review-sol-awD48G/new-ocb.json";
