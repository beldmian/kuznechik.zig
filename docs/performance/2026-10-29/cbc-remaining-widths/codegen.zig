const kuz = @import("src/kuznechik.zig");
const Before = @import("src/modes/classic_before_093.zig").Modes(kuz.Cipher);
const After = kuz.modes.classic;
export fn before_cbc1(ctx: *Before.Cbc(1), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc1(ctx: *After.Cbc(1), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc2(ctx: *Before.Cbc(2), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc2(ctx: *After.Cbc(2), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc3(ctx: *Before.Cbc(3), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc3(ctx: *After.Cbc(3), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc4(ctx: *Before.Cbc(4), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc4(ctx: *After.Cbc(4), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc5(ctx: *Before.Cbc(5), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc5(ctx: *After.Cbc(5), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc6(ctx: *Before.Cbc(6), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc6(ctx: *After.Cbc(6), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc7(ctx: *Before.Cbc(7), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc7(ctx: *After.Cbc(7), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc8(ctx: *Before.Cbc(8), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc8(ctx: *After.Cbc(8), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc9(ctx: *Before.Cbc(9), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc9(ctx: *After.Cbc(9), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc10(ctx: *Before.Cbc(10), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc10(ctx: *After.Cbc(10), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc11(ctx: *Before.Cbc(11), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc11(ctx: *After.Cbc(11), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc12(ctx: *Before.Cbc(12), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc12(ctx: *After.Cbc(12), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc13(ctx: *Before.Cbc(13), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc13(ctx: *After.Cbc(13), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc14(ctx: *Before.Cbc(14), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc14(ctx: *After.Cbc(14), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc15(ctx: *Before.Cbc(15), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc15(ctx: *After.Cbc(15), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc16(ctx: *Before.Cbc(16), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc16(ctx: *After.Cbc(16), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc17(ctx: *Before.Cbc(17), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc17(ctx: *After.Cbc(17), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc18(ctx: *Before.Cbc(18), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc18(ctx: *After.Cbc(18), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc19(ctx: *Before.Cbc(19), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc19(ctx: *After.Cbc(19), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc20(ctx: *Before.Cbc(20), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc20(ctx: *After.Cbc(20), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc21(ctx: *Before.Cbc(21), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc21(ctx: *After.Cbc(21), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc22(ctx: *Before.Cbc(22), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc22(ctx: *After.Cbc(22), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc23(ctx: *Before.Cbc(23), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc23(ctx: *After.Cbc(23), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc24(ctx: *Before.Cbc(24), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc24(ctx: *After.Cbc(24), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc25(ctx: *Before.Cbc(25), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc25(ctx: *After.Cbc(25), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc26(ctx: *Before.Cbc(26), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc26(ctx: *After.Cbc(26), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc27(ctx: *Before.Cbc(27), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc27(ctx: *After.Cbc(27), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc28(ctx: *Before.Cbc(28), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc28(ctx: *After.Cbc(28), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc29(ctx: *Before.Cbc(29), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc29(ctx: *After.Cbc(29), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc30(ctx: *Before.Cbc(30), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc30(ctx: *After.Cbc(30), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc31(ctx: *Before.Cbc(31), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc31(ctx: *After.Cbc(31), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc32(ctx: *Before.Cbc(32), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc32(ctx: *After.Cbc(32), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc33(ctx: *Before.Cbc(33), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc33(ctx: *After.Cbc(33), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc34(ctx: *Before.Cbc(34), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc34(ctx: *After.Cbc(34), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc35(ctx: *Before.Cbc(35), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc35(ctx: *After.Cbc(35), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc36(ctx: *Before.Cbc(36), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc36(ctx: *After.Cbc(36), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc37(ctx: *Before.Cbc(37), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc37(ctx: *After.Cbc(37), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc38(ctx: *Before.Cbc(38), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc38(ctx: *After.Cbc(38), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc39(ctx: *Before.Cbc(39), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc39(ctx: *After.Cbc(39), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc40(ctx: *Before.Cbc(40), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc40(ctx: *After.Cbc(40), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc41(ctx: *Before.Cbc(41), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc41(ctx: *After.Cbc(41), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc42(ctx: *Before.Cbc(42), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc42(ctx: *After.Cbc(42), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc43(ctx: *Before.Cbc(43), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc43(ctx: *After.Cbc(43), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc44(ctx: *Before.Cbc(44), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc44(ctx: *After.Cbc(44), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc45(ctx: *Before.Cbc(45), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc45(ctx: *After.Cbc(45), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc46(ctx: *Before.Cbc(46), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc46(ctx: *After.Cbc(46), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc47(ctx: *Before.Cbc(47), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc47(ctx: *After.Cbc(47), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc48(ctx: *Before.Cbc(48), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc48(ctx: *After.Cbc(48), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc49(ctx: *Before.Cbc(49), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc49(ctx: *After.Cbc(49), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc50(ctx: *Before.Cbc(50), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc50(ctx: *After.Cbc(50), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc51(ctx: *Before.Cbc(51), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc51(ctx: *After.Cbc(51), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc52(ctx: *Before.Cbc(52), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc52(ctx: *After.Cbc(52), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc53(ctx: *Before.Cbc(53), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc53(ctx: *After.Cbc(53), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc54(ctx: *Before.Cbc(54), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc54(ctx: *After.Cbc(54), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc55(ctx: *Before.Cbc(55), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc55(ctx: *After.Cbc(55), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc56(ctx: *Before.Cbc(56), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc56(ctx: *After.Cbc(56), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc57(ctx: *Before.Cbc(57), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc57(ctx: *After.Cbc(57), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc58(ctx: *Before.Cbc(58), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc58(ctx: *After.Cbc(58), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc59(ctx: *Before.Cbc(59), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc59(ctx: *After.Cbc(59), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc60(ctx: *Before.Cbc(60), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc60(ctx: *After.Cbc(60), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc61(ctx: *Before.Cbc(61), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc61(ctx: *After.Cbc(61), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc62(ctx: *Before.Cbc(62), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc62(ctx: *After.Cbc(62), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc63(ctx: *Before.Cbc(63), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc63(ctx: *After.Cbc(63), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc64(ctx: *Before.Cbc(64), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc64(ctx: *After.Cbc(64), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc65(ctx: *Before.Cbc(65), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc65(ctx: *After.Cbc(65), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn before_cbc128(ctx: *Before.Cbc(128), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
export fn after_cbc128(ctx: *After.Cbc(128), ptr: [*]u8, len: usize) bool {
    ctx.encrypt(ptr[0..len]) catch return false;
    return true;
}
