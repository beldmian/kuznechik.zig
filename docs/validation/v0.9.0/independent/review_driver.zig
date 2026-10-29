const std = @import("std");
const t = std.testing;
const C = @import("kuznechik.zig").Cipher;
const M = @import("modes/mgm.zig").Mgm(C);
const p = @import("modes/mgm_profiles.zig");
const P = p.Profiles(C);
const v = @import("review_vectors.zig");
var multipart_checks: usize = 0;
var failure_checks: usize = 0;
fn same(a: []const u8, b: []const u8) !void { try t.expectEqualSlices(u8,a,b); }
fn hdr(c: v.Case) p.EspHeader {
 return .{ .spi=std.mem.readInt(u32,c.esp[0..4],.big), .sequence=if(c.esp.len==12) .{.esn=std.mem.readInt(u64,c.esp[4..12],.big)} else .{.sn=std.mem.readInt(u32,c.esp[4..8],.big)} };
}
fn ike(c: v.Case) p.IkeAad { return .{.header=c.head,.unencrypted_payloads=c.extra,.encrypted_header=if(c.kind==.fragment) .{.fragment=c.tail[0..8].*} else .{.payload=c.tail[0..4].*}}; }
fn seal(c: v.Case, cipher: *const C, data: []u8) !void {
 const iv=p.KtreeIv.decode(c.iv);
 switch(c.kind) {
 .raw => try same(&c.tag,&try M.seal(cipher,c.nonce,c.aad,data)),
 .tlsl => try same(&c.tag,&try P.Tls13MgmL.seal(cipher,c.write_iv,c.seq,data)),
 .tlss => try same(&c.tag,&try P.Tls13MgmS.seal(cipher,c.write_iv,c.seq,data)),
 .espsn,.espesn => try same(c.tag[0..12],&try P.EspMgmKtree.seal(cipher,c.salt,iv,hdr(c),data)),
 .macsn,.macesn => try same(c.tag[0..12],&try P.EspMgmMacKtree.seal(cipher,c.salt,iv,hdr(c),data)),
 .ike,.fragment => try same(c.tag[0..12],&try P.IkeMgmKtree.seal(cipher,c.salt,iv,ike(c),data)),
 }
}
fn open(c: v.Case, cipher: *const C, data: []u8, tag: []const u8) !void {
 const iv=p.KtreeIv.decode(c.iv);
 switch(c.kind) {
 .raw => try M.openParts(cipher,c.nonce,&.{c.aad},data,tag),
 .tlsl => try P.Tls13MgmL.open(cipher,c.write_iv,c.seq,data,tag),
 .tlss => try P.Tls13MgmS.open(cipher,c.write_iv,c.seq,data,tag),
 .espsn,.espesn => try P.EspMgmKtree.open(cipher,c.salt,iv,hdr(c),data,tag),
 .macsn,.macesn => try P.EspMgmMacKtree.open(cipher,c.salt,iv,hdr(c),data,tag),
 .ike,.fragment => try P.IkeMgmKtree.open(cipher,c.salt,iv,ike(c),data,tag),
 }
}
fn checkParts(c: v.Case, cipher: *const C, parts: []const []const u8) !void {
 var storage: [2051]u8 = @splat(0x93);
 const data=storage[1..][0..c.plain.len];
 @memcpy(data,c.plain);
 const actual=try M.sealParts(cipher,c.nonce,parts,data);
 try same(&c.tag,&actual); try same(c.enc,data);
 for(4..17) |n| {
  var bad=c.tag; bad[n-1]^=1;
  try t.expectError(error.AuthenticationFailed,M.openParts(cipher,c.nonce,parts,data,bad[0..n]));
  try same(c.enc,data); failure_checks+=1;
 }
 try M.openParts(cipher,c.nonce,parts,data,&c.tag);
 try same(c.plain,data);
 try t.expectEqual(@as(u8,0x93),storage[0]);
 try t.expectEqual(@as(u8,0x93),storage[data.len+1]);
 multipart_checks+=1;
}
fn fixtures() !void {
 for(v.cases) |c| {
  const cipher=C.init(c.key);
  const wrong=C.init(@splat(0xe7));
  var storage: [2051]u8 = @splat(0x93);
  const data=storage[1..][0..c.plain.len];
  @memcpy(data,c.plain);
  try seal(c,&cipher,data); try same(c.enc,data);
  const taglen: usize=if(c.kind==.raw or c.kind==.tlsl or c.kind==.tlss) 16 else 12;
  for(0..taglen) |i| {
   var bad=c.tag; bad[i]^=1;
   try t.expectError(error.AuthenticationFailed,open(c,&cipher,data,bad[0..taglen]));
   try same(c.enc,data); failure_checks+=1;
  }
  try t.expectError(error.AuthenticationFailed,open(c,&wrong,data,c.tag[0..taglen]));
  try same(c.enc,data); failure_checks+=1;
  if(c.kind!=.raw) {
   for([_]usize{0,1,4,8,11,13,15,17,32}) |n| {
    if(n==taglen) continue;
    const bad: [32]u8=@splat(0);
    try t.expectError(error.InvalidTagLength,open(c,&cipher,data,bad[0..n]));
    try same(c.enc,data); failure_checks+=1;
   }
  }
  if(data.len>0) {
   data[data.len-1]^=1;
   const bad=data[data.len-1];
   try t.expectError(error.AuthenticationFailed,open(c,&cipher,data,c.tag[0..taglen]));
   try t.expectEqual(bad,data[data.len-1]);
   data[data.len-1]^=1; try same(c.enc,data); failure_checks+=1;
  }
  try bindMetadata(c,&cipher,data,taglen);
  try open(c,&cipher,data,c.tag[0..taglen]); try same(c.plain,data);
  try t.expectEqual(@as(u8,0x93),storage[0]); try t.expectEqual(@as(u8,0x93),storage[data.len+1]);
  if(c.kind!=.raw) continue;
  for([_]usize{0,1,2,7,15,16,17,31,32,33,63,64,65,1007,1008,1009,1023,1024,1025,1040,2048,2049}) |split| {
   if(split>c.aad.len) continue;
   const parts=[_][]const u8{&.{},c.aad[0..split],&.{},&.{},c.aad[split..],&.{}};
   try checkParts(c,&cipher,&parts);
  }
  for([_]usize{1,3,7,15,16,17,31,1023,1024,1025}) |chunk| {
   var parts: [4100][]const u8=undefined;
   var used: usize=0; var at: usize=0;
   while(at<c.aad.len) {
    const end=@min(c.aad.len,at+chunk);
    parts[used]=c.aad[at..end]; parts[used+1]=c.aad[at..at]; used+=2; at=end;
   }
   try checkParts(c,&cipher,parts[0..used]);
  }
 }
 std.debug.print("oracle fixtures: {d}; multipart partitions: {d}; failed authentication/tag checks: {d}\n",.{v.cases.len,multipart_checks,failure_checks});
}
fn fail(c: v.Case, cipher: *const C, data: []u8, taglen: usize) !void {
 try t.expectError(error.AuthenticationFailed,open(c,cipher,data,c.tag[0..taglen]));
 try same(c.enc,data); failure_checks+=1;
}
fn bindMetadata(c: v.Case, cipher: *const C, data: []u8, taglen: usize) !void {
 var altered=c;
 if(c.kind==.raw) {
  altered.nonce[15]^=1; try fail(altered,cipher,data,taglen);
  if(c.aad.len>0) {
   var aad: [2050]u8=undefined; @memcpy(aad[0..c.aad.len],c.aad); aad[c.aad.len-1]^=1;
   altered=c; altered.aad=aad[0..c.aad.len]; try fail(altered,cipher,data,taglen);
  }
 } else if(c.kind==.tlsl or c.kind==.tlss) {
  altered.write_iv[15]^=1; try fail(altered,cipher,data,taglen);
  altered=c; altered.seq^=1; try fail(altered,cipher,data,taglen);
 } else {
  altered.salt[11]^=1; try fail(altered,cipher,data,taglen);
  altered=c; altered.iv[7]^=1; try fail(altered,cipher,data,taglen);
  if(c.kind==.ike or c.kind==.fragment) {
   altered=c; altered.head[27]^=1; try fail(altered,cipher,data,taglen);
   var tail: [8]u8=undefined; @memcpy(tail[0..c.tail.len],c.tail); tail[c.tail.len-1]^=1;
   altered=c; altered.tail=tail[0..c.tail.len]; try fail(altered,cipher,data,taglen);
   if(c.extra.len>0) {
    var extra: [2050]u8=undefined; @memcpy(extra[0..c.extra.len],c.extra); extra[c.extra.len-1]^=1;
    altered=c; altered.extra=extra[0..c.extra.len]; try fail(altered,cipher,data,taglen);
   }
  } else {
   var esp: [12]u8=undefined; @memcpy(esp[0..c.esp.len],c.esp);
   esp[0]^=1; altered=c; altered.esp=esp[0..c.esp.len]; try fail(altered,cipher,data,taglen);
   esp[0]^=1; esp[4]^=1; try fail(altered,cipher,data,taglen);
   if(c.kind==.macsn or c.kind==.macesn) {
    altered=c; altered.iv[0]^=1; try fail(altered,cipher,data,taglen);
   }
  }
 }
}
fn metadata() !void {
 for(v.cases) |c| {
  const iv=p.KtreeIv.decode(c.iv);
  try same(&c.iv,&try iv.encode());
  const seeds=try iv.seeds();
  try same(&[_]u8{0,c.iv[0]},&seeds[0]);
  try same(c.iv[1..3],&seeds[1]); try same(c.iv[3..5],&seeds[2]);
  const expected_nonce=[_]u8{0}++c.iv[5..8].*++c.salt;
  try same(&expected_nonce,&try iv.nonce(c.salt));
  if(c.kind==.tlsl or c.kind==.tlss) {
   const masks=if(c.kind==.tlsl) [3]u64{0xf800000000000000,0xfffffff000000000,0xffffffffffffe000} else [3]u64{0xffffffffe0000000,0xffffffffffff0000,0xfffffffffffffff8};
   const seeds_tls=if(c.kind==.tlsl) try P.Tls13MgmL.seeds(c.seq) else try P.Tls13MgmS.seeds(c.seq);
   for(seeds_tls,masks) |seed,mask| try t.expectEqual(c.seq&mask,std.mem.readInt(u64,&seed,.big));
   const n=if(c.kind==.tlsl) try P.Tls13MgmL.nonce(c.write_iv,c.seq) else try P.Tls13MgmS.nonce(c.write_iv,c.seq);
   try same(&c.nonce,&n);
   const h=if(c.kind==.tlsl) try P.Tls13MgmL.header(c.plain.len) else try P.Tls13MgmS.header(c.plain.len);
   try same(c.aad,&h);
  }
 }
 var material: [44]u8=undefined; for(&material,0..) |*b,i| b.*=@intCast(i);
 const split=p.KtreeKeyMaterial.split(material);
 try same(material[0..32],&split.root_key); try same(material[32..44],&split.salt);
 var invalid=p.KtreeIv.decode(@splat(255)); invalid.pnum=0x1000000;
 try t.expectError(error.MessageCounterExhausted,invalid.encode());
 try t.expectError(error.MessageCounterExhausted,invalid.nonce(@splat(0)));
 try t.expectError(error.MessageCounterExhausted,invalid.seeds());
 std.debug.print("metadata: independent nonce/header/seeds/KEYMAT checks passed\n",.{});
}

