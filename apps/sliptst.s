#include <stdio.h>
#include <slip.h>
		
		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

start:
		bit  moddesc
		
		ldx  userzp+1
		jsr  lkf_free

		lda  #4
		jsr  lkf_set_zpsize
		
		lda  #0
		ldx  #<moddesc
		ldy  start+2			; #>moddesc
		jsr  lkf_get_moduleif
		nop

bigloop:
		lda  #1					; buffer of 256 bytes
		jsr  lkf_palloc
		nop
		stx  userzp+1			; remember page
		
		txa
		ldx  #<256
		ldy  #>256
		jsr  slip_putpacket
		bcc  +
		ldx  userzp+1
		jsr  lkf_free

		jsr  slip_unlock
		lda  #2
		rts						; exit(2)
		
	+ -	jsr  slip_getpacket
		bcs  -

		;; got packet
		sta  userzp+1
		stx  userzp+2
		sty  userzp+3
		ldy  #0
		sty  userzp+0

loop:	lda  userzp+2
		ora  userzp+3
		beq  loop_end
		lda  (userzp),y
		jsr  hexout
		tya
		and  #7
		cmp  #7
		bne  +
		lda  #$0a
		.byte $2c				; (bit$20a9)
	+	lda  #$20
		jsr  out
		lda  userzp+2
		bne  +
		dec  userzp+3
	+	dec  userzp+2
		iny
		bne  loop
		inc  userzp+1
		jmp  loop
		
loop_end:
		lda  #"<"
		jsr  out
		lda  #$0a
		jsr  out
		jmp  bigloop
		
hexout:
		pha
		lsr  a
		lsr  a
		lsr  a
		lsr  a
		jsr  +
		pla
		and  #$0f
	+	tax
		lda  hextab,x
out:	ldx  #stdout
		sec
		jsr  fputc
		nop
		rts
		
		RELO_END ; no more code to relocate

hextab:	.text "0123456789abcdef"
				
moddesc:
		;; MACRO defined in slip.h
		;;  (unlock, putpacket, getpacket)
		SLIP_struct3
		
end_of_code:	
