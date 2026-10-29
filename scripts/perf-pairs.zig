//! Compare two source trees through their public batch APIs in one process.
//! See docs/PERFORMANCE.md for the build command. JSONL goes to stderr.
const std = @import("std");
const builtin = @import("builtin");
const baseline = @import("baseline");
const candidate = @import("candidate");
const B = baseline.block;
const samples = 31;

noinline fn apply(comptime inverse: bool, cipher: anytype, messages: []align(16) B) void {
    asm volatile ("" ::: .{ .memory = true });
    const Cipher = @typeInfo(@TypeOf(cipher)).pointer.child;
    if (comptime @hasDecl(Cipher, "encryptBlocks") and @hasDecl(Cipher, "decryptBlocks")) {
        if (inverse) cipher.decryptBlocks(messages) else cipher.encryptBlocks(messages);
    } else {
        for (messages) |*message| {
            if (inverse) cipher.decrypt(message) else cipher.encrypt(message);
        }
    }
}

noinline fn run(comptime inverse: bool, cipher: anytype, messages: []align(16) B, repetitions: usize) !u64 {
    var timer = try std.time.Timer.start();
    for (0..repetitions) |_| apply(inverse, cipher, messages);
    const elapsed = timer.read();
    std.mem.doNotOptimizeAway(messages.ptr);
    asm volatile ("" ::: .{ .memory = true });
    return elapsed;
}

fn checksum(messages: []const B) u64 {
    var hash: u64 = 0xcbf29ce484222325;
    for (std.mem.sliceAsBytes(messages)) |byte| hash = (hash ^ byte) *% 0x100000001b3;
    return hash;
}

fn compare(comptime inverse: bool, before_cipher: *const baseline.Cipher, after_cipher: *const candidate.Cipher, initial: []const B) !void {
    const allocator = std.heap.page_allocator;
    const before = try allocator.alignedAlloc(B, .@"64", initial.len);
    defer allocator.free(before);
    const after = try allocator.alignedAlloc(B, .@"64", initial.len);
    defer allocator.free(after);
    const repetitions = @max(1, (1048576 + initial.len - 1) / initial.len);
    var a: [samples]u64 = undefined;
    var b: [samples]u64 = undefined;
    var ratios: [samples]f64 = undefined;
    @memcpy(before, initial);
    @memcpy(after, initial);
    _ = try run(inverse, before_cipher, before, 1);
    _ = try run(inverse, after_cipher, after, 1);
    if (!std.mem.eql(B, before, after)) return error.CipherMismatch;
    for (0..samples) |sample| {
        @memcpy(before, initial);
        @memcpy(after, initial);
        // Balance allocation/page placement independently of execution order.
        const before_messages = if (sample % 4 < 2) before else after;
        const after_messages = if (sample % 4 < 2) after else before;
        if (sample % 2 == 0) {
            a[sample] = try run(inverse, before_cipher, before_messages, repetitions);
            b[sample] = try run(inverse, after_cipher, after_messages, repetitions);
        } else {
            b[sample] = try run(inverse, after_cipher, after_messages, repetitions);
            a[sample] = try run(inverse, before_cipher, before_messages, repetitions);
        }
        if (!std.mem.eql(B, before, after)) return error.CipherMismatch;
        ratios[sample] = @as(f64, @floatFromInt(b[sample])) / @as(f64, @floatFromInt(a[sample]));
    }
    var sorted_a = a;
    var sorted_b = b;
    std.mem.sort(u64, &sorted_a, {}, std.sort.asc(u64));
    std.mem.sort(u64, &sorted_b, {}, std.sort.asc(u64));
    std.mem.sort(f64, &ratios, {}, std.sort.asc(f64));
    const count: f64 = @floatFromInt(initial.len * repetitions);
    std.debug.print(
        "{{\"type\":\"paired_result\",\"operation\":\"{s}\",\"length\":{d},\"repetitions\":{d},\"samples\":{d},\"before_ns_per_block\":{d:.6},\"after_ns_per_block\":{d:.6},\"median_paired_ratio\":{d:.9},\"checksum\":\"{x:0>16}\",\"before\":[",
        .{ if (inverse) "decrypt" else "encrypt", initial.len, repetitions, samples, @as(f64, @floatFromInt(sorted_a[samples / 2])) / count, @as(f64, @floatFromInt(sorted_b[samples / 2])) / count, ratios[samples / 2], checksum(after) },
    );
    for (a, 0..) |elapsed, i| std.debug.print("{s}{d}", .{ if (i == 0) "" else ",", elapsed });
    std.debug.print("],\"after\":[", .{});
    for (b, 0..) |elapsed, i| std.debug.print("{s}{d}", .{ if (i == 0) "" else ",", elapsed });
    std.debug.print("]}}\n", .{});
}

pub fn main() !void {
    var args = std.process.args();
    _ = args.next();
    const seed = if (args.next()) |value| try std.fmt.parseInt(u64, value, 10) else 123;
    if (args.next() != null) return error.UnexpectedArgument;
    std.debug.print("{{\"type\":\"paired_config\",\"zig\":\"{s}\",\"cpu\":\"{s}\",\"optimize\":\"{s}\",\"backend\":\"{s}\",\"seed\":{d},\"samples\":{d},\"minimum_blocks\":1048576,\"alternates_buffers\":true}}\n", .{ builtin.zig_version_string, builtin.cpu.model.name, @tagName(builtin.mode), @tagName(builtin.zig_backend), seed, samples });
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();
    var key: baseline.key = undefined;
    random.bytes(std.mem.asBytes(&key));
    const before_cipher = baseline.Cipher.init(key);
    const after_cipher = candidate.Cipher.init(key);
    const initial = try std.heap.page_allocator.alignedAlloc(B, .@"64", 8388608);
    defer std.heap.page_allocator.free(initial);
    random.bytes(std.mem.sliceAsBytes(initial));
    for ([_]usize{ 64, 256, 511, 512, 513, 1023, 1024, 1025, 4096, 16384, 131072, 1048576, 8388608 }) |length| {
        inline for (.{ false, true }) |inverse| try compare(inverse, &before_cipher, &after_cipher, initial[0..length]);
    }
}
