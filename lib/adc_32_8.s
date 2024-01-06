;   adc_32_8 - Add a 32 bit with an 8 bit integer
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

.global	adc_32_u8
.global	adc_32_s8


	;; adc_32_u8
	;; add an unsigned 8 bit to a 32 bit unsigned integer
	;; < A 8bit
	;; < X/Y pointer to 32bit, overwritten with result
	;; < C Carry
	;; > N C V flags
	;; uses tmpzp+0,+1,+2

adc_32_u8:
		php
		sei
		stx	tmpzp+0
		sty	tmpzp+1
		tay
		jmp	common


	;; adc_32_s8
	;; add an signed 8 bit to a 32 bit unsigned integer
	;; < A 8bit
	;; < X/Y pointer to 32bit, overwritten with result
	;; < C Carry
	;; > N C V flags
	;; uses tmpzp+0,+1

adc_32_s8:
		php
		sei
		stx	tmpzp+0
		sty	tmpzp+1

		;; fill X with sign of 8 bit
		ldx	#$ff
		tay
		bmi	+
common:		ldx	#$00
	+
		;; save original I flag to tmpzp+2
		pla
		sta	tmpzp+2

		;; adc four bytes
		tya
		ldy	#0
		adc	(tmpzp),y
		sta	(tmpzp),y
		txa
		iny
		adc	(tmpzp),y
		sta	(tmpzp),y
		txa
		iny
		adc	(tmpzp),y
		sta	(tmpzp),y
		txa
		iny
		adc	(tmpzp),y
		sta	(tmpzp),y

		;; restore I flag without changing others
		php
		lda	tmpzp+2
		and	#$04		; I flag
		bne	+		; I flag was set
		pla
		and	#~$04		; clear I flag
		pha
	+	plp
		rts

