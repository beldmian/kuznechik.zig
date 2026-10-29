//! Diagonally normalized recursive equal-block circuit:70 constant GFNI maps.
//! One generated graph serves scalar verification and the64-block vector path.
//! See docs/performance/2026-10-29/operand-scheduling/prepare.py for its exact derivation.
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
pub const row_scale = [16]u8{ 144, 133, 239, 208, 6, 1, 54, 23, 191, 229, 100, 170, 23, 97, 141, 71 };
pub const column_scale = [16]u8{ 119, 210, 40, 16, 208, 110, 181, 93, 172, 176, 195, 20, 203, 222, 90, 1 };
pub const row_inverse = [16]u8{ 107, 233, 70, 25, 95, 1, 74, 49, 224, 254, 52, 79, 49, 51, 199, 124 };
pub const column_inverse = [16]u8{ 250, 48, 156, 181, 25, 109, 16, 41, 173, 34, 47, 251, 255, 18, 135, 1 };
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
    const w32 = multiply(T, w31, 71);
    const w33 = multiply(T, w30, 9);
    const w34 = multiply(T, w29, 22);
    const w35 = w32 ^ w33;
    const w36 = w32 ^ w34;
    const w37 = w27 ^ w28;
    const w38 = multiply(T, w37, 55);
    const w39 = multiply(T, w28, 97);
    const w40 = w38 ^ w39;
    const w41 = w25 ^ w26;
    const w42 = multiply(T, w41, 154);
    const w43 = multiply(T, w26, 156);
    const w44 = multiply(T, w25, 83);
    const w45 = w42 ^ w43;
    const w46 = w42 ^ w44;
    const w47 = w35 ^ w40;
    const w48 = w36 ^ w38;
    const w49 = w35 ^ w45;
    const w50 = w36 ^ w46;
    const w51 = w21 ^ w23;
    const w52 = w22 ^ w24;
    const w53 = w51 ^ w52;
    const w54 = multiply(T, w53, 117);
    const w55 = multiply(T, w52, 10);
    const w56 = multiply(T, w51, 83);
    const w57 = w54 ^ w55;
    const w58 = w54 ^ w56;
    const w59 = w23 ^ w24;
    const w60 = multiply(T, w59, 107);
    const w61 = multiply(T, w24, 219);
    const w62 = multiply(T, w23, 6);
    const w63 = w60 ^ w61;
    const w64 = w60 ^ w62;
    const w65 = w21 ^ w22;
    const w66 = multiply(T, w65, 69);
    const w67 = multiply(T, w22, 33);
    const w68 = multiply(T, w21, 16);
    const w69 = w66 ^ w67;
    const w70 = w66 ^ w68;
    const w71 = w57 ^ w63;
    const w72 = w58 ^ w64;
    const w73 = w57 ^ w69;
    const w74 = w58 ^ w70;
    const w75 = w17 ^ w19;
    const w76 = w18 ^ w20;
    const w77 = w75 ^ w76;
    const w78 = multiply(T, w77, 82);
    const w79 = multiply(T, w76, 147);
    const w80 = multiply(T, w75, 233);
    const w81 = w78 ^ w79;
    const w82 = w78 ^ w80;
    const w83 = w19 ^ w20;
    const w84 = multiply(T, w83, 226);
    const w85 = multiply(T, w20, 112);
    const w86 = multiply(T, w19, 32);
    const w87 = w84 ^ w85;
    const w88 = w84 ^ w86;
    const w89 = w17 ^ w18;
    const w90 = multiply(T, w89, 18);
    const w91 = multiply(T, w18, 28);
    const w92 = multiply(T, w17, 120);
    const w93 = w90 ^ w91;
    const w94 = w90 ^ w92;
    const w95 = w81 ^ w87;
    const w96 = w82 ^ w88;
    const w97 = w81 ^ w93;
    const w98 = w82 ^ w94;
    const w99 = w47 ^ w71;
    const w100 = w48 ^ w72;
    const w101 = w49 ^ w73;
    const w102 = w50 ^ w74;
    const w103 = w47 ^ w95;
    const w104 = w48 ^ w96;
    const w105 = w49 ^ w97;
    const w106 = w50 ^ w98;
    const w107 = input[8] ^ input[12];
    const w108 = input[9] ^ input[13];
    const w109 = input[10] ^ input[14];
    const w110 = input[11] ^ input[15];
    const w111 = w107 ^ w109;
    const w112 = w108 ^ w110;
    const w113 = w111 ^ w112;
    const w114 = multiply(T, w113, 56);
    const w115 = multiply(T, w112, 158);
    const w116 = w114 ^ w115;
    const w117 = w111 ^ w114;
    const w119 = multiply(T, w110, 21);
    const w120 = multiply(T, w109, 215);
    const w121 = w107 ^ w108;
    const w122 = multiply(T, w121, 198);
    const w123 = multiply(T, w108, 244);
    const w124 = multiply(T, w107, 195);
    const w125 = w122 ^ w123;
    const w126 = w122 ^ w124;
    const w127 = w116 ^ w119;
    const w128 = w117 ^ w120;
    const w129 = w116 ^ w125;
    const w130 = w117 ^ w126;
    const w131 = input[12] ^ input[14];
    const w132 = input[13] ^ input[15];
    const w133 = w131 ^ w132;
    const w134 = multiply(T, w133, 53);
    const w135 = multiply(T, w132, 88);
    const w136 = multiply(T, w131, 160);
    const w137 = w134 ^ w135;
    const w138 = w134 ^ w136;
    const w139 = input[14] ^ input[15];
    const w140 = multiply(T, w139, 213);
    const w141 = multiply(T, input[15], 72);
    const w142 = multiply(T, input[14], 142);
    const w143 = w140 ^ w141;
    const w144 = w140 ^ w142;
    const w145 = input[12] ^ input[13];
    const w146 = multiply(T, w145, 92);
    const w147 = multiply(T, input[13], 167);
    const w148 = multiply(T, input[12], 185);
    const w149 = w146 ^ w147;
    const w150 = w146 ^ w148;
    const w151 = w137 ^ w143;
    const w152 = w138 ^ w144;
    const w153 = w137 ^ w149;
    const w154 = w138 ^ w150;
    const w155 = input[8] ^ input[10];
    const w156 = input[9] ^ input[11];
    const w157 = w155 ^ w156;
    const w158 = multiply(T, w157, 117);
    const w159 = multiply(T, w156, 158);
    const w160 = multiply(T, w155, 224);
    const w161 = w158 ^ w159;
    const w162 = w158 ^ w160;
    const w163 = input[10] ^ input[11];
    const w164 = multiply(T, w163, 231);
    const w165 = multiply(T, input[11], 140);
    const w166 = w164 ^ w165;
    const w168 = multiply(T, input[9], 125);
    const w169 = w161 ^ w166;
    const w170 = w162 ^ w164;
    const w171 = w161 ^ w168;
    const w172 = input[8] ^ w162;
    const w173 = w127 ^ w151;
    const w174 = w128 ^ w152;
    const w175 = w129 ^ w153;
    const w176 = w130 ^ w154;
    const w177 = w127 ^ w169;
    const w178 = w128 ^ w170;
    const w179 = w129 ^ w171;
    const w180 = w130 ^ w172;
    const w181 = input[0] ^ input[4];
    const w182 = input[1] ^ input[5];
    const w183 = input[2] ^ input[6];
    const w184 = input[3] ^ input[7];
    const w185 = w181 ^ w183;
    const w186 = w182 ^ w184;
    const w187 = w185 ^ w186;
    const w188 = multiply(T, w187, 110);
    const w189 = multiply(T, w185, 182);
    const w190 = w188 ^ w189;
    const w191 = w183 ^ w184;
    const w192 = multiply(T, w191, 52);
    const w193 = multiply(T, w183, 216);
    const w194 = w184 ^ w192;
    const w195 = w192 ^ w193;
    const w196 = w181 ^ w182;
    const w197 = multiply(T, w196, 165);
    const w198 = multiply(T, w182, 242);
    const w199 = multiply(T, w181, 13);
    const w200 = w197 ^ w198;
    const w201 = w197 ^ w199;
    const w202 = w188 ^ w194;
    const w203 = w190 ^ w195;
    const w204 = w188 ^ w200;
    const w205 = w190 ^ w201;
    const w206 = input[4] ^ input[6];
    const w207 = input[5] ^ input[7];
    const w208 = w206 ^ w207;
    const w209 = multiply(T, w208, 142);
    const w210 = multiply(T, w206, 93);
    const w211 = w209 ^ w210;
    const w212 = input[6] ^ input[7];
    const w213 = multiply(T, w212, 161);
    const w214 = multiply(T, input[7], 61);
    const w215 = multiply(T, input[6], 59);
    const w216 = w213 ^ w214;
    const w217 = w213 ^ w215;
    const w218 = input[4] ^ input[5];
    const w219 = multiply(T, w218, 192);
    const w220 = multiply(T, input[5], 93);
    const w221 = multiply(T, input[4], 60);
    const w222 = w219 ^ w220;
    const w223 = w219 ^ w221;
    const w224 = w209 ^ w216;
    const w225 = w211 ^ w217;
    const w226 = w209 ^ w222;
    const w227 = w211 ^ w223;
    const w229 = input[1] ^ input[3];
    const w231 = multiply(T, w229, 133);
    const w232 = input[2] ^ input[3];
    const w233 = multiply(T, w232, 93);
    const w234 = multiply(T, input[3], 2);
    const w235 = multiply(T, input[2], 27);
    const w236 = w233 ^ w234;
    const w237 = w233 ^ w235;
    const w238 = input[0] ^ input[1];
    const w239 = multiply(T, w238, 44);
    const w240 = multiply(T, input[1], 169);
    const w241 = multiply(T, input[0], 141);
    const w242 = w239 ^ w240;
    const w243 = w239 ^ w241;
    const w244 = w231 ^ w236;
    const w245 = w231 ^ w242;
    const w246 = w202 ^ w224;
    const w247 = w203 ^ w225;
    const w248 = w204 ^ w226;
    const w249 = w205 ^ w227;
    const w250 = w202 ^ w244;
    const w251 = w203 ^ w237;
    const w252 = w204 ^ w245;
    const w253 = w205 ^ w243;
    return .{ xor3(T, w173, w99, (if (T == u8) key[0] else @as(T, @splat(key[0])))), xor3(T, w174, w100, (if (T == u8) key[1] else @as(T, @splat(key[1])))), xor3(T, w175, w101, (if (T == u8) key[2] else @as(T, @splat(key[2])))), xor3(T, w176, w102, (if (T == u8) key[3] else @as(T, @splat(key[3])))), xor3(T, w177, w103, (if (T == u8) key[4] else @as(T, @splat(key[4])))), xor3(T, w178, w104, (if (T == u8) key[5] else @as(T, @splat(key[5])))), xor3(T, w179, w105, (if (T == u8) key[6] else @as(T, @splat(key[6])))), xor3(T, w180, w106, (if (T == u8) key[7] else @as(T, @splat(key[7])))), xor3(T, w99, w246, (if (T == u8) key[8] else @as(T, @splat(key[8])))), xor3(T, w100, w247, (if (T == u8) key[9] else @as(T, @splat(key[9])))), xor3(T, w101, w248, (if (T == u8) key[10] else @as(T, @splat(key[10])))), xor3(T, w102, w249, (if (T == u8) key[11] else @as(T, @splat(key[11])))), xor3(T, w103, w250, (if (T == u8) key[12] else @as(T, @splat(key[12])))), xor3(T, w104, w251, (if (T == u8) key[13] else @as(T, @splat(key[13])))), xor3(T, w105, w252, (if (T == u8) key[14] else @as(T, @splat(key[14])))), xor3(T, w106, w253, (if (T == u8) key[15] else @as(T, @splat(key[15])))) };
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
