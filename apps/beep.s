		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; application sceleton
	
#include <system.h>
#include <stdio.h>
#include <kerrors.h>
#include <cstyle.h>
				
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
		beq  +					; (ok)
		
		cmp  #1					; need exactly NONE arguments
		bne  howto				; (if argc != 2 goto howto)

	+	rts

		;; main programm code
main_code:
		set_zeropage_size(0)	; tell the system how many zeropage
								; bytes we need
								; (set_zeropage_size() is a macro defined
								; in include/cstyle.h) 

		lda  #7					; ASCII code for "beep"
		sec						; (blocking)
		ldx  #stderr
		jsr  fputc				; print char (ring the bell)

		lda  #0					; (error code, 0 for "no error")
		rts						; return with no error
		;; or just
		;; exit(0)
		
		RELO_END ; no more code to relocate

		;; help text to print on error
		
txt_howto:
		.text "usage:",$0a
		.text " beep",$0a
		.text "  used to alert terminal user by a ",$0a
		.text "  audible sound (prints 0x07 to stderr)",$0a,0
		
end_of_code: