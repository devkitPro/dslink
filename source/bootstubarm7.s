	.global	_start
	.arm
	.section ".crt0","ax"

_start:
	ldr	r1, =__arm7_lma__
	ldr	r2, =__arm7_start__
	ldr	r4, =__arm7_end__
	sub	r3, r4, r2

	mov	r0, #3
	add	r3, r3, r0
	bics	r3, r3, r0
CIDLoop:
	ldmia	r1!, {r0}
	stmia	r2!, {r0}
	subs	r3, r3, #4
	bne	CIDLoop
	b	decrunch_bins

	.text
decrunch_bins:
	ldr	sp, =0x380FE7C

	mov	r12, #0x04000000
	mov	r0, #0

	str	r0, [r12, #0x208]

	mov	r0, #0x100
	add	r3, r12, #0x180
	strh	r0, [r3]

	mov	r2, #1
	bl	waitsync

	mov	r2, #0
	strh	r2, [r3]

	bl	waitsync

	mov	r4, #0x02000000
	ldr	r0, [r4,#4]
	mov	r1, #0x02f00000

	ldr	r2, =0x06020000
	bl	decrunch

	ldr	r0, [r4,#8]
	mov	r1, #0x02f00000
	ldr	r2, [r4,#12]
	bl	decrunch

	ldr	r0, [r4,#12]
	ldr	r1, =0x02FFFE24
	str	r0, [r1]
	ldr	r1, =0x06020000
	bx	r1

	.pool

waitsync:
	ldrh	r0, [r3]
	and	r0, r0, #0x000f
	cmp	r0, r2
	bne	waitsync
	bx	lr


decrunch:
	push	{r2,lr}
	bl	exo_decrunch

	mov	r1, r0
	mov	r2, r0
	mov	r2, #0x02f00000
	sub	r2, r2, r0
	asr	r2, #2

	pop	{r0,lr}


@ Reglist:
@   r0, r1: dst, src
@   r2: wcount, then wcount>>3
@   r3-r10: data buffer
@   r12: wcount&7

memcpy32:
	and	r12, r2, #7
	movs	r2, r2, lsr #3
	beq	.Lres_cpy32
	stmfd	sp!, {r4-r10}
	@ copy 32byte chunks with 8fold xxmia
.Lmain_cpy32:
	ldmia	r1!, {r3-r10}
	stmia	r0!, {r3-r10}
	subs	r2, r2, #1
	bhi		.Lmain_cpy32
	ldmfd	sp!, {r4-r10}
	@ and the residual 0-7 words
.Lres_cpy32:
	subs	r12, r12, #1
	ldmcsia	r1!, {r3}
	stmcsia	r0!, {r3}
	bcs	.Lres_cpy32
	bx	lr

