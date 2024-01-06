	;; for emacs: -*- MODE: asm; tab-width: 4; -*-
	
	;; uptime - print system's uptime by reading
	;; the real time clock of CIA2 (which is
	;; set to "00:00:00.0am" at boot time)
	
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

		lda  userzp
		cmp  #1
		beq  +

		;; HowTo
		ldx  #stdout
		bit  howto_txt
		jsr  lkf_strout
		lda  #1
		rts

	+	ldx  userzp+1
		jsr  lkf_free

		;; FIXME
		;; shouldn't this be in the kernel ?? (direct access to CIA2)
		sei
		lda  CIA2_TODHR			; (reading TODHR makes the CIA latch the
		sta  bufHR				; current time)
		ldy  CIA2_TODMIN
		ldx  CIA2_TODSEC
		lda  CIA2_TOD10
		cli
		sty  bufMIN
		stx  bufSEC
		sta  buf10

		ldx  #stdout
		bit  begin_txt
		jsr  lkf_strout

		lda  bufHR
		bpl  +
		and  #$1f
		clc
		sed
		adc  #$12
		cld
	+	jsr  print_bcd
		lda  #":"
		jsr  putc
		lda  bufMIN
		jsr  print_bcd

		;; we don't print seconds ... uptime doesn't need to be measured
		;; in such small units ;-)

		lda  #$0a
		jsr  putc
		lda  #0
		rts

print_bcd:
		pha
		lsr  a
		lsr  a
		lsr  a
		lsr  a
		jsr  +
		pla
		and  #$0f
	+	ora  #"0"
putc:	sec
		ldx  #stdout
		jsr  fputc
		nop
		rts

		RELO_END ; no more code to relocate

begin_txt:
		.text "uptime is ",0

howto_txt:
		.text "uptime:	print system's uptime",$0a,0

bufHR:	.buf 1
bufMIN:	.buf 1
bufSEC:	.buf 1
buf10:	.buf 1

end_of_code: