		;; kill - v1.0
		
#include <system.h>
#include <stdio.h>
#include <kerrors.h>

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		ldx  #stdin				; don't need any input
		jsr  fclose				; close std-in channel (ignore errors)
		
		lda  #4					; allocate 3 bytes of zeropage
		jsr  lkf_set_zpsize		; (2 is default)

		ldx  userzp				; get number of arguments submitted
		
		ldy  #0
		sty  userzp+3
		sty  userzp				; now (userzp) points to first argument
	-	iny
		lda  (userzp),y
		bne  -					; skip first argument
		iny
		
		lda  #9					; (default for signal number)
		sta  userzp+2
		cpx  #2
		beq  continue1			; no further argument (except cmdname)
		cpx  #3
		bne  HowTo				; more than 1 additional argument -> error

		;; read number of signal
		lda  (userzp),y
		cmp  #"-"
		bne  HowTo
		iny
		jsr  readdecimal
		iny
		bcc  continue1
		
HowTo:
		ldx  #stdout
		bit  HowTo_txt
		jsr  lkf_strout
		nop
		lda  #1
		jmp  lkf_suicide

continue1:
		;; A holds number of signal
		lda  userzp+3
		bne  HowTo
		lda  userzp+2
		cmp  #9
		beq  +
		cmp  #8
		bcs  HowTo
	+	pha
		sty  userzp+3
		;; free memory used by submitted arguments
		ldx  userzp+1
		jsr  lkf_free
		;; read PID
		ldy  userzp+3
		jsr  readdecimal
		bcs  HowTo
		pla
		tax
		lda  userzp+2
		ldy  userzp+3
		jsr  lkf_sendsignal
		bcs  +
		lda  #0
		rts						; exit(0)

	+	cmp  #lerr_tryagain
		beq  +
		jmp  lkf_suicerrout
	+	ldx  #stdout
		bit  warn_txt
		jsr  lkf_strout
		lda  #0
		rts
		
readdecimal:
		lda  #0
		sta  userzp+2
		sta  userzp+3
		beq  +

	-	ldx  userzp+3
		lda  userzp+2			; *10
		asl  a
		rol  userzp+3
		asl  a
		rol  userzp+3
		adc  userzp+2
		sta  userzp+2
		txa
		adc  userzp+3
		asl  userzp+2
		rol  a
		sta  userzp+3
		
	+	lda  (userzp),y
		sec
		sbc  #"0"
		bcc  isnodigit
		cmp  #10
		bcs  isnodigit
		adc  userzp+2
		sta  userzp+2
		bcc  +
		inc  userzp+3
	+	iny
		lda  (userzp),y
		bne  -
		rts

isnodigit:
		sec
		rts

		RELO_END ; no more code to relocate
		
HowTo_txt:
		.text "Usage: kill [-signo] PID",$0a
		.text "  valid signal numbers are 0..7, 9"
		.byte $0a,$00

warn_txt:
		.text "Signal wasn't delivered,", $0a
		.text "not handled by destination task",$0a,0
		
end_of_code:
