		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; simple webserver
	
;#define DEBUG

#include <system.h>
#include <stdio.h>
#include <kerrors.h>
#include <cstyle.h>
#include <ipv4.h>
#include <debug.h>

#define HTTP_PORT 80

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION,	<LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code
		
		;; (task is entered here)
		
		jsr  parse_commandline
		
		ldx  userzp+1			; address of commandline (hi byte)
		jsr  lkf_free			; free used memory
								; (commandline not needed any more)

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
		cmp  #1
		bne  howto
		rts

		bit  ipv4_struct
		
		;; main programm code
main_code:
		set_zeropage_size(0)	; tell the system how many zeropage
								; bytes we need
								; (set_zeropage_size() is a macro defined
								; in include/cstyle.h) 

		;; search for packet interface
		lda  #0
		ldx  #<ipv4_struct
		ldy  main_code-1		; #>ipv4_struct
		jsr  lkf_get_moduleif
		nop

		db("got module")

		;; ok, try to listen
		clc						; (open)
		ldx  #IPV4_TCP			; (TCP)
		lda  #<HTTP_PORT		; (port number)
		ldy  #>HTTP_PORT
		jsr  IPv4_listen
		bcc  loop

		jsr  print_tcpip_error
		jsr  IPv4_unlock
		lda  #2
		rts						; exit(2)		

		;; listening, waiting for connect
loop:
		db("loop")
		
		sec						; (blocking)
		lda  #<HTTP_PORT
		ldy  #>HTTP_PORT
		jsr  IPv4_accept
		bcc  +

		jsr  print_tcpip_error
		jsr  IPv4_unlock
		lda  #1
		rts						; exit(1)		
		
		;; connected!
	+	stx  in_stream
		sty  out_stream

		db("connected")

		;; read request...
		;;  first is command, should read "CMD "
		jsr  readinupper
		bcs  http_badreq
		cmp  #"G"
		bne  http_notimpl
		jsr  readinupper
		bcs  http_badreq
		cmp  #"E"
		bne  http_notimpl
		jsr  readinupper
		bcs  http_badreq
		cmp  #"T"
		bne  http_notimpl
		jsr  readinupper
		bcs  http_badreq
		cmp  #" "
		bne  http_notimpl
		
		;; second is URL, should read "URL "
		jsr  readinupper
		bcs  http_badreq
		cmp  #"/"
		bne  http_nofile
		
		ldy  #0
	-	sec
		jsr  fgetc
		bcs  havename
		cmp  #$0c
		beq  -					; ignore /r
		cmp  #$0a
		beq  havename
		cmp  #" "
		beq  havename
		sta  filename,y
		iny
		cpy  #end_of_code-filename
		bne  -
		beq  http_nofile

finish_input:
		db("finish input")
		clc
		ldx  in_stream
		jsr  fgetc
		bcc  finish_input
		db("closing")
		ldx  in_stream
		jmp  fclose
		
http_badreq:
		db("bad request")
		lda  #txt_E400-txt_E
	-	pha
		jsr  finish_input
		pla
		jsr  send_htmlerror
		ldx  out_stream
		jsr  fclose
		jmp  loop
		
http_notimpl:
		db("not implemented")
		lda  #txt_E501-txt_E
		jmp  -
		
http_nofile:
		db("no such file")
		lda  #txt_E404-txt_E
		jmp  -
		
havename:
		tya
		bne  +

	-	lda  defaultdocument,y
		beq  +
		sta  filename,y
		iny
		bne  -
                

	+	lda  #0
		sta  filename,y
		sty  filename_len
		db("have filename")

#ifdef DEBUG
		ldx  #stdout
		bit  filename
		jsr  lkf_strout
#endif
		lda  #<filename
		ldy  [-]+2				; #>filename
		ldx  #fmode_ro
		jsr  fopen
		bcs  http_nofile
		stx  in_fstream
		db("file open")

		;; serv file with HTML header...

		ldx  out_stream
		bit  txt_header
		jsr  lkf_strout

		;; get mime type
		ldx  #0
	-	ldy  filename_len
	-	dey
		lda  filename,y
		jsr  toupper
		cmp  mimetab,x
		bne  nextmime
		inx
		lda  mimetab,x
		bne  -
		beq  foundmime
		
nextmime:
		inx
		lda  mimetab,x
		bne  nextmime
		inx
		inx
		lda  mimetab,x
		bne  --
 foundmime:
		lda  mimetab+1,x
		tay						; (offset to mimestrings)
		ldx  out_stream
	-	lda  mimestrings,y
		beq  +
		sec
		jsr  fputc
		iny
		bne  -
	+	ldy  #0
	-	lda  txt_headterm,y
		sec
		jsr  fputc
		iny
		cpy  #2
		bne  -

		;; head is complete ... read and pass file
		db("passing file")

	-	ldx  in_fstream
		sec
		jsr  fgetc
		bcs  +
		ldx  out_stream
		sec
		jsr  fputc
		bcc  -

	+	ldx  in_fstream
		jsr  fclose
		ldx  out_stream
		jsr  fclose
		jsr  finish_input
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
		

		;; send back error message
		;; < Y=offset to E_txt (error message)
send_htmlerror:
		pha
		;; print first part of error message
		ldx  out_stream
		bit  txt_errhead1
		jsr  lkf_strout
		bcs  s_err
		;; print error code and string
		pla
		pha
		tay
	-	sec
		lda  txt_E,y
		beq  +
		jsr  fputc
		bcs  s_err
		iny
		bne  -
		;; print second part of error message
	+	ldx  out_stream
		bit  txt_errhead2
		jsr  lkf_strout
		bcs  s_err
		;; print error code and string
		pla
		tay
	-	sec
		lda  txt_E,y
		beq  +
		jsr  fputc
		bcs  s_err+1
		iny
		bne  -
		;; print last part of error message
	+	ldx  out_stream
		bit  txt_errhead3
		jsr  lkf_strout
		bcs  s_err+1
		rts

s_err:	pla
		sec
		rts

readinupper:
		sec
		ldx  in_stream
		jsr  fgetc
		bcs  ++
		cmp  #$0c
		beq  readinupper		; ignore /r
toupper:
		and  #$7f				; (not really neccessary)
		cmp  #$60
		bcc  +
		cmp  #$80
		bcs  +
		sbc  #$20 -1
	+	clc 
	+	rts

		RELO_END ; no more code to relocate

in_stream:		.buf 1
in_fstream:		.buf 1
out_stream:		.buf 1
filename_len:	.buf 1

ipv4_struct:	IPv4_struct8		; defined in ipv4.h

		;; list of file extensions and corresponding mimetypes
		;; (reversely spelled !)
mimetab:
		.text "MTH", 0, ms1-mimestrings  ; HTM
		.text "LMTH", 0, ms1-mimestrings ; HTML 
		.text "TXT", 0, ms2-mimestrings  ; TXT
		.text "FIG", 0, ms3-mimestrings  ; GIF
		.text "GPJ", 0, ms4-mimestrings  ; JPG
		.text "GEPJ", 0, ms4-mimestrings ; JPEG
		.byte 0, ms5-mimestrings

mimestrings:
ms1:	.text "text/html",0
ms2:	.text "text/plain",0
ms3:	.text "image/gif",0
ms4:	.text "image/jpeg",0
ms5:	.text "application/octet-stream",0 ; for all unknown suffixes

		;; generic HTML header

txt_header:
		.text "HTTP/1.0 200 OK",$0a
		.text "Server: LUnix (LNG) Experimental WebServer V1.1",$0a
		.text "Content-type: ",0

		;; HTML header for error reports
		
txt_errhead1:
		.text "HTTP/1.0 ",0
txt_errhead2:
		.text $0a
		.text "Content-type: text/html"
txt_headterm:	.byte $0a,$0a
		.text "<html>"
		.text "<head>"
		.text "<title>ExperimentalWebServer-Error</title>"
		.text "</head>"
		.text "<body>"
		.text "<h3>HTTP/1.0 ",0
txt_errhead3:
		.text "</h3></body></html>",$0a,0

txt_E:	
txt_E400:
		.text "400 Bad Request",0
txt_E404:
		.text "404 Can't Access File",0
txt_E501:
		.text "501 Not Implemented",0

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

		;; help text to print on error
		;; (and user to hold filename later)

filename:
txt_howto:
		.text "usage:",$0a
		.text "  httpd",$0a
		.text "  LNG Experimental WebServer V1.1",$0a,0

defaultdocument:
		.text "index.html",0

end_of_code:
