const std = @import("std");

/// Consume at most the bytes used by these fixed-width harnesses.
pub fn run(callback: *const fn ([*]const u8, usize) callconv(.c) i32, smoke: []const u8) !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);
    if (args.len > 2) return error.InvalidArguments;
    if (args.len == 2 and std.mem.eql(u8, args[1], "--smoke")) {
        _ = callback(smoke.ptr, smoke.len);
        return;
    }
    const file = if (args.len == 2) try std.fs.cwd().openFile(args[1], .{}) else std.fs.File.stdin();
    defer if (args.len == 2) file.close();
    try consume(file, callback);
}

fn consume(file: std.fs.File, callback: *const fn ([*]const u8, usize) callconv(.c) i32) !void {
    var buf: [48]u8 = undefined;
    const len = try file.readAll(&buf);
    _ = callback(&buf, len);
}

var observed: [48]u8 = undefined;
var observed_len: usize = 0;
fn record(data: [*]const u8, len: usize) callconv(.c) i32 {
    observed_len = len;
    @memcpy(observed[0..len], data[0..len]);
    return 0;
}

test "file input reaches callback, including empty and short inputs" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const cases = [_][]const u8{ "", "a", "different input", "01234567890123456789012345678901234567890123456789" };
    for (cases) |input| {
        try tmp.dir.writeFile(.{ .sub_path = "input", .data = input });
        const file = try tmp.dir.openFile("input", .{});
        defer file.close();
        try consume(file, &record);
        const expected = input[0..@min(input.len, 48)];
        try std.testing.expectEqualSlices(u8, expected, observed[0..observed_len]);
    }
}
