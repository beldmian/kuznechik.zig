const std = @import("std");
const kuz = @import("kuz");
const Before = @import("before").Modes(kuz.Cipher);
const After = kuz.modes.classic;
comptime {
    if (@sizeOf(kuz.Cipher) != 352) @compileError("Cipher layout changed");
    for (.{ 1, 2, 3, 16, 64, 65 }) |m| {
        for (.{ .{ Before.Cfb(m), After.Cfb(m) }, .{ Before.Ofb(m), After.Ofb(m) }, .{ Before.Cmac, After.Cmac } }) |pair| {
            if (@sizeOf(pair[0]) != @sizeOf(pair[1]) or @alignOf(pair[0]) != @alignOf(pair[1])) @compileError("mode layout changed");
            for (@typeInfo(pair[0]).@"struct".fields) |field| {
                if (@offsetOf(pair[0], field.name) != @offsetOf(pair[1], field.name)) @compileError("mode field offset changed");
            }
        }
    }
}
pub fn main() void {
    std.debug.print("Cipher=352 bytes; CFB/OFB/CMAC sizes, alignments and field offsets unchanged.\n", .{});
}
