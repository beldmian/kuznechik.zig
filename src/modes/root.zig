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
        const rekey = @import("acpkm.zig").Modes(Cipher, classic);
        pub const acpkm = rekey.acpkm;
        pub const AcpkmMaster = rekey.AcpkmMaster;
        pub const CtrAcpkm = rekey.CtrAcpkm;
        pub const CtrAcpkmWithCounter = rekey.CtrAcpkmWithCounter;
        pub const CtrAcpkmMaster = rekey.CtrAcpkmMaster;
        pub const CtrAcpkmMasterWithCounter = rekey.CtrAcpkmMasterWithCounter;
        pub const GcmAcpkm = rekey.GcmAcpkm(32);
        pub const GcmAcpkmWithCounter = rekey.GcmAcpkm;
        pub const GcmAcpkmMaster = rekey.GcmAcpkmMaster(32);
        pub const GcmAcpkmMasterWithCounter = rekey.GcmAcpkmMaster;
        pub const CbcAcpkmMaster = rekey.CbcAcpkmMaster;
        pub const CfbAcpkmMaster = rekey.CfbAcpkmMaster;
        pub const OmacAcpkmMaster = rekey.OmacAcpkmMaster;
        const compositions = @import("compositions.zig").Modes(Cipher, classic, rekey);
        pub const KExp15 = compositions.KExp15;
        pub const TlsCtrOmac = compositions.TlsCtrOmac;
        pub const TlsRecord = @import("compositions.zig").Record;
        pub const CtrAcpkmOmac = compositions.CtrAcpkmOmac;
        pub const ecbEncrypt = classic.ecbEncrypt;
        pub const ecbDecrypt = classic.ecbDecrypt;
        pub const Gcm = @import("gcm.zig").Gcm(Cipher, 32);
        pub const Mgm = @import("mgm.zig").Mgm(Cipher);
        const profile_module = @import("mgm_profiles.zig");
        pub const MgmProfiles = profile_module.Profiles(Cipher);
        pub const Tls13MgmL = MgmProfiles.Tls13MgmL;
        pub const Tls13MgmS = MgmProfiles.Tls13MgmS;
        pub const EspMgmKtree = MgmProfiles.EspMgmKtree;
        pub const EspMgmMacKtree = MgmProfiles.EspMgmMacKtree;
        pub const IkeMgmKtree = MgmProfiles.IkeMgmKtree;
        pub const KtreeIv = profile_module.KtreeIv;
        pub const KtreeKeyMaterial = profile_module.KtreeKeyMaterial;
        pub const EspHeader = profile_module.EspHeader;
        pub const EspSequence = profile_module.EspSequence;
        pub const IkeAad = profile_module.IkeAad;
        pub const Ocb = @import("ocb.zig").Ocb(Cipher);
        pub fn OcbWithTag(comptime tag_bytes: usize) type {
            return @import("ocb.zig").OcbWithTag(Cipher, tag_bytes);
        }
        pub const Ccm = @import("ccm.zig").Ccm(Cipher, 3);
        pub fn CcmWithLength(comptime length_bytes: u4) type {
            return @import("ccm.zig").Ccm(Cipher, length_bytes);
        }
        pub fn GcmWithCounter(comptime counter_bits: u7) type {
            return @import("gcm.zig").Gcm(Cipher, counter_bits);
        }
    };
}
