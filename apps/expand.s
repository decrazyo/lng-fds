		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; application that does command line expansion
		;;
		;; may be used by the shell or incorporated into a
		;; improved version of the shell

		;; pattern:
		;;  ?    exactly one character
		;;  *    any number of characters
		;; else  exact matching character

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
		
		set_zeropage_size(4)	; tell the system how many zeropage
		jsr  parse_commandline
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
		sty  userzp+2
		lda  userzp+1
		sta  userzp+3			; userzp+2 points to regexp
		
	-	lda  (userzp),y
		beq  +
		iny
		bne  -
		jmp  howto

	+	iny
		beq  howto
		lda  (userzp),y
		bne  howto				; don't want a second arg
		sty  userzp				; userzp now points to 0 !!
		rts

		bit dir_struct			; (let system relocate dir_struct)

		;; main programm code
main_code:
		lda  userzp
		ldy  userzp+1			; (points to 0, see parse_commandline)
		jsr  fopendir
		nop						; (catch errors)
		stx  fno_dir

loop:
		sec						; (blocking freaddir)
		lda  #<dir_struct
		ldy  main_code-1		; #>dir_struct
		ldx  fno_dir
		jsr  freaddir
		bcc  +					; (no error?)
		cmp  #lerr_eof
		beq  loopend
		jmp  lkf_suicerrout		; die with errormessage

	+	jsr  checkfilename		; see if filename matches regexp
		bcc  loop				; (no match?)

		ldy  #0
	-	lda  dir_struct+12,y
		beq  +
		sec						; (blocking fputc)
		ldx  #stdout
		jsr  fputc
		nop						; (catch errors)
		iny
		bne  -

	+	lda  #10				; LF
		sec						; (blocking fputc)
		ldx  #stdout
		jsr  fputc
		nop						; (catch errors)
		
		jmp  loop

loopend:
		ldx  fno_dir
		jsr  fclose
		nop						; (catch errors)
		
		lda  #0					; (error code, 0 for "no error")
		rts						; return with no error

		;; check: syszp+2 points to regexp,
		;; dir_struct+12 is filename to check
		
#define FNAME dir_struct+12
#define REGEXP (userzp+2)

#define ANY  "?"
#define STAR "*"

		;; match linear (stop at "*" or end)
linmatch:
	-	lda  REGEXP,y
		beq  lm_end
		cmp  #STAR
		beq  lm_end
		cmp  FNAME,x
		beq  +
		cmp  #ANY
		bne  ++
		lda  FNAME,x
		beq  ++
	+	iny
		inx
		bne  -
	+	clc
		rts

ch_match:
lm_end:	sec
		rts
		
checkfilename:	
		ldy  #0
		ldx  #0

		jsr  linmatch
		bcc  ch_nomatch
ch_loop:
		cmp  #STAR
		beq  +					; stopped at "*"?

		lda  FNAME,x
		beq  ch_match			; match
ch_nomatch:
		clc
		rts

	+	;; search for substring

	-	iny
		lda  REGEXP,y
		beq  ch_match
		cmp  #STAR
		beq  -

		stx  userzp
		sty  userzp+1

	-	lda  FNAME,x
		beq  ch_nomatch

		jsr  linmatch
		bcs  ch_loop

		inc  userzp
		beq  ch_nomatch
		ldx  userzp
		ldy  userzp+1
		bcc  -					; (always jump)
				
		;; ------------------------------------------
		RELO_END ; no more code to relocate
		ident(expand,0.9)

		;; help text to print on error		
txt_howto:
		.text "Usage: expand [regexp]",$0a
		.text "  list filenames matching regexp",$0a,0
		
fno_dir:
		.buf 1
dir_struct:
		.buf DIRSTRUCT_LEN


end_of_code:
