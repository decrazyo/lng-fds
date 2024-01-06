;   checkdate - Check if Date and Time arguments are syntactical correct 
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

#include <jumptab.h>
#include <kerrors.h>


.global checktime
.global checkdate


	;; checktime
	;; < X/Y address of storage filled with time
	;; > c=1 error

checktime:
		sei
		stx	syszp
		ldx	lk_ipid
		lda	lk_tstatus,x
		ora	#tstatus_szu
		sta	lk_tstatus,x
		cli
		sty	syszp+1

		;; check syntax of argument
		ldy	#3		; end_of_time-time-1
		jsr	timeboth
		bcs	jmperr0

		sei
		ldx	lk_ipid
		lda	lk_tstatus,x
		and	#~(tstatus_szu)
		sta	lk_tstatus,x
		cli
		clc
		rts

illarg0:	lda	#lerr_illarg
jmperr0:	jmp	lkf_catcherr


timeboth:	;; check the time parameters, is used by both functions
		lda	(syszp),y	; sec10
		jsr	checkbcd
		bcs	jmperr0
		cmp	#$10
		bcs	illarg0
		dey
		lda	(syszp),y	; second
		jsr	checkbcd
		bcs	jmperr0
		cmp	#$60
		bcs	illarg0
		dey
		lda	(syszp),y	; minute
		jsr	checkbcd
		bcs	jmperr0
		cmp	#$60
		bcs	illarg0
		dey
		lda	(syszp),y	; hour
		jsr	checkbcd
		bcs	jmperr0
		cmp	#$24
		bcs	illarg0
		dey
		rts			; C=0



	;; checkdate
	;; < X/Y address of storage filled with date
	;; > c=1 error

checkdate:
		sei
		stx	syszp
		ldx	lk_ipid
		lda	lk_tstatus,x
		ora	#tstatus_szu
		sta	lk_tstatus,x
		cli
		sty	syszp+1

		;; check syntax of argument
		ldy	#10		; end_of_date-date-1
		lda	(syszp),y	; zonemin
		jsr	checkbcd
		bcs	jmperr1
		cmp	#$60
		bcs	illarg1
		dey
		lda	(syszp),y	; zonehour
		and	#$7f
		jsr	checkbcd
		bcs	jmperr1
		cmp	#$16		; value contains DST and even more
		bcs	illarg1
		dey

		jsr	timeboth
		bcs	jmperr1

		lda	(syszp),y	; day
		beq	illarg1
		jsr	checkbcd
		bcs	jmperr1
		sta	syszp+2		; daymax depends on month and leap year
		dey
		lda	(syszp),y	; month
		beq	illarg1
		jsr	checkbcd
		bcs	jmperr1
		cmp	#$13
		bcs	illarg1
		jsr	bcdtohex
		sta	syszp+3		; remember month in hex for max of day
		dey
		lda	(syszp),y	; year
		jsr	checkbcd
		bcs	jmperr1
		sta	syszp+4
		dey
		lda	(syszp),y	; century
		jsr	checkbcd
		bcs	jmperr1
		sta	syszp+5
		dey
		lda	(syszp),y	; weekday
		cmp	#$08
		bcs	jmperr1
		;; check maximum of day
		lda	syszp+2		; day to A
		ldy	syszp+3		; month in hex to y
		cmp	daymonth,y	; is day >= days+1 of this month
		bcc	enddate		; if no, write date
		cpy	#2		; is february ?
		bne	illarg1		; if no, leap year is irrelevant
		cmp	#$30		; is day >= 30
		bcs	illarg1		; if yes, leap year is irrelevant
		;; month==2, date==29, so check for leap year
		lda	syszp+4		; is year equal 0 ?
		bne	year4leap	; if not, leap year equiv to year%4==0
		lda	syszp+5		; century to A
		jsr	bcdtohex
		and	#$03		; is century%4 equal 0 ?
		beq	enddate		; if yes, it's a leap year
illarg1:	lda	#lerr_illarg
jmperr1:	jmp	lkf_catcherr
year4leap:	jsr	bcdtohex
		and	#$03		; is year%4 equal 0 ?
		bne	illarg1		; if no, it's not a leap year
enddate:	
		sei
		ldx	lk_ipid
		lda	lk_tstatus,x
		and	#~(tstatus_szu)
		sta	lk_tstatus,x
		cli
		clc
		rts


;;; data -------------------------------------------------------------------

		RELO_JMP(+)

;; format of date and time
;date:
;weekday:	.byte	0	; range from 00 to 07, 00 means invalid
;century:	.byte	0	; range form 00 to 99
;year:		.byte	0	; range form 00 to 99
;month:		.byte	1	; range form 01 to 12
;day:		.byte	1	; range form 01 to 31
;time:
;hour:		.byte	0	; range from 00 to 23
;minute:	.byte	0	; range from 00 to 59
;second:	.byte	0	; range from 00 to 59
;sec10:		.byte	0	; range from 00 to 09
;end_of_time:
;zonehour:	.byte	0	; range from 00 to 15, bit 7 sign, dst included
;zonemin:	.byte	0	; range from 00 to 59, timezone can be 30 min
;end_of_date:

daymonth:	.byte	$00,$32,$29,$32,$31,$32,$31,$32,$32,$31,$32,$31,$32
			;   jan feb mar apr may jun jul aug sep oct nov dec
	+

