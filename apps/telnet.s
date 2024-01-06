		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; TCP/IP application
		;; simple telnet client (and test server)

#include <stdio.h>
#include <ipv4.h>
#include <kerrors.h>
						
		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		jmp  initialize


; read decimal

read_decimal:
		lda  #0
		sta  userzp+2

	-	lda  (userzp),y
		sec
		sbc  #"0"
		bcc  ++
		cmp  #10
		bcs  ++
		sta  userzp+3
		lda  userzp+2
		cmp  #26
		bcs  +
		asl  a
		asl  a
		adc  userzp+2
		asl  a
		sta  userzp+2
		adc  userzp+3
		bcs  +
		sta  userzp+2
		iny
		bne  -
	+	sec
		rts

	+	lda  userzp+2
		clc
		rts

		;;
		
	-	ldx  #stderr
		bit  txt_howto
		jsr  lkf_strout
		lda  #1
		jmp  lkf_suicide			; exit(1)

; read IP address from commandline

read_IPnPort:
		lda  #0
		sta  passive_flag		; default is to open socket actively
		
		lda  userzp
		cmp  #3
		bne  -					; need exactly 2 arguments

		ldy  #0
		sty  userzp
	-	iny
		lda  (userzp),y
		bne  -
		iny

		lda  (userzp),y
		cmp  #"a"				; check for "*" passive mode flag
		bne  +					; not, then expect IP address of server
		iny
		lda  (userzp),y
		bne  err_syntax
		dec  passive_flag
		bmi  read_Port			; skip reading IP address of server

	+	jsr  read_decimal
		bcs  err_syntax
		sta  remote_ip
		ldx  #1

	-	lda  (userzp),y
		cmp  #"."
		bne  err_syntax
		iny
		beq  err_syntax
		jsr  read_decimal
		bcs  err_syntax
		sta  remote_ip,x
		inx
		cpx  #4
		bne  -

read_Port:		
		iny
		
		jsr  read_decimal
		bcs  err_syntax

		sta  remote_port
		lda  #0
		sta  remote_port+1

		rts

err_syntax:
		ldx  #stderr
		bit  txt_syntax
		jsr  lkf_strout
		lda  #1					; exit(1)
		jmp  lkf_suicide

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

print_ip:
		lda  remote_ip
		jsr  print_decimal
		ldx  #1

	-	stx  userzp
		lda  #"."
		jsr  putc
		ldx  userzp
		lda  remote_ip,x
		jsr  print_decimal
		ldx  userzp
		inx
		cpx  #4
		bne  -

		rts

		bit  ipv4_struct
initialize:
		lda  #4
		jsr  lkf_set_zpsize

		jsr  read_IPnPort

		ldx  userzp+1
		jsr  lkf_free

		; search for packet interface

		lda  #0
		ldx  #<ipv4_struct
		ldy  initialize-1		; #>ipv4_struct
		jsr  lkf_get_moduleif
		nop

		bit  passive_flag
		bmi  open_passively

		;; ok, try to connect		
		ldx  #stdout
		bit  txt_trying
		jsr  lkf_strout

		jsr  print_ip
		lda  #"."
		jsr  putc
		jsr  putc
		jsr  putc
		lda  #$0a
		jsr  putc

		ldx  #IPV4_TCP
		bit  ip_struct
		jsr  IPv4_connect
		bcc  +
	-	jmp  telnet_err

open_passively:
		clc						; (open)
		ldx  #IPV4_TCP			; (TCP)
		lda  remote_port		; (port number)
		ldy  remote_port+1
		jsr  IPv4_listen
		bcs  -
		
		ldx  #stdout
		bit  txt_listening
		jsr  lkf_strout
		lda  remote_port
		jsr  print_decimal
		lda  #$0a
		jsr  putc
		
		sec						; (blocking)
		lda  remote_port		; (port number)
		ldy  remote_port+1
		jsr  IPv4_accept
		bcs  -
		
	+	stx  tcp_fd_read
		sty  tcp_fd_write

		ldx  #stdout
		bit  txt_conn
		jsr  lkf_strout
		
		jsr  print_ip
		lda  #"."
		jsr  putc
		lda  #$0a
		jsr  putc

main_loop:
		ldx  tcp_fd_read
		clc						; non blocking
		jsr  fgetc
		bcc  +
		cmp  #lerr_tryagain
		bne  rem_closed
		beq  +++
	+	bit  iacflag
		bmi  is_iac
		cmp  #$ff
		bne  +
		lda  #$80
		sta  iacflag
		bne  main_loop
	+	ldx  #stdout
		sec						; blocking
		jsr  fputc
		bcs  loc_closed
		bcc  main_loop

	+ -	ldx  #stdin
		clc						; non blocking
		jsr  fgetc
		bcc  +
		cmp  #lerr_tryagain
		bne  loc_closed
		beq  ++
	+	ldx  tcp_fd_write
		sec						; blocking
		jsr  fputc
		bcs  rem_closed
		bcc  -
		
	+	jsr  lkf_force_taskswitch
		jmp  main_loop

rem_closed:
		ldx  #stdout
		bit  txt_closed
		jsr  lkf_strout
loc_closed:
		ldx  tcp_fd_read
		jsr  fclose
		ldx  tcp_fd_write
		jsr  fclose
		jsr  IPv4_unlock
		lda  #0
		jmp  lkf_suicide

is_iac:
		bvs  +
		sta  chbuf
		lda  #$c0
		sta  iacflag
		jmp  main_loop

	+	tax
		lda  #0
		sta  iacflag
		lda  chbuf
		cmp  #$fd
		bne  main_loop

		; respond $ff $fc $xx to $ff $fd $xx

		txa
		pha
		lda  #$ff
		ldx  tcp_fd_write
		sec
		jsr  fputc
		lda  #$fc
		sec
		jsr  fputc
		pla
		sec
		jsr  fputc
		jmp  main_loop

telnet_err:
		pha
		ldx  #stderr
		bit  txt_unable
		jsr  lkf_strout
		pla

		cmp  #E_CONTIMEOUT
		bne  +
		ldx  #stderr
		bit  txt_E_CONTIMEOUT
		jsr  lkf_strout
		jmp  lkf_suicide
		+
		cmp  #E_CONREFUSED
		bne  +
		ldx  #stderr
		bit  txt_E_CONREFUSED
		jsr  lkf_strout
		jmp  lkf_suicide
		+
		cmp  #E_NOPERM
		bne  +
		ldx  #stderr
		bit  txt_E_NOPERM
		jsr  lkf_strout
		jmp  lkf_suicide
		+
		cmp  #E_NOPORT
		bne  +
		ldx  #stderr
		bit  txt_E_NOPORT
		jsr  lkf_strout
		jmp  lkf_suicide
		+
		cmp  #E_NOROUTE
		bne  +
		ldx  #stderr
		bit  txt_E_NOROUTE
		jsr  lkf_strout
		jmp  lkf_suicide
		+
		cmp  #E_NOSOCK
		bne  +
		ldx  #stderr
		bit  txt_E_NOSOCK
		jsr  lkf_strout
		jmp  lkf_suicide
		+
		cmp  #E_NOTIMP
		bne  +
		ldx  #stderr
		bit  txt_E_NOTIMP
		jsr  lkf_strout
		jmp  lkf_suicide
		+
		cmp  #E_PROT
		bne  +
		ldx  #stderr
		bit  txt_E_PROT
		jsr  lkf_strout
		jmp  lkf_suicide
		+
		cmp  #E_PORTINUSE
		bne  +
		ldx  #stderr
		bit  txt_E_PORTINUSE
		jsr  lkf_strout
		+
		jsr  IPv4_unlock
		jmp  lkf_suicide

.endofcode

		
tcp_fd_read:	.buf 1
tcp_fd_write:	.buf 1
passive_flag:	.buf 1			; set if, telnet should open socket as listener
		
ip_struct:
		.buf 8
remote_ip   equ ip_struct+0
remote_port equ ip_struct+4

dec_tab:
		.byte 10,100
iacflag:  .byte 0
chbuf:    .byte 0

ipv4_struct:
		IPv4_struct8			; defined in ipv4.h
		
txt_listening:
		.text "Listening on port ",0
txt_trying:
		.text "Trying ",0
txt_conn:
		.text "Connected to ",0
txt_E_CONTIMEOUT:
		.text "timeout error",$0a,0
txt_E_CONREFUSED:
		.text "connection refused",$0a,0
txt_E_NOPERM:
		.text "no permisson",$0a,0
txt_E_NOPORT:
		.text "no port",$0a,0
txt_E_NOROUTE:
		.text "no route to host",$0a,0
txt_E_NOSOCK:
		.text "no socket available",$0a,0
txt_E_NOTIMP:
		.text "not implemented",$0a,0
txt_E_PROT:
		.text "protocol error",$0a,0
txt_E_PORTINUSE:
		.text "port in use",$0a,0
txt_unable:
		.text "Unable to connect to remote host",$0a,"::",0
txt_howto:
		.text "usage:  telnet <IP> [<port>]",$0a
		.text "  IP internet address of remote",$0a
		.text "    host in digits.",$0a
		.text "  port port to connect to",$0a,0
txt_syntax:
		.text "syntax of",$0a
		.text "IP: <num>.<num>.<num>.<num>",$0a
		.text "port: <num>",$0a
		.text "each number in range 0..255",$0a,0
txt_closed:
		.text $0a,"Connection closed by foreign host.",$0a,0

end_of_code:
