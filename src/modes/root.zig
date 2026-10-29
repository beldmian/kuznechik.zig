pub fn Modes(comptime Cipher: type) type {
    return struct {
        pub const classic = @import("classic.zig").Modes(Cipher);
        pub const Ctr = classic.Ctr;
        pub const CtrWithCounter = classic.CtrWithCounter;
        pub const Cbc = classic.Cbc(1);
        pub const CbcWithIv = classic.Cbc;
        pub const Cfb = classic.Cfb(1);
        pub const CfbWithIv = classic.Cfb;
        pub const Ofb = classic.Ofb(1);
        pub const OfbWithIv = classic.Ofb;
        pub const Cmac = classic.Cmac;
        pub const ecbEncrypt = classic.ecbEncrypt;
        pub const ecbDecrypt = classic.ecbDecrypt;
        pub const Gcm = @import("gcm.zig").Gcm(Cipher, 32);
        pub const Mgm = @import("mgm.zig").Mgm(Cipher);
        pub const Ccm = @import("ccm.zig").Ccm(Cipher, 3);
        pub fn CcmWithLength(comptime length_bytes: u4) type {
            return @import("ccm.zig").Ccm(Cipher, length_bytes);
        }
        pub fn GcmWithCounter(comptime counter_bits: u7) type {
            return @import("gcm.zig").Gcm(Cipher, counter_bits);
        }
    };
}
