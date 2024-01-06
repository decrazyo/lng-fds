#include <system.h>
#include <stdio.h>

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		bit  testfunc
		jsr  lkf_ufd_open
		nop

		lda  #0
		jsr  fputc
		jsr  fgetc
		jsr  fclose
		
		ldx  #stdout
		bit  text
		jsr  lkf_strout
		nop
				
		ldy  #0
		sty  userzp

arg_loop:
		lda  (userzp),y
		beq  arg_end
		lda  #"\""
		jsr  out
	-	lda  (userzp),y
		beq  arg_newline
		jsr  out
		iny
		bne  -
arg_newline:
		lda  #"\""
		jsr  out
		lda  #$0a
		jsr  out
		iny
		jmp  arg_loop
arg_end:

		ldx  #0					; signal 0
		lda  #<sighndl
		ldy  wloop1+2			; #>sighndl
		jsr  lkf_signal
		nop

		lda  #0
		sta  userzp
		sta  userzp+1
		lda  #$11
		ldx  #$22
		ldy  #$33
wloop1:	bit  sighndl
		ldy  #0
	-	iny
		bne  -
		inc  userzp
		bne  wloop1
		inc  userzp+1
		bne  wloop1
		
		lda  #0
		rts
		
sighndl:
		ldx  #stdout
		bit  sig_txt
		jsr  lkf_strout
		nop
		rti
		
out:	
		ldx  #stdout
		sec						; forced
		jsr  fputc
		nop
		rts

testfunc:
		cpx  #fsuser_fclose
		beq  +
		jmp  lkf_io_return
	+	rts
		
		RELO_JMP(+)

sig_txt:
		.text "Caught Signal"
		.byte $0a,$00
		
text:	
		.text "Hello and goodbye!"
		.byte $0a
		.text "These are my args:"
		.byte $0a,$00
		
	+	RELO_END ; no more code to relocate

end_of_code:


