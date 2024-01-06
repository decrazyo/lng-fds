;   smwrtc - Date and time functions for the Smart Watch (Dallas DS1216 B series)
;	     real time clock
;   Copyright (C) 2000 Maciej Witkowiak <ytm@elysium.pl>
;
; parts of code are from ciartc by
; Alexander Bluhm <mam96ehy@studserv.uni-leipzig.de>
; Smart Watch handler code is based on documents by Tim G. Corcoran

; This module provides a date and time interface. The time is stored and
; read from a Smart Watch chip hooked to cia1 joystick port 2.
; I don't have such device, more information about it can be obtained from
; ftp://ftp.elysium.pl/tools/systems/geos-software/updates/
;
; This driver was never tested, and I am not aware of any Y2K problems
; concerning Smart Watch device (which are possible, because the documentation
; I use was dated on 1990)
; Date and time are always read from Smart Watch, so cia (and C64/128) is not
; required to work - we need only 8-bit I/O port.
;
; Using the weekday is independent and optional. It is simply incremented
; every day and reset on Monday. Monday is 1 and Sunday 7. 0 is not changed.
; The timezone is just stored and never changed. It can be used to convert
; this format to unix time.

; IMPORTANT NOTES:
; - I don't know if SmartWatch has Y2K problem
; - my documents are ambigous, I don't know if first returned/stored value is
;   seconds/10 or seconds/100
; - I don't know if SmartWatch handles am/pm exactly like cia
; - I don't know how SmartWatch handles weekday=0

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

	;; read_byte
	;; read a byte from Smart Watch

read_byte:
		lda	#%00001110		; config lsb as input
		sta	CIA1_DDRA
		lda	#0
		sta	tmpzp+2
		ldx	#8
	-	lda	#%00001110		; setup for read all output bits hi
		sta	CIA1_PRA
		lda	#%00000010		; enable data to read
		sta	CIA1_PRA
		lda	CIA1_PRA		; read data
		ror	a			; rotate data bit to C flag
		lda	tmpzp+2
		ror	a			; roll C flag into bit 7
		sta	tmpzp+2
		dex
		bne	-
		rts

	;; write_byte
	;; write a byte to Smart Watch

write_byte:
		tax				; save data byte
		ldy	#8			; set up count
		lda	#%00001100		; initial config output enable off
		sta	CIA1_PRA
		txa
	-	and	#1			; clear all but lsb
		sta	CIA1_PRA
		ora	#%00001100		; write data bit
		sta	CIA1_PRA
		dey
		beq	+			; finished?
		txa				; get data
		lsr	a			; select next bit
		tax				; save new data
		clv
		bvc	-			; loop

	+	rts

	;; select_smartwatch
	;; write magic bytes to port to enable Smart Watch

select_smartwatch:
		lda	#%00001110		; read cycle to start dallas chip
		sta	CIA1_PRA
		lda	#%00000010
		sta	CIA1_PRA
		lda	#%00001110
		sta	CIA1_PRA
		lda	#2
		sta	tmpzp+2
	-	lda	#$c5
		jsr	write_byte
		lda	#$3a
		jsr	write_byte
		lda	#$a3
		jsr	write_byte
		lda	#$5c
		jsr	write_byte
		dec	tmpzp+2
		bne	-
		rts

	;; update_date
	;; read time from Smart Watch
	;; at this point irq must be disabled

update_date:
		lda	CIA1_DDRA		; store cia1 registers
		pha
		lda	CIA1_PRA
		pha

		lda	#%00001111		; load new config - 4 outputs
		sta	CIA1_DDRA
		sta	CIA1_PRA		; states: ce true, sclk low
		jsr	select_smartwatch	; select clock chip
		jsr	read_byte			; read secs/100 ?
		sta	sec10
		jsr	read_byte			; read secs
		sta	second
		jsr	read_byte			; read mins
		sta	minute
		jsr	read_byte			; read hours
		tax
		and	#%00011111
		cmp	#$12			; is it twelve (BCD)
		bne	+
		txa
		eor	#%00100000		; toggle am/pm bit (SW bit 5)
		tax
	+	txa
		and	#%00011111
		sta	hour
		txa				; get plain hours
		and	#%00100000		; isolate am/pm bit
		bne	+			; set - it's am, do nothing
		sed
		lda	hour
		clc
		adc	#$12
		sta	hour
		cld
	+	jsr	read_byte			; read weekday
		sta	weekday
		jsr	read_byte			; read day
		sta	day
		jsr	read_byte			; read month
		sta	month
		jsr	read_byte			; read year
		sta	year
		
		pla				; restore cia1 registers
		sta	CIA1_PRA
		pla
		sta	CIA1_DDRA
		rts

	;; write_time
	;; write time to Smart Watch
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
		ora	#$20
	+	tay
		cpx	#$00
		bne	+
		tya
		ora	#$12
		tay
		eor	#$20	; cia inverts am/pm on write when hour==12, SW works similar?
	+	sta	tmpzp+7

		;; reset ntp
		lda	li_vn_mode
		ora	#%11000000	; not synchronized
		sta	li_vn_mode

		lda	CIA1_DDRA		; store cia1 registers
		pha
		lda	CIA1_PRA
		pha

		lda	#%00001111		; new configuration all outputs
		sta	CIA1_DDRA
		lda	#%00001110
		sta	CIA1_PRA
		jsr	select_smartwatch
		lda	sec10
		jsr	write_byte
		lda	second
		jsr	write_byte
		lda	minute
		jsr	write_byte
		lda	tmpzp+7			; converted hour
		jsr	write_byte
		lda	weekday
		jsr	write_byte
		lda	day
		jsr	write_byte
		lda	month
		jsr	write_byte
		lda	year
		jsr	write_byte
		
		pla				; restore cia1 registers
		sta	CIA1_PRA
		pla
		sta	CIA1_DDRA
		rts

;;; api --------------------------------------------------------------------

	;; rtc api: rtc_lock
	;; < A device number

rtc_lock:
		clc
		rts

	;; rtc api: rtc_time_read
	;; read time from SmartWatch
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
	;; write time to SmartWatch
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
	;; read date and time from SmartWatch
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
	;; write date and time to SmartWatch
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

		; update date&time every 17 minutes, really not necessary...

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

howto_txt:	.text "usage: smwrtc",$0a,0

	+

;;; initialisation ---------------------------------------------------------

hiaddr_modstr:	bit	module_struct

initialize:
		;; parse commandline
		ldx	userzp
		cpx	#1
		beq	normal_mode

		ldx	#stdout
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

		jmp	main_loop
end_of_code:
