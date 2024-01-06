		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; simple ftp client

#define DEBUG
		
#include <stdio.h>
#include <ipv4.h>
#include <kerrors.h>
#include <debug.h>

		;; BUFLEN must be larger than IPV4_TCPINFOSIZE!
#define BUFLEN 80

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		lda  #4
		jsr  lkf_set_zpsize

		;; parse commandline
		lda  userzp
		cmp  #2
		beq  +					; exactly 2 args

		bit  ipv4_struct
HowTo:	ldx  #stdout
		bit  howto_txt
		jsr  lkf_strout
		lda  #1
		jmp  lkf_suicide		; exit(1)

	+	ldy  #0
		sty  userzp
	-	iny
		lda  (userzp),y
		bne  -
		iny

		;; get ip of remote host
		jsr  read_dec_n_dot
		sta  remote_ip
		jsr  read_dec_n_dot
		sta  remote_ip+1
		jsr  read_dec_n_dot
		sta  remote_ip+2
		jsr  read_decimal
		bcs  HowTo
		sta  remote_ip+3
		lda  (userzp),y
		bne  HowTo
		iny
		lda  (userzp),y
		bne  HowTo

		ldx  userzp+1			; free memory
		jsr  lkf_free

		; search for packet interface
		lda  #0
		ldx  #<ipv4_struct
		ldy  HowTo-1			; #>ipv4_struct
		jsr  lkf_get_moduleif
		nop

		;; insert ownip into port command string

		bit  linebuf			; (linebuf is bigger than required!?)
		jsr  IPv4_tcpinfo
		ldy  #5
		lda  linebuf
		jsr  put_decimal
		iny						; (skip dot)
		lda  linebuf+1
		jsr  put_decimal
		iny						; (skip dot)
		lda  linebuf+2
		jsr  put_decimal
		iny						; (skip dot)
		lda  linebuf+3
		jsr  put_decimal

		;; ok, try to connect
		ldx  #stdout
		bit  txt_trying
		jsr  lkf_strout

		ldx  #IPV4_TCP
		bit  ip_struct
		jsr  IPv4_connect
		bcc  +
		jsr  print_tcpip_error
		jsr  IPv4_unlock
exit1:	
		lda  #1
		jmp  lkf_suicide		; exit(1)

	+	stx  tcp_fd_read
		sty  tcp_fd_write
		
		ldx  #stdout
		bit  txt_conn
		jsr  lkf_strout

		jsr  read_server_feedback
		bcs  exit1
		
		;; username
		ldx  #stdout
		bit  txt_username
		jsr  lkf_strout
		ldx  tcp_fd_write
		bit  ntxt_user
		jsr  lkf_strout
		lda  #$80
		sta  echo_flag			; need echo
		jsr  netpass
		jsr  read_server_feedback ; (ftp_respcode should be 331)
		bcs  exit1
		
		;; password
		ldx  #stdout
		bit  txt_password
		jsr  lkf_strout
		ldx  tcp_fd_write
		bit  ntxt_pass
		jsr  lkf_strout
		lda  #$0
		sta  echo_flag			; no echo
		jsr  netpass
		jsr  read_server_feedback
		bcs  exit1

		;; main command-loop
mainloop:
		ldx  #stdout
		bit  ftp_prompt_txt
		jsr  lkf_strout
		jsr  readline
		cpy  #0
		beq  mainloop			; ignore empty lines
		ldy  #0
		SKIP_BYTE
	-	iny						; skip trailing spaces
		lda  linebuf,y
		cmp  #" "
		beq  -
		cmp  #0
		beq  mainloop			; ignore space-lines
		sty  userzp+2			; remember start of command string

		jsr  do_internal		; internal command ?
		bcc  mainloop

		ldx  tcp_fd_write		; unknown command, pass it to server
		bit  linebuf
		jsr  lkf_strout
		lda  #13
		jsr  netputc
		lda  #10
		jsr  netputc
		jsr  read_server_feedback
		jmp  mainloop

		;; search for local (client) keywords
do_internal:
		ldx  #0
		
	-	ldy  userzp+2

	-	lda  intcmdlist,x
		bmi  ++
		cmp  linebuf,y
		bne  +
		iny
		inx
		bne  -					; (always jump)

	+ -	inx
		lda  intcmdlist,x
		bpl  -
		inx
		lda  intcmdlist,x
		bne  ---
		sec
		rts						; (is no internal command)

	-	iny
	+	lda  linebuf,y
		cmp  #" "
		beq  -					; skip spaces
		sty  userzp+2

		lda  intcmdlist,x
		cmp  #$80
		beq  intcommand_dir
		cmp  #$81
		beq  intcommand_cd
		cmp  #$82
		beq  intcommand_get
		cmp  #$83
		beq  intcommand_more
		
		sec						; (internal error)
		rts						; unknown command code

syntax_error:
		ldx  #stdout
		bit  synerror_txt
		jsr  lkf_strout
		clc
		rts
		
		;; internal commands

intcommand_dir:
		lda  linebuf,y
		bne  syntax_error		; (no further arguments allowed)
		lda  #$80
	-	ldx  #stdout
	-	sta  list_flag
		stx  data_stream
		jsr  read_server_data
		clc
		rts

intcommand_more:
		lda  linebuf,y
		beq  syntax_error
		lda  #0
		beq  --					; (always jump)

intcommand_get:
		lda  linebuf,y
		beq  syntax_error
		clc
		lda  userzp+2
		adc  #<linebuf
		ldy  intcommand_get+2	; #>linebuf
		bcc  +
		iny
	+	ldx  #fmode_wo
		jsr  fopen
		bcc  +
		jsr  lkf_print_error
		clc
		rts
	+	lda  #0
		beq  -					; (always jump)
		
intcommand_cd:
		lda  linebuf,y
		beq  syntax_error
		ldx  tcp_fd_write
		bit  ntxt_cwd
		jsr  lkf_strout
		nop
		jsr  netput_restoline
		jsr  read_server_feedback
		clc
		rts
		
		;; start listening to local port (16448 = $4040)
		;; and pass incoming data to data_stream
		;; (either "list" or "retr ...")

read_server_data:
		ldy  #tsp_termwx
		lda  (lk_tsp),y			; width of terminal
		sta  cxpos				; no of charts before inserting newline
		
		clc
		ldx  #IPV4_TCP
		lda  #64
		ldy  #64
		jsr  IPv4_listen
		bcc  +

		jsr  print_tcpip_error
		jmp  exit1

	+	stx  listen_port
		
		;; ownip has already been inserted into port command string
		
		ldx  tcp_fd_write
		bit  ntxt_port			; send "port..."
		jsr  lkf_strout
		jsr  read_server_feedback
		bcs  +

		jsr  rsd_putinit
		jsr  read_server_feedback
		bcc  ++
		
	+	jmp  end_listen

	+	sec
		lda  #64
		ldy  #64
		bit  ip_struct
		jsr  IPv4_accept
		bcc  +
		
		jsr  print_tcpip_error
		jmp  exit1
		
	+	stx  userzp+1
		tya
		tax
		jsr  fclose

		;; prepare transfer

		lda  data_stream
		cmp  #stdout
		bne  +					; transfer without buffering

	-	jmp  oloop
		
	+	ldy  #0
		sty  endflag

		lda  #1
		jsr  lkf_palloc			; try to allocate single page
		bcs  -					; no memory, then transfer without buffering
		
		;; core transfer loop (with buffering)
		
wwloop:
		stx  userzp+3
		stx  memstart
		ldy  #0
		sty  userzp+2
		sty  lastbytes

		;; read from network into internal memory
		
	-	sec
		ldx  userzp+1
		jsr  fgetc				; read byte from network
		bcs  wdumpnend
		sta  (userzp+2),y
		iny
		bne  -
		
		lda  #"."				; progress indicator
		clc						; (non blocking)
		ldx  #stdout
		jsr  fputc
		
		lda  #1
		jsr  lkf_palloc
		bcs  wdump
		
		txa
		ldx  userzp+3
		sta  lk_memnxt,x
		sta  userzp+3
		ldy  #0
		beq  -					; (always jump)

		;; write buffered data to disc
wdumpnend:
		lda  #$ff
		sta  endflag
		sty  lastbytes
		
wdump:
		ldx  memstart
	-	stx  userzp+3
		lda  lk_memnxt,x
		beq  wlastdump
		ldy  #0
		
	-	lda  (userzp+2),y
		sec
		ldx  data_stream
		jsr  fputc				; write byte to local screen/disc
		bcs  tr_abort			; (Mmmm...)
		iny
		bne  -
		
		lda  #$08				; progress indicator
		clc						; (non blocking)
		ldx  #stdout
		jsr  fputc
		
		ldx  userzp+3
		lda  lk_memnxt,x
		pha
		lda  #0
		sta  lk_memnxt,x
		jsr  lkf_free
		pla
		tax
		bne  --					; (always jump)

wlastdump:
		ldy  #0
		bit  endflag
		bpl  +
		cpy  lastbytes
		beq  ++
		
	+ -	lda  (userzp+2),y
		sec
		ldx  data_stream
		jsr  fputc				; write byte to local screen/disc
		bcs  tr_abort			; (Mmmm...)
		iny
		cpy  lastbytes
		bne  -

	+	bit  endflag
		bmi  +
		ldx  userzp+3			; (use current page for next buffer)
		bne  jwwloop				; (always jump)
		
	+	ldx  userzp+3
		jsr  lkf_free
		jmp  tr_abort

jwwloop:
		jmp  wwloop
		
		;; core transfer loop (without buffering)
		
oloop:	sec
		ldx  userzp+1
		jsr  fgetc				; read byte from network
		bcs  tr_abort
		ldx  data_stream
		cpx  #stdout
		bne  ++
		
		cmp  #$0a
		beq  +
		dec  cxpos
		bne  ++
		sec
		jsr  fputc
	+	ldy  #tsp_termwx
		lda  (lk_tsp),y			; width of terminal
		sta  cxpos				; no of charts before inserting newline		
		lda  #$0a
		ldx  #stdout
		
	+	sec		
		jsr  fputc				; write byte to local screen/disc
		bcs  tr_abort			; (Mmmm...)
		jmp  oloop

		;; transfer done
		
tr_abort:
		ldx  userzp+1
		jsr  fclose				; close network-stream
		jsr  read_server_feedback
		ldx  #<64
		ldy  #>0
		jsr  lkf_sleep			; wait for 1 second
		ldx  data_stream
		cpx  #3
		bcc  end_listen			; don't close stdout/err channel
		jsr  fclose				; close filesystem-stream

end_listen:
		sec
		ldx  listen_port
		lda  #64
		ldy  #64
		jsr  IPv4_listen		; unlisten
		bcc  +
		
		jsr  print_tcpip_error
		jmp  exit1
		
	+	rts

rsd_putinit:
		bit  list_flag
		bpl  +
		
		;; retrieve directory
		ldx  tcp_fd_write
		bit  ntxt_list			; send "list"
		jsr  lkf_strout
		nop
		rts

		;; retrieve file
	+	ldx  tcp_fd_write
		bit  ntxt_retr
		jsr  lkf_strout
		nop

netput_restoline:
		ldy  userzp+2			; offset to filename
		ldx  tcp_fd_write
	-	lda  linebuf,y
		beq  +
		sec
		jsr  fputc
		nop
		iny
		bne  -
	+	lda  #13
		jsr  netputc
		lda  #10
		jmp  netputc
		
		;; read commandline from stdin
readline:
		ldy  #0					; offset
		
	-	sec						; forced (blocking) getc
		ldx  #stdin
		jsr  fgetc
		nop
		cmp  #$20
		bcs  +
		cmp  #10
		beq  +
		cmp  #8
		bne  -					; unknown code (ignore)

		;; backspace
		tya
		beq  -					; empty line, then skip
		dey
		lda  #8					; delete
		jsr  putc
		jmp  -

	+	sta  userzp
		jsr  putc				; print character to screen (stdout)
		lda  userzp
		cmp  #10				; was it return ?
		beq  +

		cpy  #BUFLEN-1
		bcs  -					; (>BUFLEN, then ignore)

		sta  linebuf,y			; add char to buffer
		iny
		bne  -					; (always jump)
		
		;; parse_line
	+	lda  #0
		sta  linebuf,y
		rts		

exit0:
		ldx  #stdout
		bit  txt_closed
		jsr  lkf_strout
		lda  #0
		jmp  lkf_suicide
		
		;; read from stdin and pass to stdout and tcp_fd_write
netpass:
		sec
		ldx  #stdin
		jsr  fgetc
		nop
		cmp  #10
		beq  ++
		cmp  #32
		bcc  netpass
		bit  echo_flag
		bpl  +
		sta  userzp
		jsr  putc
		lda  userzp
	+	sec
		ldx  tcp_fd_write
		jsr  fputc
		nop
		jmp  netpass

	+	lda  #13				; CR
		jsr  netputc
		lda  #10				; LF
		jsr  putc
		lda  #10
netputc:
		sec
		ldx  tcp_fd_write
		jsr  fputc
		nop
		rts

		;; read single char from stream and echo it to stdout
readnecho:
		sec
		ldx  tcp_fd_read
		jsr  fgetc
		bcs  +
		pha
		jsr  putc
		pla
		rts

	+	cmp  #lerr_eof
_to_exit0:
		beq  exit0
		jmp  lkf_suicerrout

		;; wait for server feedback
		;; feedback is returned in ftp_respcode[0..2]
read_server_feedback:
		ldx  #0
		
		;; read the first 4 chars
	-	stx  userzp
		jsr  readnecho
		ldx  userzp
		sta  ftp_respcode,x
		inx
		cpx  #4
		bcc  -
		
		cmp  #"-"
		beq  multilineresp

		;; read from stream until LF (CR is ignored)
read_restoline:
		jsr  readnecho
		cmp  #10
		bne  read_restoline

		;; 221 goodbye ?
		lda  #"2"
		cmp  ftp_respcode
		bne  +
		cmp  ftp_respcode+1
		bne  +
		lda  ftp_respcode+2
		cmp  #"1"
		beq  _to_exit0

	+	lda  ftp_respcode
		cmp  #"4"				; 4,5 means error (carry set)
		rts

		;; read rest of multi line response
multilineresp:	
		lda  #" "
		sta  ftp_respcode+3
	-	jsr  read_restoline
		ldx  #0
		
		;; read the first 4 chars
	-	stx  userzp
		jsr  readnecho
		ldx  userzp
		cmp  ftp_respcode,x
		bne  --
		inx
		cpx  #4
		bcc  -

		jmp  read_restoline
		
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

read_dec_n_dot:
		jsr  read_decimal
		bcs  +
		lda  (userzp),y
		cmp  #"."
		bne  +
		iny
		lda  userzp+2
		rts
	+	jmp  HowTo
		
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

put_decimal:
		ldx  #"0"
	-	cmp  #100
		bcc  +
		sbc  #100
		inx
		bne  -
	+	pha
		txa
		sta  ntxt_port,y
		iny
		pla
		ldx  #"0"
	-	cmp  #10
		bcc  +
		sbc  #10
		inx
		bne  -
	+	pha
		txa
		sta  ntxt_port,y
		iny
		pla
		ora  #"0"
		sta  ntxt_port,y
		iny
		rts

putc:	sec
		ldx  #stdout
		jsr  fputc
		nop
		rts

.endofcode

ip_struct:
remote_ip:		.buf 4
				.word 21			; 21 is ftp-port
				.buf 2
		
ipv4_struct:	IPv4_struct9		; defined in ipv4.h
		
txt_trying:		.text "Trying ...",$0a,0
txt_conn:		.text "Connected",$0a,0
txt_username:	.text "Name: ",0
txt_password:	.text "Password: ",0
synerror_txt:	.text "syntax error",$0a,$0

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
		
					;; 0123456789012345678901234567890123456789
howto_txt:		.text "usage: ftp remote_host",$0a
				.text "  host in dotted decimal notation",$0a
				.text "  a.b.c.d each decimal in range 0..255",$0a,0

txt_closed:		.text $0a,"Connection closed by foreign host.",$0a,0

ntxt_user:		.text "USER ",0
ntxt_pass:		.text "PASS ",0
ntxt_port:		.text "PORT 192,168,000,064,64,64",13,10,0
ntxt_list:		.text "LIST",13,10,0
ntxt_retr:		.text "RETR ",0
ntxt_cwd:		.text "CWD ",0

ftp_prompt_txt:	.text "ftp> ",0

intcmdlist:		.text "dir",$80
				.text "cd",$81
				.text "get",$82
				.text "more",$83
				.byte 0

ftp_respcode:	.buf 4
tcp_fd_read:	.buf 1
tcp_fd_write:	.buf 1
echo_flag:		.buf 1
listen_port:	.buf 1
list_flag:		.buf 1
data_stream:	.buf 1

endflag:		.buf 1
memstart:		.buf 1
lastbytes:		.buf 1
cxpos:			.buf 1

linebuf:		.buf BUFLEN
		
end_of_code:
