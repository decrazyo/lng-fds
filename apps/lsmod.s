		;; lsmod
		;; list modules
		
		
#include <system.h>
#include <stdio.h>

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		ldy  #0
	-	lda  titleline,y
		beq  +
		jsr  out
		iny
		bne  -
		
	+	lda  #4					; allocate 4 bytes of zeropage
		jsr  lkf_set_zpsize

		lda  lk_modroot+1
		beq  done				; (empty list)

		sta  userzp+1
		lda  lk_modroot
		sta  userzp

	-	;; print out single module info line
		ldy  #0
		lda  (userzp),y
		jsr  out
		iny
		lda  (userzp),y
		jsr  out
		iny
		lda  (userzp),y
		jsr  out
		iny
		lda  (userzp),y
		jsr  decout				
		ldy  #4
		lda  (userzp),y
		jsr  decout				
		ldy  #5
		lda  (userzp),y
		jsr  decout

		lda  #" "
		jsr  out
		lda  userzp+1
		jsr  hexout
		lda  userzp
		jsr  hexout
		
		lda  #$0a
		jsr  out

		ldy  #7
		lda  (userzp),y
		tax
		dey
		lda  (userzp),y
		sta  userzp
		stx  userzp+1
		bne  -

done:
		lda  #0
		rts
		

		;; print decimal number (8bit)
decout:
		pha
		lda  #" "
		jsr  out
		pla
		
		ldx  #0
		ldy  #2
	-	sec
	-	sbc  dectab,y
		bcc  +
		inx
		bcs  -
	+	adc  dectab,y
		pha
		txa
		beq  +
		ldx  #"0"
		ora  #"0"
		SKIP_WORD
	+	lda  #" "
		stx  userzp+2
		jsr  out
		ldx  userzp+2
		pla
		dey
		bne  --
		ora  #"0"
out:
		ldx  #stdout
		sec
		jsr  fputc
		nop
		rts		

		;; print hexadecimal
hexout:
		pha
		lsr  a
		lsr  a
		lsr  a
		lsr  a
		tax
		lda  hextab,x
		jsr  out
		pla
		and  #$0f
		tax
		lda  hextab,x
		jmp  out
				
		RELO_END ; no more code to relocate

dectab:	.byte 1,10,100
titleline:
		.text "Typ  SZ Ver Num Addr"
		.byte $0a, $00
hextab:
		.text "0123456789abcdef"
		
end_of_code:


