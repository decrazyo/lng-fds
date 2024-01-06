; cat [-etv] [file] ...
;	Concatenate files to stdout

; v1.0	(c) 1999 Piotr Roszatycki <dexter@fnet.pl>
;		Initial release. Handles one file.
; v1.1 (c) 2001 Paul Daniels <paul_d@sourceforge.net>
;		Added support for multiple files
;		Added -e to show newline as a dollar ($)
;		Added -t to show tabs as ^I
;		Added -v to show non printables.
		
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
tmpa	equ userzp+3
fh		equ userzp+4

LINEMAX	equ	80

; Get more zero page

		lda #5
		jsr lkf_set_zpsize

; Get terminal width, console doesn't autoscroll yet

		ldy  #tsp_termwx
		lda  (lk_tsp),y		; get terminal width
		cmp  #LINEMAX+1
		bcc  +
		lda  #LINEMAX		; (upper limit)
	+	sta  linelen+1

; Process cmd line options

		ldx ARGS
		stx ARGC
		ldy #0
		sty ARGS
		sty filflg+1

	-	inc ARGS		; Skip cmd name
		lda (ARGS),y
		bne -

; Loop thro arguments

loop:
		inc ARGS		; Skip null
		dec ARGC
		beq finished
		ldy #0
		lda (ARGS),y
		cmp #"-"
		bne disp_file	; switch?
	-	inc ARGS		; yes
		lda (ARGS),y
		beq loop		; no more switches
		cmp #"e"
		bne +			; -e?
		lda #1			; yes
		sta show_end+1
		bne -
	+	cmp #"t"
		bne +			; -t?
		lda #1			; yes
		sta show_tab+1
		bne -
	+	cmp #"v"
		bne show_usage	; -v?
		lda #1			; yes
		sta show_ctrl+1
		bne -
finished:
filflg:
		lda #00			; Self modified
		bne +			; Any files cat'ed?
		lda #stdin		; No
		sta fh
		jsr disp_fh

	+	lda #0			; return (0);
		rts

show_usage:
		ldx #stderr
		bit usage
		jsr lkf_strout
		nop				; exit on error
		lda #1			; return (1);
		rts

disp_file:
		lda #1
		sta filflg+1
		lda ARGS
		ldy ARGS+1
		sec
		ldx #fmode_ro
		jsr fopen		; open file
		nop				; exit on error
		stx fh
		ldy #0
	-	inc ARGS		; Skip filename
		lda (ARGS),y
		bne -
		jsr disp_fh
		jmp loop
	
disp_fh:
		lda #0			; Column
		sta column+1
next:
		sec
		ldx fh
		jsr fgetc
		bcs got_err

		; Check for set flags and handle them here

		sta tmpa
show_end:
		lda #0			; Self modified
		beq show_tab
		lda tmpa
		cmp #$0a
		bne show_tab
		lda #"$"
		jsr disp_char
		lda #$0a
		jsr disp_char
		jmp next
show_tab:
		lda #0			; Self modified
		beq show_ctrl
		lda tmpa
		cmp #$09
		bne show_ctrl
		lda #"^"
		jsr disp_char
		lda #"I"
		jsr disp_char
		jmp next
show_ctrl:
		lda #0			; Self modified
		beq prn_char
		lda tmpa
		bpl +			; Bit 7 set
		and #$7f		; yes
		sta tmpa
		lda #"M"
		jsr disp_char
		lda #"-"
		jsr disp_char
	+	lda tmpa
		cmp #32			;
		bcs +			; char >= 32?
		lda #"^"		; no
		jsr disp_char
		lda tmpa
		clc
		adc #64
	+	jsr disp_char
		jmp next

prn_char:
		lda tmpa
		jsr disp_char
		jmp next
got_err:
		cmp #lerr_eof
		beq +
		jmp lkf_suicerrout
	+	ldx fh
		jsr fclose
		nop
		rts

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
linelen:
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
		.text "Usage: cat [-etv] [file] ..."
		.byte $0a,$00
		
end_of_code:
