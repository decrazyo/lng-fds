;;; uudecode for LNG
;;; base on version for LUnix 0.compatible

;;;  with GNU shareutils 4.2  (uudecode for UNIX)
;;;  uu and base64 decoding !

#include <system.h>
#include <kerrors.h>
#include <stdio.h>

#define LINE_LEN_MAX 100
		
		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		;; main
decode:  
		lda  userzp
		cmp  #1
		beq  +

		;; HowTo
		ldx  #stdout
		bit  how_to_txt
		jsr  lkf_strout
		lda  #1
		rts						; exit(1)
		
	+	ldx  userzp+1
		jsr  lkf_pfree

		;; search for line beginning with "begin"
		
		lda  #0
		sta  last_data
		sta  hlp
		jsr  read_line
		bcc  +
		lda  #0
		rts						; exit(0)
	+	ldx  #5

	-	lda  line,x
		cmp  begin_txt,x
		bne  _chk_next
		dex
		bpl  -

		; found "begin " (uu-encoded) !
		ldx  #6
_begfound:
	-	lda  line,x
		beq  decode
		inx
		cmp  #$20				; scan for " "
		bne  -

		stx  tmp				; print found <name>
		ldx  #stdout
		bit  found_txt
		jsr  lkf_strout
		nop

		ldy  tmp
	-	lda  line,y
		cmp  #$21
		bcc  +
		jsr  putc
		iny
		bne  -
	+	lda  #$0a
		jsr  putc
		lda  #0
	-	sta  line,y

		;; open file for writing
		clc
		lda  tmp
		adc  #<line
		ldy  [-]+2				; #>line
		bcc  +
		iny
	+	ldx  #fmode_wo
		jsr  fopen
		nop
		stx  outfd

		;; jump to decoding routine
		bit  hlp
		bmi  +
		jmp  read_uu
	+	jmp  read_base64

_chk_next:
		ldx  #12

	-	lda  line,x
		cmp  begin64_txt,x
		bne  +
		dex
		bpl  -

		; found "begin-base64 "

		dec  hlp
		ldx  #13
		jmp  _begfound

	+	jmp  decode

		;; read line from stdin
read_line:
		ldy  #0
	-	sec
		ldx  #stdin
		jsr  fgetc
		bcs  _gerror
		cmp  #10
		beq  +
		cmp  #13
		beq  +
		sta  line,y
		iny
		cpy  #LINE_LEN_MAX-1
		bne  -

		ldx  #stderr
		bit  line_too_long
		jsr  lkf_strout
		lda  #1
		jmp  lkf_suicide

	+	cpy  #0
		beq  -					; ignore empty lines
		
	-	lda  #0
		sta  line,y				; terminate line with $00
		clc
		rts

_gerror:
		cmp  #lerr_eof
		bne  +
		cpy  #0
		bne  -
		sec
		rts
	+	jmp  lkf_suicerrout	

		; decode single char
dec_char:
		sec
		sbc  #$20
		and  #$3f
		rts

	-	ldx  #stderr
		bit  short_file
		jsr  lkf_strout
		lda  #1
		rts

;
; uu-decoding
;

read_uu:
		jsr  read_line
		bcs  -

		ldy  #1
		sty  tmp2
		lda  line
		jsr  dec_char
		sta  n
		bne  +

		jmp  uu_end

		; n is >= 1 !

	+ -	ldy  tmp2
		lda  line,y
		jsr  dec_char
		asl  a
		asl  a
		sta  tmp
		lda  line+1,y
		jsr  dec_char
		sta  hlp
		lsr  a
		lsr  a
		lsr  a
		lsr  a
		ora  tmp
		jsr  writebyte
		lda  n
		cmp  #2
		bcc  +		     ; skip if n<2
		lda  hlp
		asl  a
		asl  a
		asl  a
		asl  a
		sta  tmp
		ldx  tmp2
		lda  line+2,y
		jsr  dec_char
		sta  hlp
		lsr  a
		lsr  a
		ora  tmp
		jsr  writebyte
		lda  n
		cmp  #3
		bcc  +		     ; skip if n<3
		lda  hlp
		lsr  a
		ror  a
		ror  a
		and  #$c0
		sta  tmp
		ldx  tmp2
		lda  line+3,y
		jsr  dec_char
		ora  tmp
		jsr  writebyte
		
	+	clc
		lda  tmp2
		adc  #4
		sta  tmp2
		sec
		lda  n
		sbc  #3
		sta  n
		bmi  +
		bne  -

	+	jmp  read_uu

uu_end:  
		jsr  read_line
		bcs  +
		lda  line
		cmp  #101
		bne  +
		lda  line+1
		cmp  #110
		bne  +
		lda  line+2
		cmp  #100
		bne  +
		lda  line+3
		bne  +
		lda  #0
		rts

	+	ldx  #stderr
		bit  missing_end
		jsr  lkf_strout
		lda  #1
		rts

;
; base64 decoding
;

	-	ldx  #stderr
		bit  short_file
		jsr  lkf_strout
		lda  #1
		rts

read_base64:
		jsr  read_line
		bcs  -

		lda  #0
		sta  tmp2
		ldx  #3
		lda  #"="

	-	cmp  line,x
		bne  +
		dex
		bpl  -

		lda  #0
		rts

	+	bit  last_data
		bpl  rd_b64

		ldx  #stderr
		bit  base64_error
		jsr  lkf_strout
		lda  #1
		rts

rd_b64:	ldx  tmp2
		lda  line,x
		beq  read_base64

	-	ldy  line,x
		lda  base64tab,y
		and  #$40
		beq  +

		tya
		beq  +
		inx
		cmp  #"="
		bne  -

	+	tya
		beq  read_base64

		lda  base64tab,y
		sta  c1
		inx

	-	ldy  line,x
		lda  base64tab,y
		and  #$40
		beq  +

		tya
		beq  b64_illline
		inx
		cmp  #"="
		bne  -

b64_illline:
		ldx  #stderr
		bit  illegal_line
		jsr  lkf_strout
		lda  #1
		rts

	+	lda  base64tab,y
		sta  c2
		inx
		
	-	ldy  line,x
		lda  base64tab,y
		cmp  #$7f
		bne  +

		inx
		tya
		bne  -
		beq  b64_illline

	+	cpy  #"="
		bne  +

		stx  tmp2
		lda  c1
		asl  a
		asl  a
		sta  tmp
		lda  c2
		lsr  a
		lsr  a
		lsr  a
		lsr  a
		ora  tmp
		dec  last_data
		jsr  writebyte
		jmp  read_base64

	+	lda  base64tab,y
		sta  c3
		inx
		
	-	ldy  line,x
		lda  base64tab,y
		cmp  #$7f
		bne  +

		tya
		bne  -
		beq  b64_illline

	+	stx  tmp2
		lda  c1
		asl  a
		asl  a
		sta  tmp
		lda  c2
		lsr  a
		lsr  a
		lsr  a
		lsr  a
		ora  tmp
		jsr  writebyte
		lda  c2
		asl  a
		asl  a
		asl  a
		asl  a
		sta  tmp
		lda  c3
		lsr  a
		lsr  a
		ora  tmp
		jsr  writebyte
		ldx  tmp2
		ldy  line,x
		cpy  #"="
		bne  +

		dec  last_data
		jmp  read_base64

	+	lda  c3
		lsr  a
		ror  a
		ror  a
		and  #$c0
		inc  tmp2
		ora  base64tab,y
		jsr  writebyte
		jmp  rd_b64
		
;
; ********************************************
;


writebyte:
		sec
		stx  userzp
		ldx  outfd
		jsr  fputc
		nop
		ldx  userzp
		rts

putc:	
		sec
		ldx  #stdout
		jsr  fputc
		nop
		rts
						
		RELO_END ; no more code to relocate

		;base 64 table

base64tab:
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; 00-07
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; 08-0f
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; 10-17
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; 18-1f
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; 20-27
		.byte $7f, $7f, $7f, $3e, $7f, $7f, $7f, $3f ; 28-2f
		.byte $34, $35, $36, $37, $38, $39, $3a, $3b ; 30-37
		.byte $3c, $3d, $7f, $7f, $7f, $40, $7f, $7f ; 38-3f
		.byte $7f, $00, $01, $02, $03, $04, $05, $06 ; 40-47
		.byte $07, $08, $09, $0a, $0b, $0c, $0d, $0e ; 48-4f
		.byte $0f, $10, $11, $12, $13, $14, $15, $16 ; 50-57
		.byte $17, $18, $19, $7f, $7f, $7f, $7f, $7f ; 58-5f
		.byte $7f, $1a, $1b, $1c, $1d, $1e, $1f, $20 ; 60-67
		.byte $21, $22, $23, $24, $25, $26, $27, $28 ; 68-6f
		.byte $29, $2a, $2b, $2c, $2d, $2e, $2f, $30 ; 70-77
		.byte $31, $32, $33, $7f, $7f, $7f, $7f, $7f ; 78-7f
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; 80-87
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; 88-8f
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; 90-97
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; 98-9f
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; a0-a7
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; a8-af
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; b0-b7
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; b8-bf
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; c0-c7
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; c8-cf
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; d0-d7
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; d8-df
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; e0-e7
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; e8-ef
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; f0-f7
		.byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f ; f8-ff

line_too_long:
		.text "Line too long" : .byte $0a,$00

missing_end:
		.text "No 'end' line" : .byte $0a,$00

short_file:
		.text "Short file" : .byte $0a,$00

illegal_line:
		.text "Illegal line" : .byte $0a,$00

found_txt:
		.text "Decoding " : .byte $00

begin_txt:
		.byte $62, $65, $67, $69, $6e, $20

begin64_txt:
		.byte $62, $65, $67, $69, $6e
		.byte $2d, $62, $61, $73, $65
		.byte $36, $34, $20

base64_error:
		.text "data following '=' padding character"
		.byte $0a,$00

how_to_txt:
		.text "Usage: uudecode" : .byte $0a
		.text "  Decode a file created with uuencode." : .byte $0a
		.text "  Input is stdin" : .byte $0a,$00

n:		.buf 1  ; number of bytes per line
tmp:	.buf 1
tmp2:	.buf 1
hlp:	.buf 1

c1:		.buf 1 ; 3 * char for bas64 decoding
c2:		.buf 1
c3:		.buf 1 

last_data:		.buf 1
outfd:			.buf 1
line:     .buf LINE_LEN_MAX ; linebuffer
		
end_of_code:	
