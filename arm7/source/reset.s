	.text
	.align 4

	.arm
@---------------------------------------------------------------------------------
	.global arm7Reset
	.type	arm7Reset STT_FUNC
@---------------------------------------------------------------------------------
arm7Reset:
@---------------------------------------------------------------------------------
	mrs	r0, cpsr			@ cpu interrupt disable
	orr	r0, r0, #0x80			@ (set i flag)
	msr	cpsr, r0

	ldr	r0,=0x2FFFE34

	ldr	r0,[r0]
	bx	r0

	.pool