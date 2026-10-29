const std=@import("std");
const C=@import("kuznechik.zig").Cipher;
const M=@import("modes/mgm.zig").Mgm(C);
pub fn main() !void {
 const c=C.init(@splat(0x71));
 const nonce: [16]u8=@splat(0x4b);
 var reference: [64]u8=@splat(0x4b);
 var aliased: [64]u8=@splat(0x4b);
 const expected=try M.sealParts(&c,nonce,&.{&.{1}},&reference);
 const actual=try M.sealParts(&c,aliased[0..16].*,&.{&.{1}},&aliased);
 std.debug.print("expected tag={x}\naliased tag={x}\nciphertext equal={}\n",.{expected,actual,std.mem.eql(u8,&reference,&aliased)});
 if(M.openParts(&c,nonce,&.{&.{1}},&aliased,&actual)) |_| {
  std.debug.print("open with original nonce succeeded\n",.{});
 } else |err| { std.debug.print("open with original nonce: {s}\n",.{@errorName(err)}); }
 try std.testing.expectEqual(expected,actual);
}
