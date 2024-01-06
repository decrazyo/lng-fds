		;; for emacs: -*- MODE: asm; tab-width: 4; -*-

		;; by Daniel Dallmann, Anton Treuenfels

		;; print_hex8
		;; prints 8bit-value hexadecimal to stdout

		;; < A=value
		;; > (A,X,Y=XX)

#include <stdio.h>

.global print_hex8

print_hex8:
		pha
		lsr  a
		lsr  a
		lsr  a
		lsr  a
		jsr  +
		bcs  error1
		pla
		and  #$0f

	+	cmp  #10
		bcc  +
		adc  #"a" - 10 - "0" - 1
	+	adc  #"0"
		sec
		ldx  #stdout
		jmp  fputc

		;; problem:	A holds error code, stack is dirty
error1:	tax						; remember error code
		pla						; clean up stack
		txa						; restore error code
		jmp  lkf_catcherr		; return / exit with error message

