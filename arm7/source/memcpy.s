

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
