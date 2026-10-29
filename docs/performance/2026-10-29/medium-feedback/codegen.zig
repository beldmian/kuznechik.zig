const kuz = @import("src/kuznechik.zig");
const Before = @import("src/modes/classic_before_092.zig").Modes(kuz.Cipher);
const After = kuz.modes.classic;
export fn before_cfb8(ctx: *Before.Cfb(8), ptr: [*]u8, len: usize) void { ctx.encrypt(ptr[0..len]); }
export fn after_cfb8(ctx: *After.Cfb(8), ptr: [*]u8, len: usize) void { ctx.encrypt(ptr[0..len]); }
export fn before_cfb3(ctx: *Before.Cfb(3), ptr: [*]u8, len: usize) void { ctx.encrypt(ptr[0..len]); }
export fn after_cfb3(ctx: *After.Cfb(3), ptr: [*]u8, len: usize) void { ctx.encrypt(ptr[0..len]); }
export fn before_cfb65(ctx: *Before.Cfb(65), ptr: [*]u8, len: usize) void { ctx.encrypt(ptr[0..len]); }
export fn after_cfb65(ctx: *After.Cfb(65), ptr: [*]u8, len: usize) void { ctx.encrypt(ptr[0..len]); }
export fn before_cbc2(ctx: *Before.Cbc(2), ptr: [*]u8, len: usize) bool { ctx.encrypt(ptr[0..len]) catch return false; return true; }
export fn after_cbc2(ctx: *After.Cbc(2), ptr: [*]u8, len: usize) bool { ctx.encrypt(ptr[0..len]) catch return false; return true; }
export fn before_cbc3(ctx: *Before.Cbc(3), ptr: [*]u8, len: usize) bool { ctx.encrypt(ptr[0..len]) catch return false; return true; }
export fn after_cbc3(ctx: *After.Cbc(3), ptr: [*]u8, len: usize) bool { ctx.encrypt(ptr[0..len]) catch return false; return true; }
export fn before_cbc8(ctx: *Before.Cbc(8), ptr: [*]u8, len: usize) bool { ctx.encrypt(ptr[0..len]) catch return false; return true; }
export fn after_cbc8(ctx: *After.Cbc(8), ptr: [*]u8, len: usize) bool { ctx.encrypt(ptr[0..len]) catch return false; return true; }
