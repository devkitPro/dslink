	.global	_start
	.arm

_start:
	mov	r12, #0x04000000
	str	r12, [r12, #0x208]

	add	r3, r12, #0x180		@ r3 = 4000180

	mov	r0, #0x100
	strh	r0, [r3]

	mov	r2, #1
	bl	waitsync

	mov	r2, #0
	strh	r2, [r3]

	bl	waitsync

	mov	r4, #0x02000000
	ldr	r0, [r4,#4]
	mov	r1, #0x06000000
	ldr	r2, [r4,#8]
	ldr	r2, [r2]
	add	r1, r1, r2
	bl	exo_decrunch

	ldr	r0, [r4,#12]
	ldr	r1, [r4,#20]
	ldr	r2, [r4,#16]
	ldr	r2, [r2]
	add	r1, r1, r2
	bl	exo_decrunch

	ldr	r1, =0x02FFFE24
	str	r0, [r1]
	mov	r1, #0x06000000
	bx	r1

waitsync:
	ldrh	r0, [r3]
	and	r0, r0, #0x000f
	cmp	r0, r2
	bne	waitsync
	bx	lr
