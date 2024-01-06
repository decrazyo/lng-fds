		;; sleep - v1.0
		;; (could/should be included in the shell itself)
		;; (sleep is a nice sceleton for other commands)
		
#include <system.h>
#include <stdio.h>

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		ldx  #stdin				; don't need any input
		jsr  fclose				; close std-in channel (ignore errors)
		
		lda  #3					; allocate 3 bytes of zeropage
		jsr  lkf_set_zpsize		; (2 is default)
		
		lda  userzp				; get number of arguments submitted
		cmp  #1
		beq  continue1			; no further argument (except cmdname)
		cmp  #2
		bne  HowTo				; more than 1 additional argument -> error

		;; read number of seconds
		ldy  #0
		sty  userzp				; now (userzp) points to first argument
	-	iny
		lda  (userzp),y
		bne  -					; skip first argument
		iny
		jsr  readdecimal
		bcc  continue1
		
HowTo:
		ldx  #stdout
		bit  HowTo_txt
		jsr  lkf_strout
		nop
		lda  #1
		jmp  lkf_suicide

continue1:
		;; A holds number of seconds to wait
		sta  userzp
		
		ldx  userzp+1
		jsr  lkf_free			; free memory used by submitted arguments
		
		ldx  #stdout			; don't need any output
		jsr  fclose				; close std-out channel
		nop						; let kernel handle errors
		ldx  #stderr
		jsr  fclose				; close std-error channel
		nop						; let kernel handle errors

		lda  #0					; *64
		asl  userzp
		rol  a
		asl  userzp
		rol  a
		asl  userzp
		rol  a
		asl  userzp
		rol  a
		asl  userzp
		rol  a
		asl  userzp
		rol  a
		tay
		ldx  userzp
		jsr  lkf_sleep
		lda  #0
		rts						; exit(0)

readdecimal:
		lda  #0
		sta  userzp+2
		beq  +

	-	lda  userzp+2			; *10
		asl  a
		asl  a
		adc  userzp+2
		asl  a
		sta  userzp+2
		
	+	lda  (userzp),y
		sec
		sbc  #"0"
		bcc  isnodigit
		cmp  #10
		bcs  isnodigit
		adc  userzp+2
		sta  userzp+2
		iny
		lda  (userzp),y
		bne  -

		lda  userzp+2
		rts

isnodigit:
		sec
		rts

		RELO_END ; no more code to relocate
		
HowTo_txt:
		.text "Usage: sleep [seconds]"
		.byte $0a,$00
		
end_of_code:
