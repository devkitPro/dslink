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
