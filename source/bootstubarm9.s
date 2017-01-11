	.global	_start

_start:
	b	setup

	.word	endarm7
	.word	endarm9
	.word	0x02e40000

setup:
	mov	r0, #0
	mov	r12, #0x04000000
	str	r0, [r12, #0x208]

	ldr	r0, =0x00002078			@ disable TCM and protection unit
	mcr	p15, 0, r0, c1, c0

	@ Disable caches
	mov	r0, #0
	mcr	p15, 0, r0, c7, c5, 0		@ Instruction cache
	mcr	p15, 0, r0, c7, c6, 0		@ Data cache

	@ Wait for write buffer to empty
	mcr	p15, 0, r0, c7, c10, 4

	mov	r0, #0x8a000000
	mov	r12, #0x04000000
	str	r0,[r12,#0x240]

	add	r3, r12, #0x180			@ r3 = 4000180

	mov	r2, #1
	bl	waitsync

	mov	r0, #0x100
	strh	r0, [r3]

	mov	r2, #0
	bl	waitsync

	strh	r2, [r3]

	ldr	r12, =0x02FFFE04
	mov	r1, #0
	str	r1, [r12,#0xf8]
	ldr	r1, =0xE59FF018
	str	r1, [r12]
	str	r12, [r12,#0x20]
	bx	r12

	.pool

waitsync:
	ldrh	r0, [r3]
	and	r0, r0, #0x000f
	cmp	r0, r2
	bne	waitsync
	bx	lr

	.data

	.align 2
arm7bin:
	.incbin	"data/dslink.arm7.exo"
endarm7:
	.align 2
arm9bin:
	.incbin	"data/dslink.arm9.exo"
endarm9:
