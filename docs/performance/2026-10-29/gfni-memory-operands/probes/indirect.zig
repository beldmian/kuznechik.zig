const W = @Vector(64,u8);
const pool = [2]u64{0x1122334455667788,0x80c0e0f0f8fcfeff};
export fn probe(a: *const W, out: *W) void {
 out.* = asm ("vgf2p8affineqb $0, %[m]{1to8}, %[a], %[out]"
 : [out] "=v" (-> W),
 : [a] "v" (a.*), [m] "*m" (@as(*const u64,&pool[1])),
 : .{ .memory = true });
}
