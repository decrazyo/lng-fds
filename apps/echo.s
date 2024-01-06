; echo [-nE] string
;	Print string to stdout

; v1.0	(c) 2001 Paul Daniels <paul_d@sourceforge.net>
;		-n no linefeed added
;		-E ignore ^ sequences
;		^000 - octal	^a - alert			^c - no trailing newline
;		^f - formfeed	^n - newline		^r - carriage return

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
TMPA	equ userzp+3
LINCNT	equ userzp+4
OCTAL	equ userzp+5

SCRNWID	equ 80
SCRNLEN equ 24

; Get more zero page

		lda #6
		jsr lkf_set_zpsize

; Get terminal width

		ldy  #tsp_termwx
		lda  (lk_tsp),y		; get terminal width
		cmp  #SCRNWID+1
		bcc  +
		lda  #SCRNWID		; (upper limit)
	+	sta  scrnwid+1

; Get terminal height

		ldy  #tsp_termwy
		lda  (lk_tsp),y		; get terminal height
		cmp  #SCRNLEN+1
		bcc  +
		lda  #SCRNLEN		; (upper limit)
	+	sta  scrnlen+1

; Process cmd line options

		ldx ARGS
		stx ARGC
		ldy #0
		sty ARGS

	-	inc ARGS		; Skip cmd name
		lda (ARGS),y
		bne -

; Init print column

		lda #0
		sta column+1

; Loop thro arguments

loop:
		inc ARGS		; Skip null
		dec ARGC
		beq finished
		ldy #0
		lda (ARGS),y
		cmp #"-"
		bne disp_args	; switch?
	-	inc ARGS		; yes
		lda (ARGS),y
		beq loop		; no more switches
		cmp #"n"
		bne +			; -n?
		lda #1			; yes
		sta disp_cr+1
		bne -
	+	cmp #"E"
		bne show_usage	; -E?
		lda #1			; yes
		sta proc_slsh+1
		bne -
finished:
disp_cr:
		lda #0			; self modified
		bne +
		lda #$0a
		jsr disp_char
	+	lda #0			; return (0);
		rts

show_usage:
		ldx #stderr
		bit usage
		jsr lkf_strout
		nop				; exit on error
		lda #1			; return (1);
		rts

disp_args:
		sta TMPA
proc_slsh:
		lda #0			; self modified
		bne doit
		lda TMPA
		cmp #"^"
		bne doit
		inc ARGS
		ldy #0
		sty OCTAL
		lda (ARGS),y
		beq finished
		sta TMPA
		cmp #"^"
		beq doit
		cmp #"a"		; alert
		bne +
		lda #7
		sta TMPA
		bne doit
	+	cmp #"c"		; no trailing lf
		bne +
		lda #1
		sta disp_cr+1
		bne next
	+	cmp #"n"		; newline
		bne +
		lda #$0a
		sta TMPA
		bne doit
	+	cmp #"r"		; carriage return
		bne +
		lda #$0d
		sta TMPA
		bne doit
	+	cmp #"f"		; formfeed
		bne +
scrnlen:
		lda #0			; Self modified
		sta LINCNT
	-	lda #$0a
		jsr disp_char
		dec LINCNT
		bne -
		beq next
	+	cmp #"0"		; Octal
		bcc doit
		cmp #"8"
		bcs doit
		jmp read_oct

doit:	lda TMPA
		jsr disp_char
next:
		inc ARGS
		ldy #0
		lda (ARGS),y
		bne disp_args
		jmp finished

read_oct:
	-	asl OCTAL		; Multiply number by 8
		asl OCTAL
		asl OCTAL
		and #7			; Convert digit
		ora OCTAL		; Add to running total
		sta OCTAL
		inc ARGS
		ldy #0
		lda (ARGS),y
		cmp #"0"
		bcc +
		cmp #"8"
		bcc -
	+	sta TMPA
		lda OCTAL
		jsr disp_char
		jmp proc_slsh

disp_char:
		cmp #$0a		; Displaying a linefeed?
		bne +
		ldx #$ff		; Yes, reset column count
		stx column+1
	+	sec				; Output char
		ldx #stdout
		jsr fputc
		inc column+1	; Next char on last column?
column:
		lda #00			; Self modified
scrnwid:
		cmp #0			; Self modified
		bne +
		lda #$0a		; Yes, move to next column
		sec					 
		ldx #stdout
		jsr fputc
		lda #0
		sta column+1
	+	rts

		.byte $02		; End Of Code - marker !

usage:
		.text "Usage: echo [-nE] [string]"
		.byte $0a,$00
		
end_of_code:
