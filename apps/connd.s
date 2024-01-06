		;; connect-demon
		;; waits for a incoming TCP/IP connection on a given port
		;; starts an application
		
#include <stdio.h>
#include <ipv4.h>
#include <kerrors.h>
						
		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		;; set terminal width to vt100 standard 25x80
		ldy  #tsp_termwx
		lda  #80
		sta  (lk_tsp),y
		ldy  #tsp_termwy
		lda  #25
		sta  (lk_tsp),y
		
		;; get 4 bytes of zeropage
		lda  #4
		jsr  lkf_set_zpsize
		
		;; parse commandline
		lda  userzp
		cmp  #3
		bcs  +					; at least 3 args

		bit  wait_struct
		bit  ipv4_struct
HowTo:	ldx  #stdout
		bit  howto_txt
		jsr  lkf_strout
		lda  #1
		rts						; exit(1)

	+	ldy  #0
		sty  userzp
	-	iny
		lda  (userzp),y
		bne  -
		iny

		;; get port number to listen on
		jsr  read_decimal
		bcs  HowTo
		sta  listen_port
		lda  (userzp),y
		bne  HowTo
		iny
		lda  (userzp),y
		beq  HowTo

		;; setup fork-structure (using arguments directly)
		cpy  #3
		bcc  HowTo				; doesn't work if y<3
		dey		
		dey
		dey
		sty  userzp

		; search for packet interface
		lda  #0
		ldx  #<ipv4_struct
		ldy  HowTo-1			; #>ipv4_struct
		jsr  lkf_get_moduleif
		nop

		;; ok, try to listen
		clc						; (open)
		ldx  #IPV4_TCP			; (TCP)
		lda  listen_port
		ldy  #0					; (port number)
		jsr  IPv4_listen
		bcc  +

		jsr  print_tcpip_error
		jsr  IPv4_unlock
		lda  #2
		rts						; exit(2)		

		;; listening, waiting for connect
	+
		
loop:	
		sec						; (blocking)
		lda  listen_port
		ldy  #0
		jsr  IPv4_accept
		bcc  +

		jsr  print_tcpip_error
		jsr  IPv4_unlock
		lda  #3
		rts						; exit(2)		
		
		;; connected!
	+	stx  in_stream
		sty  out_stream
		
		;; invoke application
		tya						; write stream
		ldy  #2
		sta  (userzp),y
		dey
		sta  (userzp),y
		txa
		dey
		sta  (userzp),y
		
		lda  userzp
		ldy  userzp+1
		jsr  lkf_forkto
		nop

		ldx  in_stream
		jsr  fclose
		ldx  out_stream
		jsr  fclose
		
		ldx  #stdout
		bit  txt_start
		jsr  lkf_strout
		
		sec
		ldx  #<wait_struct
		ldy  HowTo-4			; #>wait_struct
		jsr  lkf_wait

		jmp  loop
		
print_tcpip_error:
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
		rts
		
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

.endofcode

listen_port:	.buf 1
in_stream:		.buf 1
out_stream:		.buf 1
		
ipv4_struct:	IPv4_struct8		; defined in ipv4.h
wait_struct:	.buf 7
				
txt_start:		.text "application spawnd",0
		
txt_E_CONTIMEOUT:	.text "timeout error",$0a,0
txt_E_CONREFUSED:	.text "connection refused",$0a,0
txt_E_NOPERM:		.text "no permisson",$0a,0
txt_E_NOPORT:		.text "no port",$0a,0
txt_E_NOROUTE:		.text "no route to host",$0a,0
txt_E_NOSOCK:		.text "no socket available",$0a,0
txt_E_NOTIMP:		.text "not implemented",$0a,0
txt_E_PROT:			.text "protocol error",$0a,0
txt_E_PORTINUSE:	.text "port in use",$0a,0
		
txt_unable:		.text "Unable to connect to remote host",$0a,"::",0
		
howto_txt:		.text "usage: connd port command",$0a
				.text "  port - TCP port to listen on",$0a
				.text "  command - application to start on connect",$0a,0
		
end_of_code:
