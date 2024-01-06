; rm [-i] file ...
;	Remove files

; v1.0	Unknown
;	Remove multiple files
; v1.1	(c) 2001 Paul Daniels <paul_d@sourceforge.net>
;	Added -i for interactive mode
		
#include <system.h>
#include <kerrors.h>
#include <stdio.h>

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

ARGS	equ userzp
ARGC	equ userzp+2

; get more zero page

		lda #3
		jsr lkf_set_zpsize

; Process cmd lines options

		ldx ARGS
		stx ARGC
		ldy #0
		sty ARGS
		sty filflg+1

skip_param:
		inc ARGS
		lda (ARGS),y
		bne skip_param

; Loop thro' arguments

loop:
		inc ARGS		; Skip null
		dec ARGC
		beq finished	; more args?
		ldy #0			; No
		lda (ARGS),y
		cmp #"-"		; Switch?
		bne rm_file		; no
	-	inc ARGS
		lda (ARGS),y	; more switches?
		beq loop		; no
		cmp #"i"
		bne HowTo
		lda #1
		sta intflg+1
		bne -
finished:
filflg:
		lda #0			; Self modified
		beq HowTo

		lda #0
		rts
rm_file:
		lda #1
		sta filflg+1
intflg:
		lda #0
		beq rm_file2	; interactive?
		ldy #0
	-	lda (ARGS),y
		beq +
		sec
		ldx #stdout
		jsr fputc
		iny
		bne -
	+	lda #"?"
		sec
		ldx #stdout
		jsr fputc
		lda #" "
		sec
		ldx #stdout
		jsr fputc
		sec
		ldx #stdin
		jsr fgetc
		nop
		sta tmpa+1
		lda #$0a
		sec
		ldx #stdout
		jsr fputc
tmpa:
		lda #0		; Self modify
		cmp #"y"
		bne +

rm_file2:
		lda ARGS
		ldy ARGS+1
		ldx #fcmd_del
		jsr fcmd
		nop				; exit on error
	+	ldy #0
		jmp skip_param

HowTo:
		ldx  #stderr
		bit  howto_txt
		jsr  lkf_strout
		lda  #1
		rts				; exit(1)
		
		.byte $02				; End Of Code - marker !
		
howto_txt:
		.text "Usage: rm [-i] file ..."
		.byte $0a,$00
		
end_of_code:
