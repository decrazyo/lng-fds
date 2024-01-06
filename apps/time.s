	;; for emacs: -*- MODE: asm; tab-width: 4; -*-

	;; time - print current time by reading the real time clock of CIA1

#include <system.h>
#include <stdio.h>
#include <config.h>
#include MACHINE_H

		start_of_code equ $1000

		.org start_of_code

		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION,	<LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		;; start

		lda  #3
		jsr  lkf_set_zpsize

		lda  userzp
		cmp  #1
		beq  get_time

		cmp  #3
		beq  set_time

HowTo:		ldx  #stdout
		bit  howto_txt
		jsr  lkf_strout
		lda  #1
		jmp  lkf_suicerrout

set_time:
		ldy  #0
		sty  userzp
		;; skip command name
	-	iny
		lda  (userzp),y
		bne  -
		;; check for "-s" switch
		iny
		lda  #"-"
		jsr  argck
		lda  #$73				; "s"
		jsr  argck
		lda  #0
		jsr  argck
		;; read time
		jsr  read_bcd
		sta  bufHR
		lda  #":"
		jsr  argck
		jsr  read_bcd
		sta  bufMIN
		lda  #0
		sta  bufSEC
		lda  #":"
		cmp  (userzp),y
		bne  +
		iny
		jsr  read_bcd
		sta  bufSEC
	+	lda  (userzp),y
		cmp  #$61				; "a"
		beq  +
		cmp  #$70				; "p"
		bne  HowTo
		lda  bufHR
		ora  #$80
		sta  bufHR
	+	lda  bufHR
		ldx  bufMIN
		ldy  bufSEC
		;; FIXME -> move into kernel or system dependent library
		sei
		sta  CIA1_TODHR
		stx  CIA1_TODMIN
		sty  CIA1_TODSEC
		lda  #0
		sta  CIA1_TOD10
		cli
		rts

get_time:	
		ldx  userzp+1
		jsr  lkf_free

		;; FIXME
		;; shouldn't this be in the kernel ?? (direct access to CIA1)
		sei
		lda  CIA1_TODHR			; (reading TODHR makes the CIA latch the
		sta  bufHR				; current time)
		ldy  CIA1_TODMIN
		ldx  CIA1_TODSEC
		lda  CIA1_TOD10
		cli
		sty  bufMIN
		stx  bufSEC
		sta  buf10

		ldx  #stdout
		bit  begin_txt
		jsr  lkf_strout

		lda  bufHR
		and  #$1f
		jsr  print_bcd
		lda  #":"
		jsr  putc
		lda  bufMIN
		jsr  print_bcd
		lda  #":"
		jsr  putc
		lda  bufSEC
		jsr  print_bcd
		lda  #"."
		jsr  putc
		lda  buf10
		jsr  print_bcd2
		lda  #$61				; "a"
		bit  bufHR
		bpl  +
		lda  #$70				; "p"
	+	jsr  putc
		lda  #$6d				; "m"
		jsr  putc
		lda  #$0a
		jsr  putc
		lda  #0
		rts

argck:
		cmp  (userzp),y
		beq  ++
		cmp  #":"
		bne  +
		;; alternative seperators
		lda  (userzp),y
		cmp  #"."
		beq  ++
		cmp  #","
		beq  ++
	+	jmp  HowTo
	+	iny
		rts

read_bcd:
		lda  (userzp),y
		cmp  #"0"
		bcc  illchar
		cmp  #"9"+1
		bcs  illchar
		and  #$0f
		sta  userzp+2
		iny
		lda  (userzp),y
		cmp  #"0"
		bcc  +
		cmp  #"9"+1
		bcs  +
		iny

		pha
		lda  userzp+2
		asl  a
		asl  a
		asl  a
		asl  a
		sta  userzp+2
		pla
		and  #$0f
		ora  userzp+2
		sta  userzp+2

	+	lda  userzp+2
		clc
		rts

illchar:
		jmp  HowTo

print_bcd:
		pha
		lsr  a
		lsr  a
		lsr  a
		lsr  a
		jsr  print_bcd2
		pla
		and  #$0f
print_bcd2:		
		ora  #"0"
putc:	sec
		ldx  #stdout
		jsr  fputc
		nop
		rts

		RELO_END ; no more code to relocate

begin_txt:
		.text "time ",0

howto_txt:
		.text "usage: time [-s hh:mm[:ss](am|pm)]",$0a
		.text " get/set current time",$0a,0

bufHR:	.buf 1
bufMIN:	.buf 1
bufSEC:	.buf 1
buf10:	.buf 1

end_of_code:
