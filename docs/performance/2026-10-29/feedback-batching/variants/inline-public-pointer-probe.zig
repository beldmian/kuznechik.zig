const std=@import("std");
inline fn foo(x: u32) u32 { return x+1; }
fn get() *const fn(u32) u32 { return foo; }
test "pointer" { const f=get(); try std.testing.expectEqual(@as(u32,2),f(1)); }
