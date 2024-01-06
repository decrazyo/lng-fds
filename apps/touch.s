		;; simple touch command (for multiple files)
		;; © by Stefan Haubenthal 2001
		
#include <system.h>
#include <kerrors.h>
#include <stdio.h>

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		lda  userzp				; get number of submitted arguments
		cmp  #2
		bcc  HowTo				; (need at least one additional argument)

		;; read file name
		ldy #0
		sty userzp				; now (userzp) points to first argument
	-	iny
		lda (userzp),y
		bne -					; skip first argument
		iny
		sty  userzp
		tya
loop:	ldy  userzp+1
		sec
		ldx #fmode_wo
		jsr fopen
		bcc +
		jmp lkf_suicerrout
	+	ldy  #0
	-	iny
		lda  (userzp),y
		bne  -
		iny
		lda  (userzp),y
		beq  loop_end
		tya
		adc  userzp				; (carry was cleared by fcmd)
		sta  userzp
		bcc  loop				; (always jump)
		
loop_end:
		lda  #0
		rts

HowTo:
		ldx  #stderr
		bit  howto_txt
		jsr  lkf_strout
		lda  #1
		rts						; exit(1)
		
		RELO_END
		
howto_txt:
		.text "Usage: touch <file> ..."
		.byte $0a,$00
		
end_of_code:
