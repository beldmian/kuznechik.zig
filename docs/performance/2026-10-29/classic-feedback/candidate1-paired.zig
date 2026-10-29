const std = @import("std");
const kuz = @import("kuz");
const Before = @import("before").Modes(kuz.Cipher);
const After = kuz.modes.classic;
const Result = struct { ns: u64, tag: [16]u8 };
// Each repetition measures a complete operation with a new mode context, input
// copy, and (for CMAC) subkey setup and finalization. Key expansion is outside.
noinline fn run(comptime M: type, comptime kind: usize, comptime width: usize, cipher: kuz.Cipher, iv: [width * 16]u8, plain: []const u8, data: []u8, reps: usize, split: bool) !Result {
    var tag: [16]u8 = @splat(0);
    asm volatile ("" ::: .{ .memory = true });
    var timer = try std.time.Timer.start();
    for (0..reps) |_| {
        @memcpy(data, plain);
        if (kind == 0) {
            var ctx = M.Cfb(width).init(cipher, iv);
            if (split) ctx.encrypt(data[0..1]);
            ctx.encrypt(data[@intFromBool(split)..]);
        } else if (kind == 1) {
            var ctx = M.Ofb(width).init(cipher, iv);
            if (split) ctx.xor(data[0..1]);
            ctx.xor(data[@intFromBool(split)..]);
        } else {
            var ctx = M.Cmac.init(cipher);
            if (split) ctx.update(data[0..1]);
            ctx.update(data[@intFromBool(split)..]);
            tag = ctx.final();
        }
        std.mem.doNotOptimizeAway(data.ptr);
        std.mem.doNotOptimizeAway(&tag);
        asm volatile ("" ::: .{ .memory = true });
    }
    return .{ .ns = timer.read(), .tag = tag };
}
pub fn main() !void {
    var args = std.process.args();
    _ = args.next();
    const seed = if (args.next()) |s| try std.fmt.parseInt(u64, s, 10) else 123;
    const budget = if (args.next()) |s| try std.fmt.parseInt(usize, s, 10) else 262144;
    const only = if (args.next()) |s| try std.fmt.parseInt(usize, s, 10) else 99;
    const layout = if (args.next()) |s| try std.fmt.parseInt(usize, s, 10) else 0;
    var rng = std.Random.DefaultPrng.init(seed);
    var key: kuz.key = undefined;
    rng.random().bytes(std.mem.asBytes(&key));
    const cipher = kuz.Cipher.init(key);
    const initial = try std.heap.page_allocator.alloc(u8, 16384 + 16);
    const a_mem = try std.heap.page_allocator.alloc(u8, initial.len);
    const b_mem = try std.heap.page_allocator.alloc(u8, initial.len);
    rng.random().bytes(initial);
    const names = [_][]const u8{ "CFB-encrypt", "OFB-xor", "CMAC" };
    inline for (0..3) |kind| {
        if (only == 99 or only == kind) {
            inline for (.{ 1, 2, 3, 65 }) |width| {
                if (kind != 2 or width == 1) {
                    var iv: [width * 16]u8 = undefined;
                    rng.random().bytes(&iv);
                    for ([_]usize{ 16, 64, 1024, 16384 }) |n| {
                        for ([_]bool{ false, true }) |split| {
                            const off = if (layout % 2 == 0) @as(usize, 0) else 1;
                            // Swap output buffers in the second layout to control address effects.
                            const a = (if (layout < 2) a_mem else b_mem)[off..][0..n];
                            const b = (if (layout < 2) b_mem else a_mem)[off..][0..n];
                            const plain = initial[off..][0..n];
                            const reps = @max(8, budget / n);
                            var before: [7]u64 = undefined;
                            var after: [7]u64 = undefined;
                            var checksum: u64 = 0;
                            for (0..9) |j| {
                                var x: Result = undefined;
                                var y: Result = undefined;
                                if ((j + seed) % 2 == 0) {
                                    x = try run(Before, kind, width, cipher, iv, plain, a, reps, split);
                                    y = try run(After, kind, width, cipher, iv, plain, b, reps, split);
                                } else {
                                    y = try run(After, kind, width, cipher, iv, plain, b, reps, split);
                                    x = try run(Before, kind, width, cipher, iv, plain, a, reps, split);
                                }
                                if (!std.mem.eql(u8, a, b) or !std.meta.eql(x.tag, y.tag)) return error.FullOutputMismatch;
                                checksum +%= std.hash.Wyhash.hash(j, b);
                                checksum +%= std.hash.Wyhash.hash(j, &y.tag);
                                if (j < 2) continue;
                                before[j - 2] = x.ns;
                                after[j - 2] = y.ns;
                            }
                            std.debug.print("{{\"mode\":\"{s}\",\"m\":{d},\"bytes\":{d},\"split1\":{},\"layout\":{d},\"offset\":{d},\"seed\":{d},\"reps\":{d},\"checksum\":{d},\"before\":{any},\"after\":{any}}}\n", .{ names[kind], width, n, split, layout, off, seed, reps, checksum, before, after });
                        }
                    }
                }
            }
        }
    }
}
