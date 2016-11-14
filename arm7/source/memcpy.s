/*
	Copyright 2009 - 2015 Dave Murphy (WinterMute)

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

@ === procedure memcpy32(dest: pointer; const src: pointer; wcount: u32); ======
@     Fast-copy by words.
@	  param dest Destination address.
@	  param src Source address.
@	  param wcount Number of words.
@	  note: src and dst must be word aligned.
@	  note: r0 and r1 return as dst + wdn and src + wdn.

@ Reglist:
@   r0, r1: dst, src
@   r2: wcount, then wcount>>3
@   r3-r10: data buffer
@   r12: wcount&7

	.align	2
	.code	32
	.global	memcpy32
memcpy32:
	cmp	r1, r0
	bge	copy_forward

	add	r3, r1, r2, lsl #2
	cmp	r0, r3
	blt	copy_backward

copy_forward:
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

copy_backward:
	add	r0, r0, r2, lsl #2
	add	r1, r1, r2, lsl #2

	and	r12, r2, #7
	movs	r2, r2, lsr #3
	beq	.Lres_bcpy32
	stmfd	sp!, {r4-r10}
	@ copy 32byte chunks with 8fold xxmia
.Lmain_bcpy32:
	ldmdb	r1!, {r3-r10}
	stmdb	r0!, {r3-r10}
	subs	r2, r2, #1
	bhi	.Lmain_bcpy32
	ldmfd	sp!, {r4-r10}
	@ and the residual 0-7 words
.Lres_bcpy32:
	subs	r12, r12, #1
	ldmcsdb	r1!, {r3}
	stmcsdb	r0!, {r3}
	bcs	.Lres_bcpy32
	bx	lr
