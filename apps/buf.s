		;; memory bufferd stream
		;; stdin is written into memory until EOF, then
		;; output to stdout
		
#include <system.h>
#include <stdio.h>
#include <kerrors.h>

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		lda  #3
		jsr  lkf_set_zpsize
		
		lda  userzp
		cmp  #1
		beq  +

		;; HowTo
		ldx  #stderr
		bit  howto_txt
		jsr  lkf_strout
		lda  #1
		jmp  lkf_suicide

	+	ldx  userzp+1
		jsr  lkf_free

		ldy  #0
		sty  userzp
		sty  userzp+1
		
read_loop:
		lda  #1
		jsr  lkf_palloc
		nop
		ldy  userzp+1
		beq  +
		txa
		sta  lk_memnxt,y
		bne  ++					; (always jump)
	+	stx  start_page
	+	stx  userzp+1
		ldy  #0
		ldx  #stdin
	-	sec						; (blocking fgetc)
		jsr  fgetc
		bcs  read_loop_end
		sta  (userzp),y
		iny
		bne  -
		beq  read_loop

read_loop_end:
		cmp  #lerr_eof
		beq  +
		jmp lkf_suicerrout

	+	sty  userzp+2
		ldx  #stdin
		jsr  fclose
		ldy  #0
		lda  start_page
write_loop:
		sta  userzp+1
		tax
		lda  lk_memnxt,x
		beq  write_last_page
		ldx  #stdout
	-	lda  (userzp),y
		sec
		jsr  fputc
		nop
		iny
		bne  -
		ldx  userzp+1
		lda  lk_memnxt,x
		bne  write_loop			; (always jump)

write_last_page:
		ldx  #stdout
	-	cpy  userzp+2
		beq  write_loop_end
		lda  (userzp),y
		sec
		jsr  fputc
		nop
		iny
		bne  -

write_loop_end:
		lda  #0
		rts						; exit(0)
		
		RELO_END ; no more code to relocate

start_page:		.buf 1
howto_txt:		.text "Usage: buf",$0a
				.text "  read stdin into memory until EOF,",$0a
				.text "  then pass to stdout.",$0a,0

end_of_code:


