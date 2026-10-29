//! RFC 8645 Appendix A.2; copied byte-for-byte from the RFC.
const hex = @import("test_helpers.zig").hex;
pub const v0 = struct { // CTR-ACPKM mode with AES-256
    pub const key = hex("8899aabbccddeeff0011223344556677fedcba98765432100123456789abcdef");
    pub const plain = hex("1122334455667700ffeeddccbbaa998800112233445566778899aabbcceeff0a" ++
        "112233445566778899aabbcceeff0a002233445566778899aabbcceeff0a0011" ++
        "33445566778899aabbcceeff0a001122445566778899aabbcceeff0a00112233" ++
        "5566778899aabbcceeff0a0011223344");
    pub const ciphertext = hex("ec5ccbde8c18d3b8725668d0a737f4581989e74232629d60997de24bc0e39fb8" ++
        "f5aaba0be364f053eef0bc15c2764cea9e7cc376bd8719c9770fca2de2a37cb5" ++
        "5b2b771bf83a0517be042d8228fe2a95844e9f08fdf7b8944cb7aab7de3c67b4" ++
        "56b843fc3231de46d5ab14f8ac09c739");
    pub const key1 = hex("8899aabbccddeeff0011223344556677fedcba98765432100123456789abcdef");
    pub const key2 = hex("f680d1212fa43df4ec3a91de2ab16f1b36b0488a4fc12e0998d2e4a888e84f3d");
    pub const key3 = hex("8eb97e43271a42f1ca8ee25f5cc7c83b1ace9e5ed06aa53b57b96acf365d24b8");
    pub const key4 = hex("c5716cc96798bc2d4a1787b78adf94ace816f80bdbbcad7d6078129c0cb402f5");
};
pub const v1 = struct { // GCM-ACPKM mode with AES-128
    pub const key = hex("00000000000000000000000000000000");
    pub const plain = hex("0000000000000000000000000000000000000000000000000000000000000000" ++
        "00000000000000000000000000000000");
    pub const ciphertext = hex("0388dace60b6a392f328c2b971b2fe78f795aaab494b5923f7fd89ff948bc1e0" ++
        "d6b31246e9ce9ff13ab3427ee89196ad");
    pub const tag = hex("b00f155a60a36551868b53a2a41b7b66");
    pub const key2 = hex("151a9fb0b6acc5976afb5031d1dec841");
};
pub const v2 = struct { // CTR-ACPKM-Master mode with AES-256
    pub const key = hex("8899aabbccddeeff0011223344556677fedcba98765432100123456789abcdef");
    pub const plain = hex("1122334455667700ffeeddccbbaa998800112233445566778899aabbcceeff0a" ++
        "112233445566778899aabbcceeff0a002233445566778899aabbcceeff0a0011" ++
        "33445566778899aabbcceeff0a001122445566778899aabbcceeff0a00112233" ++
        "5566778899aabbcceeff0a0011223344");
    pub const ciphertext = hex("9d8085c6f236123f7151d52b2433d4d4f6b787891c41789aab459bd31edb76ab" ++
        "5b256cc250e1051c8424c634dc0b2971010622fa07aa763e1bd3f3544f584ac6" ++
        "9b4d38da9f33cb5665a2ed8fcb6684ca82b608f9d31b007f6a82eb87b1e7b9dc" ++
        "d74d9e8f0f9dff599bc935a716da7366");
    pub const material = hex("9f10bbf13a79fbbd4a4ca864c490746439fe506d4b869b2103a3b6a479283c60" ++
        "77911750e0d177e59a13782bf18908d0ab6b59ee924905b3abc7a4e3696576c3" ++
        "e8762b308b08ebce3e939ac2c03e76d4609aabd9153313d3cfd394e775df3a94" ++
        "f2ee91456bdc3de4912c87c329cf31a92f202e5ac49a2a653133d6748c4ff912");
};
pub const v3 = struct { // GCM-ACPKM-Master mode with AES-256
    pub const key = hex("000000000000000000000000000000000000000000000000");
    pub const plain = hex("0000000000000000000000000000000000000000000000000000000000000000" ++
        "0000000000000000000000000000000000000000000000000000000000000000" ++
        "00000000000000000000000000000000");
    pub const ciphertext = hex("43fa718164b1e3d71e7b6539a7021d52699b9e1b4324b7529574e790f2be60e8" ++
        "1162c9902a2b777fd96ad61a99e0c6de4b91d429e31a8c11aff0bc47f680af14" ++
        "401cc11814638e762483377516347008");
    pub const tag = hex("cc3aba118ce785fd777894d4b52069f8");
    pub const material = hex("93baaffb35fbe739c17c6ac22eecf18f7b89f0bf8b1807059648689f36a765cc" ++
        "cd5dace20d47d918d786d041a83bab99f5f8b106d27178b1b008c9990b72e287" ++
        "5a2d3cbef16e673c");
};
pub const v4 = struct { // CBC-ACPKM-Master mode with AES-256
    pub const key = hex("8899aabbccddeeff0011223344556677fedcba98765432100123456789abcdef");
    pub const plain = hex("1122334455667700ffeeddccbbaa998800112233445566778899aabbcceeff0a" ++
        "112233445566778899aabbcceeff0a002233445566778899aabbcceeff0a0011" ++
        "33445566778899aabbcceeff0a001122445566778899aabbcceeff0a00112233" ++
        "5566778899aabbcceeff0a0011223344");
    pub const ciphertext = hex("59cb5bcac2692c600d4603a0c740c97c80b60274548bf7c9781fa1058bf68b42" ++
        "8c24fbcf6815b1af65fe477595b497591965a500580d5023721be990e18330e9" ++
        "56d834f46f0f4de62053a95cb5f63c1466682b8bdd6eb27edec751d62f45a545" ++
        "7f4d87f9cae9560979c4fafe340b4534");
};
pub const v5 = struct { // CFB-ACPKM-Master mode with AES-256
    pub const key = hex("8899aabbccddeeff0011223344556677fedcba98765432100123456789abcdef");
    pub const plain = hex("1122334455667700ffeeddccbbaa998800112233445566778899aabbcceeff0a" ++
        "112233445566778899aabbcceeff0a002233445566778899aabbcceeff0a0011" ++
        "33445566778899aabbcceeff0a001122445566778899aabbcceeff0a00112233" ++
        "5566778899aabbcc");
    pub const ciphertext = hex("0d1bae1dad3be691563ccf53d8bf098b6bb3e771163ca07c9d8dac3c5ca80924" ++
        "84676c9f96f87d9b0661ab395386a988c2997608e6d3cf0c10f9738d0740c8a3" ++
        "cd06d916b5d957b98d0d51bbf24977ab4571e6f00e810ff8dde433bf0af42090" ++
        "c23ae1bfccb437b3");
};
pub const v6 = struct { // OMAC-ACPKM-Master mode with AES-256
    pub const key = hex("8899aabbccddeeff0011223344556677fedcba98765432100123456789abcdef");
    pub const plain = hex("1122334455667700ffeeddccbbaa998800112233445566778899aabbcceeff0a" ++
        "112233445566778899aabbcceeff0a002233445566778899aabbcceeff0a0011" ++
        "33445566778899aabbcceeff0a001122");
    pub const tag = hex("b3adb8921832054c0921e7b808cfa0b8");
    pub const material = hex("9f10bbf13a79fbbd4a4ca864c490746439fe506d4b869b2103a3b6a479283c60" ++
        "77911750e0d177e59a13782bf18908d0ab6b59ee924905b3abc7a4e3696576c3" ++
        "9dcc66420dff455b21f393f0d4d66e67bb1b060b87666d087a9da74955c35b48" ++
        "f2ee91456bdc3de4912c87c329cf31a92f202e5ac49a2a653133d6748c4ff912" ++
        "7821c7c76cbd796356acf88e696a0007");
};
