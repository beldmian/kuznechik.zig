const std = @import("std");
const C = @import("kuz").Cipher;
const First = @import("first").Ocb(C);
const Second = @import("second").Ocb(C);
const Slot = struct {
    cipher: C,
    nonce: [12]u8,
    plain: []u8,
    sealed: []u8,
    work: []u8,
    aad: []u8,
    tag: [16]u8,
    result_tag: [16]u8,
};
var checksum: u64 = 0;
const Case = struct { p: usize, a: usize };
fn cases() [89]Case {
    var out: [89]Case = undefined;
    var i: usize = 0;
    for ([_]usize{ 0, 1, 15, 16, 17 }) |p| for ([_]usize{ 0, 1, 15, 16, 17 }) |a| {
        out[i] = .{ .p = p, .a = a };
        i += 1;
    };
    for ([_]usize{ 64, 256, 1024, 1500, 4096, 16384 }) |p| for ([_]usize{ 0, 16, 17 }) |a| {
        out[i] = .{ .p = p, .a = a };
        i += 1;
    };
    for ([_]usize{ 7, 8, 9, 31, 32, 33, 63, 64, 65, 127, 128, 129, 255, 256, 257, 1023, 1024, 1025, 4095, 4096, 4097 }) |blocks| {
        out[i] = .{ .p = blocks * 16 + 1, .a = 17 };
        out[i + 1] = .{ .p = 17, .a = blocks * 16 + 15 };
        i += 2;
    }
    for ([_]Case{ .{ .p = 1048576, .a = 0 }, .{ .p = 1048576, .a = 17 }, .{ .p = 0, .a = 1048576 }, .{ .p = 1048576, .a = 1048576 } }) |c| {
        out[i] = c;
        i += 1;
    }
    std.debug.assert(i == out.len);
    return out;
}
// No allocator, key setup, reference work, full-output comparison, or hashing
// in this timed loop. Both paths include the same input reset and pool dispatch.
noinline fn runFirst(slots: []Slot, iterations: usize, opening: bool) !u64 {
    return run(First, slots, iterations, opening);
}
noinline fn runSecond(slots: []Slot, iterations: usize, opening: bool) !u64 {
    return run(Second, slots, iterations, opening);
}
fn run(comptime M: type, slots: []Slot, iterations: usize, opening: bool) !u64 {
    var timer = try std.time.Timer.start();
    for (0..iterations) |i| {
        const s = &slots[i % slots.len];
        if (opening) {
            @memcpy(s.work, s.sealed);
            try M.open(&s.cipher, &s.nonce, s.aad, s.work, s.tag);
        } else {
            @memcpy(s.work, s.plain);
            // Unique encryption nonces within this run, also varying bottom bits.
            const seq = std.mem.readInt(u64, s.nonce[4..12], .big) +% 1;
            std.mem.writeInt(u64, s.nonce[4..12], seq, .big);
            s.result_tag = try M.seal(&s.cipher, &s.nonce, s.aad, s.work);
        }
        std.mem.doNotOptimizeAway(s.work.ptr);
        std.mem.doNotOptimizeAway(&s.result_tag);
    }
    return timer.read();
}
fn validate(slots: []Slot, opening: bool) !void {
    for (slots) |*s| {
        if (opening) {
            if (!std.mem.eql(u8, s.plain, s.work)) return error.BadPlaintext;
        } else {
            @memcpy(s.sealed, s.plain);
            const expected = try First.seal(&s.cipher, &s.nonce, s.aad, s.sealed);
            if (!std.mem.eql(u8, s.sealed, s.work) or !std.mem.eql(u8, &expected, &s.result_tag)) return error.BadCiphertext;
        }
        checksum +%= std.hash.Wyhash.hash(0, s.work);
        checksum +%= std.hash.Wyhash.hash(0, &s.result_tag);
    }
}
pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);
    const seed = if (args.len > 1) try std.fmt.parseInt(u64, args[1], 0) else 7253;
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();
    var slots: [8]Slot = undefined;
    for (&slots) |*s| {
        var key: @Vector(32, u8) = undefined;
        random.bytes(std.mem.asBytes(&key));
        s.* = .{ .cipher = C.init(key), .nonce = undefined, .plain = try alloc.alloc(u8, 1048576), .sealed = try alloc.alloc(u8, 1048576), .work = try alloc.alloc(u8, 1048576), .aad = try alloc.alloc(u8, 1048576), .tag = undefined, .result_tag = @splat(0) };
        random.bytes(&s.nonce);
        random.bytes(s.plain);
        random.bytes(s.aad);
    }
    std.debug.print("seed,payload,aad,operation,pair,first_then_second,iterations,first_ns,second_ns\n", .{});
    for (cases()) |c| {
        for (&slots) |*s| {
            s.plain = s.plain.ptr[0..c.p];
            s.sealed = s.sealed.ptr[0..c.p];
            s.work = s.work.ptr[0..c.p];
            s.aad = s.aad.ptr[0..c.a];
        }
        for ([_]bool{ false, true }) |opening| {
            // Every opening sample uses valid ciphertexts prepared outside timing.
            for (&slots) |*s| {
                @memcpy(s.sealed, s.plain);
                s.tag = try First.seal(&s.cipher, &s.nonce, s.aad, s.sealed);
            }
            _ = try runFirst(&slots, 8, opening);
            try validate(&slots, opening);
            _ = try runSecond(&slots, 8, opening);
            try validate(&slots, opening);
            const warm = try runFirst(&slots, 8, opening);
            try validate(&slots, opening);
            // Target 4ms per side, eight-slot multiple; minimum eight calls.
            const iterations = @max(8, @min(32768, (32000000 / @max(1, warm)) / 8 * 8));
            for (0..7) |pair| {
                var a: u64 = undefined;
                var b: u64 = undefined;
                // Restore nonce and source state so both variants do identical work.
                var nonces: [8][12]u8 = undefined;
                for (&slots, 0..) |s, i| nonces[i] = s.nonce;
                if (pair % 2 == 0) {
                    a = try runFirst(&slots, iterations, opening);
                    try validate(&slots, opening);
                    for (&slots, 0..) |*s, i| s.nonce = nonces[i];
                    b = try runSecond(&slots, iterations, opening);
                    try validate(&slots, opening);
                } else {
                    b = try runSecond(&slots, iterations, opening);
                    try validate(&slots, opening);
                    for (&slots, 0..) |*s, i| s.nonce = nonces[i];
                    a = try runFirst(&slots, iterations, opening);
                    try validate(&slots, opening);
                }
                std.debug.print("{d},{d},{d},{s},{d},{},{d},{d},{d}\n", .{ seed, c.p, c.a, if (opening) "open" else "seal", pair, pair % 2 == 0, iterations, a, b });
            }
        }
    }
    std.debug.print("checksum={x}\n", .{checksum});
}
