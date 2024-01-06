		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; more
		;; simple first time implementation
	
#include <system.h>
#include <stdio.h>
#include <fs.h>
#include <kerrors.h>
		
		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION,	<LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		ldx  #stdout
		jsr  lkf_fgetdevice
		cpy  #MAJOR_CONSOLE
		beq  ok
		cpy  #MAJOR_USER
		beq  ok					; might be a wrong guess !
		;; is pipe, iec (cbm drive) or other - "more" doesn't work here
	-	lda  #1
		rts

in_end:
		cmp  #lerr_eof
		bne  -
		lda  #0
		rts

		;; howto
		
	-	ldx  #stdout
		bit  txt_howto
		jsr  lkf_strout
		lda  #1
		rts
		
		;; parse commandline
ok:
		lda  userzp
		cmp  #1					; no further arguments accepted
		beq  go

		cmp  #2
		bne  -

		;; open file
		ldx  #stdin
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

		ldy  #tsp_termwy
		lda  (lk_tsp),y			; get number of visible lines
		sec
		sbc  #1
		sta  userzp				; leave at least 1 line (for more prompt)
		sec
		sbc  #3
		sta  l_num				; for the future leave at least 3 old lines

loop:	
	-	ldx  #stdin
		sec
		jsr  fgetc
		bcs  in_end
		pha
		ldx  #stdout
		sec
		jsr  fputc
		pla
		cmp  #$0a
		bne  -					; wait for newline
		dec  userzp
		bne  -

		ldx  #stdout
		bit  txt_more
		jsr  lkf_strout

	-	ldx  #stdout
		sec
		jsr  fgetc				; hack!! reading from stdout  :)
		nop
		cmp  #$71				; "q"
		beq  quit
		cmp  #$0a
		beq  single_line
		cmp  #$20
		bne  -

l_num equ *+1					; number of lines to print (default 20)
		lda  #20
	-	sta  userzp
		ldx  #stdout
		bit  txt_cont
		jsr  lkf_strout

		jmp  loop
		
single_line:
		lda  #1
		bne  -

quit:	lda  #0
		rts

		RELO_END ; no more code to relocate

txt_howto:
		.text "usage:",$0a
		.text "  more [file]",$0a
		.text "  print file (or stdin) page wise",$0a,0
		
		;; inverse "<more>"
txt_more:
		.text $1b,"[7m<more>",$1b,"[m",$00

		;; go to beginning of current line and rease
txt_cont:		
		.text $0d,$1b,"[K",$00
end_of_code:	





