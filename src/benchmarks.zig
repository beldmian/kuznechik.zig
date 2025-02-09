const std = @import("std");
const kuznechik = @import("kuznechik.zig");
const zbench = @import("zbench");

var msg: kuznechik.block = @as(kuznechik.block, @splat(0));

const EncryptBenchmark = struct {
    cipher: kuznechik.Cipher,

    fn init(k: kuznechik.key) EncryptBenchmark {
        return .{ .cipher = kuznechik.Cipher.init(k) };
    }

    pub fn run(self: EncryptBenchmark, _: std.mem.Allocator) void {
        self.cipher.encrypt(&msg);
    }
};

const DecryptBenchmark = struct {
    cipher: kuznechik.Cipher,

    fn init(k: kuznechik.key) DecryptBenchmark {
        return .{ .cipher = kuznechik.Cipher.init(k) };
    }

    pub fn run(self: DecryptBenchmark, _: std.mem.Allocator) void {
        self.cipher.decrypt(&msg);
    }
};

fn beforeEach() void {
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();
    for (0..16) |i| {
        msg[i] = rand.int(u8);
    }
}

pub fn main() !void {
    const k = kuznechik.key{ 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef };
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();

    try bench.addParam("Encrypt Benchmark", &EncryptBenchmark.init(k), .{});
    try bench.addParam("Decrypt Benchmark", &DecryptBenchmark.init(k), .{});

    try stdout.writeAll("\n");
    try bench.run(stdout);
}
