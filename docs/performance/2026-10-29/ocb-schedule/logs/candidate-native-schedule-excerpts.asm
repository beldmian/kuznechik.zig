 104f6db:	40 08 fa             	or     %dil,%dl
 104f6de:	c5 f9 fd c0          	vpaddw %xmm0,%xmm0,%xmm0
 104f6e2:	00 c9                	add    %cl,%cl
 104f6e4:	c4 e3 71 20 ca 02    	vpinsrb $0x2,%edx,%xmm1,%xmm1
 104f6ea:	30 c8                	xor    %cl,%al
 104f6ec:	4c 39 f3             	cmp    %r14,%rbx
 104f6ef:	f2 0f 78 ca 20 18    	insertq $0x18,$0x20,%xmm2,%xmm1
 104f6f5:	c4 e2 79 59 94 24 48 	vpbroadcastq 0x348(%rsp),%xmm2
 104f6fc:	03 00 00
 104f6ff:	4c 0f 47 f3          	cmova  %rbx,%r14
 104f703:	c5 e9 71 d2 07       	vpsrlw $0x7,%xmm2,%xmm2
 104f708:	62 f3 55 08 25 c2 e2 	vpternlogd $0xe2,%xmm2,%xmm5,%xmm0
 104f70f:	62 f2 4d 08 7d c1    	vpermt2b %xmm1,%xmm6,%xmm0
 104f715:	c4 e3 79 20 c0 0f    	vpinsrb $0xf,%eax,%xmm0,%xmm0
 104f71b:	c5 f9 7f 84 24 50 03 	vmovdqa %xmm0,0x350(%rsp)
 104f722:	00 00
 104f724:	4d 85 f6             	test   %r14,%r14
 104f727:	0f 84 32 02 00 00    	je     104f95f <bench.runSecond+0x61f>
 104f72d:	f3 49 0f bd c6       	lzcnt  %r14,%rax
 104f732:	b9 40 00 00 00       	mov    $0x40,%ecx
 104f737:	48 29 c1             	sub    %rax,%rcx
 104f73a:	48 83 f8 3f          	cmp    $0x3f,%rax
 104f73e:	75 10                	jne    104f750 <bench.runSecond+0x410>
 104f740:	31 c0                	xor    %eax,%eax
 104f742:	e9 5b 01 00 00       	jmp    104f8a2 <bench.runSecond+0x562>
 104f747:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 104f74e:	00 00
 104f750:	89 ca                	mov    %ecx,%edx
 104f752:	83 e2 7e             	and    $0x7e,%edx
 104f755:	48 8d b4 24 70 03 00 	lea    0x370(%rsp),%rsi
 104f75c:	00
 104f75d:	31 c0                	xor    %eax,%eax
 104f75f:	90                   	nop
 104f760:	c4 c3 79 14 c1 01    	vpextrb $0x1,%xmm0,%r9d
 104f766:	c5 f9 7e c7          	vmovd  %xmm0,%edi
 104f76a:	c4 c3 79 14 c3 02    	vpextrb $0x2,%xmm0,%r11d
 104f770:	c4 e3 79 14 c3 03    	vpextrb $0x3,%xmm0,%ebx
 104f776:	c5 f9 70 d8 55       	vpshufd $0x55,%xmm0,%xmm3
 104f77b:	c4 c3 79 14 c4 0f    	vpextrb $0xf,%xmm0,%r12d
 104f781:	48 83 c0 02          	add    $0x2,%rax
 104f785:	45 89 ca             	mov    %r9d,%r10d
 104f788:	45 89 de             	mov    %r11d,%r14d
 104f78b:	44 8d 04 3f          	lea    (%rdi,%rdi,1),%r8d
 104f78f:	45 00 c9             	add    %r9b,%r9b
 104f792:	c0 eb 07             	shr    $0x7,%bl
 104f795:	45 00 db             	add    %r11b,%r11b
 104f798:	c5 e1 71 d3 07       	vpsrlw $0x7,%xmm3,%xmm3
 104f79d:	40 c0 ff 07          	sar    $0x7,%dil
 104f7a1:	45 00 e4             	add    %r12b,%r12b
 104f7a4:	41 c0 ea 07          	shr    $0x7,%r10b
 104f7a8:	41 c0 ee 07          	shr    $0x7,%r14b
 104f7ac:	44 08 db             	or     %r11b,%bl
 104f7af:	40 80 e7 87          	and    $0x87,%dil
 104f7b3:	41 c0 eb 07          	shr    $0x7,%r11b
 104f7b7:	45 08 c2             	or     %r8b,%r10b
 104f7ba:	45 08 ce             	or     %r9b,%r14b
 104f7bd:	44 30 e7             	xor    %r12b,%dil
 104f7c0:	41 c0 e9 07          	shr    $0x7,%r9b
 104f7c4:	41 c0 f8 07          	sar    $0x7,%r8b
 104f7c8:	c4 c1 79 6e ca       	vmovd  %r10d,%xmm1
 104f7cd:	45 00 d2             	add    %r10b,%r10b
 104f7d0:	41 80 e0 87          	and    $0x87,%r8b
 104f7d4:	c4 c3 71 20 ce 01    	vpinsrb $0x1,%r14d,%xmm1,%xmm1
 104f7da:	45 00 f6             	add    %r14b,%r14b
 104f7dd:	45 08 d1             	or     %r10b,%r9b
 104f7e0:	c4 e3 71 20 d3 02    	vpinsrb $0x2,%ebx,%xmm1,%xmm2
 104f7e6:	c5 f1 73 d0 18       	vpsrlq $0x18,%xmm0,%xmm1
 104f7eb:	45 08 f3             	or     %r14b,%r11b

 1050be6:	c4 e3 79 14 d9 0f    	vpextrb $0xf,%xmm3,%ecx
 1050bec:	40 08 fa             	or     %dil,%dl
 1050bef:	00 c9                	add    %cl,%cl
 1050bf1:	c4 e3 79 20 c2 02    	vpinsrb $0x2,%edx,%xmm0,%xmm0
 1050bf7:	30 c8                	xor    %cl,%al
 1050bf9:	4c 39 fb             	cmp    %r15,%rbx
 1050bfc:	f2 0f 78 c1 20 18    	insertq $0x18,$0x20,%xmm1,%xmm0
 1050c02:	c5 f1 73 db 07       	vpsrldq $0x7,%xmm3,%xmm1
 1050c07:	c5 e9 71 d2 07       	vpsrlw $0x7,%xmm2,%xmm2
 1050c0c:	4c 0f 47 fb          	cmova  %rbx,%r15
 1050c10:	c5 f1 fd c9          	vpaddw %xmm1,%xmm1,%xmm1
 1050c14:	62 f3 55 08 25 ca e2 	vpternlogd $0xe2,%xmm2,%xmm5,%xmm1
 1050c1b:	62 f2 4d 08 7d c8    	vpermt2b %xmm0,%xmm6,%xmm1
 1050c21:	c4 e3 71 20 f8 0f    	vpinsrb $0xf,%eax,%xmm1,%xmm7
 1050c27:	c5 f9 7f bc 24 60 0b 	vmovdqa %xmm7,0xb60(%rsp)
 1050c2e:	00 00
 1050c30:	4d 85 ff             	test   %r15,%r15
 1050c33:	0f 84 40 02 00 00    	je     1050e79 <bench.runSecond+0x1b39>
 1050c39:	f3 49 0f bd c7       	lzcnt  %r15,%rax
 1050c3e:	b9 40 00 00 00       	mov    $0x40,%ecx
 1050c43:	48 29 c1             	sub    %rax,%rcx
 1050c46:	48 83 f8 3f          	cmp    $0x3f,%rax
 1050c4a:	75 14                	jne    1050c60 <bench.runSecond+0x1920>
 1050c4c:	31 c0                	xor    %eax,%eax
 1050c4e:	c5 f9 6f c7          	vmovdqa %xmm7,%xmm0
 1050c52:	e9 6b 01 00 00       	jmp    1050dc2 <bench.runSecond+0x1a82>
 1050c57:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 1050c5e:	00 00
 1050c60:	89 ca                	mov    %ecx,%edx
 1050c62:	83 e2 7e             	and    $0x7e,%edx
 1050c65:	48 8d b4 24 80 0b 00 	lea    0xb80(%rsp),%rsi
 1050c6c:	00
 1050c6d:	31 c0                	xor    %eax,%eax
 1050c6f:	c5 f9 6f c7          	vmovdqa %xmm7,%xmm0
 1050c73:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1050c7a:	84 00 00 00 00 00
 1050c80:	c4 c3 79 14 c1 01    	vpextrb $0x1,%xmm0,%r9d
 1050c86:	c5 f9 7e c7          	vmovd  %xmm0,%edi
 1050c8a:	c4 c3 79 14 c3 02    	vpextrb $0x2,%xmm0,%r11d
 1050c90:	c4 e3 79 14 c3 03    	vpextrb $0x3,%xmm0,%ebx
 1050c96:	c5 f9 70 d8 55       	vpshufd $0x55,%xmm0,%xmm3
 1050c9b:	c4 c3 79 14 c4 0f    	vpextrb $0xf,%xmm0,%r12d
 1050ca1:	48 83 c0 02          	add    $0x2,%rax
 1050ca5:	45 89 ca             	mov    %r9d,%r10d
 1050ca8:	45 89 df             	mov    %r11d,%r15d
 1050cab:	44 8d 04 3f          	lea    (%rdi,%rdi,1),%r8d
 1050caf:	45 00 c9             	add    %r9b,%r9b
 1050cb2:	c0 eb 07             	shr    $0x7,%bl
 1050cb5:	45 00 db             	add    %r11b,%r11b
 1050cb8:	c5 e1 71 d3 07       	vpsrlw $0x7,%xmm3,%xmm3
 1050cbd:	40 c0 ff 07          	sar    $0x7,%dil
 1050cc1:	45 00 e4             	add    %r12b,%r12b
 1050cc4:	41 c0 ea 07          	shr    $0x7,%r10b
 1050cc8:	41 c0 ef 07          	shr    $0x7,%r15b
 1050ccc:	44 08 db             	or     %r11b,%bl
 1050ccf:	40 80 e7 87          	and    $0x87,%dil
 1050cd3:	41 c0 eb 07          	shr    $0x7,%r11b
 1050cd7:	45 08 c2             	or     %r8b,%r10b
 1050cda:	45 08 cf             	or     %r9b,%r15b
 1050cdd:	44 30 e7             	xor    %r12b,%dil
 1050ce0:	41 c0 e9 07          	shr    $0x7,%r9b
 1050ce4:	41 c0 f8 07          	sar    $0x7,%r8b
 1050ce8:	c4 c1 79 6e ca       	vmovd  %r10d,%xmm1
 1050ced:	45 00 d2             	add    %r10b,%r10b
 1050cf0:	41 80 e0 87          	and    $0x87,%r8b
 1050cf4:	c4 c3 71 20 cf 01    	vpinsrb $0x1,%r15d,%xmm1,%xmm1
 1050cfa:	45 00 ff             	add    %r15b,%r15b
 1050cfd:	45 08 d1             	or     %r10b,%r9b
