;   mult_32_8 - Multiply a 32 bit with an 8 bit unsigned integer
;   Copyright (C) 2000 Alexander Bluhm
;
;   This program is free software; you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation; either version 2 of the License, or
;   (at your option) any later version.
;
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License
;   along with this program; if not, write to the Free Software
;   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
;

; Alexander Bluhm <mam96ehy@studserv.uni-leipzig.de>

#include <system.h>

.global	mult_u32_u8

	;; mult_u32_u8
	;; multipy a 32 with an 8 bit unsigned integer
	;; < A 8bit
	;; < X/Y pointer to 32bit, overwritten with result
	;; > A highest byte of result (bit 32-39)
	;; uses tmpzp and syszp

mult_u32_u8:
		;; save registers
		php
		sei
		sta	tmpzp+5		; 8bit
		stx	tmpzp+6		; 32bit
		sty	tmpzp+7

		;; tmpzp = 32bit and syszp = 0
		lda	#0
		sta	tmpzp+4
		sta	syszp+4
		sta	syszp+3
		sta	syszp+2
		sta	syszp+1
		sta	syszp+0
		ldy	#3
	-	lda	(tmpzp+6),y
		sta	tmpzp,y
		dey
		bpl	-
		
		;; check bits of 8bit
		ldy	#7
	-	lda	tmpzp+5
		beq	++		; speed hack
		lsr	a
		sta	tmpzp+5
		bcc	+

		;; syszp += tmpzp
		clc
		lda	tmpzp+0
		adc	syszp+0
		sta	syszp+0
		lda	tmpzp+1
		adc	syszp+1
		sta	syszp+1
		lda	tmpzp+2
		adc	syszp+2
		sta	syszp+2
		lda	tmpzp+3
		adc	syszp+3
		sta	syszp+3
		lda	tmpzp+4
		adc	syszp+4
		sta	syszp+4

		;; tmpzp <<= 1
	+	asl	tmpzp+0
		rol	tmpzp+1
		rol	tmpzp+2
		rol	tmpzp+3
		rol	tmpzp+4

		dey
		bpl	-
	+
		;; result = syszp
		ldy	#3
	-	lda	syszp,y
		sta	(tmpzp+6),y
		dey
		bpl	-

		lda	syszp+4
		plp
		rts

