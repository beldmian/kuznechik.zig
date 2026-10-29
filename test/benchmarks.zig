const std = @import("std");
const builtin = @import("builtin");
const kuznechik = @import("kuznechik");

const Operation = enum { encrypt, decrypt };
const Mode = enum { encrypt, decrypt, both };
const Api = enum { single, bulk };
const ApiMode = enum { single, bulk, both };
const max_samples = 101;
const default_widths = [_]usize{ 1, 2, 4, 8, 16, 32, 256 };
const supported_widths = [_]usize{ 1, 2, 3, 4, 5, 7, 8, 15, 16, 31, 32, 63, 64, 256 };

const Options = struct {
    blocks: usize = 262144,
    samples: usize = 9,
    seed: u64,
    mode: Mode = .both,
    width: ?usize = null,
    api: ApiMode = .single,
};

fn usage() void {
    std.debug.print(
        \\Usage: benchmark [--blocks N] [--samples N] [--seed N] [--mode encrypt|decrypt|both] [--width N] [--api single|bulk|both]
        \\  --blocks N   Minimum blocks per timed sample (default 262144).
        \\  --samples N  Number of samples, 3..101 (default 9).
        \\  --seed N     Reproducible runtime input seed (default random).
        \\  --mode MODE  Operations to measure (default both).
        \\  --width N    Measure width 1, 2, 3, 4, 5, 7, 8, 15, 16,
        \\               31, 32, 63, 64, or 256.
        \\               Defaults: 1, 2, 4, 8, 16, 32, 256.
        \\  --api API    API to measure (default single); bulk falls back to
        \\               single-block calls if the library has no bulk API.
        \\Outputs JSON lines to stderr. Width 1 measures a dependent chain;
        \\larger widths measure independent chains using the selected API.
        \\
    , .{});
}

fn parseOptions() !?Options {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var options = Options{ .seed = std.crypto.random.int(u64) };
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            usage();
            return null;
        }
        if (i + 1 == args.len) return error.MissingArgumentValue;
        const value = args[i + 1];
        if (std.mem.eql(u8, arg, "--blocks")) {
            options.blocks = try std.fmt.parseInt(usize, value, 0);
            if (options.blocks == 0 or options.blocks > std.math.maxInt(usize) - 255) return error.InvalidBlockCount;
        } else if (std.mem.eql(u8, arg, "--samples")) {
            options.samples = try std.fmt.parseInt(usize, value, 0);
            if (options.samples < 3 or options.samples > max_samples) return error.InvalidSampleCount;
        } else if (std.mem.eql(u8, arg, "--seed")) {
            options.seed = try std.fmt.parseInt(u64, value, 0);
        } else if (std.mem.eql(u8, arg, "--mode")) {
            options.mode = std.meta.stringToEnum(Mode, value) orelse return error.InvalidMode;
        } else if (std.mem.eql(u8, arg, "--width")) {
            const width = try std.fmt.parseInt(usize, value, 0);
            if (std.mem.indexOfScalar(usize, &supported_widths, width) == null) return error.InvalidWidth;
            options.width = width;
        } else if (std.mem.eql(u8, arg, "--api")) {
            options.api = std.meta.stringToEnum(ApiMode, value) orelse return error.InvalidApi;
        } else {
            return error.UnknownArgument;
        }
        i += 1;
    }
    return options;
}

fn bulkAvailable(comptime operation: Operation) bool {
    return switch (operation) {
        .encrypt => @hasDecl(kuznechik.Cipher, "encryptBlocks"),
        .decrypt => @hasDecl(kuznechik.Cipher, "decryptBlocks"),
    };
}

/// Each lane depends on its previous result; lanes do not depend on each other.
/// The checksum observes every output lane. A separate compilation boundary
/// keeps setup and timing outside the workload.
noinline fn run(
    comptime operation: Operation,
    comptime api: Api,
    comptime width: usize,
    cipher: *const kuznechik.Cipher,
    states: *[width]kuznechik.block,
    rounds: usize,
) void {
    var local = states.*;
    for (0..rounds) |_| {
        if (comptime api == .bulk and bulkAvailable(operation)) {
            switch (operation) {
                .encrypt => cipher.encryptBlocks(&local),
                .decrypt => cipher.decryptBlocks(&local),
            }
        } else {
            inline for (0..width) |lane| {
                switch (operation) {
                    .encrypt => cipher.encrypt(&local[lane]),
                    .decrypt => cipher.decrypt(&local[lane]),
                }
            }
        }
    }
    states.* = local;
    std.mem.doNotOptimizeAway(states);
}

fn checksum(comptime width: usize, states: [width]kuznechik.block) u64 {
    var result: u64 = 0xcbf29ce484222325;
    for (states) |state| {
        const bytes: [16]u8 = state;
        for (bytes) |byte| result = (result ^ byte) *% 0x100000001b3;
    }
    return result;
}

fn measure(comptime operation: Operation, comptime api: Api, comptime width: usize, cipher: *const kuznechik.Cipher, options: Options) !void {
    var prng = std.Random.DefaultPrng.init(options.seed ^ @as(u64, width));
    var initial: [width]kuznechik.block align(16) = undefined;
    prng.random().bytes(std.mem.asBytes(&initial));
    const rounds = (options.blocks + width - 1) / width;
    const block_count = rounds * width;

    var states = initial;
    run(operation, api, width, cipher, &states, @max(1, rounds / 8));

    var samples: [max_samples]u64 = undefined;
    var observed: u64 = 0;
    var timer = try std.time.Timer.start();
    for (0..options.samples) |sample| {
        states = initial;
        // Observe inputs before starting the clock. The output barrier in run
        // and the checksum prevent elimination of timed work.
        std.mem.doNotOptimizeAway(&states);
        timer.reset();
        run(operation, api, width, cipher, &states, rounds);
        samples[sample] = timer.read();
        observed +%= checksum(width, states);
    }
    var sorted: [max_samples]u64 = undefined;
    @memcpy(sorted[0..options.samples], samples[0..options.samples]);
    std.mem.sort(u64, sorted[0..options.samples], {}, std.sort.asc(u64));
    const minimum: f64 = @as(f64, @floatFromInt(sorted[0])) / @as(f64, @floatFromInt(block_count));
    const middle = options.samples / 2;
    const median_elapsed = if (options.samples % 2 == 1)
        @as(f64, @floatFromInt(sorted[middle]))
    else
        (@as(f64, @floatFromInt(sorted[middle - 1])) + @as(f64, @floatFromInt(sorted[middle]))) / 2.0;
    const median = median_elapsed / @as(f64, @floatFromInt(block_count));
    const mib_per_second = (16.0 * 1_000_000_000.0 / (1024.0 * 1024.0)) / median;
    std.debug.print(
        "{{\"type\":\"result\",\"operation\":\"{s}\",\"api\":\"{s}\",\"bulk_available\":{s},\"width\":{d},\"blocks\":{d},\"samples\":{d},\"median_ns_per_block\":{d:.3},\"min_ns_per_block\":{d:.3},\"median_mib_per_s\":{d:.3},\"checksum\":\"{x:0>16}\",\"elapsed_ns\":[",
        .{ @tagName(operation), @tagName(api), if (bulkAvailable(operation)) "true" else "false", width, block_count, options.samples, median, minimum, mib_per_second, observed },
    );
    for (samples[0..options.samples], 0..) |elapsed, i| {
        std.debug.print("{s}{d}", .{ if (i == 0) "" else ",", elapsed });
    }
    std.debug.print("]}}\n", .{});
}

pub fn main() !void {
    const options = (parseOptions() catch |err| {
        usage();
        return err;
    }) orelse return;
    var prng = std.Random.DefaultPrng.init(options.seed);
    var key_bytes: [32]u8 = undefined;
    prng.random().bytes(&key_bytes);
    const cipher = kuznechik.Cipher.init(key_bytes);
    std.debug.print(
        "{{\"type\":\"config\",\"zig\":\"{s}\",\"arch\":\"{s}\",\"cpu\":\"{s}\",\"optimize\":\"{s}\",\"zig_backend\":\"{s}\",\"seed\":{d},\"blocks\":{d},\"samples\":{d},\"mode\":\"{s}\",\"api\":\"{s}\",\"width_filter\":{d},\"cpu_features\":[",
        .{ builtin.zig_version_string, @tagName(builtin.cpu.arch), builtin.cpu.model.name, @tagName(builtin.mode), @tagName(builtin.zig_backend), options.seed, options.blocks, options.samples, @tagName(options.mode), @tagName(options.api), options.width orelse 0 },
    );
    inline for (builtin.cpu.features.ints, 0..) |mask, i| {
        std.debug.print("{s}\"{x:0>16}\"", .{ if (i == 0) "" else ",", mask });
    }
    std.debug.print("]}}\n", .{});
    inline for (.{ Operation.encrypt, Operation.decrypt }) |operation| {
        if (options.mode == .both or std.mem.eql(u8, @tagName(options.mode), @tagName(operation))) {
            inline for (supported_widths) |width| {
                if (if (options.width) |selected| selected == width else std.mem.indexOfScalar(usize, &default_widths, width) != null) {
                    inline for (.{ Api.single, Api.bulk }) |api| {
                        if (options.api == .both or std.mem.eql(u8, @tagName(options.api), @tagName(api))) {
                            try measure(operation, api, width, &cipher, options);
                        }
                    }
                }
            }
        }
    }
}
