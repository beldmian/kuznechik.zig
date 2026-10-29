000000000104c6c0 <ocb.OcbWithTag(kuznechik.Cipher,16).Schedule.init>:
 104c6c0:	55                   	push   %rbp
 104c6c1:	48 89 e5             	mov    %rsp,%rbp
 104c6c4:	53                   	push   %rbx
 104c6c5:	48 81 ec 38 03 00 00 	sub    $0x338,%rsp
 104c6cc:	48 89 f0             	mov    %rsi,%rax
 104c6cf:	48 8d b5 c0 fc ff ff 	lea    -0x340(%rbp),%rsi
 104c6d6:	48 89 fb             	mov    %rdi,%rbx
 104c6d9:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 104c6dd:	48 89 c7             	mov    %rax,%rdi
 104c6e0:	c5 f8 29 85 c0 fc ff 	vmovaps %xmm0,-0x340(%rbp)
 104c6e7:	ff
 104c6e8:	e8 f3 d4 00 00       	call   1059be0 <kuznechik.Cipher.encrypt>
 104c6ed:	c5 f9 6f 8d c0 fc ff 	vmovdqa -0x340(%rbp),%xmm1
 104c6f4:	ff
 104c6f5:	c4 e3 79 14 ca 01    	vpextrb $0x1,%xmm1,%edx
 104c6fb:	c5 f9 7e c8          	vmovd  %xmm1,%eax
 104c6ff:	c4 e3 79 14 ce 02    	vpextrb $0x2,%xmm1,%esi
 104c705:	c4 c3 79 14 c8 03    	vpextrb $0x3,%xmm1,%r8d
 104c70b:	c5 f9 70 d1 55       	vpshufd $0x55,%xmm1,%xmm2
 104c710:	c4 c3 79 14 ca 0f    	vpextrb $0xf,%xmm1,%r10d
 104c716:	89 d7                	mov    %edx,%edi
 104c718:	41 89 f1             	mov    %esi,%r9d
 104c71b:	8d 0c 00             	lea    (%rax,%rax,1),%ecx
 104c71e:	00 d2                	add    %dl,%dl
 104c720:	41 c0 e8 07          	shr    $0x7,%r8b
 104c724:	40 00 f6             	add    %sil,%sil
 104c727:	c5 d9 71 d2 07       	vpsrlw $0x7,%xmm2,%xmm4
 104c72c:	c0 f8 07             	sar    $0x7,%al
 104c72f:	45 00 d2             	add    %r10b,%r10b
 104c732:	40 c0 ef 07          	shr    $0x7,%dil
 104c736:	41 c0 e9 07          	shr    $0x7,%r9b
 104c73a:	41 08 f0             	or     %sil,%r8b
 104c73d:	40 c0 ee 07          	shr    $0x7,%sil
 104c741:	24 87                	and    $0x87,%al
 104c743:	40 08 cf             	or     %cl,%dil
 104c746:	41 08 d1             	or     %dl,%r9b
 104c749:	c0 ea 07             	shr    $0x7,%dl
 104c74c:	44 30 d0             	xor    %r10b,%al
 104c74f:	c0 f9 07             	sar    $0x7,%cl
 104c752:	c5 f9 6e c7          	vmovd  %edi,%xmm0
 104c756:	40 00 ff             	add    %dil,%dil
 104c759:	80 e1 87             	and    $0x87,%cl
 104c75c:	c4 c3 79 20 c1 01    	vpinsrb $0x1,%r9d,%xmm0,%xmm0
 104c762:	45 00 c9             	add    %r9b,%r9b
 104c765:	40 08 fa             	or     %dil,%dl
 104c768:	c4 c3 79 20 d8 02    	vpinsrb $0x2,%r8d,%xmm0,%xmm3
 104c76e:	c5 f9 73 d1 18       	vpsrlq $0x18,%xmm1,%xmm0
 104c773:	c5 f1 73 d9 07       	vpsrldq $0x7,%xmm1,%xmm1
 104c778:	44 08 ce             	or     %r9b,%sil
 104c77b:	45 00 c0             	add    %r8b,%r8b
 104c77e:	c5 f9 fd d0          	vpaddw %xmm0,%xmm0,%xmm2
 104c782:	c4 e2 79 58 05 c5 3a 	vpbroadcastd -0x4c53b(%rip),%xmm0        # 1000250 <__init_array_end+0x250>
 104c789:	fb ff
 104c78b:	c5 f1 fd e9          	vpaddw %xmm1,%xmm1,%xmm5
 104c78f:	c5 f9 6f 0d 59 3c fb 	vmovdqa -0x4c3a7(%rip),%xmm1        # 10003f0 <__init_array_end+0x3f0>
 104c796:	ff
 104c797:	62 f3 7d 08 25 d4 e2 	vpternlogd $0xe2,%xmm4,%xmm0,%xmm2
 104c79e:	c4 e2 79 59 a5 c8 fc 	vpbroadcastq -0x338(%rbp),%xmm4
 104c7a5:	ff ff
 104c7a7:	f2 0f 78 da 20 18    	insertq $0x18,$0x20,%xmm2,%xmm3
 104c7ad:	c5 f9 7e d7          	vmovd  %xmm2,%edi
 104c7b1:	40 c0 ef 07          	shr    $0x7,%dil
 104c7b5:	41 08 f8             	or     %dil,%r8b
 104c7b8:	c5 d9 71 d4 07       	vpsrlw $0x7,%xmm4,%xmm4
 104c7bd:	62 f3 7d 08 25 ec e2 	vpternlogd $0xe2,%xmm4,%xmm0,%xmm5
 104c7c4:	c4 e2 79 58 25 7f 3a 	vpbroadcastd -0x4c581(%rip),%xmm4        # 100024c <__init_array_end+0x24c>
 104c7cb:	fb ff
 104c7cd:	c5 c9 73 d5 08       	vpsrlq $0x8,%xmm5,%xmm6
 104c7d2:	c5 d1 fd fd          	vpaddw %xmm5,%xmm5,%xmm7
 104c7d6:	62 f2 6d 08 75 e5    	vpermi2b %xmm5,%xmm2,%xmm4
 104c7dc:	62 f2 75 08 7d eb    	vpermt2b %xmm3,%xmm1,%xmm5
 104c7e2:	c5 e9 fd d2          	vpaddw %xmm2,%xmm2,%xmm2
 104c7e6:	c5 e1 71 d4 07       	vpsrlw $0x7,%xmm4,%xmm3
 104c7eb:	c4 e3 49 20 e0 07    	vpinsrb $0x7,%eax,%xmm6,%xmm4
 104c7f1:	c4 63 51 20 c0 0f    	vpinsrb $0xf,%eax,%xmm5,%xmm8
 104c7f7:	00 c0                	add    %al,%al
 104c7f9:	62 f3 7d 08 25 d3 e2 	vpternlogd $0xe2,%xmm3,%xmm0,%xmm2
 104c800:	c5 f9 6e da          	vmovd  %edx,%xmm3
 104c804:	c5 d1 71 d4 07       	vpsrlw $0x7,%xmm4,%xmm5
 104c809:	30 c1                	xor    %al,%cl
 104c80b:	b8 40 00 00 00       	mov    $0x40,%eax
 104c810:	c5 79 7f 85 d0 fc ff 	vmovdqa %xmm8,-0x330(%rbp)
 104c817:	ff
 104c818:	c4 e3 61 20 de 01    	vpinsrb $0x1,%esi,%xmm3,%xmm3
 104c81e:	62 f3 7d 08 25 ef b8 	vpternlogd $0xb8,%xmm7,%xmm0,%xmm5
 104c825:	c4 c3 61 20 d8 02    	vpinsrb $0x2,%r8d,%xmm3,%xmm3
 104c82b:	f2 0f 78 da 20 18    	insertq $0x18,$0x20,%xmm2,%xmm3
 104c831:	62 f2 75 08 7d eb    	vpermt2b %xmm3,%xmm1,%xmm5
 104c837:	c4 e3 51 20 e1 0f    	vpinsrb $0xf,%ecx,%xmm5,%xmm4
 104c83d:	c5 f9 7f a5 e0 fc ff 	vmovdqa %xmm4,-0x320(%rbp)
 104c844:	ff
 104c845:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 104c84c:	00 00 00 00
 104c850:	c4 e3 79 14 e6 01    	vpextrb $0x1,%xmm4,%esi
 104c856:	c5 f9 7e e1          	vmovd  %xmm4,%ecx
 104c85a:	c4 e3 79 14 e7 02    	vpextrb $0x2,%xmm4,%edi
 104c860:	c4 c3 79 14 e1 03    	vpextrb $0x3,%xmm4,%r9d
 104c866:	c5 f9 70 ec 55       	vpshufd $0x55,%xmm4,%xmm5
 104c86b:	c4 c3 79 14 e3 0f    	vpextrb $0xf,%xmm4,%r11d
 104c871:	41 89 f0             	mov    %esi,%r8d
 104c874:	41 89 fa             	mov    %edi,%r10d
 104c877:	8d 14 09             	lea    (%rcx,%rcx,1),%edx
 104c87a:	40 00 f6             	add    %sil,%sil
 104c87d:	41 c0 e9 07          	shr    $0x7,%r9b
 104c881:	40 00 ff             	add    %dil,%dil
 104c884:	c5 d1 71 d5 07       	vpsrlw $0x7,%xmm5,%xmm5
 104c889:	c0 f9 07             	sar    $0x7,%cl
 104c88c:	45 00 db             	add    %r11b,%r11b
 104c88f:	41 c0 e8 07          	shr    $0x7,%r8b
 104c893:	41 c0 ea 07          	shr    $0x7,%r10b
 104c897:	41 08 f9             	or     %dil,%r9b
 104c89a:	80 e1 87             	and    $0x87,%cl
 104c89d:	40 c0 ef 07          	shr    $0x7,%dil
 104c8a1:	41 08 d0             	or     %dl,%r8b
 104c8a4:	41 08 f2             	or     %sil,%r10b
 104c8a7:	44 30 d9             	xor    %r11b,%cl
 104c8aa:	40 c0 ee 07          	shr    $0x7,%sil
 104c8ae:	c0 fa 07             	sar    $0x7,%dl
 104c8b1:	c4 c1 79 6e d0       	vmovd  %r8d,%xmm2
 104c8b6:	45 00 c0             	add    %r8b,%r8b
 104c8b9:	80 e2 87             	and    $0x87,%dl
 104c8bc:	c4 c3 69 20 d2 01    	vpinsrb $0x1,%r10d,%xmm2,%xmm2
 104c8c2:	45 00 d2             	add    %r10b,%r10b
 104c8c5:	44 08 c6             	or     %r8b,%sil
 104c8c8:	c4 c3 69 20 d9 02    	vpinsrb $0x2,%r9d,%xmm2,%xmm3
 104c8ce:	c5 e9 73 d4 18       	vpsrlq $0x18,%xmm4,%xmm2
 104c8d3:	44 08 d7             	or     %r10b,%dil
 104c8d6:	45 00 c9             	add    %r9b,%r9b
 104c8d9:	c5 e9 fd d2          	vpaddw %xmm2,%xmm2,%xmm2
 104c8dd:	62 f3 7d 08 25 d5 e2 	vpternlogd $0xe2,%xmm5,%xmm0,%xmm2
 104c8e4:	c5 d1 73 dc 07       	vpsrldq $0x7,%xmm4,%xmm5
 104c8e9:	c5 f9 70 e4 ee       	vpshufd $0xee,%xmm4,%xmm4
 104c8ee:	f2 0f 78 da 20 18    	insertq $0x18,$0x20,%xmm2,%xmm3
 104c8f4:	c5 d9 71 d4 07       	vpsrlw $0x7,%xmm4,%xmm4
 104c8f9:	c5 d1 fd ed          	vpaddw %xmm5,%xmm5,%xmm5
 104c8fd:	c4 c1 79 7e d0       	vmovd  %xmm2,%r8d
 104c902:	c5 e9 fd d2          	vpaddw %xmm2,%xmm2,%xmm2
 104c906:	62 f3 7d 08 25 ec e2 	vpternlogd $0xe2,%xmm4,%xmm0,%xmm5
 104c90d:	41 c0 e8 07          	shr    $0x7,%r8b
 104c911:	c5 d9 73 d5 08       	vpsrlq $0x8,%xmm5,%xmm4
 104c916:	c5 d1 fd f5          	vpaddw %xmm5,%xmm5,%xmm6
 104c91a:	45 08 c1             	or     %r8b,%r9b
 104c91d:	62 f2 75 08 7d eb    	vpermt2b %xmm3,%xmm1,%xmm5
 104c923:	c4 e3 51 20 d9 0f    	vpinsrb $0xf,%ecx,%xmm5,%xmm3
 104c929:	c5 f9 7f 9c 05 b0 fc 	vmovdqa %xmm3,-0x350(%rbp,%rax,1)
 104c930:	ff ff
 104c932:	c5 f9 70 dd 55       	vpshufd $0x55,%xmm5,%xmm3
 104c937:	c5 e1 71 d3 07       	vpsrlw $0x7,%xmm3,%xmm3
 104c93c:	62 f3 7d 08 25 d3 e2 	vpternlogd $0xe2,%xmm3,%xmm0,%xmm2
 104c943:	c5 f9 6e de          	vmovd  %esi,%xmm3
 104c947:	c4 e3 61 20 df 01    	vpinsrb $0x1,%edi,%xmm3,%xmm3
 104c94d:	c4 c3 61 20 d9 02    	vpinsrb $0x2,%r9d,%xmm3,%xmm3
 104c953:	f2 0f 78 da 20 18    	insertq $0x18,$0x20,%xmm2,%xmm3
 104c959:	c4 e3 59 20 d1 07    	vpinsrb $0x7,%ecx,%xmm4,%xmm2
 104c95f:	00 c9                	add    %cl,%cl
 104c961:	c5 e9 71 d2 07       	vpsrlw $0x7,%xmm2,%xmm2
 104c966:	30 ca                	xor    %cl,%dl
 104c968:	62 f3 7d 08 25 d6 b8 	vpternlogd $0xb8,%xmm6,%xmm0,%xmm2
 104c96f:	62 f2 75 08 7d d3    	vpermt2b %xmm3,%xmm1,%xmm2
 104c975:	c4 e3 69 20 e2 0f    	vpinsrb $0xf,%edx,%xmm2,%xmm4
 104c97b:	c5 f9 7f a4 05 c0 fc 	vmovdqa %xmm4,-0x340(%rbp,%rax,1)
 104c982:	ff ff
 104c984:	48 83 c0 20          	add    $0x20,%rax
 104c988:	48 3d 40 03 00 00    	cmp    $0x340,%rax
 104c98e:	0f 85 bc fe ff ff    	jne    104c850 <ocb.OcbWithTag(kuznechik.Cipher,16).Schedule.init+0x190>
 104c994:	48 8d b5 c0 fc ff ff 	lea    -0x340(%rbp),%rsi
 104c99b:	ba 30 03 00 00       	mov    $0x330,%edx
 104c9a0:	48 89 df             	mov    %rbx,%rdi
 104c9a3:	e8 c8 92 01 00       	call   1065c70 <memcpy>
 104c9a8:	48 81 c4 38 03 00 00 	add    $0x338,%rsp
 104c9af:	5b                   	pop    %rbx
 104c9b0:	5d                   	pop    %rbp
 104c9b1:	c3                   	ret
 104c9b2:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 104c9b9:	1f 84 00 00 00 00 00
