;   ciartc - Date and time functions for the cia1 real time clock
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

; This module provides a date and time interface. The time is stored in
; the cia1 time of day register. The process sleeps for a while
; and then updates the date. This must be done at least once every 12 hours
; and after 12:00am the date is incremented. The same checks are performed
; on any time read operation, to ensure that the date is correct.
; The hour format is converted from 01-12am/pm to 00-23. Every access
; to this interface has to be in 00-23 format.
; Before writing any data call checktime or checkdate to verify the syntax.
; Using the weekday is independent and optional. It is simply incremented
; every day and reset on Monday. Monday is 1 and Sunday 7. 0 is not changed.
; The timezone is just stored and never changed. It can be used to convert
; this format to unix time.

#include <system.h>
#include <jumptab.h>
#include <stdio.h>
#include <kerrors.h>
#include <config.h>
#include MACHINE_H

start_of_code:
		.byte >LNG_MAGIC, <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.word 0

		jmp  initialize

;;; data -------------------------------------------------------------------

		RELO_JMP(+)

date:
weekday:	.byte	0	; range from 00 to 07, 00 means invalid
century:	.byte	0	; range form 00 to 99
year:		.byte	0	; range form 00 to 99
month:		.byte	1	; range form 01 to 12
day:		.byte	1	; range form 01 to 31
time:
hour:		.byte	0	; range from 00 to 23
minute:		.byte	0	; range from 00 to 59
second:		.byte	0	; range from 00 to 59
sec10:		.byte	0	; range from 00 to 09
end_of_time:
zonehour:	.byte	0	; range from 00 to 15, bit 7 sign, dst included
zonemin:	.byte	0	; range from 00 to 59, timezone can be 30 min
end_of_date:

ampmhour:	.byte	1	; range from 01 to 12, bit 7 am/pm
daymonth:	.byte	$00,$32,$29,$32,$31,$32,$31,$32,$32,$31,$32,$31,$32
			;   jan feb mar apr may jun jul aug sep oct nov dec

refdate:	.buf	11		; last clock set, needed by ntp
end_of_refdate:

ntp:					; all values are big endian
li_vn_mode:	.byte	%11011100	; not synchronized, version 3, server
stratum:	.byte	1		; primary reference
poll:		.byte	6		; NTP.MINPOLL
precision:	.byte	~3+1		; 1/10 seconds
delay:		.byte	0,0,0,0		; 0 seconds
dispersion:	.byte	0,0,$05,$35	; 20 ms + 86*4 us
identifier:	.byte	0,0,0,0
end_of_ntp:

bits:		.byte	$01,$02,$04,$08,$10,$20,$40,$80


module_struct:
		.asc "rtc"	; module identifier
		.byte 7		; module interface size
		.byte 1		; module interface version number
		.byte 1		; weight (number of available virtual devices)
		.word 0000	; (reserved, used by kernel)
	
	+	jmp rtc_lock
		jmp rtc_time_read
		jmp rtc_time_write
		jmp rtc_date_read
		jmp rtc_date_write
		jmp rtc_ntp_read
		jmp rtc_ntp_write
		jmp rtc_ntp_reference
		
		
;;; utilities --------------------------------------------------------------

	;; update_date
	;; read time from cia and increment date if neccessary
	;; irq must be disabled

update_date:
		;; copy cia_tod to time
		lda	CIA1_TODHR		; latch time
		sta	hour
		ldx	CIA1_TODMIN
		stx	minute
		ldx	CIA1_TODSEC
		stx	second
		ldx	CIA1_TOD10		; free latch
		stx	sec10
		;; convert from 01-12am/pm to 00-23
		and	#$7f
		cmp	#$12
		bne	+
		lda	#$00
	+	ldy	hour
		bpl	+
		sed
		clc
		adc	#$12
		cld
	+	sta	hour
		tya
		eor	ampmhour	; has am/pm flag changed
		sty	ampmhour
		bpl	return		; if no, return
		tya			; is am/pm flag set
		bmi	return		; if yes, return
		;; increment date
		ldy	weekday
		beq	++		; 0 is invalid, don't change
		iny			; increment weekday
		cpy	#8
		bcc	+
		ldy	#1
	+	sty	weekday
	+	sed
		lda	month
		jsr	bcdtohex
		tay			; move hexadecimal month to Y
		lda	day		
		clc
		adc	#$01		; increment day
		sta	day
		cmp	daymonth,y	; is day >= days+1 of this month
		bcc	endincdate	; if no, write hour=0 back to cia
		cpy	#2		; is february ?
		bne	monthover	; if no, leap year is irrelevant
		cmp	#$30		; is day >= 30
		bcs	monthover	; if yes, leap year is irrelevant
		;; month==2, date==29, so check for leap year
		lda	year		; is year equal 0 ?
		bne	year4leap	; if not, leap year equiv to year%4==0
		lda	century
		jsr	bcdtohex
		and	#$03		; is century%4 equal 0 ?
		bne	monthover	; if no, it's not a leap year
		beq	endincdate	; if yes, it's a leap year
return:		clc			; only for jump in
		rts
year4leap:	jsr	bcdtohex
		and	#$03		; is year%4 equal 0 ?
		beq	endincdate	; if yes, it's a leap year
monthover:	ldx	#$01		; we have an overflow in days
		stx	day		; so set day to 01
		;; increment month
		lda	month
		clc
		adc	#$01		; increment month
		sta	month
		cmp	#$13
		bcc	endincdate	; month < 13
		stx	month
		;; increment year and century
		lda	year
		adc	#$00		; carry always set
		sta	year
		lda	century 
		adc	#$00		; carry depends on year overflow
		sta	century
endincdate:	cld			; carry is only set on century overflow
		rts


	;; write_time
	;; write time to cia
	;; irq must be disabled

write_time:
		;; convert from 00-23 to 01-12am/pm
		lda	hour
		tax
		cmp	#$12
		bcc	+
		sed
		sec
		sbc	#$12
		cld
		tax
		ora	#$80
	+	tay
		cpx	#$00
		bne	+
		tya
		ora	#$12
		tay
		eor	#$80	; cia inverts am/pm on write when hour==12
	+	sty	ampmhour
		;; write time to cia_tod
		sta	CIA1_TODHR	; stop clock
		ldx	minute
		stx	CIA1_TODMIN
		ldx	second
		stx	CIA1_TODSEC
		ldx	sec10
		stx	CIA1_TOD10	; continue clock
		;; reset ntp
		lda	li_vn_mode
		ora	#%11000000	; not synchronized
		sta	li_vn_mode
		rts


;;; api --------------------------------------------------------------------

	;; rtc api: rtc_lock
	;; < A device number

rtc_lock:
		clc
		rts

	;; rtc api: rtc_time_read
	;; read time from CIA1
	;; < X/Y address of storage to be filled with time

rtc_time_read:
		php
		sei
		stx	tmpzp
		sty	tmpzp+1
		jsr	update_date
		ldy	#end_of_time-time-1
	-	lda	time,y
		sta	(tmpzp),y
		dey
		bpl	-
		plp
		rts


	;; rtc api: rtc_time_write
	;; write time to CIA1
	;; checkdate should be called before
	;; < X/Y address of storage filled with time

rtc_time_write:
		php
		sei
		stx	tmpzp
		sty	tmpzp+1
		ldy	#end_of_time-time-1
	-	lda	(tmpzp),y
		sta	time,y
		dey
		bpl	-
		jsr	write_time
		ldy	#end_of_date-date-1
	-	lda	date,y
		sta	refdate,y
		dey
		bpl	-
		plp
		rts


	;; rtc api: rtc_date_read
	;; read date and time from CIA1
	;; < X/Y address of storage to be filled with date

rtc_date_read:
		php
		sei
		stx	tmpzp
		sty	tmpzp+1
		jsr	update_date
		ldy	#end_of_date-date-1
	-	lda	date,y
		sta	(tmpzp),y
		dey
		bpl	-
		plp
		rts


	;; rtc api: rtc_date_write
	;; write date and time to CIA1
	;; checkdate should be called before
	;; < X/Y address of storage filled with date

rtc_date_write:
		php
		sei
		stx	tmpzp
		sty	tmpzp+1
		ldy	#end_of_date-date-1
	-	lda	(tmpzp),y
		sta	date,y
		sta	refdate,y
		dey
		bpl	-
		jsr	write_time
		plp
		rts


	;; rtc api: rtc_ntp_read
	;; get ntp header
	;; < X/Y address for header

rtc_ntp_read:
		php
		sei
		stx	tmpzp
		sty	tmpzp+1
		ldy	#end_of_ntp-ntp-1
	-	lda	ntp,y
		sta	(tmpzp),y
		dey
		bpl	-
		plp
		rts


	;; rtc api: rtc_ntp_write
	;; write ntp information
	;; should be called immedeatly after rtc_date_write
	;; < X/Y address of storage filled with ntp information

rtc_ntp_write:
		php
		sei
		stx	tmpzp		; copy all ntp
		sty	tmpzp+1
		ldy	#end_of_ntp-ntp-1
	-	lda	(tmpzp),y
		sta	ntp,y
		dey
		bpl	-

		;; stratum = peer.stratum + 1
		inc	stratum		; FIXME: must be <= NTP.MAXSTRATUM
		
		;; dispersion = peer.dispersion + 
		;;		(1<<peer.precision) + sys.dispersion
		lda	precision
		clc
		adc	#16
		bvs	+		; should never jump
		bmi	+		; too small
		lsr	a
		lsr	a
		lsr	a
		eor	#$ff		; 3-a = 3+(~a+1) = ~a+4
		clc
		adc	#4
		bmi	+		; should never jump
		tay
		lda	precision
		and	#$07
		tax
		lda	bits,x
		clc
	-	adc	dispersion,y
		sta	dispersion,y
		bcc	+
		lda	#0
		dey
		bpl	-		; should always jump
	+
		lda	#$35
		clc
		adc	dispersion+3
		sta	dispersion+3
		lda	#$05
		adc	dispersion+2
		sta	dispersion+2
		bcc	+
		inc	dispersion+1
		bne	+
		inc	dispersion+0	; should never overflow
	+

		lda	#~3+1		; precision = sys.precision
		sta	precision
		
		plp
		rts


	;; rtc api: rtc_ntp_reference
	;; get date when clock was last set
	;; < X/Y address of storage to be filled with date

rtc_ntp_reference:
		php
		sei
		stx	tmpzp
		sty	tmpzp+1
		ldy	#end_of_refdate-refdate-1
	-	lda	refdate,y
		sta	(tmpzp),y
		dey
		bpl	-
		plp
		rts


;;; main -------------------------------------------------------------------

main:

main_loop:
		ldx	#$ff
		ldy	#$ff
		jsr	lkf_sleep	; about 17 minutes
		nop
		sei
		jsr	update_date
		cli
		jmp	main_loop


end_of_permanent_code:	
;;; initialisation data ----------------------------------------------------

		RELO_JMP(+)

howto_txt:	.text "usage: cia1rtc",$0a,0

	+

;;; initialisation ---------------------------------------------------------

hiaddr_modstr:	bit	module_struct
		
initialize:
		;; parse commandline
		ldx	userzp
		cpx	#1
		beq	normal_mode
		
HowTo:		ldx	#stdout
		bit	howto_txt
		jsr	lkf_strout
		lda	#1
		rts
		
normal_mode:
		;; free memory used for commandline arguments
		ldx	userzp+1
		jsr	lkf_free
		nop
		lda	#0
		jsr	lkf_set_zpsize
		nop

		;; register module
		ldx	#<module_struct
		ldy	hiaddr_modstr+2		; #>module_struct 
		jsr	lkf_add_module
		nop
	
		jmp	main
				
end_of_code:
