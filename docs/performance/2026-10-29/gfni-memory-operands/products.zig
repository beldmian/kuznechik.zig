//! Independent polynomial oracle and actual optimized GFNI products, all lanes.
const std=@import("std");
const core=@import("toeplitz_core.zig");
fn mul(a:u8,b:u8) u8 {
    var p:u16=0;
    for(0..8) |i| { if((b>>@as(u3,@intCast(i)))&1!=0) p^=@as(u16,a)<<@intCast(i); }
    var i:usize=16;
    while(i>8) { i-=1; if((p>>@as(u4,@intCast(i)))&1!=0) p^=@as(u16,0x1c3)<<@intCast(i-8); }
    return @truncate(p);
}
fn affine(m:u64,x:u8) u8 {
 var y:u8=0;
 for(0..8) |j| {const row:u8=@truncate(m>>@as(u6,@intCast((7-j)*8)));y|=@as(u8,@intCast(@popCount(row&x)&1))<<@intCast(j);}
 return y;
}
fn matrix(c:u8) u64 {
 var m:u64=0;
 for(0..8) |i| {const y=mul(@as(u8,1)<<@intCast(i),c); for(0..8) |j| {m|=@as(u64,(y>>@as(u3,@intCast(j)))&1)<<@as(u6,@intCast((7-j)*8+i));}}
 return m;
}
inline fn mixed(x:core.W, comptime c:u8, y:core.W) core.W {
 return core.multiplyConstant(x,c)^core.multiplyConstant(y,c^0xa5)^core.multiplyConstant(x^y,c);
}
test "independent all 256 matrices, all bytes in all 64 GFNI lanes" {
 inline for(0..256) |c| {
  const m=matrix(c);
  for(0..256) |v| try std.testing.expectEqual(mul(@intCast(v),c),affine(m,@intCast(v)));
  for(0..256) |shift| {
   var x:core.W=undefined;
   for(0..64) |lane| x[lane]=@truncate(shift+lane*17);
   std.mem.doNotOptimizeAway(&x);
   const y=core.multiplyConstant(x,c);
   for(0..64) |lane| try std.testing.expectEqual(mul(x[lane],c),y[lane]);
  }
 }
}
test "repeated inlined mixed coefficients and mutable input alias pressure" {
 var rng=std.Random.DefaultPrng.init(0x944d656d);
 var x:core.W=undefined; var y:core.W=undefined;
 rng.random().bytes(std.mem.asBytes(&x)); rng.random().bytes(std.mem.asBytes(&y));
 for(0..1024) |_| {
  inline for(.{2,71,9,22,55,97,154,156,83,117,10,107,219,6,69,33}) |c| {
   const z=mixed(x,c,y);
   for(0..64) |lane| try std.testing.expectEqual(mul(x[lane],c)^mul(y[lane],c^0xa5)^mul(x[lane]^y[lane],c),z[lane]);
   x=y; y=z;
  }
 }
}