fn aliases() !void {
 var c=C.init(@splat(0x71));
 const nonce: [16]u8=@splat(1); const salt: [12]u8=@splat(7);
 const iv=p.KtreeIv{.i1=1,.i2=2,.i3=3,.pnum=4};
 const esp=p.EspHeader{.spi=5,.sequence=.{.esn=0x1234567890abcdef}};
 var bytes: [128]u8=@splat(0x4b); const before=bytes;
 // Every one-byte overlap and every offset of a 16-byte input tag.
 for(0..64) |at| {
  const parts=[_][]const u8{bytes[at..][0..1]};
  try t.expectError(error.InvalidOverlap,M.sealParts(&c,nonce,&parts,bytes[0..64]));
  try t.expectError(error.InvalidOverlap,M.openParts(&c,nonce,&parts,bytes[0..64],bytes[96..112]));
  try same(&before,&bytes);
 }
 for(0..80) |at| {
  if(at>=64) continue;
  try t.expectError(error.InvalidOverlap,M.openParts(&c,nonce,&.{&.{1}},bytes[0..64],bytes[at..][0..16]));
  try same(&before,&bytes);
 }
 var descriptors=[_][]const u8{&.{1},&.{},&.{2}};
 const desc=std.mem.sliceAsBytes(&descriptors); const saved_desc=desc[0..48].*;
 for(0..desc.len) |at| {
  try t.expectError(error.InvalidOverlap,M.sealParts(&c,nonce,&descriptors,desc[at..][0..1]));
  try t.expectError(error.InvalidOverlap,M.openParts(&c,nonce,&descriptors,desc[at..][0..1],&@as([16]u8,@splat(0))));
  try same(&saved_desc,desc);
 }
 const keybytes=std.mem.asBytes(&c); const saved_key=keybytes.*;
 inline for(.{P.Tls13MgmL,P.Tls13MgmS}) |TLS| {
  try t.expectError(error.InvalidOverlap,TLS.seal(&c,nonce,0,keybytes[1..18]));
  try t.expectError(error.InvalidOverlap,TLS.open(&c,nonce,0,keybytes[1..18],&@as([16]u8,@splat(0))));
 }
 try t.expectError(error.InvalidOverlap,P.EspMgmKtree.seal(&c,salt,iv,esp,keybytes[1..18]));
 try t.expectError(error.InvalidOverlap,P.EspMgmKtree.open(&c,salt,iv,esp,keybytes[1..18],bytes[80..92]));
 const aad=p.IkeAad{.header=@splat(9),.encrypted_header=.{.payload=@splat(8)}};
 try t.expectError(error.InvalidOverlap,P.IkeMgmKtree.seal(&c,salt,iv,aad,keybytes[1..18]));
 try t.expectError(error.InvalidOverlap,P.IkeMgmKtree.open(&c,salt,iv,aad,keybytes[1..18],bytes[80..92]));
 try same(&saved_key,keybytes);
 // Read-only Cipher/body overlap is permitted for MAC-only.
 const mac=try P.EspMgmMacKtree.seal(&c,salt,iv,esp,keybytes);
 try P.EspMgmMacKtree.open(&c,salt,iv,esp,keybytes,&mac);
 try same(&saved_key,keybytes);
 std.debug.print("alias checks: AAD byte sliding, tags, descriptors, Cipher, read-only key/body passed\n",.{});
}
fn limits() !void {
 const nonce: [16]u8=@splat(0);
 const max: usize=std.math.maxInt(u64)/8;
 try M.validate(nonce,max,0); try M.validate(nonce,max-1,1);
 try t.expectError(error.MessageTooLong,M.validate(nonce,max,1));
 try t.expectError(error.MessageTooLong,M.validate(nonce,std.math.maxInt(usize),std.math.maxInt(usize)));
 var c=C.init(@splat(0x71)); var data: [32]u8=@splat(0x53); const saved=data;
 // Synthetic slices are rejected during length summing, never accepted or read.
 const huge: []const u8=@as([*]const u8,@ptrCast(&data))[0..std.math.maxInt(usize)];
 try t.expectError(error.MessageTooLong,M.sealParts(&c,nonce,&.{huge,data[0..1]},&data));
 try t.expectError(error.MessageTooLong,M.openParts(&c,nonce,&.{huge,data[0..1]},&data,&@as([16]u8,@splat(0))));
 const near: []const u8=@as([*]const u8,@ptrCast(&data))[0..max];
 try t.expectError(error.MessageTooLong,M.sealParts(&c,nonce,&.{near},data[0..1]));
 try t.expectError(error.MessageTooLong,M.openParts(&c,nonce,&.{near},data[0..1],&@as([16]u8,@splat(0))));
 try same(&saved,&data);
 try P.EspMgmKtree.validateLength(65508);
 try t.expectError(error.MessageTooLong,P.EspMgmKtree.validateLength(65509));
 try t.expectError(error.MessageTooLong,P.EspMgmKtree.validateLength(std.math.maxInt(usize)));
 try P.IkeMgmKtree.validateLengths(65516,0);
 try t.expectError(error.MessageTooLong,P.IkeMgmKtree.validateLengths(65517,0));
 try t.expectError(error.MessageTooLong,P.IkeMgmKtree.validateLengths(std.math.maxInt(usize),std.math.maxInt(usize)));
 inline for(.{P.Tls13MgmL,P.Tls13MgmS}) |TLS| {
  try TLS.validate(TLS.max_sequence,16385);
  try t.expectError(error.InvalidLength,TLS.validate(0,0));
  try t.expectError(error.MessageTooLong,TLS.validate(0,16386));
  const seeds=try TLS.seeds(TLS.max_sequence);
  for(seeds,TLS.tree_masks) |seed,mask| try t.expectEqual(TLS.max_sequence&mask,std.mem.readInt(u64,&seed,.big));
 }
 try t.expectError(error.SequenceExhausted,P.Tls13MgmS.validate(1<<42,1));
 try t.expectError(error.SequenceExhausted,P.Tls13MgmS.seeds(1<<42));
 // Real allocated maximum payloads, including AEAD/fragment/MAC domains.
 var big: [65509]u8=@splat(0x3a);
 const original=big;
 const iv=p.KtreeIv.decode(@splat(0xff)); const salt: [12]u8=@splat(9);
 const esp=p.EspHeader{.spi=1,.sequence=.{.esn=std.math.maxInt(u64)}};
 const tag=try P.EspMgmKtree.seal(&c,salt,iv,esp,big[0..65508]);
 const encrypted=big;
 try t.expectError(error.MessageTooLong,P.EspMgmKtree.seal(&c,salt,iv,esp,&big));
 try same(&encrypted,&big);
 try P.EspMgmKtree.open(&c,salt,iv,esp,big[0..65508],&tag); try same(&original,&big);
 const mac=try P.EspMgmMacKtree.seal(&c,salt,iv,esp,big[0..65508]);
 try P.EspMgmMacKtree.open(&c,salt,iv,esp,big[0..65508],&mac); try same(&original,&big);
 const aad=p.IkeAad{.header=@splat(2),.unencrypted_payloads=&.{1,2,3,4,5},.encrypted_header=.{.fragment=@splat(7)}};
 const n=65536-20-41;
 const itag=try P.IkeMgmKtree.seal(&c,salt,iv,aad,big[0..n]);
 const ike_enc=big;
 try t.expectError(error.MessageTooLong,P.IkeMgmKtree.seal(&c,salt,iv,aad,big[0..n+1]));
 try same(&ike_enc,&big);
 try P.IkeMgmKtree.open(&c,salt,iv,aad,big[0..n],&itag); try same(&original,&big);
 std.debug.print("limits: checked integer/parts overflow and real ESP/MAC/IKE extent maxima passed; sizeof(Cipher)={d}\n",.{@sizeOf(C)});
}
pub fn main() !void { try fixtures(); try metadata(); try aliases(); try limits(); std.debug.print("INDEPENDENT REVIEW DRIVER PASS\n",.{}); }
