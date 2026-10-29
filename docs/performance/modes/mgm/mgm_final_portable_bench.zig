const std = @import("std");
const Kuz = @import("kuznechik.zig").Cipher;
const Cipher = Kuz;
const Mode = @import("modes/mgm_final_portable.zig").Mgm(Cipher);
var data: [1024 * 1024]u8 align(64) = @splat(0xa5);
pub fn main() !void {
    const cipher = Cipher.init(@splat(42));
    const aad: [32]u8 = @splat(0x5a);
    const nonce: [16]u8 = @splat(0x11);
    for ([_]usize{ 32, 128, 1024, 16384, 1048576 }) |length| {
        const iterations = @max(32, 33554432 / length);
        for (0..@max(1, iterations / 8)) |_| {
            const tag = try Mode.seal(&cipher, nonce, &aad, data[0..length]);
            std.mem.doNotOptimizeAway(tag);
        }
        var samples: [7]u64 = undefined;
        for (&samples) |*sample| {
            var timer = try std.time.Timer.start();
            for (0..iterations) |_| {
                const tag = try Mode.seal(&cipher, nonce, &aad, data[0..length]);
                std.mem.doNotOptimizeAway(tag);
            }
            sample.* = timer.read();
            std.mem.doNotOptimizeAway(data[0..length]);
        }
        std.mem.sort(u64, &samples, {}, std.sort.asc(u64));
        const bytes: f64 = @floatFromInt(iterations * length);
        const ns: f64 = @floatFromInt(samples[3]);
        std.debug.print("length={d} iterations={d} median_ns={d} MiB_s={d:.3} ns_samples={any}\n", .{ length, iterations, samples[3], bytes * 1e9 / ns / 1048576, samples });
    }
}
