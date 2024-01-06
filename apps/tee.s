		;; tee - v1.0
		;; (c) 1999 Piotr Roszatycki <dexter@fnet.pl>
		
#include <system.h>
#include <kerrors.h>
#include <stdio.h>

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		tee_argv equ userzp
		tee_file equ userzp+2

		lda #3					; allocate 3 bytes of zeropage
		jsr lkf_set_zpsize			; (2 is default)
		
		ldx #stdout				; write to stdout if no argument
		stx tee_file

		lda tee_argv				; get number of arguments submitted
		cmp #1
		beq tee_fread
		cmp #2
		bne tee_help 				; no argument - print help

		;; read file name
		ldy #0
		sty tee_argv				; now (userzp) points to first argument
	-	iny
		lda (tee_argv),y
		bne -					; skip first argument
		iny
		
		tya					; (userzp) -> A/Y
		clc
		adc tee_argv
		ldy tee_argv+1
		bcc +
		iny
	+	sec
		ldx #fmode_wo				; (write only)
		jsr fopen				; open file
		bcc +
		jmp lkf_suicerrout
	+	stx tee_file
		
tee_fread:
		sec
		ldx #stdin
		jsr fgetc
		bcs tee_ferror
			
		sec					 
		ldx tee_file
		jsr fputc
		jmp tee_fread

tee_ferror:	
		cmp #lerr_eof
		beq tee_feof
		jmp lkf_suicerrout
tee_feof:
		ldx userzp+2
		jsr fclose
		lda #$00
		rts						; exit(0)

tee_help:
		ldx #stdout
		bit tee_helptext
		jsr lkf_strout
		nop
		lda #1
		jmp lkf_suicide

		RELO_END ; no more code to relocate
		
tee_helptext:
		.text "Usage: tee [file]"
		.byte $0a,$00
		
end_of_code:
