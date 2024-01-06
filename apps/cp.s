;; cp - v1.0
;; only works on files for now
;; Gene McCulley <mcculley@cuspy.com>
#include <system.h>
#include <kerrors.h>
#include <stdio.h>

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		source_file  equ userzp+2
		dest_file    equ userzp+3
		source_name  equ userzp+4
		dest_name    equ userzp+5

		ldx  #stdin  ; don't need any input
		jsr  fclose  ; (ignore errors)
		ldx  #stdout ; don't need any regular output
		jsr  fclose  ; (ignore errors)

		lda  #6	            ; allocate more zeropage
		jsr  lkf_set_zpsize ; (2 bytes is default)

		lda  userzp	    ; get number of arguments submitted
		cmp  #3
		bne  usage	    ; wrong number of arguments -> error

		;; read arguments
		ldy #0              ; the first argument is the program name
		sty userzp
	-	iny
		lda (userzp),y
		bne -
		iny
		sty source_name
	-	iny
		lda (userzp),y
		bne -
		iny
		sty dest_name

		;; open source file
		lda source_name
		ldy userzp+1
		sec
		ldx #fmode_ro
		jsr fopen
		bcc +
		jmp lkf_suicerrout
	+	stx source_file

		;; open dest file
		lda dest_name
		ldy userzp+1
		sec
		ldx #fmode_wo
		jsr fopen
		bcc +
		jmp lkf_suicerrout
	+	stx dest_file

move_byte:
		sec
		ldx source_file
		jsr fgetc
		bcs got_ferror

		sec
		ldx dest_file
		jsr fputc
		bcs bad_error
		jmp move_byte

got_ferror:
		cmp #lerr_eof
		beq done
bad_error:	jmp lkf_suicerrout

done:
		;; close files and return successfully
		sec
		ldx source_file
		jsr fclose
		sec
		ldx dest_file
		jsr fclose
		lda #$00
		rts

usage:
		ldx  #stderr
		bit  usage_txt
		jsr  lkf_strout
		nop
		lda  #1
		rts

.endofcode
		
usage_txt:
		.text "Usage: cp source destination"
		.byte $0a,$00

end_of_code:
