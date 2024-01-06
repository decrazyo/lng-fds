		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; simple readline

#include <stdio.h>
#include <kerrors.h>

.global sreadline
		
		;; sreadline
		;; 
		;;  < userzp=pointer to buffer
		;;    Y=length of buffer (up to 255 chars)
		;; 
		;;  > c=1 :	A=errorcode (maybe just EOF)
		;;    c=0 :	Y=length of line
		
sreadline:
		dey
		sty  len_limit
		ldy  #0

	-	sec
		ldx  #stdin
		jsr  fgetc
		bcs  io_error

		cmp  #10				; newline
		beq  _eol
		cmp  #8					; backspace
		beq  _backspc
		cmp  #32
		bcc  -					; ignore all <32
		
		cpy  len_limit
		beq  -					; skip if buffer is already filled up
		sta  (userzp),y
		sec
		ldx  #stdout
		jsr  fputc
		bcs  catcherr
		iny
		bne  -

_eol:	lda  #0
		sta  (userzp),y
		lda  #10
		sec
		ldx  #stdout
		jsr  fputc
		bcs  catcherr
		rts

io_error:
		cmp  #lerr_eof
		beq  io_eof

catcherr:
		jmp  lkf_catcherr

_backspc:
		cpy  #0
		beq  -					; ignore backspaces, when len=0
		sec
		ldx  #stdout
		jsr  fputc
		bcs  catcherr
		dey
		jmp  -
		
io_eof:	tya
		bne  _eol				; EOF is newline, if line is not empty
		lda  #lerr_eof
		jmp  catcherr

		RELO_JMP(+)
		
len_limit:		
		.buf 1

	+							; end