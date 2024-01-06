;   date - Read or write current time and date using the rtc module
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

; #define DEBUG

#include <system.h>
#include <stdio.h>
#include <debug.h>

start_of_code:
		
		.byte >LNG_MAGIC, <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.word 0

		;; parse commandline
		ldx	#0
		bit	optstring
	-	jsr	getopt
		cmp	#"t"
		bne	+
		sty	timearg
		jmp	-
	+	cmp	#"d"
		bne	+
		sty	datearg
		jmp	-
	+	cmp	#"w"
		bne	+
		sty	weekarg
		jmp	-
	+	cmp	#"z"
		bne	+
		sty	zonearg
		jmp	-
	+	cmp	#"u"
		bne	+
		inc	unixopt
		jmp	-
	+	cmp	#"n"
		bne	+
		inc	ntpopt
		jmp	-
	+	cmp	#0
		bne	HowTo		; invalid option
		cpx	userzp
		bne	HowTo		; additional arguments
		stx	optind

		;; get rtc module
		lda	#1
	-	bit	rtc_moddesc
		ldx	#<rtc_moddesc
		ldy	- +2
		jsr	lkf_get_moduleif
		nop

		;; read date
	-	bit	date
		ldx	#<date
		ldy	- +2
		jsr	rtc_date_read

		lda	optind
		sec
		sbc	unixopt
		sec
		sbc	ntpopt
		cmp	#1
		bne	set_time
		jmp	get_time

HowTo:		ldx	#stderr
		bit	howto_txt
		jsr	lkf_strout
		lda	#1
		rts


set_time:
		lda	#4
		jsr	lkf_set_zpsize
		nop

		ldy	timearg
		beq	+
		ldx	#hour-date
		lda	#4
		jsr	read_num_bcd
	+
		ldy	datearg
		beq	+
		ldx	#century-date
		lda	#4
		jsr	read_num_bcd
	+
		ldy	weekarg
		beq	+
		ldx	#weekday-date
		lda	#1
		jsr	read_num_bcd
	+
		ldy	zonearg
		beq	+++
		sty	userzp
		ldy	#0
		lda	(userzp),y
		ldx	#$00
		cmp	#"-"
		bne	+
		ldx	#$80
		iny
	+	cmp	#"+"
		bne	+
		iny
	+	stx	unix		; used as temporary storage
		ldx	#zonehour-date
		lda	#2
		jsr	read_num_bcd+4
		lda	unix
		ora	zonehour
		sta	zonehour
	+

	-	bit	date
		ldx	#<date
		ldy	- +2
		jsr	checkdate
		bcc	+
		ldx	#stderr
		bit	illdat_txt
		jsr	lkf_strout
		nop
		jsr	get_time
		jmp	HowTo
	+
		ldx	#<date
		ldy	- +2
		jsr	rtc_date_write

#ifdef DEBUG
		jmp	get_time
#endif
		lda	#0
		rts

read_num_bcd:
		sty	userzp
		ldy	#0
		stx	userzp+3
		clc
		adc	userzp+3
		sta	userzp+3
	-	lda	(userzp),y
		beq	+		; fill date with 0
		jsr	read_bcd
	+	sta	date,x
		inx
		cpx	userzp+3
		bcc	-
		lda	(userzp),y
		bne	illchar
		rts

illbcd:		
		cmp	#0
		beq	+
		iny
		cmp	#":"
		beq	read_bcd
		cmp	#"."
		beq	read_bcd
		cmp	#","
		beq	read_bcd
	+	pla			; remove return address
		pla
illchar:
		pla
		pla
illarg:
		ldx	#stderr
	-	bit	illarg_txt
		jsr	lkf_strout
		nop
		lda	userzp
		sta	- +1		; selfmod
		ldy	userzp+1
		sty	- +2		; selfmod
		ldy	#0
		sty	userzp
		cmp	#0
		bne	-
		lda	#$0a
		sec
		jsr	lkf_fputc
		nop
		jmp	HowTo


read_bcd:
		lda	(userzp),y
		cmp	#"0"
		bcc	illbcd
		cmp	#"9"+1
		bcs	illbcd
		and	#$0f
		sta	userzp+2
		iny
		lda	(userzp),y
		cmp	#"0"
		bcc	+
		cmp	#"9"+1
		bcs	+
		iny

		pha
		lda	userzp+2
		asl	a
		asl	a
		asl	a
		asl	a
		sta	userzp+2
		pla
		and	#$0f
		ora	userzp+2
		sta	userzp+2
				
	+	lda	userzp+2
		rts



get_time:	
		;; free commandline
		ldx	userzp+1
		jsr	lkf_free
		nop
		lda	#1
		jsr	lkf_set_zpsize
		nop

		lda	unixopt
		bne	print_unix

		lda	ntpopt
		bne	print_ntp

		;; print date and time to stdout
		ldy	#zonehour-date
		sty	userzp
		lda	#0
		jsr	print_date

		pha
		bit	zonehour
		bmi	+
		lda	#"+"
		bne	++		; allways jump
	+	lda	#"-"
	+	ldx	#stdout
		sec
		jsr	lkf_fputc
		nop
		pla

		ldy	#end_of_date-date
		sty	userzp
		pha
		tax
		lda	date,x		; zonehour
		and	#$7f
		jsr	print_hex8
		nop
		pla
		jsr	print_seperator

		lda	#0
		rts


		;; print date and seperators
print_date:    
		pha
		tax
		lda	date,x
		jsr	print_hex8
		nop
		pla
print_seperator:
		pha
		tax
		lda	seperator,x
		beq	+
		ldx	#stdout
		sec
		jsr	lkf_fputc
		nop
	+	pla
		clc
		adc	#1
		cmp	userzp
		bcc	print_date
		rts


haddr_date:	bit	date
haddr_unix:	bit	unix
haddr_ntp:	bit	ntp

		;; print time in seconds from 1970.01.01 01.00.00 UTC
print_unix:
		lda	#4
		jsr	lkf_set_zpsize
		nop

		lda	#<date
		sta	userzp+0
		lda	haddr_date+2
		sta	userzp+1
		lda	#<unix
		sta	userzp+2
		lda	haddr_unix+2
		sta	userzp+3
		jsr	datetounix
		nop

		lda	unix+3
		jsr	print_hex8
		nop
		lda	unix+2
		jsr	print_hex8
		nop
		lda	unix+1
		jsr	print_hex8
		nop
		lda	unix+0
		jsr	print_hex8
		nop
		ldx	#stdout
		lda	#$0a
		jsr	lkf_fputc
		nop

		lda	#0
		rts

		;; print time in seconds from 1900.01.01 01.00.00 UTC
print_ntp:
		lda	#4
		jsr	lkf_set_zpsize
		nop

		lda	#<date
		sta	userzp+0
		lda	haddr_date+2
		sta	userzp+1
		lda	#<ntp
		sta	userzp+2
		lda	haddr_ntp+2
		sta	userzp+3
		jsr	datetontp
		nop

		
		lda	ntp+0
		jsr	print_hex8
		nop
		lda	ntp+1
		jsr	print_hex8
		nop
		lda	ntp+2
		jsr	print_hex8
		nop
		lda	ntp+3
		jsr	print_hex8
		nop
		lda	ntp+4
		jsr	print_hex8
		nop
		lda	ntp+5
		jsr	print_hex8
		nop
		lda	ntp+6
		jsr	print_hex8
		nop
		lda	ntp+7
		jsr	print_hex8
		nop
		ldx	#stdout
		lda	#$0a
		jsr	lkf_fputc
		nop

		lda	#0
		rts


		.byte	$0c
		.word	+

howto_txt:
		.text	"usage: date [...]",$0a
		.text	" -t hh:mm:ss.tt  set time",$0a
		.text	" -d ccyy.mm.dd  set date",$0a
		.text	" -w ww  set weekday",$0a
		.text	" -z shhmm  set timezone, s is + or -",$0a
		.text	" -u print time in unix format",$a
		.text	" -n print time in ntp format",$a
		.text	" get current weekday,date,time,timezone",$0a,0

illarg_txt:	.text	"illegal argument -- ",0
illdat_txt:	.text	"illegal data -- ",$0a," ",0

optstring:	.text	"t:d:w:z:unh",0
timearg:	.byte	0
datearg:	.byte	0
weekarg:	.byte	0
zonearg:	.byte	0
unixopt:	.byte	0
ntpopt:		.byte	0
optind:		.byte	0

rtc_moddesc:
		.asc	"rtc"
		.byte	4
rtc_time_read:	jmp	lkf_suicide
rtc_time_write: jmp	lkf_suicide
rtc_date_read:	jmp	lkf_suicide
rtc_date_write: jmp	lkf_suicide

date:
weekday:	.byte	0	; range from 00 to 07, 0 means invalid
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
zonehour:	.byte	0	; 0 UTC, 1 CET/MEZ, 2 CEST/MESZ, bit 7 is sign
zonemin:	.byte	0	; range from 00 to 59
end_of_date:

seperator:	.text	" ",0,".. ::. ",0,$0a

unix:		.byte	0,0,0,0
ntp:		.byte	0,0,0,0,0,0,0,0
	+

end_of_code:
