		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; application skeleton
	
#include <system.h>
#include <stdio.h>
#include <kerrors.h>
#include <cstyle.h>
#include <ident.h>
				
		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION,	<LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code
		
		;; (task is entered here)
		
		jsr  parse_commandline
		
		ldx  userzp+1			; address of commandline (hi byte)
		jsr  lkf_free			; free used memory
								; (commandline not needed any more)

		jmp  main_code
		

		;; print howto message and terminate with error (code 1)
		
howto:	ldx  #stdout
		bit  txt_howto
		jsr  lkf_strout
		exit(1)					; (exit() is a macro defined in
								;  include/cstyle.h)

		;; commandline
		;;  first argument is the command name itself
		;;  so userzp (argc = argument count) is at least 1
		;;  userzp+1 holds the hi-byte of the argument strings address

		;; format of the argument string:
		;;  "<command-name>",0,"<argument1>",0,...,"<last argument>",0 ,0
		
parse_commandline:
		;; check for correct number of arguments
		lda  userzp				; (number of given arguments)
		cmp  #2					; need exactly one argument
		bne  howto				; (if argc != 2 goto howto)

		;; get pointer to first option (skip command name)

		ldy  #0
		sty  userzp				; now (userzp) is a 16bit pointer to
								; the argument string
	-	iny
		lda  (userzp),y
		bne  -
		iny

		;; now (userzp),y points to first char of first option string

		;...
		rts

		;; main programm code
main_code:
		set_zeropage_size(1)	; tell the system how many zeropage
								; bytes we need
								; (set_zeropage_size() is a macro defined
								; in include/cstyle.h) 
		;...

		lda  #0					; (error code, 0 for "no error")
		rts						; return with no error
		;; or just
		;; exit(0)
		
		RELO_END ; no more code to relocate

		ident(foo,0.0)

		;; help text to print on error
		
txt_howto:
		.text "Usage: foo [file]",$0a
		.text "  insert short description",$0a,0
		
end_of_code:
