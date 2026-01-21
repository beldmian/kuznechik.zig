const std = @import("std");
const kuznechik = @import("kuznechik");

var msg: kuznechik.block = @as(kuznechik.block, @splat(0));

const EncryptBenchmark = struct {
    cipher: kuznechik.Cipher,

    fn init(k: kuznechik.key) EncryptBenchmark {
        return .{ .cipher = kuznechik.Cipher.init(k) };
    }

    pub fn run(self: EncryptBenchmark) void {
        self.cipher.encrypt(&msg);
    }
};

const DecryptBenchmark = struct {
    cipher: kuznechik.Cipher,

    fn init(k: kuznechik.key) DecryptBenchmark {
        return .{ .cipher = kuznechik.Cipher.init(k) };
    }

    pub fn run(self: DecryptBenchmark) void {
        self.cipher.decrypt(&msg);
    }
};

fn beforeEach() void {
    const rand = std.crypto.random;

    for (0..16) |i| {
        msg[i] = rand.int(u8);
    }
}

fn runBenchmark(name: []const u8, runner: anytype, iterations: usize) !void {
    var timer = try std.time.Timer.start();
    var min_time: u64 = std.math.maxInt(u64);
    var max_time: u64 = 0;
    var total_time: u64 = 0;

    const print = std.debug.print;

    print("Running benchmark: {s} ({d} iterations)\n", .{ name, iterations });

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        beforeEach();

        var j: usize = 0;
        timer.reset();
        while (j < 1000) : (j += 1) {
            runner.run();
        }
        const elapsed = timer.read() / 1000;

        min_time = @min(min_time, elapsed);
        max_time = @max(max_time, elapsed);
        total_time += elapsed;
    }

    const avg_time = total_time / iterations;
    print("{s}:\n", .{name});
    print("  Iterations: {d}\n", .{iterations});
    print("  Total time: {d} ns\n", .{total_time});
    print("  Average time: {d} ns\n", .{avg_time});
    print("  Min time: {d} ns\n", .{min_time});
    print("  Max time: {d} ns\n", .{max_time});
    print("\n", .{});
}

pub fn main() !void {
    const k = kuznechik.key{ 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef };
    const iterations = 1000;

    try runBenchmark("Encrypt Benchmark", EncryptBenchmark.init(k), iterations);
    // try runBenchmark("Decrypt Benchmark", DecryptBenchmark.init(k), iterations);
}
