const k = @import("kuznechik.zig");
export fn encrypt(c: *const k.Cipher, b: *align(16) k.block) void { c.encrypt(b); }
export fn decrypt(c: *const k.Cipher, b: *align(16) k.block) void { c.decrypt(b); }
