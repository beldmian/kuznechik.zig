const std = @import("std");
const Before = @import("baseline/src/kuznechik.zig");
const After = @import("candidate/src/kuznechik.zig");
const Result = struct { ns: u64, state: [32]u8 = @splat(0), head: usize = 0 };
noinline fn blocks(comptime M: type, c: M.Cipher, data: []align(16) M.block, n: usize, jobs: usize, reps: usize, inverse: bool, singleton: bool) !Result {
    asm volatile ("" ::: .{ .memory = true });
    var timer = try std.time.Timer.start();
    for (0..reps) |_| {
        for (0..jobs) |j| {
            const slice = data[j*n..][0..n];
            if (singleton) {
                if (inverse) c.decrypt(&slice[0]) else c.encrypt(&slice[0]);
            } else {
                if (inverse) c.decryptBlocks(slice) else c.encryptBlocks(slice);
            }
        }
        std.mem.doNotOptimizeAway(data.ptr);
        asm volatile ("" ::: .{ .memory = true });
    }
    return .{.ns=timer.read()};
}
noinline fn cbc(comptime M: type, c: M.Cipher, iv: [32]u8, initial: []const u8, data: []u8, reps: usize, inverse: bool) !Result {
    var last: M.modes.CbcWithIv(2) = undefined;
    asm volatile ("" ::: .{ .memory = true });
    var timer = try std.time.Timer.start();
    for (0..reps) |_| {
        @memcpy(data, initial);
        last = M.modes.CbcWithIv(2).init(c, iv);
        if (inverse) try last.decrypt(data) else try last.encrypt(data);
        std.mem.doNotOptimizeAway(data.ptr);
        asm volatile ("" ::: .{ .memory = true });
    }
    const elapsed=timer.read();
    return .{.ns=elapsed,.state=@bitCast(last.register),.head=last.head};
}
pub fn main() !void {
    var args=std.process.args(); _=args.next();
    const seed=try std.fmt.parseInt(u64,args.next() orelse "123",10);
    const layout=try std.fmt.parseInt(usize,args.next() orelse "0",10);
    const budget=try std.fmt.parseInt(usize,args.next() orelse "262144",10);
    const samples=try std.fmt.parseInt(usize,args.next() orelse "15",10);
    var rng=std.Random.DefaultPrng.init(seed);
    var key: Before.key=undefined; rng.random().bytes(std.mem.asBytes(&key));
    const a_cipher=Before.Cipher.init(key); const b_cipher=After.Cipher.init(key);
    var iv: [32]u8=undefined; rng.random().bytes(&iv);
    const size=8192+16;
    const init=try std.heap.page_allocator.alignedAlloc(Before.block,.@"64",size);
    const a_mem=try std.heap.page_allocator.alignedAlloc(Before.block,.@"64",size);
    const b_mem=try std.heap.page_allocator.alignedAlloc(Before.block,.@"64",size);
    rng.random().bytes(std.mem.sliceAsBytes(init));
    const a=if(layout<2) a_mem else b_mem; const b=if(layout<2) b_mem else a_mem;
    inline for (0..4) |kind| {
        for ([_]usize{1,2,3,4,5,8,16,24,25,31,63,64,65,1024}) |n| {
            if ((kind==1 and n!=2) or (kind==2 and n!=1)) continue;
            // kind 3 uses n blocks per complete CBC operation, including short controls.
            const jobs: usize=if(kind==1) 64 else 1;
            const reps=@max(4,budget/(n*jobs));
            const off=1+layout%4;
            inline for (.{false,true}) |inverse| {
                var checksum:u64=0;
                for (0..samples+2) |j| {
                    @memcpy(a,init); @memcpy(b,init);
                    var x:Result=undefined; var y:Result=undefined;
                    const bytes=n*16;
                    const byteoff=off*16+1;
                    if ((j+seed)%2==0) {
                        x=if(kind==3) try cbc(Before,a_cipher,iv,std.mem.sliceAsBytes(init)[byteoff..][0..bytes],std.mem.sliceAsBytes(a)[byteoff..][0..bytes],reps,inverse) else try blocks(Before,a_cipher,a[off..][0..n*jobs],n,jobs,reps,inverse,kind==2);
                        y=if(kind==3) try cbc(After,b_cipher,iv,std.mem.sliceAsBytes(init)[byteoff..][0..bytes],std.mem.sliceAsBytes(b)[byteoff..][0..bytes],reps,inverse) else try blocks(After,b_cipher,b[off..][0..n*jobs],n,jobs,reps,inverse,kind==2);
                    } else {
                        y=if(kind==3) try cbc(After,b_cipher,iv,std.mem.sliceAsBytes(init)[byteoff..][0..bytes],std.mem.sliceAsBytes(b)[byteoff..][0..bytes],reps,inverse) else try blocks(After,b_cipher,b[off..][0..n*jobs],n,jobs,reps,inverse,kind==2);
                        x=if(kind==3) try cbc(Before,a_cipher,iv,std.mem.sliceAsBytes(init)[byteoff..][0..bytes],std.mem.sliceAsBytes(a)[byteoff..][0..bytes],reps,inverse) else try blocks(Before,a_cipher,a[off..][0..n*jobs],n,jobs,reps,inverse,kind==2);
                    }
                    if (!std.mem.eql(u8,std.mem.sliceAsBytes(a),std.mem.sliceAsBytes(b)) or !std.meta.eql(x.state,y.state) or x.head!=y.head) return error.CompleteOutputMismatch;
                    const lo=if(kind==3) byteoff else off*16;
                    const hi=lo+(if(kind==3) bytes else n*jobs*16);
                    if(!std.mem.eql(u8,std.mem.sliceAsBytes(a)[0..lo],std.mem.sliceAsBytes(init)[0..lo]) or !std.mem.eql(u8,std.mem.sliceAsBytes(a)[hi..],std.mem.sliceAsBytes(init)[hi..])) return error.GuardMismatch;
                    checksum +%= std.hash.Wyhash.hash(j,std.mem.sliceAsBytes(b));
                    checksum +%= std.hash.Wyhash.hash(j,&y.state);
                    if(j>=2) std.debug.print("{{\"kind\":{d},\"n\":{d},\"inverse\":{},\"seed\":{d},\"layout\":{d},\"pair\":{d},\"reps\":{d},\"jobs\":{d},\"before\":{d},\"after\":{d},\"checksum\":{d}}}\n",.{kind,n,inverse,seed,layout,j-2,reps,jobs,x.ns,y.ns,checksum});
                }
            }
        }
    }
}
