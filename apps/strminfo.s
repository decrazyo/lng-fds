	;; for emacs: -*- MODE: asm; tab-width: 4; -*-
	;; strminfo - simple stream usage report
	
#include <system.h>
#include <stdio.h>

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION,	<LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		lda  #5
		jsr  lkf_set_zpsize

		lda  userzp+1			; use argument page
		bne  +
		lda  #1					; allocate one, if none
		jsr  lkf_palloc
		nop
		stx  userzp+1
		
	+	ldx  #stdout
		bit  text
		jsr  lkf_strout
		nop

		lda  #1
		sta  userzp+1			; (first 8 smbs are not available)
		lda  #0
		sta  userzp+2
		
	-	lda  #%00000001
		sta  userzp

	-	ldx  userzp+1
		lda  lk_smbmap,x
		and  userzp
		bne  +

		lda  lk_smbpage,x
		sta  userzp+3
		jsr  print_space
		ldy  #fsmb_major
		lda  (userzp+2),y		; Major
		pha
		jsr  print_decimal
		jsr  print_space
		ldy  #fsmb_minor
		lda  (userzp+2),y		; Minor
		jsr  print_decimal
		jsr  print_space
		ldy  #fsmb_wrcnt
		lda  (userzp+2),y		; number of writing ends
		jsr  print_decimal
		jsr  print_space
		ldy  #fsmb_rdcnt
		lda  (userzp+2),y		; number of reading ends
		jsr  print_decimal
		pla		
		jsr  print_explanation
		lda  #$0a
		jsr  putc
		
	+	asl  userzp
		clc
		lda  userzp+2
		adc  #$20
		sta  userzp+2
		bcc  -
		inc  userzp+1
		lda  userzp+1
		cmp  #$20
		bcc  --		
		
		lda  #0
		rts
		
print_explanation:
		cmp  #MAJOR_PIPE
		beq  p_pipe
		cmp  #MAJOR_IEC
		beq  p_iec
		cmp  #MAJOR_CONSOLE
		beq  p_console
		cmp  #MAJOR_USER
		beq  p_user
		cmp  #MAJOR_IDE64
		beq  p_ide64
		cmp  #MAJOR_SYS
		beq  p_sys
		rts						; (unknown)
		
p_pipe:	
		ldy  #o_pipe
		SKIP_WORD
p_iec:	
		ldy  #o_iec
		SKIP_WORD
p_console:
		ldy  #o_console
		SKIP_WORD
p_user:	
		ldy  #o_user
		SKIP_WORD
p_ide64:
		ldy  #o_ide64
		SKIP_WORD
p_sys:
		ldy  #o_sys
	-	lda  txt_misc,y
		beq  +
		jsr  putc
		iny
		bne  -
	+	rts
		
print_decimal:
		ldx  #0
	-	cmp  #100
		bcc  +
		sbc  #100
		inx
		bne  -
	+	pha
		jsr  xout
		pla
	-	cmp  #10
		bcc  +
		sbc  #10
		inx
		bne  -
	+	pha
		jsr  xout
		pla
		jmp  +

xout:	txa
		beq  print_space
	+	ora  #"0"
putc:	sec
		ldx  #stdout
		jsr  fputc
		nop
		ldx  #0
		rts

print_space:
		lda  #" "
		jmp  putc

		RELO_END ; no more code to relocate
		
text:
		.text "summary of open streams",$0a
		.text " maj/min  wr/rd",$0a,0

txt_misc:
		o_pipe equ *-txt_misc
		.text " (pipe)",0
		o_iec equ *-txt_misc
		.text " (cbm)",0
		o_console equ *-txt_misc
		.text " (console)",0
		o_user equ *-txt_misc
		.text " (user)",0
		o_ide64 equ *-txt_misc
		.text " (ide64)",0
		o_sys equ *-txt_misc
		.text " (sys)",0

end_of_code:

