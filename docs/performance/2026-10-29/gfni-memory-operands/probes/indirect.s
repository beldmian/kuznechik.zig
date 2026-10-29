	.intel_syntax noprefix
	.file	"indirect"
	.file	1 "/tmp/kuz-toolchains/zig-x86_64-linux-0.15.1/lib/std" "builtin.zig"
	.file	2 "/home/t3/.cache/gfni-memory-probes-global.9tezaT/b/4fedd5365958bf1a72a8ed4adbee5842" "builtin.zig"
	.file	3 "/tmp/kuz-toolchains/zig-x86_64-linux-0.15.1/lib/std" "start.zig"
	.file	4 "/home/t3/.t3/worktrees/kuznechik.zig/t3-9024bc12/docs/performance/2026-10-29/gfni-memory-operands/probes" "indirect.zig"
	.file	5 "/tmp/kuz-toolchains/zig-x86_64-linux-0.15.1/lib/std" "Target.zig"
	.file	6 "/tmp/kuz-toolchains/zig-x86_64-linux-0.15.1/lib/std/Target" "x86.zig"
	.text
	.globl	probe
	.p2align	4
	.type	probe,@function
probe:
.Lfunc_begin0:
	.loc	4 3 0
	.cfi_startproc
	push	rbp
	.cfi_def_cfa_offset 16
	.cfi_offset rbp, -16
	mov	rbp, rsp
	.cfi_def_cfa_register rbp
.Ltmp0:
	.loc	4 6 49 prologue_end
	vmovaps	zmm0, zmmword ptr [rdi]
	mov	qword ptr [rbp - 8], offset indirect.pool+8
	#APP
	vgf2p8affineqb	zmm0, zmm0, qword ptr [rbp - 8]{1to8}, 0
	#NO_APP
	vmovaps	zmmword ptr [rsi], zmm0
	.loc	4 6 49 epilogue_begin is_stmt 0
	pop	rbp
	.cfi_def_cfa rsp, 8
	vzeroupper
	ret
.Ltmp1:
.Lfunc_end0:
	.size	probe, .Lfunc_end0-probe
	.cfi_endproc

	.type	indirect.pool,@object
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	3, 0x0
indirect.pool:
	.quad	1234605616436508552
	.quad	-9169081515752227073
	.size	indirect.pool, 16

	.section	.debug_abbrev,"",@progbits
	.byte	1
	.byte	17
	.byte	1
	.byte	37
	.byte	14
	.byte	19
	.byte	5
	.byte	3
	.byte	14
	.byte	16
	.byte	23
	.byte	27
	.byte	14
	.ascii	"\264B"
	.byte	25
	.byte	17
	.byte	1
	.byte	18
	.byte	6
	.byte	0
	.byte	0
	.byte	2
	.byte	52
	.byte	0
	.byte	3
	.byte	14
	.byte	73
	.byte	19
	.byte	58
	.byte	11
	.byte	59
	.byte	11
	.byte	110
	.byte	14
	.byte	0
	.byte	0
	.byte	3
	.byte	4
	.byte	1
	.byte	73
	.byte	19
	.byte	3
	.byte	14
	.byte	11
	.byte	11
	.byte	58
	.byte	11
	.byte	59
	.byte	5
	.ascii	"\210\001"
	.byte	15
	.byte	0
	.byte	0
	.byte	4
	.byte	40
	.byte	0
	.byte	3
	.byte	14
	.byte	28
	.byte	15
	.byte	0
	.byte	0
	.byte	5
	.byte	36
	.byte	0
	.byte	3
	.byte	14
	.byte	62
	.byte	11
	.byte	11
	.byte	11
	.byte	0
	.byte	0
	.byte	6
	.byte	52
	.byte	0
	.byte	3
	.byte	14
	.byte	73
	.byte	19
	.byte	58
	.byte	11
	.byte	59
	.byte	11
	.byte	2
	.byte	24
	.byte	110
	.byte	14
	.byte	0
	.byte	0
	.byte	7
	.byte	1
	.byte	1
	.byte	73
	.byte	19
	.byte	0
	.byte	0
	.byte	8
	.byte	33
	.byte	0
	.byte	73
	.byte	19
	.byte	55
	.byte	11
	.byte	0
	.byte	0
	.byte	9
	.byte	36
	.byte	0
	.byte	3
	.byte	14
	.byte	11
	.byte	11
	.byte	62
	.byte	11
	.byte	0
	.byte	0
	.byte	10
	.byte	52
	.byte	0
	.byte	3
	.byte	14
	.byte	73
	.byte	19
	.byte	58
	.byte	11
	.byte	59
	.byte	5
	.byte	110
	.byte	14
	.byte	0
	.byte	0
	.byte	11
	.byte	19
	.byte	1
	.byte	3
	.byte	14
	.byte	11
	.byte	11
	.ascii	"\210\001"
	.byte	15
	.byte	0
	.byte	0
	.byte	12
	.byte	13
	.byte	0
	.byte	3
	.byte	14
	.byte	73
	.byte	19
	.ascii	"\210\001"
	.byte	15
	.byte	56
	.byte	11
	.byte	0
	.byte	0
	.byte	13
	.byte	15
	.byte	0
	.byte	73
	.byte	19
	.byte	3
	.byte	14
	.byte	0
	.byte	0
	.byte	14
	.byte	19
	.byte	1
	.byte	3
	.byte	14
	.byte	11
	.byte	5
	.ascii	"\210\001"
	.byte	15
	.byte	0
	.byte	0
	.byte	15
	.byte	46
	.byte	1
	.byte	17
	.byte	1
	.byte	18
	.byte	6
	.byte	64
	.byte	24
	.byte	110
	.byte	14
	.byte	3
	.byte	14
	.byte	58
	.byte	11
	.byte	59
	.byte	11
	.byte	73
	.byte	19
	.byte	0
	.byte	0
	.byte	16
	.byte	5
	.byte	0
	.byte	2
	.byte	24
	.byte	3
	.byte	14
	.byte	58
	.byte	11
	.byte	59
	.byte	11
	.byte	73
	.byte	19
	.byte	0
	.byte	0
	.byte	17
	.byte	1
	.byte	1
	.ascii	"\207B"
	.byte	25
	.byte	73
	.byte	19
	.byte	0
	.byte	0
	.byte	0
	.section	.debug_info,"",@progbits
.Lcu_begin0:
	.long	.Ldebug_info_end0-.Ldebug_info_start0
.Ldebug_info_start0:
	.short	4
	.long	.debug_abbrev
	.byte	8
	.byte	1
	.long	.Linfo_string0
	.short	12
	.long	.Linfo_string1
	.long	.Lline_table_start0
	.long	.Linfo_string2

	.quad	.Lfunc_begin0
	.long	.Lfunc_end0-.Lfunc_begin0
	.byte	2
	.long	.Linfo_string3
	.long	57
	.byte	2
	.byte	6
	.long	.Linfo_string19
	.byte	3
	.long	150
	.long	.Linfo_string18
	.byte	8
	.byte	1
	.short	1027
	.byte	8
	.byte	4
	.long	.Linfo_string5
	.byte	0
	.byte	4
	.long	.Linfo_string6
	.byte	1
	.byte	4
	.long	.Linfo_string7
	.byte	2
	.byte	4
	.long	.Linfo_string8
	.byte	3
	.byte	4
	.long	.Linfo_string9
	.byte	4
	.byte	4
	.long	.Linfo_string10
	.byte	5
	.byte	4
	.long	.Linfo_string11
	.byte	6
	.byte	4
	.long	.Linfo_string12
	.byte	7
	.byte	4
	.long	.Linfo_string13
	.byte	8
	.byte	4
	.long	.Linfo_string14
	.byte	9
	.byte	4
	.long	.Linfo_string15
	.byte	10
	.byte	4
	.long	.Linfo_string16
	.byte	11
	.byte	4
	.long	.Linfo_string17
	.byte	12
	.byte	0
	.byte	5
	.long	.Linfo_string4
	.byte	7
	.byte	8
	.byte	2
	.long	.Linfo_string20
	.long	172
	.byte	3
	.byte	17
	.long	.Linfo_string22
	.byte	5
	.long	.Linfo_string21
	.byte	2
	.byte	1
	.byte	2
	.long	.Linfo_string23
	.long	194
	.byte	2
	.byte	8
	.long	.Linfo_string29
	.byte	3
	.long	227
	.long	.Linfo_string28
	.byte	1
	.byte	1
	.short	782
	.byte	1
	.byte	4
	.long	.Linfo_string25
	.byte	0
	.byte	4
	.long	.Linfo_string26
	.byte	1
	.byte	4
	.long	.Linfo_string27
	.byte	2
	.byte	0
	.byte	5
	.long	.Linfo_string24
	.byte	7
	.byte	1
	.byte	6
	.long	.Linfo_string30
	.long	259
	.byte	4
	.byte	2
	.byte	9
	.byte	3
	.quad	indirect.pool
	.long	.Linfo_string32
	.byte	7
	.long	150
	.byte	8
	.long	271
	.byte	2
	.byte	0
	.byte	9
	.long	.Linfo_string31
	.byte	8
	.byte	7
	.byte	10
	.long	.Linfo_string33
	.long	294
	.byte	5
	.short	1153
	.long	.Linfo_string37
	.byte	11
	.long	.Linfo_string36
	.byte	40
	.byte	8
	.byte	12
	.long	.Linfo_string34
	.long	313
	.byte	8
	.byte	0
	.byte	0
	.byte	7
	.long	325
	.byte	8
	.long	271
	.byte	5
	.byte	0
	.byte	5
	.long	.Linfo_string35
	.byte	7
	.byte	8
	.byte	2
	.long	.Linfo_string38
	.long	347
	.byte	2
	.byte	14
	.long	.Linfo_string99
	.byte	11
	.long	.Linfo_string98
	.byte	56
	.byte	8
	.byte	12
	.long	.Linfo_string39
	.long	673
	.byte	8
	.byte	0
	.byte	12
	.long	.Linfo_string47
	.long	294
	.byte	8
	.byte	8
	.byte	12
	.long	.Linfo_string50
	.long	387
	.byte	1
	.byte	48
	.byte	3
	.long	769
	.long	.Linfo_string97
	.byte	1
	.byte	5
	.short	1777
	.byte	1
	.byte	4
	.long	.Linfo_string52
	.byte	0
	.byte	4
	.long	.Linfo_string53
	.byte	1
	.byte	4
	.long	.Linfo_string54
	.byte	2
	.byte	4
	.long	.Linfo_string55
	.byte	3
	.byte	4
	.long	.Linfo_string56
	.byte	4
	.byte	4
	.long	.Linfo_string57
	.byte	5
	.byte	4
	.long	.Linfo_string58
	.byte	6
	.byte	4
	.long	.Linfo_string59
	.byte	7
	.byte	4
	.long	.Linfo_string60
	.byte	8
	.byte	4
	.long	.Linfo_string61
	.byte	9
	.byte	4
	.long	.Linfo_string62
	.byte	10
	.byte	4
	.long	.Linfo_string63
	.byte	11
	.byte	4
	.long	.Linfo_string64
	.byte	12
	.byte	4
	.long	.Linfo_string65
	.byte	13
	.byte	4
	.long	.Linfo_string66
	.byte	14
	.byte	4
	.long	.Linfo_string67
	.byte	15
	.byte	4
	.long	.Linfo_string68
	.byte	16
	.byte	4
	.long	.Linfo_string69
	.byte	17
	.byte	4
	.long	.Linfo_string70
	.byte	18
	.byte	4
	.long	.Linfo_string71
	.byte	19
	.byte	4
	.long	.Linfo_string72
	.byte	20
	.byte	4
	.long	.Linfo_string73
	.byte	21
	.byte	4
	.long	.Linfo_string74
	.byte	22
	.byte	4
	.long	.Linfo_string75
	.byte	23
	.byte	4
	.long	.Linfo_string76
	.byte	24
	.byte	4
	.long	.Linfo_string77
	.byte	25
	.byte	4
	.long	.Linfo_string78
	.byte	26
	.byte	4
	.long	.Linfo_string79
	.byte	27
	.byte	4
	.long	.Linfo_string80
	.byte	28
	.byte	4
	.long	.Linfo_string81
	.byte	29
	.byte	4
	.long	.Linfo_string82
	.byte	30
	.byte	4
	.long	.Linfo_string83
	.byte	31
	.byte	4
	.long	.Linfo_string84
	.byte	32
	.byte	4
	.long	.Linfo_string85
	.byte	33
	.byte	4
	.long	.Linfo_string86
	.byte	34
	.byte	4
	.long	.Linfo_string87
	.byte	35
	.byte	4
	.long	.Linfo_string88
	.byte	36
	.byte	4
	.long	.Linfo_string89
	.byte	37
	.byte	4
	.long	.Linfo_string90
	.byte	38
	.byte	4
	.long	.Linfo_string91
	.byte	39
	.byte	4
	.long	.Linfo_string92
	.byte	40
	.byte	4
	.long	.Linfo_string93
	.byte	41
	.byte	4
	.long	.Linfo_string94
	.byte	42
	.byte	4
	.long	.Linfo_string95
	.byte	43
	.byte	4
	.long	.Linfo_string96
	.byte	44
	.byte	0
	.byte	0
	.byte	13
	.long	682
	.long	.Linfo_string49
	.byte	11
	.long	.Linfo_string48
	.byte	72
	.byte	8
	.byte	12
	.long	.Linfo_string40
	.long	723
	.byte	8
	.byte	0
	.byte	12
	.long	.Linfo_string46
	.long	723
	.byte	8
	.byte	16
	.byte	12
	.long	.Linfo_string47
	.long	294
	.byte	8
	.byte	32
	.byte	0
	.byte	11
	.long	.Linfo_string45
	.byte	16
	.byte	8
	.byte	12
	.long	.Linfo_string41
	.long	753
	.byte	8
	.byte	0
	.byte	12
	.long	.Linfo_string44
	.long	325
	.byte	8
	.byte	8
	.byte	0
	.byte	13
	.long	762
	.long	.Linfo_string43
	.byte	5
	.long	.Linfo_string42
	.byte	7
	.byte	1
	.byte	5
	.long	.Linfo_string51
	.byte	7
	.byte	1
	.byte	10
	.long	.Linfo_string100
	.long	792
	.byte	5
	.short	2072
	.long	.Linfo_string103
	.byte	14
	.long	.Linfo_string102
	.short	256
	.byte	1
	.byte	12
	.long	.Linfo_string101
	.long	823
	.byte	1
	.byte	0
	.byte	12
	.long	.Linfo_string44
	.long	762
	.byte	1
	.byte	255
	.byte	0
	.byte	7
	.long	762
	.byte	8
	.long	271
	.byte	255
	.byte	0
	.byte	10
	.long	.Linfo_string104
	.long	682
	.byte	6
	.short	4997
	.long	.Linfo_string105
	.byte	15
	.quad	.Lfunc_begin0
	.long	.Lfunc_end0-.Lfunc_begin0
	.byte	1
	.byte	86
	.long	.Linfo_string106
	.long	.Linfo_string107
	.byte	4
	.byte	3
	.long	907
	.byte	16
	.byte	1
	.byte	85
	.long	.Linfo_string109
	.byte	4
	.byte	3
	.long	914
	.byte	16
	.byte	1
	.byte	84
	.long	.Linfo_string112
	.byte	4
	.byte	3
	.long	914
	.byte	0
	.byte	5
	.long	.Linfo_string108
	.byte	5
	.byte	0
	.byte	13
	.long	923
	.long	.Linfo_string111
	.byte	17

	.long	935
	.byte	8
	.long	271
	.byte	64
	.byte	0
	.byte	5
	.long	.Linfo_string110
	.byte	7
	.byte	1
	.byte	0
.Ldebug_info_end0:
	.section	.debug_str,"MS",@progbits,1
.Linfo_string0:
	.asciz	"zig 0.15.1"
.Linfo_string1:
	.asciz	"indirect"
.Linfo_string2:
	.asciz	"/home/t3/.t3/worktrees/kuznechik.zig/t3-9024bc12/docs/performance/2026-10-29/gfni-memory-operands/probes"
.Linfo_string3:
	.asciz	"zig_backend"
.Linfo_string4:
	.asciz	"u64"
.Linfo_string5:
	.asciz	"other"
.Linfo_string6:
	.asciz	"stage1"
.Linfo_string7:
	.asciz	"stage2_llvm"
.Linfo_string8:
	.asciz	"stage2_c"
.Linfo_string9:
	.asciz	"stage2_wasm"
.Linfo_string10:
	.asciz	"stage2_arm"
.Linfo_string11:
	.asciz	"stage2_x86_64"
.Linfo_string12:
	.asciz	"stage2_aarch64"
.Linfo_string13:
	.asciz	"stage2_x86"
.Linfo_string14:
	.asciz	"stage2_riscv64"
.Linfo_string15:
	.asciz	"stage2_sparc64"
.Linfo_string16:
	.asciz	"stage2_spirv"
.Linfo_string17:
	.asciz	"stage2_powerpc"
.Linfo_string18:
	.asciz	"builtin.CompilerBackend"
.Linfo_string19:
	.asciz	"builtin.zig_backend"
.Linfo_string20:
	.asciz	"simplified_logic"
.Linfo_string21:
	.asciz	"bool"
.Linfo_string22:
	.asciz	"start.simplified_logic"
.Linfo_string23:
	.asciz	"output_mode"
.Linfo_string24:
	.asciz	"u2"
.Linfo_string25:
	.asciz	"Exe"
.Linfo_string26:
	.asciz	"Lib"
.Linfo_string27:
	.asciz	"Obj"
.Linfo_string28:
	.asciz	"builtin.OutputMode"
.Linfo_string29:
	.asciz	"builtin.output_mode"
.Linfo_string30:
	.asciz	"pool"
.Linfo_string31:
	.asciz	"__ARRAY_SIZE_TYPE__"
.Linfo_string32:
	.asciz	"indirect.pool"
.Linfo_string33:
	.asciz	"empty"
.Linfo_string34:
	.asciz	"ints"
.Linfo_string35:
	.asciz	"usize"
.Linfo_string36:
	.asciz	"Target.Cpu.Feature.Set"
.Linfo_string37:
	.asciz	"Target.Cpu.Feature.Set.empty"
.Linfo_string38:
	.asciz	"cpu"
.Linfo_string39:
	.asciz	"model"
.Linfo_string40:
	.asciz	"name"
.Linfo_string41:
	.asciz	"ptr"
.Linfo_string42:
	.asciz	"u8"
.Linfo_string43:
	.asciz	"*u8"
.Linfo_string44:
	.asciz	"len"
.Linfo_string45:
	.asciz	"[]u8"
.Linfo_string46:
	.asciz	"llvm_name"
.Linfo_string47:
	.asciz	"features"
.Linfo_string48:
	.asciz	"Target.Cpu.Model"
.Linfo_string49:
	.asciz	"*Target.Cpu.Model"
.Linfo_string50:
	.asciz	"arch"
.Linfo_string51:
	.asciz	"u6"
.Linfo_string52:
	.asciz	"amdgcn"
.Linfo_string53:
	.asciz	"arc"
.Linfo_string54:
	.asciz	"arm"
.Linfo_string55:
	.asciz	"armeb"
.Linfo_string56:
	.asciz	"thumb"
.Linfo_string57:
	.asciz	"thumbeb"
.Linfo_string58:
	.asciz	"aarch64"
.Linfo_string59:
	.asciz	"aarch64_be"
.Linfo_string60:
	.asciz	"avr"
.Linfo_string61:
	.asciz	"bpfel"
.Linfo_string62:
	.asciz	"bpfeb"
.Linfo_string63:
	.asciz	"csky"
.Linfo_string64:
	.asciz	"hexagon"
.Linfo_string65:
	.asciz	"kalimba"
.Linfo_string66:
	.asciz	"lanai"
.Linfo_string67:
	.asciz	"loongarch32"
.Linfo_string68:
	.asciz	"loongarch64"
.Linfo_string69:
	.asciz	"m68k"
.Linfo_string70:
	.asciz	"mips"
.Linfo_string71:
	.asciz	"mipsel"
.Linfo_string72:
	.asciz	"mips64"
.Linfo_string73:
	.asciz	"mips64el"
.Linfo_string74:
	.asciz	"msp430"
.Linfo_string75:
	.asciz	"or1k"
.Linfo_string76:
	.asciz	"nvptx"
.Linfo_string77:
	.asciz	"nvptx64"
.Linfo_string78:
	.asciz	"powerpc"
.Linfo_string79:
	.asciz	"powerpcle"
.Linfo_string80:
	.asciz	"powerpc64"
.Linfo_string81:
	.asciz	"powerpc64le"
.Linfo_string82:
	.asciz	"propeller"
.Linfo_string83:
	.asciz	"riscv32"
.Linfo_string84:
	.asciz	"riscv64"
.Linfo_string85:
	.asciz	"s390x"
.Linfo_string86:
	.asciz	"sparc"
.Linfo_string87:
	.asciz	"sparc64"
.Linfo_string88:
	.asciz	"spirv32"
.Linfo_string89:
	.asciz	"spirv64"
.Linfo_string90:
	.asciz	"ve"
.Linfo_string91:
	.asciz	"wasm32"
.Linfo_string92:
	.asciz	"wasm64"
.Linfo_string93:
	.asciz	"x86"
.Linfo_string94:
	.asciz	"x86_64"
.Linfo_string95:
	.asciz	"xcore"
.Linfo_string96:
	.asciz	"xtensa"
.Linfo_string97:
	.asciz	"Target.Cpu.Arch"
.Linfo_string98:
	.asciz	"Target.Cpu"
.Linfo_string99:
	.asciz	"builtin.cpu"
.Linfo_string100:
	.asciz	"none"
.Linfo_string101:
	.asciz	"buffer"
.Linfo_string102:
	.asciz	"Target.DynamicLinker"
.Linfo_string103:
	.asciz	"Target.DynamicLinker.none"
.Linfo_string104:
	.asciz	"znver5"
.Linfo_string105:
	.asciz	"Target.x86.cpu.znver5"
.Linfo_string106:
	.asciz	"indirect.probe"
.Linfo_string107:
	.asciz	"probe"
.Linfo_string108:
	.asciz	"void"
.Linfo_string109:
	.asciz	"a"
.Linfo_string110:
	.asciz	"@Vector(64, u8)"
.Linfo_string111:
	.asciz	"*@Vector(64, u8)"
.Linfo_string112:
	.asciz	"out"
	.section	.debug_pubnames,"",@progbits
	.long	.LpubNames_end0-.LpubNames_start0
.LpubNames_start0:
	.short	2
	.long	.Lcu_begin0
	.long	943
	.long	42
	.asciz	"zig_backend"
	.long	71
	.asciz	"other"
	.long	77
	.asciz	"stage1"
	.long	83
	.asciz	"stage2_llvm"
	.long	89
	.asciz	"stage2_c"
	.long	95
	.asciz	"stage2_wasm"
	.long	101
	.asciz	"stage2_arm"
	.long	107
	.asciz	"stage2_x86_64"
	.long	113
	.asciz	"stage2_aarch64"
	.long	119
	.asciz	"stage2_x86"
	.long	125
	.asciz	"stage2_riscv64"
	.long	131
	.asciz	"stage2_sparc64"
	.long	137
	.asciz	"stage2_spirv"
	.long	143
	.asciz	"stage2_powerpc"
	.long	157
	.asciz	"simplified_logic"
	.long	179
	.asciz	"output_mode"
	.long	208
	.asciz	"Exe"
	.long	214
	.asciz	"Lib"
	.long	220
	.asciz	"Obj"
	.long	234
	.asciz	"pool"
	.long	278
	.asciz	"empty"
	.long	332
	.asciz	"cpu"
	.long	776
	.asciz	"none"
	.long	835
	.asciz	"znver5"
	.long	851
	.asciz	"probe"
	.long	0
.LpubNames_end0:
	.section	.debug_pubtypes,"",@progbits
	.long	.LpubTypes_end0-.LpubTypes_start0
.LpubTypes_start0:
	.short	2
	.long	.Lcu_begin0
	.long	943
	.long	57
	.asciz	"builtin.CompilerBackend"
	.long	150
	.asciz	"u64"
	.long	172
	.asciz	"bool"
	.long	194
	.asciz	"builtin.OutputMode"
	.long	227
	.asciz	"u2"
	.long	294
	.asciz	"Target.Cpu.Feature.Set"
	.long	325
	.asciz	"usize"
	.long	347
	.asciz	"Target.Cpu"
	.long	673
	.asciz	"*Target.Cpu.Model"
	.long	682
	.asciz	"Target.Cpu.Model"
	.long	723
	.asciz	"[]u8"
	.long	753
	.asciz	"*u8"
	.long	762
	.asciz	"u8"
	.long	769
	.asciz	"u6"
	.long	792
	.asciz	"Target.DynamicLinker"
	.long	907
	.asciz	"void"
	.long	914
	.asciz	"*@Vector(64, u8)"
	.long	935
	.asciz	"@Vector(64, u8)"
	.long	0
.LpubTypes_end0:
	.section	".note.GNU-stack","",@progbits
	.section	.debug_line,"",@progbits
.Lline_table_start0:
