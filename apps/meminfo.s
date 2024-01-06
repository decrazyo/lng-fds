	;; for emacs: -*- MODE: asm; tab-width: 4; -*-
	;; meminfo - simple memory usage report
	
#include <system.h>
#include <stdio.h>

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION,	<LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		lda  #3
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

		ldy  #0
		sty  userzp
		tya
		tax
	-	sta  (userzp),y
		iny
		bne  -	
		sei
	-	lda  lk_memown,x
		tay
		lda  (userzp),y
		clc
		adc  #1
		sta  (userzp),y
		inx
		bne  -
		cli

	-	ldy  #0
		lda  (userzp),y
		beq  +
		pha
		jsr  print_space
		jsr  print_space
		jsr  print_space
		lda  userzp
		jsr  print_decimal
		jsr  print_space
		pla
		jsr  print_decimal
		lda  userzp
		jsr  print_explanation
		lda  #$0a
		jsr  putc
	+	inc  userzp
		bne  -
		
		lda  #0
		rts
		
print_explanation:
		cmp  #$20
		bcc  p_task
		cmp  #memown_smb
		beq  p_smb
		cmp  #memown_cache
		beq  p_cache
		cmp  #memown_sys
		beq  p_sys
		cmp  #memown_modul
		beq  p_modul
		cmp  #memown_scr
		beq  p_scr
		cmp  #memown_netbuf
		beq  p_netbuf
		cmp  #memown_none
		beq  p_none
		rts						; (unknown)
		
p_task:	
		ldy  #o_task
		SKIP_WORD
p_smb:	
		ldy  #o_smb
		SKIP_WORD
p_cache:
		ldy  #o_cache
		SKIP_WORD
p_sys:	
		ldy  #o_sys
		SKIP_WORD
p_modul:
		ldy  #o_modul
		SKIP_WORD
p_scr:	
		ldy  #o_scr
		SKIP_WORD
p_netbuf:	
		ldy  #o_netbuf
		SKIP_WORD
p_none:
		ldy  #o_none
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
		.text "memory usage (internal pages)",$0a
		.text " owner,pages",$0a,0

txt_misc:
		o_task equ *-txt_misc
		.text " (task)",0
		o_smb equ *-txt_misc
		.text " (smb)",0
		o_cache equ *-txt_misc
		.text " (cache)",0
		o_sys equ *-txt_misc
		.text " (sys)",0
		o_modul equ *-txt_misc
		.text " (module)",0
		o_scr equ *-txt_misc
		.text " (screen)",0
		o_netbuf equ *-txt_misc
		.text " (netbuf)",0
		o_none equ *-txt_misc
		.text " (free)",0

end_of_code: