		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; simple poplcient

		;; how it works:
		;;  open a TCP connetcion to the pop3-host on port 110
		;;  send "user <username>"
		;;  and  "pass <password>"
		;;  expect a line beginning with "+OK" in response
		;;  ("-ERR" means error)
		;; issue "list" and print result (strip leading "+OK")
		;; commands:
		;;  list   -> "list" show list of emails on server
		;;  more # -> "retr #" download email to screen (terminated with ".")
		;;  del #  -> "dele #" delete message from server
		;;  get #  -> "retr #" to disk (terminated with ".")
		;;  quit   -> "quit"

		;; username, password, IP stored in file with extension ".p3"

		;; #define DEBUG
	
#include <system.h>
#include <stdio.h>
#include <kerrors.h>
#include <cstyle.h>
#include <ipv4.h>
#include <debug.h>

#define POP3_PORT 110

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION,	<LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code
		
		;; (task is entered here)
		
		jsr  parse_commandline
		
		jmp  main_code

		;; print howto message and terminate with error (code 1)
		
howto:	ldx  #stdout
		bit  txt_howto
		jsr  lkf_strout
		exit(1)					; (exit() is a macro defined in
								;  include/cstyle.h)

		;; commandline
		;;  first argument is the command name itself
		;;  so userzp (argc = argument count) is at least 1
		;;  userzp+1 holds the hi-byte of the argument strings address

		;; format of the argument string:
		;;  "<command-name>",0,"<argument1>",0,...,"<last argument>",0 ,0
		
parse_commandline:
		lda  userzp
		cmp  #4
		bcs  howto
		ldx  #0
		cmp  #2
		bcc  howto
		beq  +					; no 3rd argument
		dex
	+	stx  fout_save			; (flag for savefile)
		rts

		bit  ipv4_struct
		
		;; main programm code
main_code:
		set_zeropage_size(4)	; tell the system how many zeropage
								; bytes we need
								; (set_zeropage_size() is a macro defined
								; in include/cstyle.h) 

		db("connect to TCP/IP")

		;; search for packet interface
		lda  #0
		ldx  #<ipv4_struct
		ldy  main_code-1		; #>ipv4_struct
		jsr  lkf_get_moduleif
		nop

		db("reading config file")

		ldy  #0
		sty  userzp
	-	iny						; skip first argument
		lda  (userzp),y
		bne  -
		iny
		sty  userzp				; offset to database name
		
		ldy  #0
		lda  (userzp),y
		sta  linebuf,y			; copy configname into linebuffer
	-	iny
		lda  (userzp),y
		sta  linebuf,y
		bne  -

		;; append ".p3" to get name of configuration file
		lda  #"."
		sta  linebuf,y
		iny
		sty  userzp+2			; remember offset to 3rd argument (if any)
		lda  #"p"
		sta  linebuf,y
		iny
		lda  #"3"
		sta  linebuf,y
		iny
		lda  #0
		sta  linebuf,y

		ldy  *-1				; #>linebuf (relocated)
		lda  #<linebuf
		jsr  read_config

		db("got config file")

		;; open output file (append) if any
		bit  fout_save
		beq  +++
		clc
		lda  userzp+2
		adc  userzp
		ldy  userzp+1
		bcc  +
		iny
	+	ldx  #fmode_wo			; open in write mode
		jsr  fopen
		bcc  +

		jsr  lkf_print_error
		ldx  #stderr
		bit  txt_nosaveerror
		jsr  lkf_strout
		jmp  error_exit

	+	stx  fout_save			; remember stream number (is !=0)

	+	ldx  userzp+1			; address of commandline (hi byte)
		jsr  lkf_free			; free used memory
								; (commandline not needed any more)

		;; configuration:
		;;  1.2.3.4 # name of pop3-server
		;;  <username>
		;;  <password>

	-	bit  linebuf			; (need relocated address)
		lda  #<linebuf
		sta  userzp
		lda  [-]+2				; #>linebuf
		sta  userzp+1
		ldy  #0
		
		jsr  read_decimal		; read IP address of server
		bcs  conf_error
		sta  remote_ip
		
		lda  (userzp),y
		cmp  #"."
		bne  conf_error
		iny
		jsr  read_decimal
		bcs  conf_error
		sta  remote_ip+1
		
		lda  (userzp),y
		cmp  #"."
		bne  conf_error
		iny
		jsr  read_decimal
		bcs  conf_error
		sta  remote_ip+2
		
		lda  (userzp),y
		cmp  #"."
		bne  conf_error
		iny
		jsr  read_decimal
		bcs  conf_error
		sta  remote_ip+3
		
		lda  (userzp),y
		cmp  #$0a
		beq  +
		;;

conf_error:
		ldx  #stderr
		bit  conf_error_txt
		jsr  lkf_strout
		lda  #1
		rts

		;; goin on...
	+	iny
		sty  userzp+3			; (store offset to username in linebuf)

		;; ok, try to connect to server
		ldx  #stdout
		bit  txt_trying
		jsr  lkf_strout

		ldx  #IPV4_TCP
		bit  ip_struct
		jsr  IPv4_connect
		bcc  +		
		;;

		jsr  print_tcpip_error
error_exit:						; (should work, exit closes all files)
		jsr  IPv4_unlock
		lda  #2
		jmp  lkf_suicide		; exit(1)

		;; going on...
	+	stx  in_stream
		sty  out_stream

		;; server banner
		jsr  receive_comresp	; wait for server response
		bcs  error_exit
		bne  error_exit		
		
		;; authentication...
		ldx  #stdout
		bit  txt_conn
		jsr  lkf_strout

		ldx  out_stream			; send "user " to socket
		bit  txt_user
		jsr  lkf_strout
		ldy  userzp+3

	-	lda  linebuf,y			; send username to socket
		cmp  #$0a
		beq  +
		jsr  nout
		iny
		bne  -

	+	iny
		sty  userzp+3
		jsr  nlend				; send CR LF to socket
		jsr  receive_comresp	; wait for server response
		bcs  error_exit
		bne  noauth

		ldx  out_stream
		bit  txt_pass
		jsr  lkf_strout
		ldy  userzp+3

	-	lda  linebuf,y
		cmp  #$0a
		beq  +
		jsr  nout
		iny
		bne  -

	+	jsr  nlend
		jsr  receive_comresp
		bcs  error_exit
		beq  mainloop
		;;

nlend:	lda  #$0d
		jsr  nout
		lda  #$0a
nout:	sec
		ldx  out_stream
		jsr  fputc
		bcs  error_exit
		rts

noauth:	jmp  error_exit

		;; prompt for user commands

		;; (code copied from ftp.s)
		;; main command-loop
mainloop:
		ldx  #stdout
		bit  pop_prompt_txt
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

syntax_error:
		ldx  #stdout			; unknown command, print error message
		bit  synerror_txt
		jsr  lkf_strout
		jmp  mainloop

		;; (code copied from ftp.s)
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
		beq  intcommand_list
		cmp  #$81
		beq  intcommand_get
		cmp  #$82
		beq  intcommand_more
		cmp  #$83
		beq  intcommand_del
		cmp  #$84
		beq  intcommand_quit
		
		sec						; (internal error)
		rts						; unknown command code

		
		;; internal commands

intcommand_list:
		lda  linebuf,y
		bne  syntax_error		; (no further arguments allowed)
		;; send LIST command
		ldx  out_stream
		bit  txt_list
		jsr  lkf_strout
		;; print list of emails to screen
		lda  #stdout
		sta  fout_stream
		jsr  receive_text
		clc
		rts

intcommand_more:
		ldx  out_stream
		bit  txt_retr
		jsr  lkf_strout
		ldy  userzp+2
	-	lda  linebuf,y
		beq  +
		jsr  nout
		iny
		bne  -
	+	jsr  nlend
		jsr  receive_comresp
		bcs  +
		lda  #stdout
		sta  fout_stream
		jsr  receive_text
	+	clc
		rts

intcommand_del:
		ldx  out_stream
		bit  txt_dele
		jsr  lkf_strout
		ldy  userzp+2
	-	lda  linebuf,y
		beq  +
		jsr  nout
		iny
		bne  -
	+	jsr  nlend
		jsr  receive_comresp
		clc
		rts
		
intcommand_get:
		lda  fout_save
		bne  +
		ldx  #stdout
		bit  txt_unablesave
		jsr  lkf_strout			; don't use jmp!
		rts

	+	ldx  out_stream
		bit  txt_retr
		jsr  lkf_strout
		ldy  userzp+2
	-	lda  linebuf,y
		beq  +
		jsr  nout
		iny
		bne  -
	+	jsr  nlend
		jsr  receive_comresp
		bcs  +
		lda  fout_save			; write into save file
		sta  fout_stream
		jsr  receive_text
	+	clc
		rts

  		;; send QUIT
intcommand_quit:
		lda  linebuf,y
		bne  syntax_error		; (no further arguments allowed)
		ldx  out_stream
		bit  txt_quit
		jsr  lkf_strout
		
		;; close connection and exit
		
		ldx  out_stream
		jsr  fclose
		ldx  in_stream
		jsr  fclose
		jsr  IPv4_unlock
		exit(0)

		;; (code copied from ftp.s)
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
		jsr  cout
		jmp  -

	+	sta  userzp
		jsr  cout				; print character to screen (stdout)
		lda  userzp
		cmp  #10				; was it return ?
		beq  +

		cpy  #buflen-1
		bcs  -					; (>BUFLEN, then ignore)

		sta  linebuf,y			; add char to buffer
		iny
		bne  -					; (always jump)
		
		;; parse_line
	+	lda  #0
		sta  linebuf,y
		rts		

		;; print TCP/IP error message
		;; (decode TCP/IP error codes)

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


		;; read 8_bit decimal
		;; (userzp),y points to string, A=userzp+2=result (if c=0)

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


		;; receive text message
		;; terminated with line containing just "."

receive_text:
		ldy  #tsp_termwx
		lda  (lk_tsp),y			; width of terminal
		sta  cxpos				; no of chars before inserting newline

		lda  #1
		sta  last_cchar

	-	sec
		ldx  in_stream
		jsr  fgetc
		bcs  +++
		cmp  #"."				; "."
		beq  rt_point
		cmp  #$0d
		beq  rt_termchar1		; (just ignore)
		cmp  #$0a
		beq  rt_termchar2
	-	ldx  #0
		stx  last_cchar
rt_termchar1:
		ldx  fout_stream
		cpx  #stdout
		bne  ++

		;; break long lines, when printing to stdout
		cmp  #$0a
		beq  +
		dec  cxpos
		bne  ++
		sec
		jsr  fputc
	+	ldy  #tsp_termwx
		lda  (lk_tsp),y			; width of terminal
		sta  cxpos				; no of chars before inserting newline		
		lda  #$0a
		ldx  #stdout
		
	+	sec
		jsr  fputc
		bcc  --

	+	;; got error
		sec
		rts

rt_termchar2:
		sec
		ldx  fout_stream
		jsr  fputc
		ldx  last_cchar
		cpx  #2
		bne  receive_text
		clc
		rts	

rt_point:
		ldx  last_cchar
		cpx  #1
		bne  -
		inx
		stx  last_cchar
		bne  --					; ignore leading "."

		;; receive command response message (and print to stdout)
		;; single line beginning with either "+OK" or "-ERR"
		;;  returns c=0(A=0 (ok), A=-1 (err)), c=1 (i/o error)

receive_comresp:
		sec
		ldx  in_stream
		jsr  fgetc
		bcs  rc_err
		cmp  #"+"
		beq  rc_okresp
		cmp  #"-"
		beq  rc_errresp
		;; unknown response ?!
		jsr  cout
		jsr  rc_rtoeol
		ldx  #stderr
		bit  txt_protoerror
		jsr  lkf_strout
		jmp  error_exit

		;; read stream until end of line
rc_rtoeol:
		sec
		ldx  in_stream
		jsr  fgetc
		bcs  rc_err
		cmp  #$0a
		beq  cout
		cmp  #$20
		bcc  rc_rtoeol			; ignore control characters
		sec
		ldx  #stdout
		jsr  fputc
		jmp  rc_rtoeol
		
cout:	sec
		ldx  #stdout
		jsr  fputc
		
rc_err:	rts

rc_okresp:
		jsr  cout
		jsr  rc_rtoeol
		lda  #0
		rts

rc_errresp:		
		jsr  cout
		jsr  rc_rtoeol		
		lda  #$ff
		rts

		;; read configuration file
		;; code maybe used for other applications too
		;; configuration is opened, read into linebuf, all redundancy is
		;; removed (comments etc.)
		;; <  A/Y = pointer to filename

read_config:
		ldx  #%11000000
		stx  last_cchar

		ldx  #fmode_ro
		jsr  fopen
		bcc  +
		jsr  lkf_print_error
		ldx  #stderr
		bit  txt_noconferror
		jsr  lkf_strout
		jmp  error_exit

	+	stx  in_stream
		ldy  #0					; pointer to start of buffer

rcf_loop:
		sec
		jsr  fgetc
		bcs  rcf_end
		cmp  #$0a
		beq  rcf_eol
		cmp  #$09				; treat TABs like spaces
		beq  +
		cmp  #$20
		bcc  rcf_loop			; ignore control characters
		cmp  #32	
		bne  ++

	+	bit  last_cchar
		bvs  rcf_loop			; ignore redundant spaces
		lda  last_cchar
		ora  #%01000000			; set space-flag
		sta  last_cchar
		lda  #32
	-	sta  linebuf,y
		iny
		cpy  #buflen-1
		beq  rcf_buffull
		bne  rcf_loop			; (always jump)

	+	cmp  #"#"
		beq  rcf_comment

		sta  linebuf,y
		lda  #0
		sta  last_cchar			; no space, no empty line
		beq  [-]+3				; (always jump)

		;; comment ("... # blah") ignore rest of line
rcf_comment:
	-	sec						; eat up rest of line
		jsr  fgetc
		bcs  rcf_end
		cmp  #$0a
		bne  -					; fall through to rcf_eol,as if LF encountered

rcf_eol:
		bit  last_cchar
		bmi  rcf_loop			; ignore empty lines
		lda  #%11000000			; empty line, ignore spaces
		sta  last_cchar
		tya						; remove possible space at end of line
		beq  +
		lda  linebuf-1,y
		cmp  #32
		bne  +
		dey
	+	lda  #$0a
		bne  --					; (always jump)
		
rcf_end:
		cmp  #lerr_eof
		beq  +
		jsr  lkf_print_error
		jmp  error_exit
		
	+	bit  last_cchar
		bmi  ++
		tya						; remove possible space at end of line
		beq  +
		lda  linebuf-1,y
		cmp  #32
		bne  +
		dey
	+	lda  #$0a
		sta  linebuf,y
		iny
		cpy  #buflen-1
		beq  rcf_buffull
		
	+	lda  #0
		sta  linebuf,y
		ldx  in_stream
		jsr  fclose
		nop
		tya						; return with A=bufsize
		rts

rcf_buffull:
		ldx  #stderr
		bit  txt_noconferror2
		jsr  lkf_strout
		jmp  error_exit

		RELO_END ; no more code to relocate

in_stream:		.buf 1
out_stream:		.buf 1
fout_stream:	.buf 1
last_cchar:		.buf 1
cxpos:			.buf 1
fout_save:		.buf 1			; output stream to save emails

ip_struct:
remote_ip:		.buf 4
				.word POP3_PORT		; 21 is ftp-port
				.buf 2
		
ipv4_struct:	IPv4_struct9		; defined in ipv4.h
		
txt_trying:		.text "Connecting ...",$0a,0
txt_conn:		.text "Authenticating ...",$0a,0

txt_user:		.text "USER ",0
txt_pass:		.text "PASS ",0
txt_list:		.text "LIST",$0d,$0a,0
txt_retr:		.text "RETR ",0
txt_dele:		.text "DELE ",0
txt_quit:		.text "QUIT",$0d,$0a,0

txt_E_CONTIMEOUT:	.text "timeout error",$0a,0
txt_E_CONREFUSED:	.text "connection refused",$0a,0
txt_E_NOPERM:		.text "no permisson",$0a,0
txt_E_NOPORT:		.text "no port",$0a,0
txt_E_NOROUTE:		.text "no route to host",$0a,0
txt_E_NOSOCK:		.text "no socket available",$0a,0
txt_E_NOTIMP:		.text "not implemented",$0a,0
txt_E_PROT:			.text "protocol error",$0a,0
txt_E_PORTINUSE:	.text "port in use",$0a,0

txt_unable:
		.text "unable to connect to remote host",$0a,"::",0
txt_unablesave:
		.text "no save file specified",$0a,0
txt_protoerror:
		.text "pop3 protocol error",$0a,0
pop_prompt_txt:	
		.text "pop3 (list,more#,del#,quit) >",0
synerror_txt:
		.text "unknown command or syntax error",$0a,0
		
intcmdlist:	
		.text "list",$80
		.text "get", $81
		.text "more",$82
		.text "del", $83
		.text "quit",$84
		.byte 0

		;; help text to print on error
		;; (and user to hold filename later)
linebuf:
txt_howto:
		.text "usage:",$0a
		.text "  popclient <configname> [<savefile>]",$0a
		.text "  simple pop3 client to retrieve",$0a
		.text "  emails from a pop3 server",$0a
		.text "  run \"help popclient\" for details",$0a,0

txt_noconferror:
		.text "can't open configuration file",$0a,0
		
txt_noconferror2:
		.text "configuration file too large",$0a,0

conf_error_txt:
		.text "error in config file",$0a,0

txt_nosaveerror:
		.text "can't open save file",$0a,0

		buflen equ * - linebuf

end_of_code:
