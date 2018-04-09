/*
	Copyright 2006 - 2015 Dave Murphy (WinterMute)

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 2 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.

*/

#include <nds/arm9/cache_asm.h>

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
	@ address to start clearing from
	mov	r8, r0

	mrs	r0, cpsr			@ cpu interrupt disable
	orr	r0, r0, #0x80			@ (set i flag)
	msr	cpsr, r0

	adr	r1, itcm_reset_code
	mov	r2, #0
	adr	r3, itcm_reset_code_end

copy_itcm_reset:
	ldmia	r1!, {r0}
	stmia	r2!, {r0}
	cmp	r1, r3
	bne	copy_itcm_reset

	mov	r0, #0
	bx	r0

@---------------------------------------------------------------------------------
itcm_reset_code:
@---------------------------------------------------------------------------------
	@ Switch off MPU
	mrc	p15, 0, r0, c1, c0, 0
	bic	r0, r0, #PROTECT_ENABLE
	mcr	p15, 0, r0, c1, c0, 0


	adr	r12, mpu_initial_data
	ldmia	r12, {r0-r10}

	mcr	p15, 0, r0, c2, c0, 0
	mcr	p15, 0, r0, c2, c0, 1
	mcr	p15, 0, r1, c3, c0, 0
	mcr	p15, 0, r2, c5, c0, 2
	mcr	p15, 0, r3, c5, c0, 3
	mcr	p15, 0, r4, c6, c0, 0
	mcr	p15, 0, r5, c6, c1, 0
	mcr	p15, 0, r6, c6, c3, 0
	mcr	p15, 0, r7, c6, c4, 0
	mcr	p15, 0, r8, c6, c6, 0
	mcr	p15, 0, r9, c6, c7, 0
	mcr	p15, 0, r10, c9, c1, 0

	mov	r0, #0
	mcr	p15, 0, r0, c6, c2, 0   @ PU Protection Unit Data/Unified Region 2
	mcr	p15, 0, r0, c6, c5, 0   @ PU Protection Unit Data/Unified Region 5

	mrc	p15, 0, r0, c9, c1, 0   @ DTCM
	mov	r0, r0, lsr #12         @ base
	mov	r0, r0, lsl #12         @ size
	add	r0, r0, #0x4000         @ dtcm top

	sub	r0, r0, #4              @ irq vector
	mov	r1, #0
	str 	r1, [r0]
	sub	r0, r0, #4              @ IRQ1 Check Bits
	str 	r1, [r0]

	bic	r0, r0, #0x7f

	msr	cpsr_c, #0xd3      @ svc mode
	mov	sp, r0
	sub	r0, r0, #64
	msr	cpsr_c, #0xd2      @ irq mode
	mov	sp, r0
	sub	r0, r0, #4096
	msr	cpsr_c, #0xdf      @ system mode
	mov	sp, r0


	ldr	r10, =0x2FFFE24

	mov	r0, #0
	mov	r1, #0
	mov	r2, #0
	mov	r3, #0
	mov	r4, #0
	mov	r5, #0
	mov	r6, #0
	mov	r7, #0

	cmp	r8, #0x2000000
	blt	noclear
	cmp	r8, #0x3000000
	bge	noclear

doclear:
	ldr	r9, [r10, #8]	@ arm9 size
	add	r8, r8, r9
	add	r9, r8, #31
	bic	r9, r9, #31

clear1:
	cmp	r8, r9
	beq	endclear1

	str	r0, [r8, #4]!
	b	clear1

endclear1:
	
	ldr	r9,=0x4004008
	ldr	r9,[r9]
	ands	r9,r9,#0x8000
	bne	dsi_mode

	mov	r9, #0x02400000
	b	ds_mode
dsi_mode:
	mov	r9, #0x03000000
ds_mode:
	sub	r9, #0x0000c000
clear2:
	stmia	r8!, {r0, r1, r2, r3, r4, r5, r6, r7}
	cmp	r8, r9
	blt	clear2

noclear:
	mov	r12, #0x04000000
	add	r12, r12, #0x180

	mov	r0, #0x600
	strh	r0, [r12]
	mov	r0, #6
	bl	waitsync

	mov	r0, #0
	strh	r0, [r12]
	bl	waitsync

	ldr	r10, =0x2FFFE24
	ldr	r2, [r10]

	@ Switch MPU to startup default
	ldr	r0, =0x00012078
	mcr	p15, 0, r0, c1, c0, 0

	bx	r2

	.pool

@---------------------------------------------------------------------------------
waitsync:
@---------------------------------------------------------------------------------
	ldrh	r1, [r12]
	and	r1, r1, #0x000f
	cmp	r0, r1
	bne	waitsync
	bx	lr

mpu_initial_data:
	.word 0x00000042  @ p15,0,c2,c0,0..1,r0 ;PU Cachability Bits for Data/Unified+Instruction Protection Region
	.word 0x00000002  @ p15,0,c3,c0,0,r1    ;PU Write-Bufferability Bits for Data Protection Regions
	.word 0x15111011  @ p15,0,c5,c0,2,r2    ;PU Extended Access Permission Data/Unified Protection Region
	.word 0x05100011  @ p15,0,c5,c0,3,r3    ;PU Extended Access Permission Instruction Protection Region
	.word 0x04000033  @ p15,0,c6,c0,0,r4    ;PU Protection Unit Data/Unified Region 0
	.word 0x0200002b  @ p15,0,c6,c1,0,r5    ;PU Protection Unit Data/Unified Region 1 4MB
	.word 0x08000035  @ p15,0,c6,c3,0,r6    ;PU Protection Unit Data/Unified Region 3
	.word 0x0300001b  @ p15,0,c6,c4,0,r7    ;PU Protection Unit Data/Unified Region 4
	.word 0xffff001d  @ p15,0,c6,c6,0,r8    ;PU Protection Unit Data/Unified Region 6
	.word 0x027ff017  @ p15,0,c6,c7,0,r9    ;PU Protection Unit Data/Unified Region 7 4KB
	.word 0x0300000a  @ p15,0,c9,c1,0,r10   ;TCM Data TCM Base and Virtual Size
itcm_reset_code_end: