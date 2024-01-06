		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; application skeleton for ca65 -t lunix (.o65 format)
		;; Maciej 'YTM/Elysium' Witkowiak <ytm@elysium.pl>
		;; 06.04.2002

;; To write/compile any application using ca65 just put them into lng/apps
;; directory, name as APP.ca65.s and add APP.o65 to APPS list in Makefile
;;
;; Makefile will take care of everything and the resulting file will be
;; *.o65 to reflect that it is in .o65 format. That filename extension really
;; means nothing for LUnix

;; This stuff may be confusing, because ca65 syntax is mixed together with
;; lupo (LUnix preprocessor) stuff. This is done this way to keep both old
;; and .o65 targets using the very same include files - unity and consistency.

;; It might be confusing as there are two types of macros - those predefined
;; in cstyle.h where lupo preprocessor is responsible for handling them, and
;; your own macros written in ca65 language

;; you have to define variable USING_CA65 before any other includes, so
;; lupo will know which constructions to use
;; by default this is done in Makefile when calling lupo

;;#define USING_CA65 1

#include <system.h>
#include <stdio.h>
#include <kerrors.h>
#include <cstyle.h>
#include <ident.h>

		;; every app must export its entry point - function main.
		;; currently it is ignored and entry point must be the
		;; first byte of code, but in the future it might be used

		;; what's the purpose of having main and _main?
		;; main - program entry point, kernel jumps here after loading
		;; _main - will be removed in future, for internal use of application
		;;   (in case of C main will be in ctr0 while _main in user code)

		.export _main
		.export main

		;; dummy segments to keep ld65 happy
		.segment "STARTUP"
		.segment "LOWCODE"

		.segment "CODE"			; we're in CODE segment now
		;; (task is entered here)
_main:
main:
		jsr  parse_commandline

		ldx  userzp+1			; address of commandline (hi byte)
		jsr  lkf_free			; free used memory
						; (commandline not needed any more)
		jmp  main_code

		;; print howto message and terminate with error (code 1)
howto:		ldx  #stdout
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
		lda  userzp		; (number of given arguments)
		cmp  #2			; need exactly one argument
		bne  howto		; (if argc != 2 goto howto)

		;; get pointer to first option (skip command name)

		ldy  #0
		sty  userzp		; now (userzp) is a 16bit pointer to
					; the argument string
    :		iny			; ca65 has unnamed labels, but you always use ':'
		lda  (userzp),y		; as label and use ':+++...' or ':---...' to call one
		bne  :-			; of next/previous labels
		iny

		;; now (userzp),y points to first char of first option string
		;; we will do something with it: let's print it out
		sty  L01+1		; low byte is in Y register
		lda  userzp+1
		sta  L01+2		; high byte is in userzp+1

		ldx  #stdout
L01:		bit  txt_howto
		jsr  lkf_strout		; let's print it out
		rts			; return from parser to main program

		;; main programm code
main_code:
		set_zeropage_size(1)	; tell the system how many zeropage
					; bytes we need
					; (set_zeropage_size() is a macro defined
					; in cstyle.ca65.h)

		;; .o65 doesn't have restrictions of original LNG apps, so
		;; the following construction will be correctly relocated
		;; to prove this we will load txt_information address and
		;; call lkf_strout to show that text on stdout

		lda  #<txt_information
		ldy  #>txt_information	; this is forbidden in old format!
		sta  L02+1
		sty  L02+2

		ldx  #stdout
L02:		bit  txt_howto		; incorrect address upon loading
		jsr  lkf_strout

		;; you could also use:
		print_string("Hello World")
		;; there is exception - luna will interpret '\n' as $0a
		;; while ca65 will show two characters - '\' and 'n'

		lda  #0			; (error code, 0 for "no error")
		rts			; return with no error
		;; or just
		;; exit(0)

		.segment "RODATA"	; now we're in read-only data segment
		ident(foo,0.0)

		;; this might be confusing when moving parts of code
		;; from old LNG apps to ca65 - there is no '.text'
		;; assembler command - use always '.byte'

		.segment "DATA"		; and now we switch to r/w data segment
		;; help text to print on error
txt_howto:
		.byte "Usage: foo [file]",$0a
		.byte "  insert short description",$0a,0

		;; just something to show
txt_information:
		.byte ".o65 relocator works flawlessly",$0a,0

		;; here's BSS segment, space for it will not be included in
		;; output file, it will be allocated during load

		.segment "BSS"
big_buffer:
		.res 1024		; note the size of resulting file is <1024
