;   dateconvert - Convert from date format to seconds from Epoch
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
#include <jumptab.h>

.global datetounix
.global datetontp

		.byte	$0c
		.word	+
daymonth:	.byte	 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30
		;	jan feb mar apr may jun jul aug sep oct nov dec
tenfrac:	.byte	$00, $99, $33, $cc, $66
	+

error_:		jmp	error

	;; datetounix
	;; convert from date to unix format
	;; seconds since 1 Jan 1970, 32 bit signed integer
	;; minimum date 'Thu,  1 Jan 1970 00:00:00 GMT'
	;; maximum date 'Tue, 19 Jan 2038 03:14:07 GMT'
	;; < userzp+0 pointer to date, 11 bytes
	;; < userzp+2 pointer to result, 4 bytes
	;; > C=1 overflow error
	
datetounix:
		;; number of days per year to result
		ldy	#0
		lda	#<365
		sta	(userzp+2),y
		iny
		lda	#>365
		sta	(userzp+2),y
		iny
		lda	#0
		sta	(userzp+2),y
		iny
		sta	(userzp+2),y

		;; calculate years from 1970
		sed
		sec
		ldy	#2
		lda	(userzp+0),y	; year
		sbc	#$70
		tax
		dey
		lda	(userzp+0),y	; century
		sbc	#$19
		cld
		tay			; strange
		bne	error_		; less than 1970 or greater than 2069
		txa
		jsr	bcdtohex
		pha
		ldx	userzp+2
		ldy	userzp+3
		jsr	mult_u32_u8	; no overflow possible
		
		;; leap years since 1970
		ldy	#3
		lda	(userzp+0),y	; month
		cmp	#3		; C=1 if month >= march
		pla
		adc	#1		; add 2 if month >= march
		lsr	a
		lsr	a
		ldx	userzp+2
		ldy	userzp+3
		clc
		jsr	adc_32_u8	; no overflow possible
		
		;; add days of months
		ldy	#3
		lda	(userzp+0),y	; month
		jsr	bcdtohex
		tay
		dey
		bpl	+		; always jump
	-	tya
		pha
		lda	daymonth,y
		ldx	userzp+2
		ldy	userzp+3
		clc
		jsr	adc_32_u8	; no overflow possible
		pla
		tay
	+	dey
		bpl	-
		
		;; add days
		ldy	#4
		lda	(userzp+0),y	; day
		jsr	bcdtohex
		sec
		sbc	#1
		ldx	userzp+2
		ldy	userzp+3
		clc
		jsr	adc_32_u8	; no overflow possible

		;; add hour
		lda	#24
		ldx	userzp+2
		ldy	userzp+3
		jsr	mult_u32_u8	; no overflow possible
		ldy	#5
		lda	(userzp+0),y	; hour
		jsr	bcdtohex
		ldx	userzp+2
		ldy	userzp+3
		clc
		jsr	adc_32_u8	; no overflow possible

		;; timezone hour
		ldy	#9
		lda	(userzp+0),y	; zonehour
		tax
		and	#$7f
		jsr	bcdtohex
		cpx	#0
		bmi	+
		eor	#$ff		; negative
		clc
		adc	#1
	+	ldx	userzp+2
		ldy	userzp+3
		clc
		jsr	adc_32_s8
		bmi	error

		;; add minute
		lda	#60
		ldx	userzp+2
		ldy	userzp+3
		jsr	mult_u32_u8	; no overflow possible
		ldy	#6
		lda	(userzp+0),y	; minute
		jsr	bcdtohex
		ldx	userzp+2
		ldy	userzp+3
		clc
		jsr	adc_32_u8	; no overflow possible

		;; timezone minute
		ldy	#9
		lda	(userzp+0),y	; zonehour
		tax
		iny
		lda	(userzp+0),y	; zonemin
		jsr	bcdtohex
		cpx	#0
		bmi	+
		eor	#$ff		; negative
		clc
		adc	#1
	+	ldx	userzp+2
		ldy	userzp+3
		clc
		jsr	adc_32_s8
		bmi	error

		;; add second
		lda	#60
		ldx	userzp+2
		ldy	userzp+3
		jsr	mult_u32_u8
		tay
		bne	error
		ldy	#7
		lda	(userzp+0),y	; second
		jsr	bcdtohex
		ldx	userzp+2
		ldy	userzp+3
		clc
		jsr	adc_32_u8
		bcs	error
		bmi	error

		rts

error:		lda	#$77		; FIXME: what to take here ?
		jmp	lkf_catcherr
		

	;; datetontp
	;; convert from date to ntp format
	;; seconds since 1 Jan 1900, 32 bit integer + 32 bit fraction
	;; FIXME: works only within unix time
	;; minimum date 'Thu,  1 Jan 1970 00:00:00 GMT'
	;; maximum date 'Tue, 19 Jan 2038 03:14:07 GMT'
	;; < userzp+0 pointer to date, 11 bytes
	;; < userzp+2 pointer to result, 8 bytes
	;; > C=1 overflow error
	
datetontp:
		;; convert to unix format
		jsr	datetounix
		bcs	error

		;; little endian to big endian
		ldy	#3
		lda	(userzp+2),y
		pha
		dey
		lda	(userzp+2),y
		pha
		dey
		lda	(userzp+2),y
		pha
		dey
		lda	(userzp+2),y

		;; add (365*70+17)*24*60*60 = 2208988800 = 0x83aa7e80 seconds
		ldy	#3
		adc	#$80			; C=0
		sta	(userzp+2),y
		dey
		pla
		adc	#$7e
		sta	(userzp+2),y
		dey
		pla
		adc	#$aa
		sta	(userzp+2),y
		dey
		pla
		adc	#$83
		sta	(userzp+2),y
		
		;; fraction
		ldy	#8
		lda	(userzp+0),y	; sec10ond
		jsr	bcdtohex
		ldx	#$00
		cmp	#5
		bcc	+
		ldx	#$80
		sbc	#5
	+	tay
		lda	tenfrac,y
		ldy	#7
		sta	(userzp+2),y
		dey
		sta	(userzp+2),y
		dey
		sta	(userzp+2),y
		dey
		asl	a		; copy bit 7 from X to A
		pha
		txa
		asl	a
		pla
		ror	a
		sta	(userzp+2),y

		clc
		rts

