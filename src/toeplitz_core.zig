//! Diagonally normalized Toeplitz circuit:75 constant GFNI maps.
//! One generated graph serves scalar verification and the64-block vector path.
//! See docs/performance/reproduce-toeplitz.py for its exact derivation.
const std = @import("std");
pub const W = @Vector(64, u8);
fn kuzMul(a_in: u8, b_in: u8) u8 {
    var a = a_in;
    var b = b_in;
    var out: u8 = 0;
    for (0..8) |_| {
        if (b & 1 != 0) out ^= a;
        const carry = a & 0x80 != 0;
        a = (a << 1) ^ @as(u8, if (carry) 0xc3 else 0);
        b >>= 1;
    }
    return out;
}
fn matrix(comptime coefficient: u8) u64 {
    @setEvalBranchQuota(1000000);
    var out: u64 = 0;
    for (0..8) |j| {
        var row: u8 = 0;
        for (0..8) |i| row |= ((kuzMul(@as(u8, 1) << @intCast(i), coefficient) >> @intCast(j)) & 1) << @intCast(i);
        out |= @as(u64, row) << @intCast((7 - j) * 8);
    }
    return out;
}
const matrix_pool = blk: {
    @setEvalBranchQuota(10000000);
    var out: [256]u64 = undefined;
    for (0..256) |i| out[i] = matrix(@intCast(i));
    break :blk out;
};
inline fn multiply(comptime T: type, a: T, comptime coefficient: u8) T {
    @setEvalBranchQuota(1000000);
    if (T == u8) return kuzMul(a, coefficient);
    const code = comptime std.fmt.comptimePrint("vgf2p8affineqb $0, {d}(%[m]){{1to8}}, %[a], %[out]", .{@as(usize, coefficient) * 8});
    return asm (code
        : [out] "=v" (-> T),
        : [a] "v" (a),
          [m] "r" (&matrix_pool),
        : .{ .memory = true });
}
inline fn xor3(comptime T: type, a: T, b: T, c: T) T {
    if (T == u8) return a ^ b ^ c;
    return asm ("vpternlogd $0x96, %[c], %[b], %[a]"
        : [out] "=v" (-> T),
        : [a] "0" (a),
          [b] "v" (b),
          [c] "v" (c),
    );
}
pub const row_scale = [16]u8{ 153, 126, 163, 228, 204, 52, 131, 29, 203, 244, 187, 107, 18, 238, 120, 128 };
pub const column_scale = [16]u8{ 180, 250, 241, 48, 183, 114, 185, 160, 70, 131, 112, 1, 9, 87, 1, 121 };
pub const row_inverse = [16]u8{ 86, 168, 17, 202, 137, 100, 242, 35, 255, 33, 32, 144, 222, 125, 116, 94 };
pub const column_inverse = [16]u8{ 162, 119, 43, 210, 155, 87, 56, 39, 239, 242, 189, 1, 127, 114, 1, 197 };
pub inline fn multiplyConstant(a: W, comptime c: u8) W {
    if (c == 0) return @splat(0);
    if (c == 1) return a;
    return multiply(W, a, c);
}
inline fn circuit(comptime T: type, input: [16]T, key: @Vector(16, u8)) [16]T {
    const w17 = input[0] ^ input[8];
    const w18 = input[1] ^ input[9];
    const w19 = input[2] ^ input[10];
    const w20 = input[3] ^ input[11];
    const w21 = input[4] ^ input[12];
    const w22 = input[5] ^ input[13];
    const w23 = input[6] ^ input[14];
    const w24 = input[7] ^ input[15];
    const w25 = w17 ^ w21;
    const w26 = w18 ^ w22;
    const w27 = w19 ^ w23;
    const w28 = w20 ^ w24;
    const w29 = w25 ^ w27;
    const w30 = w26 ^ w28;
    const w31 = w29 ^ w30;
    const w32 = multiply(T, w31, 106);
    const w33 = multiply(T, w29, 143);
    const w34 = w30 ^ w32;
    const w35 = w32 ^ w33;
    const w36 = w27 ^ w28;
    const w37 = multiply(T, w36, 160);
    const w38 = multiply(T, w27, 46);
    const w39 = w37 ^ w38;
    const w40 = w25 ^ w26;
    const w41 = multiply(T, w40, 201);
    const w42 = multiply(T, w26, 71);
    const w43 = multiply(T, w25, 71);
    const w44 = w41 ^ w42;
    const w45 = w41 ^ w43;
    const w46 = w34 ^ w37;
    const w47 = w35 ^ w39;
    const w48 = w34 ^ w44;
    const w49 = w35 ^ w45;
    const w50 = w21 ^ w23;
    const w51 = w22 ^ w24;
    const w52 = w50 ^ w51;
    const w53 = multiply(T, w52, 218);
    const w54 = multiply(T, w51, 211);
    const w55 = multiply(T, w50, 244);
    const w56 = w53 ^ w54;
    const w57 = w53 ^ w55;
    const w58 = w23 ^ w24;
    const w59 = multiply(T, w58, 43);
    const w60 = multiply(T, w24, 37);
    const w61 = multiply(T, w23, 12);
    const w62 = w59 ^ w60;
    const w63 = w59 ^ w61;
    const w64 = w21 ^ w22;
    const w65 = multiply(T, w64, 179);
    const w66 = multiply(T, w22, 148);
    const w67 = multiply(T, w21, 157);
    const w68 = w65 ^ w66;
    const w69 = w65 ^ w67;
    const w70 = w56 ^ w62;
    const w71 = w57 ^ w63;
    const w72 = w56 ^ w68;
    const w73 = w57 ^ w69;
    const w74 = w17 ^ w19;
    const w75 = w18 ^ w20;
    const w76 = w74 ^ w75;
    const w77 = multiply(T, w76, 189);
    const w78 = multiply(T, w75, 189);
    const w79 = multiply(T, w74, 149);
    const w80 = w77 ^ w78;
    const w81 = w77 ^ w79;
    const w82 = w19 ^ w20;
    const w83 = multiply(T, w82, 212);
    const w84 = multiply(T, w20, 250);
    const w85 = multiply(T, w19, 252);
    const w86 = w83 ^ w84;
    const w87 = w83 ^ w85;
    const w88 = w17 ^ w18;
    const w89 = multiply(T, w88, 127);
    const w90 = multiply(T, w18, 87);
    const w91 = multiply(T, w17, 96);
    const w92 = w89 ^ w90;
    const w93 = w89 ^ w91;
    const w94 = w80 ^ w86;
    const w95 = w81 ^ w87;
    const w96 = w80 ^ w92;
    const w97 = w81 ^ w93;
    const w98 = w46 ^ w70;
    const w99 = w47 ^ w71;
    const w100 = w48 ^ w72;
    const w101 = w49 ^ w73;
    const w102 = w46 ^ w94;
    const w103 = w47 ^ w95;
    const w104 = w48 ^ w96;
    const w105 = w49 ^ w97;
    const w106 = input[8] ^ input[12];
    const w107 = input[9] ^ input[13];
    const w108 = input[10] ^ input[14];
    const w109 = input[11] ^ input[15];
    const w110 = w106 ^ w108;
    const w111 = w107 ^ w109;
    const w112 = w110 ^ w111;
    const w113 = multiply(T, w111, 87);
    const w114 = multiply(T, w110, 40);
    const w115 = w112 ^ w113;
    const w116 = w112 ^ w114;
    const w117 = w108 ^ w109;
    const w118 = multiply(T, w117, 227);
    const w119 = multiply(T, w109, 196);
    const w120 = multiply(T, w108, 156);
    const w121 = w118 ^ w119;
    const w122 = w118 ^ w120;
    const w123 = w106 ^ w107;
    const w124 = multiply(T, w123, 153);
    const w125 = multiply(T, w107, 230);
    const w126 = multiply(T, w106, 185);
    const w127 = w124 ^ w125;
    const w128 = w124 ^ w126;
    const w129 = w115 ^ w121;
    const w130 = w116 ^ w122;
    const w131 = w115 ^ w127;
    const w132 = w116 ^ w128;
    const w133 = input[12] ^ input[14];
    const w134 = input[13] ^ input[15];
    const w135 = w133 ^ w134;
    const w136 = multiply(T, w135, 132);
    const w137 = multiply(T, w134, 6);
    const w138 = multiply(T, w133, 220);
    const w139 = w136 ^ w137;
    const w140 = w136 ^ w138;
    const w141 = input[14] ^ input[15];
    const w142 = multiply(T, w141, 242);
    const w143 = multiply(T, input[15], 164);
    const w144 = multiply(T, input[14], 40);
    const w145 = w142 ^ w143;
    const w146 = w142 ^ w144;
    const w147 = input[12] ^ input[13];
    const w148 = multiply(T, w147, 254);
    const w149 = multiply(T, input[13], 36);
    const w150 = multiply(T, input[12], 249);
    const w151 = w148 ^ w149;
    const w152 = w148 ^ w150;
    const w153 = w139 ^ w145;
    const w154 = w140 ^ w146;
    const w155 = w139 ^ w151;
    const w156 = w140 ^ w152;
    const w157 = input[8] ^ input[10];
    const w158 = input[9] ^ input[11];
    const w159 = w157 ^ w158;
    const w160 = multiply(T, w159, 102);
    const w161 = multiply(T, w158, 57);
    const w162 = multiply(T, w157, 73);
    const w163 = w160 ^ w161;
    const w164 = w160 ^ w162;
    const w165 = input[10] ^ input[11];
    const w166 = multiply(T, w165, 28);
    const w167 = multiply(T, input[11], 27);
    const w168 = multiply(T, input[10], 108);
    const w169 = w166 ^ w167;
    const w170 = w166 ^ w168;
    const w171 = input[8] ^ input[9];
    const w172 = multiply(T, w171, 85);
    const w173 = multiply(T, input[9], 37);
    const w174 = multiply(T, input[8], 68);
    const w175 = w172 ^ w173;
    const w176 = w172 ^ w174;
    const w177 = w163 ^ w169;
    const w178 = w164 ^ w170;
    const w179 = w163 ^ w175;
    const w180 = w164 ^ w176;
    const w181 = w129 ^ w153;
    const w182 = w130 ^ w154;
    const w183 = w131 ^ w155;
    const w184 = w132 ^ w156;
    const w185 = w129 ^ w177;
    const w186 = w130 ^ w178;
    const w187 = w131 ^ w179;
    const w188 = w132 ^ w180;
    const w189 = input[0] ^ input[4];
    const w190 = input[1] ^ input[5];
    const w191 = input[2] ^ input[6];
    const w192 = input[3] ^ input[7];
    const w193 = w189 ^ w191;
    const w194 = w190 ^ w192;
    const w195 = w193 ^ w194;
    const w196 = multiply(T, w195, 224);
    const w197 = multiply(T, w194, 215);
    const w198 = multiply(T, w193, 194);
    const w199 = w196 ^ w197;
    const w200 = w196 ^ w198;
    const w201 = w191 ^ w192;
    const w202 = multiply(T, w201, 75);
    const w203 = multiply(T, w192, 122);
    const w204 = multiply(T, w191, 94);
    const w205 = w202 ^ w203;
    const w206 = w202 ^ w204;
    const w207 = w189 ^ w190;
    const w208 = multiply(T, w207, 215);
    const w209 = multiply(T, w190, 194);
    const w210 = multiply(T, w189, 157);
    const w211 = w208 ^ w209;
    const w212 = w208 ^ w210;
    const w213 = w199 ^ w205;
    const w214 = w200 ^ w206;
    const w215 = w199 ^ w211;
    const w216 = w200 ^ w212;
    const w217 = input[4] ^ input[6];
    const w218 = input[5] ^ input[7];
    const w219 = w217 ^ w218;
    const w220 = multiply(T, w219, 135);
    const w221 = multiply(T, w218, 185);
    const w222 = multiply(T, w217, 163);
    const w223 = w220 ^ w221;
    const w224 = w220 ^ w222;
    const w225 = input[6] ^ input[7];
    const w226 = multiply(T, w225, 180);
    const w227 = multiply(T, input[7], 165);
    const w228 = multiply(T, input[6], 174);
    const w229 = w226 ^ w227;
    const w230 = w226 ^ w228;
    const w231 = input[4] ^ input[5];
    const w232 = multiply(T, w231, 27);
    const w233 = multiply(T, input[4], 96);
    const w234 = input[5] ^ w232;
    const w235 = w232 ^ w233;
    const w236 = w223 ^ w229;
    const w237 = w224 ^ w230;
    const w238 = w223 ^ w234;
    const w239 = w224 ^ w235;
    const w240 = input[0] ^ input[2];
    const w241 = input[1] ^ input[3];
    const w242 = w240 ^ w241;
    const w243 = multiply(T, w242, 198);
    const w244 = multiply(T, w241, 153);
    const w245 = w243 ^ w244;
    const w246 = w240 ^ w243;
    const w247 = input[2] ^ input[3];
    const w248 = multiply(T, w247, 90);
    const w249 = multiply(T, input[3], 33);
    const w250 = multiply(T, input[2], 194);
    const w251 = w248 ^ w249;
    const w252 = w248 ^ w250;
    const w253 = input[0] ^ input[1];
    const w254 = multiply(T, input[1], 153);
    const w255 = multiply(T, input[0], 61);
    const w256 = w253 ^ w254;
    const w257 = w253 ^ w255;
    const w258 = w245 ^ w251;
    const w259 = w246 ^ w252;
    const w260 = w245 ^ w256;
    const w261 = w246 ^ w257;
    const w262 = w213 ^ w236;
    const w263 = w214 ^ w237;
    const w264 = w215 ^ w238;
    const w265 = w216 ^ w239;
    const w266 = w213 ^ w258;
    const w267 = w214 ^ w259;
    const w268 = w215 ^ w260;
    const w269 = w216 ^ w261;
    return .{ xor3(T, w181, w98, (if (T == u8) key[0] else @as(T, @splat(key[0])))), xor3(T, w182, w99, (if (T == u8) key[1] else @as(T, @splat(key[1])))), xor3(T, w183, w100, (if (T == u8) key[2] else @as(T, @splat(key[2])))), xor3(T, w184, w101, (if (T == u8) key[3] else @as(T, @splat(key[3])))), xor3(T, w185, w102, (if (T == u8) key[4] else @as(T, @splat(key[4])))), xor3(T, w186, w103, (if (T == u8) key[5] else @as(T, @splat(key[5])))), xor3(T, w187, w104, (if (T == u8) key[6] else @as(T, @splat(key[6])))), xor3(T, w188, w105, (if (T == u8) key[7] else @as(T, @splat(key[7])))), xor3(T, w98, w262, (if (T == u8) key[8] else @as(T, @splat(key[8])))), xor3(T, w99, w263, (if (T == u8) key[9] else @as(T, @splat(key[9])))), xor3(T, w100, w264, (if (T == u8) key[10] else @as(T, @splat(key[10])))), xor3(T, w101, w265, (if (T == u8) key[11] else @as(T, @splat(key[11])))), xor3(T, w102, w266, (if (T == u8) key[12] else @as(T, @splat(key[12])))), xor3(T, w103, w267, (if (T == u8) key[13] else @as(T, @splat(key[13])))), xor3(T, w104, w268, (if (T == u8) key[14] else @as(T, @splat(key[14])))), xor3(T, w105, w269, (if (T == u8) key[15] else @as(T, @splat(key[15])))) };
}
pub inline fn forward(comptime T: type, input: [16]T) [16]T {
    return circuit(T, input, @splat(0));
}
pub inline fn inverse(comptime T: type, input: [16]T) [16]T {
    var rev: [16]T = undefined;
    inline for (0..16) |i| rev[i] = input[15 - i];
    const y = forward(T, rev);
    inline for (0..16) |i| rev[i] = y[15 - i];
    return rev;
}
pub inline fn forwardSeeded(input: [16]W, key: @Vector(16, u8)) [16]W {
    return circuit(W, input, key);
}
pub inline fn inverseSeeded(input: [16]W, key: @Vector(16, u8)) [16]W {
    var rev: [16]W = undefined;
    var rk: @Vector(16, u8) = undefined;
    inline for (0..16) |i| {
        rev[i] = input[15 - i];
        rk[i] = key[15 - i];
    }
    const y = forwardSeeded(rev, rk);
    inline for (0..16) |i| rev[i] = y[15 - i];
    return rev;
}
