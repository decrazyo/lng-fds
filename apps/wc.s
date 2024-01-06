#include <system.h>
#include <kerrors.h>
#include <stdio.h>

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		chars equ userzp
		words equ userzp+2
		lines equ userzp+4
		wflag equ userzp+6
		hlp   equ userzp+7
		
		;; wc counts chars, words and lines

		lda  userzp
		cmp  #1					; no further arguments accepted
		beq  go

		cmp  #2
		beq  +
		jmp  HowTo

		;; open file
	+	ldx  #stdin
		jsr  fclose				; close old stdin-channel
		nop
		ldy  #0
		sty  userzp
	-	iny
		lda  (userzp),y
		bne  -
		iny
		tya
		ldy  userzp+1
		ldx  #fmode_ro
		jsr  fopen
		nop						; will use old stdin-channel, as it is the
								; first available fd

go:		ldx  userzp+1			; free unused argument memory
		jsr  lkf_free

		lda  #9
		jsr  lkf_set_zpsize
		lda  #0
		ldx  #6
	-	sta  userzp,x
		dex
		bpl  -

loop:	ldx  #stdin
		sec
		jsr  lkf_fgetc
		bcs  loop_end
		inc  chars
		bne  +
		inc  chars+1
	+	cmp  #$20
		beq  isspace
		cmp  #$08
		beq  isspace
		cmp  #$0a
		bne  not_white_space
		inc  lines
		bne  isspace
		inc  lines+1
isspace:
		bit  wflag
		bpl  wskip
		inc  words
		bne  +
		inc  words+1
	+	lda  #$00
		sta  wflag
wskip:	
		jmp  loop

not_white_space:		
		lda  wflag
		bmi  loop
		lda  #$80
		sta  wflag
		jmp  loop

loop_end:
		cmp  #lerr_eof
		beq  loop_end2
		jmp  lkf_suicerrout

loop_end2:
		;; print report
		ldx  lines
		ldy  lines+1
		jsr  print_decimal
		ldx  words
		ldy  words+1
		jsr  print_decimal
		ldx  chars
		ldy  chars+1
		jsr  print_decimal
		lda  #$0a
		jsr  putc
		lda  #0					; return with exitcode=0
		rts
		
print_decimal:
		stx  hlp
		sty  hlp+1
		
		ldx  #4
		ldy  #0

	-	sec
		lda  hlp
		sbc  d_tab_lo,x
		lda  hlp+1
		sbc  d_tab_hi,x
		bcc  +

		sta  hlp+1
		lda  hlp
		sbc  d_tab_lo,x
		sta  hlp
		iny
		jmp  -

	+	tya
		beq  +
		ora  #"0"
		jsr  putc
		ldy  #"0"

	+	dex
		bne  -
		lda  hlp
		ora  #"0"
		jsr  putc
		lda  #$20		
putc:	sec						; forced (non blocking)
		stx  wflag
		ldx  #stdout
		jsr  lkf_fputc
		nop
		ldx  wflag
		rts
			
HowTo:
		ldx  #stderr
		bit  HowTo_txt
		jsr  lkf_strout
		nop
		lda  #1
		rts

		RELO_END ; no more code to relocate
				
HowTo_txt:
		;;    "0123456789012345678901234567890123456789"
		.text "Usage: wc [file]"
		.byte $0a
		.text "  Counts chars, words and lines (16bit)"
		.byte $0a,$00

d_tab_lo: .byte <1, <10, <100, <1000, <10000
d_tab_hi: .byte >1, >10, >100, >1000, >10000

end_of_code:

