;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		
#include <stdio.h>
#include <ipv4.h>
#include <kerrors.h>
						
		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		bit  ipv4_struct
initialize:		
		lda  #4
		jsr  lkf_set_zpsize

		lda  userzp
		cmp  #1
		beq  +

		ldx  #stdout
		bit  txt_howto
		jsr  lkf_strout
		lda  #1
		rts

	-	ldx  #stdout
		bit  txt_noinfo
		jsr  lkf_strout
		lda  #0
		rts	
		
	+	ldx  userzp+1
		jsr  lkf_free

		;; search for packet interface

		lda  #0
		ldx  #<ipv4_struct
		ldy  initialize-1		; #>ipv4_struct
		jsr  lkf_get_moduleif
		bcc  +

		cmp  #lerr_nosuchmodule
		beq  -
		jmp  lkf_suicerrout

		;; get info
		
		bit  tcpinfo_struct
	+	jsr  IPv4_tcpinfo
	-	bit  txt_info
		lda  #<txt_info	
		sta  userzp
		lda  [-]+2
		sta  userzp+1

		;; print info
		
ploop:	ldy  #0
		lda  (userzp),y
		beq  pend
		bmi  extra
		jsr  putc
		
pnext:	inc  userzp
		bne  ploop
		inc  userzp+1
		bne  ploop				; (always jump)

pend:	jsr  IPv4_unlock		; leave
		lda  #0
		rts						; exit(0)

extra:	cmp  #$80
		beq  print_ip
		cmp  #$82
		beq  print_word
		;; print_byte
		ldx  userzp+3
		lda  tcpinfo_struct,x
		jsr  print_decimal
		inc  userzp+3
		jmp  pnext

print_word:
		lda  tcpinfo_struct+9	; hi byte of no. of checksum errors
		beq  +
		jsr  print_decimal
		lda  #"/"
		jsr  putc
	+	lda  tcpinfo_struct+8
		jsr  print_decimal
		jmp  pnext
		
print_ip:
		lda  #4
		sta  userzp+3			; pointer to next bytes in tcpinfo structure
		
		lda  tcpinfo_struct
		jsr  print_decimal
		lda  #"."
		jsr  putc
		lda  tcpinfo_struct+1
		jsr  print_decimal
		lda  #"."
		jsr  putc
		lda  tcpinfo_struct+2
		jsr  print_decimal
		lda  #"."
		jsr  putc
		lda  tcpinfo_struct+3
		jsr  print_decimal

		jmp  pnext


; print decimal to stdout

print_decimal:
		ldx  #1
		ldy  #0

	-	cmp  dec_tab,x
		bcc  +
		sbc  dec_tab,x
		iny
		bne  -

	+	sta  userzp+2
		tya
		beq  +
		ora  #"0"
		jsr  putc
		ldy  #"0"
	+	lda  userzp+2
		dex
		bpl  -

		ora  #"0"
putc:	stx  [+]+1
		sec
		ldx  #stdout
		jsr  fputc
		nop
	+	ldx  #0
		rts

		.byte 2					; end of code
		
dec_tab:
		.byte 10,100
		
ipv4_struct:
		IPv4_struct9			; defined in ipv4.h
tcpinfo_struct:
		.buf IPV4_TCPINFOSIZE
		
txt_howto:
		.text "usage:  tcpipstat",$0a
		.text "  print status of tcpip-stack",$0a,0

txt_info:		
		.text "status of TCP/IP stack:",$0a
		.text "  IP address....... ",$80,$0a
		.text "  used sockets..... ",$81,$0a
		.text "  available sockets ",$81,$0a
		.text "  used buffers..... ",$81,$0a
		.text "  available buffers ",$81,$0a
		.text "  checksum errors.. ",$82,$0a,0

txt_noinfo:
		.text "no TCP/IP module found",$0a,0
		
end_of_code:
