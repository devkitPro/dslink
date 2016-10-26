/*
	Copyright 2015 Dave Murphy (WinterMute)

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

	ldr	r0, =0x380FFFC         @ irq vector
	mov	r1, #0
	str 	r1, [r0]
	sub	r0, r0, #4             @ IRQ1 Check Bits
	str 	r1, [r0]
	sub	r0, r0, #4             @ IRQ2 Check Bits
	str 	r1, [r0]

	sub	r0, r0, #128
	bic	r0, r0, #7

	msr	cpsr_c, #0xd3      @ svc mode
	mov	sp, r0
	sub	r0, r0, #128
	msr	cpsr_c, #0xd2      @ irq mode
	mov	sp, r0
	sub	r0, r0, #128
	msr	cpsr_c, #0xdf      @ system mode
	mov	sp, r0

	ldr	r0,=0x2FFFE34

	ldr	r0,[r0]
	bx	r0

	.pool
