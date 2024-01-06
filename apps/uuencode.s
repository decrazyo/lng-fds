;;; uuencode for LNG
;;;
;;; based on the version for LUnix v0.1
		
;;; compatible with GNU shareutils 4.2  (uuencode for UNIX) 
;;; uu and base64 encoding !


#include <system.h>
#include <kerrors.h>
#include <stdio.h>

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		;; main

		lda  userzp
		cmp  #2					; usage:  uuencode [-m] <dst_name>
		bcc  HowTo
		
		ldy  #0
		sty  mode
		sty  userzp

	-	iny						; skip first parameter
		lda  (userzp),y
		bne  -

		;; look for "-m" option string
		
		iny
		lda  (userzp),y
		cmp  #"-"
		bne  +
		iny
		lda  (userzp),y
		cmp  #$6d	; "m"
		bne  HowTo
		dec  mode
		iny
		lda  (userzp),y
		bne  HowTo
		iny

		;; dest-name (name of file when decodeing)
		
	+	lda  (userzp),y
		sty  userzp
		bne  +

HowTo:
		ldx  #stdout
		bit  HowTo_txt
		jsr  lkf_strout
		nop
		lda  #1
		rts						; exit(1)
		
		;; print header
		
	+	ldx  #stdout
		bit  mode
		bmi  +
		bit  begin_txt			; "begin\0"
		jsr  lkf_strout
		nop
		jmp  ++
	+	bit  begin64_txt		; "begin-base64\0"
		jsr  lkf_strout
		nop
		
	+	ldx  #stdout			; "664"
		bit  mode_txt
		jsr  lkf_strout
		nop

		ldy  #0
	-	lda  (userzp),y
		beq  +
		jsr  putc
		iny
		bne  -
		
	-	jmp  HowTo

	+	iny
		lda  (userzp),y
		bne  -
		lda  #$0a
		jsr  putc

		;; free argument page (no longer needed)
		
		ldx  userzp+1
		jsr  lkf_pfree

		;; start encoding
		
		jsr  encode

		;; print tail
		
		ldx  #stdout
		bit  mode
		bmi  +
		bit  end_uu_txt
		jsr  lkf_strout
		nop
		lda  #0
		rts						; exit(0)

	+	bit  end_base64_txt
		jsr  lkf_strout
		nop
		lda  #0
		rts						; exit(0)

		;; encode single char (in X)
enc:	bit  mode
		bmi  +
		lda  uu_std,x
		rts
	+	lda  uu_base64,x
		rts

		
		;; encode until EOF

	-	cmp  #lerr_eof
		beq  +
		jmp  lkf_suicerrout		; exit with errormessage
		
encode:	ldy  #0					; read up to 45 bytes
	-	sec
		ldx  #stdin
		jsr  fgetc
		bcs  --
		sta  buf,y
		iny
		cpy  #45
		bne  -

	+	tya
		bne +
		jmp  enc_loopend
		
	+	sty  n
		bit  mode
		bmi  +

		lda  uu_std,y
		jsr  putc

	+	ldy  #0
		sty  tmp2

		lda  n
		cmp  #3
		bcc  skip_line
 
line_loop:		
		lda  buf,y
		lsr  a
		lsr  a
		tax
		jsr  enc
		jsr  putc
		lda  buf,y
		asl  a
		asl  a
		asl  a
		asl  a
		sta  tmp
		lda  buf+1,y
		lsr  a
		lsr  a
		lsr  a
		lsr  a
		and  #$0f
		ora  tmp
		and  #$3f
		tax
		jsr  enc
		jsr  putc
		lda  buf+1,y
		asl  a
		asl  a
		sta  tmp
		lda  buf+2,y
		asl  a
		rol  a
		rol  a
		and  #$03
		ora  tmp
		and  #$3f
		tax
		jsr  enc
		jsr  putc
		lda  buf+2,y
		and  #$3f
		tax
		jsr  enc
		jsr  putc
		iny
		iny
		iny
		sec
		lda  n
		sbc  #3
		sta  n
		cmp  #3
		bcs  line_loop

skip_line:
        cmp  #0
		bne  +
		lda  #$0a
		jsr  putc
		jmp  encode
		
	+	ldx  n
		beq  enc_loopend

		lda  buf,y
		sta  c1
		cpx  #1
		beq  +
		lda  buf+1,y
		SKIP_WORD
	+	lda  #0
		sta  c2

		lda  c1
		lsr  a
		lsr  a
		tax
		jsr  enc
		jsr  putc
		lda  c1
		asl  a
		asl  a
		asl  a
		asl  a
		sta  tmp
		lda  c2
		lsr  a
		lsr  a
		lsr  a
		lsr  a
		ora  tmp
		and  #$3f
		tax
		jsr  enc
		jsr  putc
		lda  n
		cmp  #1 
		bne  ++

		bit  mode
		bmi  +
		lda  uu_std
		SKIP_WORD
	+	lda  #"="
		jmp  ++

	+	lda  c2
		asl  a
		asl  a
		and  #$3f
		tax
		jsr  enc
	+	jsr  putc
		bit  mode
		bmi  +
		lda  uu_std
		SKIP_WORD
	+	lda  #"="
		jsr  putc
		lda  #$0a
		jsr  putc

enc_loopend:    
		bit  mode
		bmi  +

		lda  uu_std
		jsr  putc
		lda  #$0a
		jsr  putc
		
	+	rts

putc:	ldx  #stdout
		sec
		jsr  fputc
		nop
		rts

		RELO_END ; no more code to relocate

uu_std:
 .byte $60, $21, $22, $23, $24, $25, $26, $27
 .byte $28, $29, $2a, $2b, $2c, $2d, $2e, $2f
 .byte $30, $31, $32, $33, $34, $35, $36, $37
 .byte $38, $39, $3a, $3b, $3c, $3d, $3e, $3f
 .byte $40, $41, $42, $43, $44, $45, $46, $47
 .byte $48, $49, $4a, $4b, $4c, $4d, $4e, $4f
 .byte $50, $51, $52, $53, $54, $55, $56, $57
 .byte $58, $59, $5a, $5b, $5c, $5d, $5e, $5f

uu_base64:
 .byte $41, $42, $43, $44, $45, $46, $47, $48
 .byte $49, $4a, $4b, $4c, $4d, $4e, $4f, $50
 .byte $51, $52, $53, $54, $55, $56, $57, $58
 .byte $59, $5a, $61, $62, $63, $64, $65, $66
 .byte $67, $68, $69, $6a, $6b, $6c, $6d, $6e
 .byte $6f, $70, $71, $72, $73, $74, $75, $76
 .byte $77, $78, $79, $7a, $30, $31, $32, $33
 .byte $34, $35, $36, $37, $38, $39, $2b, $2f

HowTo_txt:
 .text "Usage: uuencode [-m] name_of_file" : .byte $0a
 .text "  Encode a binary file. Input is" : .byte $0a
 .text "  stdin, output is stdout." : .byte $0a,$0a
 .text "  -m use base64 encoding as of RFC1521" : .byte $0a,$00

begin_txt:
		.byte $62, $65, $67, $69, $6e, 0 ; "begin\0"

begin64_txt:
		.byte $62, $65, $67, $69, $6e    ; "begin-base64\0"
		.byte $2d, $62, $61, $73, $65
		.byte $36, $34, 0

mode_txt:
		.text " 664 "
		.byte 0

end_uu_txt:
		.byte 101,110,100,10,0	; "end\n\0"

end_base64_txt:
		.text "===="			; "====\n\0"
		.byte $0a,0

n:        .buf 1
mode:     .buf 1
tmp:      .buf 1
tmp2:     .buf 1
c1:       .buf 1
c2:       .buf 1
buf:      .buf 80

end_of_code:	
