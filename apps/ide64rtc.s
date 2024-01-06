; ide64rtc - Date and time functions for the IDE64 real time clock
; Maciej Witkowiak <ytm@elysium.pl>
; 25.11.2001, 07.12.2001
;
; parts of code are from ciartc by
; Alexander Bluhm <mam96ehy@studserv.uni-leipzig.de>
; handler code based on information provided by <josef.soucek@ct.cz>

; The timezone is just stored and never changed. It can be used to convert
; this format to unix time.

; NOTES
; - there is no ide64.h, hence adresses are defined here (later)
; - there is no check if ide64 is present and has RTC (later)
; - sec10 is unsupported
; - setting time is unsupported

#include <system.h>
#include <jumptab.h>
#include <stdio.h>
#include <kerrors.h>
#include <config.h>
#include MACHINE_H

#define IDE64_CLOCKPORT		$de5f
#define IDE64_CLOCKRESET	$defb 

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
;------------------------------------------
; In BCD format
;
;    0   1   2    3    4   5        6
;  SEC MIN HOUR DAY MONTH WEEKDAY YEAR (00-99)
;------------------------------------------

write_byte:	sta IDE64_CLOCKPORT ; bit 0
		lsr a
		sta IDE64_CLOCKPORT ; bit 1
		lsr a
		sta IDE64_CLOCKPORT ; bit 2
		lsr a
		sta IDE64_CLOCKPORT ; bit 3
		lsr a
		sta IDE64_CLOCKPORT ; bit 4
		lsr a
		sta IDE64_CLOCKPORT ; bit 5
		lsr a
		sta IDE64_CLOCKPORT ; bit 6
		lsr a
		sta IDE64_CLOCKPORT ; bit 7
		rts

read_byte:	lda #0
		sta tmpzp+2
		lda IDE64_CLOCKPORT  ; bit 0
		lsr a
		ror tmpzp+2
		lda IDE64_CLOCKPORT  ; bit 1
		lsr a
		ror tmpzp+2
		lda IDE64_CLOCKPORT  ; bit 2
		lsr a
		ror tmpzp+2
		lda IDE64_CLOCKPORT  ; bit 3
		lsr a
		ror tmpzp+2
		lda IDE64_CLOCKPORT  ; bit 4
		lsr a
		ror tmpzp+2
		lda IDE64_CLOCKPORT  ; bit 5
		lsr a
		ror tmpzp+2
		lda IDE64_CLOCKPORT  ; bit 6
		lsr a
		ror tmpzp+2
		lda IDE64_CLOCKPORT  ; bit 7
		lsr a
		ror tmpzp+2
		lda tmpzp+2
		rts

	;; update_date
	;; read time and date from IDE64 RTC
	;; at this point irq must be disabled
update_date:	lda #2				; irq must be disabled
		sta IDE64_CLOCKRESET		;enable clock chip
		lda #%10111111			;clock burst read command
		jsr write_byte
		jsr read_byte
		sta second
		jsr read_byte
		sta minute
		jsr read_byte
		sta hour
		jsr read_byte
		sta day
		jsr read_byte
		sta month
		jsr read_byte
		sta weekday
		jsr read_byte
		sta year
		lda #0
		sta sec10
		sta IDE64_CLOCKRESET		;disable clock chip

		lda year
		cmp #$80			;<80 - 1980-1999
		bcc +
		lda #$19
		SKIP_WORD
	+	lda #$20			; years 2000-2079
		sta century
		dec weekday			; convert weekday
		lda weekday
		bne +
		lda #7				; if==0 - it was Sunday
		sta weekday
	+	rts

	;; write_time
	;; write time to IDE64 RTC
	;; irq must be disabled

write_time:
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
	;; read time from IDE64 RTC
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
	;; write time to IDE64 RTC
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
	;; read date and time from IDE64 RTC
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
	;; write date and time to IDE64 RTC
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

howto_txt:	.text "usage: ide64rtc",$0a,0

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
