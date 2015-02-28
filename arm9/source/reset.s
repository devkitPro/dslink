	.text
	.align 4

	.arm

	.arch	armv5te
	.cpu	arm946e-s

@---------------------------------------------------------------------------------
	.global arm9Reset
	.type	arm9Reset STT_FUNC
@---------------------------------------------------------------------------------
arm9Reset:
@---------------------------------------------------------------------------------

	ldr	r1, =0x00062078			@ disable protection unit
	mcr	p15, 0, r1, c1, c0
	@ Disable cache
	mov	r0, #0
	mcr	p15, 0, r0, c7, c5, 0		@ Instruction cache
	mcr	p15, 0, r0, c7, c6, 0		@ Data cache

	@ Wait for write buffer to empty 
	mcr	p15, 0, r0, c7, c10, 4

	mrs	r0, cpsr			@ cpu interrupt disable
	orr	r0, r0, #0x80			@ (set i flag)
	msr	cpsr, r0

	ldr	r0,=0x2FFFE24

	ldr	r0,[r0]
	bx	r0

	.pool
