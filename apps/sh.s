
		;; LNG Shell - first version
		;; (signal stuff is missing)

		;; derived from lunix shell, which is derived from
		;; sh0 (minimal lunix shell)

#include <system.h>
#include <stdio.h>
#include <kerrors.h>

SHOPT_NOMSG	    equ	 $80  	 ; no startup message
SHOPT_NOECHO    equ  $40     ; dont echo input
SHOPT_NOPROMPT  equ  $20     ; dont print a prompt
SHOPT_NOQUIT    equ  $10     ; dont quit shell after executing script
SHOPT_DOVERSION equ  $08     ; print shell version _after_ EOF

ARGS	 equ userzp
ARGC	 equ userzp+2
fd_stdin equ userzp+3


		start_of_code equ $1000

		.org start_of_code

		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		; Get more zero page

		lda #4
		jsr lkf_set_zpsize

		ldx #stdin
		stx fd_stdin

		ldx  #0
		stx  exitflag
		stx  childcnt			; no child processes jet
		stx  hist_wr
		stx  options

		lda  #1
	-	sta  histbuf,x			; clear historybuffer
		inx
		bne  -
		stx  histbuf

; Process cmd line options

		ldx ARGS
		stx ARGC
		ldy #0
		sty ARGS

	-	inc ARGS		; Skip cmd name
		lda (ARGS),y
		bne -

; Loop thro arguments

loop:
		inc ARGS		; Skip null
		dec ARGC
		beq finished
		ldy #0
		lda (ARGS),y
		cmp #"-"
		beq +           ; switch?

		;;from_file:
		lda ARGS
		ldy ARGS+1
		sec
		ldx #fmode_ro
		jsr fopen		; open file
		;;nop			; exit on error
		bcs nofile
		stx fd_stdin

		ldy #0
	-	inc ARGS		; Skip filename
		lda (ARGS),y
		bne -
		beq loop

    +

	 	inc ARGS		; yes
		lda (ARGS),y
		beq loop		; no more switches (single "-")

	 	inc ARGS

		cmp #"s"
		bne +			; -s?
		           		; yes
		lda  options
		ora  #SHOPT_NOMSG
		ora  #SHOPT_NOPROMPT
		ora  #SHOPT_NOECHO
		sta  options
		bne  loop

    +
		cmp #"v"
		bne +			; -v?
		           		; yes
		lda  options
		ora  #SHOPT_DOVERSION
		sta  options

		bne  loop
    +

		cmp #"r"
		bne +			; -s?
		           		; yes
		lda  options
		ora  #SHOPT_NOQUIT
		sta  options
		bne  loop
	+
		bne show_usage

finished:

		lda  options
		and  #SHOPT_NOMSG
		bne  +
                            
		; shell version
		ldx  #stdout
		bit  txt_welcome
		jsr  lkf_strout
		nop
	+

		;;ldx  userzp+1
		;;jsr  lkf_free			; free argument page (argumets are ignored)

		;;lda  #3
		;;jsr  lkf_set_zpsize		; allocate 3 zp bytes

		;; re-entered after completed commandlines

start:	lda  #0					; reset status
		sta  stat
		sta  stat2
		sta  bgrflag
		sta  escape_flag
		sta  quote_flag

		lda  exitflag
		cmp  #$ff
		beq  exit0

		jsr  scan_childs

		jsr  print_prompt

		lda  #0					; reset length of command line
		sta  cmdlen
		lda  hist_wr
		sta  hist_rd

		;; read a single commandline

in_loop:
								; forced (blocking) getc
		;;ldx  #stdin
		ldx  fd_stdin
		sec
		jsr  fgetc
		bcc  proc_inp

		cmp  #lerr_eof
		beq  file_end

		pha
		jsr close_file
		pla
		jmp  lkf_suicerrout

nofile:

file_end:

		lda  options
		and  #SHOPT_DOVERSION
		beq  +

		; shell version
		ldx  #stdout
		bit  txt_welcome
		jsr  lkf_strout
		nop

	+
    	lda  options
		and  #SHOPT_NOQUIT
		beq  exit0

		jsr close_file

		ldx  #stdin
		stx  fd_stdin
		;;ldx  #$00	;; we know stdin==0
		stx  options

		jmp start

close_file:
		ldx fd_stdin
		cpx #stdin
		beq _close_file

		jsr fclose
		nop

_close_file:
		rts

show_usage:
		ldx  #stdout
		bit  usage
		jsr  lkf_strout
		nop
exit0:
		jsr  close_file
		lda  #0
		jmp  lkf_suicide			; exit with exitcode 0

got_tab:
		jsr  ccomplete
		jmp  in_loop

proc_inp:
		bit  escape_flag
		bmi  do_escape

		cmp  #$20
		bcs  forw_to_screen
		cmp  #10
		beq  forw_to_screen		; return
		cmp  #$1b				; <ESC> ?
		beq  got_escape
		cmp  #9					; TAB (command completion)
		beq  got_tab
		cmp  #8
		bne  in_loop			; unknown, ignore


		;; backspace
		ldx  cmdlen
		beq  in_loop			; empty line, then skip
		dex						; else emulate backspace by...
		stx  cmdlen
		lda  #8					; delete
		jsr  putc
		jmp  in_loop

got_escape:
		lda  #$80
		sta  escape_flag
		jmp  in_loop

do_escape:
		bvs  +					; stage2
		ldx  #$c0
		stx  escape_flag
		cmp  #"["
		bne  exit_escape
		jmp  in_loop

	+	ldx  #0
		stx  escape_flag
		cmp  #$41				; A
		bne  +
		;; csr up
		jmp  up_hist


	+	cmp  #$42				; B
		bne  exit_escape
		jmp  down_hist

exit_escape:
		lda  #0
		sta  escape_flag
		jmp  in_loop

forw_to_screen:
		pha						; remember char
		jsr  putc				; print character to screen (stdout)
		pla						; (cleanup stack)
		cmp  #10				; was it return ?
		beq  ++

		ldy  cmdlen				; line too long ?
		cpy  #255
		beq  +					; then skip adding to buffer

		sta  cmdbuf,y			; add char to buffer
		iny
		sty  cmdlen				; increment length of buffer
	+	jmp  in_loop

	+	jsr  add_hist
		jsr  intbef				; internal command ("exit") ?
		bcc  +					; no error, then goto prompt

		;; parse_line
		lda  #0					; else reset stopflag and
		sta  stopflg			; read-pointer
		sta  userzp+2
		ldx  cmdlen				; load length of commandline
		bne  dothework			; and start processing it.

	+	jmp  start				; no command, then skip


		;; get next non white space character
		;; from buffer
nexnex:
		jsr  getakt
		bcc  +
	-	cmp  #32
		bne  getakt
		jsr  getnex
		bcs  -
	+	rts

getnex:	inc  userzp+2
getakt:							; get current character from buffer
		ldx  userzp+2
		cpx  cmdlen
		bcs  get_eob			; end of buffer ?
		lda  cmdbuf,x
		tax

		cmp  #"\""
		bne  +             ; not quote
		lda  quote_flag
		eor  #$80
		sta  quote_flag
		;;bne  getnex
		jmp  getnex

	+	bit  quote_flag
		bmi  +             ; dont check special/whitespace when quoted

		cmp  #$20
		beq  got_whitespc		; reached white spaces
		cmp  #$09
		beq  got_whitespc
		cmp  #"!"
		beq  got_special
		cmp  #"&"
		beq  got_special

	+	clc
		txa
		rts

get_eob:
		lda  #0
		.byte $2c
got_whitespc:
		lda  #32
got_special:
		cmp  #0
		sec						; return with A=0 and c=1 if end of buffer
		rts

searched:
		jsr  getnex
		bcc  searched
		jmp  oeb


dothework:						; process commandline
		dex
		lda  cmdbuf,x			; read last character of commandline
		cmp  #"&"				; is it "&" ?
		bne  +

		dec  cmdlen
		beq  cmd_done
		lda  #$80
		sta  bgrflag			; set background-flag (...&)
		lda  #$ff				; NULL
		bne  ++					; yes, then command's stdin=NULL

cmd_done:
		jmp  start

	+
	    lda  #stdin
		;;lda fd_stdin
	+	sta  tmpinfd			; remember channel

next_com:
		ldy  #0					; reset command length
		sty  len
		sty  userzp
		lda  #1
		jsr  lkf_palloc			; allocate single page
		nop
		stx  userzp+1			; (userzp) room for appstruct
		jsr  nexnex
		ldy  #3
		bcs  oeb				; read command

	-	sta  (userzp),y
		iny
		beq  searched			; more then 18 chars, then skip
		jsr  getnex
		bcc  -

oeb:	lda  #0					; add $00 to filename
		sta  (userzp),y
		iny
		jsr  makparampage		; create parameter page
		tax						; (remember last char)
		lda  #0
		iny
		sta  (userzp),y			; end-marker
		ldy  #0
		lda  tmpinfd
		sta  (userzp),y         ; child stdin
		cpx  #"!"
		bne  +
		;; need more pipes
		jsr  lkf_popen
		nop
		stx  tmpinfd
		tya
		jmp  ++
	+	lda  #stdout
	+	ldy  #1
		sta  (userzp),y         ; child stdout
		lda  #stderr			; changed! always use stderr
		iny
		sta  (userzp),y         ; child stderr

		lda  userzp
		ldy  userzp+1
		jsr  lkf_forkto         ; fork to child

		ror  lasterr
		bpl  +
		jsr  lkf_print_error
	+	stx  lastPID
		sty  lastPID+1

		ldy  #0
		lda  (userzp),y
		cmp  #3
		bcc  +
		tax
		jsr  fclose

	+	ldy  #1
		lda  (userzp),y
		cmp  #3
		bcc  +
		tax
		jsr  fclose

	+	ldx  userzp+1			; release memory needed for app-struct
		jsr  lkf_pfree

		bit  lasterr
		bpl  +
		jmp  start				; skip, print prompt

	+	inc  childcnt
		bit  bgrflag           ; if not "&", then skip message
		bpl  +

		lda  childcnt          ; print " [nn]  PID\n"
		sta  hlp
		lda  #0
		sta  hlp+1
		lda  #91
		jsr  putc
		jsr  decout
		lda  #93
		jsr  putc
		lda  #32
		jsr  putc
		;; ldy  childcnt
		;; ldx  stat
		;; lda  cmdbuf-2,x
		;; sta  hlp
		;; sta  childpidtab_lo,y
		;; lda  cmdbuf-1,x
		;; sta  hlp+1
		;; sta  childpidtab_hi,y
		lda  lastPID
		sta  hlp
		lda  lastPID+1
		sta  hlp+1
		jsr  decout
		lda  #$0a
		jsr  putc

	+	lda  #0
		bit  stopflg
		bmi  toerrrout			; stop, if there was a userbreak
		jsr  getakt
		beq  +					; skip, if this is the last command
		cmp  #"!"
		bne  syntax_error
		inc  userzp+2			; pointer to next char in buffer
		jsr  nexnex				; (skip trailing white spaces)
		bcs  syntax_error
		jmp  next_com			; process next command

syntax_error:
          lda  #11
          jmp  toerrrout

	+	bit  bgrflag			; if not "&", then skip message
		bmi  skipwait			; set, then don't wait for completion

waitfortermempf:
		sec
		jsr  scan_childs+1		; blocking
		lda  lastPID
		ora  lastPID+1
		bne  waitfortermempf

		;; endwait
		lda  #0
		sta  stat2
		jmp  cmd_done

skipwait: jmp  start

toerrrout:
          pha
          sei
          ldx  stat            ; kill all started processes
          beq  killedrdy
          dex
          lda  cmdbuf,x
          tay
          dex
          lda  cmdbuf,x
          stx  stat
          jsr  lkf_getipid
          bcs  toerrrout+1
		;; jsr  kill
          jmp  toerrrout+1

killedrdy:
		ldx  #stderr       ; print error message
		jsr  lkf_strout
		bit  kiltext
		pla
		jsr  hexout
		lda  #$0a
		jsr  putc
		jmp  cmd_done  ; and return to prompt

hexout:
		pha
		lsr  a
		lsr  a
		lsr  a
		lsr  a
		jsr  +
		pla
		and  #15
	+	tax
		lda  hextab,x
		jmp  putc

		;; shell internal command ?

intbef:
          ; reset pointer
		  ldy  #0
          sty  userzp+2

		  ; get first non-space character
          jsr  nexnex
          bcs  noint		; end of buffer, space or special char
		  cmp  #"#"			; "#" starts EOL-Comment => ignore
		  beq  isint
		-
          cmp  beftab,y
          bne  noint
          iny
          jsr  getnex
          bcs  trenn		; end of buffer, space or special char
          jmp  -

		  ; not an internal command
noint:    lda  #0
          sta  exitflag
          sta  userzp+2
          sec
        - rts

          ; return from internal command
isint:
          clc
		  rts

trenn:    lda  beftab,y
          bne  noint

		  ; "exit"

          sei
          lda  childcnt
          beq  +               ; alone on stdout or 2nd try, then exit
          bit  exitflag
          bmi  +
          lda  #128
          sta  exitflag
          ldx  #stdout
          bit  txt0
          jsr  lkf_strout          ; "you have running jobs"
          bcc  -

        + jmp  exit0


makparampage:
		jsr  nexnex
		bcs  +

	-	sta  (userzp),y
		iny
		jsr  getnex
		bcc  -
		cmp  #" "
		bne  +

		lda  #0
		sta  (userzp),y
		iny
		bne  makparampage

	+	lda  #0
		sta  (userzp),y
		jmp  getakt

decout:
          ldx  #4
          ldy  #0

        - lda  hlp
          cmp  d_tab_lo,x
          lda  hlp+1
          sbc  d_tab_hi,x
          bcc  +

          sta  hlp+1
          lda  hlp
          sbc  d_tab_lo,x
          sta  hlp
          iny
          jmp  -

        + tya
          beq  +
          ora  #"0"
          jsr  putc
          ldy  #"0"

        + dex
          bne  -
          lda  hlp
          ora  #"0"
          jmp  putc


		;; look for terminated childs and print appropriate messages

	-	bit wait_struct

scan_childs:
		clc						; non-blocking
		ldx  #<wait_struct
		ldy  [-]+2
		jsr  lkf_wait				; look for terminated child
		bcs  scan_done
		dec  childcnt
		cmp  #0
		beq  +

		pha
		lda  wait_struct+5		; PID lo
		sta  hlp
		lda  wait_struct+6		; PID hi
		sta  hlp+1
		jsr  decout
		ldx  #stdout
		bit  child_message_txt
		jsr  lkf_strout
		nop
		pla
		jsr  hexout
		lda  #$0a
		jsr  putc

	+	lda  wait_struct+5
		cmp  lastPID
		bne  +
		lda  wait_struct+6
		cmp  lastPID+1
		bne  +
		lda  #0					; last process has finished
		sta  lastPID
		sta  lastPID+1
	+	jmp  scan_childs

scan_done:
		rts

;
; history stuff
;

up_hist:
		ldx  hist_rd
		lda  histbuf,x
		cmp  #1
		beq  +

	-	dex
		lda  histbuf,x
		beq  ++
		cmp  #1
		bne  -

	+	jmp  in_loop			; found $01, then skip (end of buffer)

	+	stx  hist_rd

          ; replace line

hist_update:
		lda  #$0d				; to beginning of current line
		jsr  putc
		lda  #$1b				; rease rest of line
		jsr  putc
		lda  #91				; "["
		jsr  putc
		lda  #75				; "K"
		jsr  putc
		jsr  print_prompt

		ldy  #0
		ldx  hist_rd
		cpx  hist_wr
		beq  +

	-	inx
		lda  histbuf,x
		beq  +
		sta  cmdbuf,y
		stx  userzp
		jsr  putc
		ldx  userzp
		iny
		bne  -

	+	sty  cmdlen
	-	jmp  in_loop

down_hist:
		ldx  hist_rd
		cpx  hist_wr
		beq  -               ; end reached, then skip

	-	inx
		lda  histbuf,x
		bne  -

		stx  hist_rd
		jmp  hist_update

		;; add commandline to history
add_hist:
		ldx  hist_wr			; compare with latest commandline
		lda  histbuf,x
		cmp  #1
		beq  add_ok

	-	dex
		lda  histbuf,x
		beq  +
		cmp  #1
		bne  -
		beq  add_ok

	+	ldy  #0
	-	inx
		cpy  cmdlen
		beq  +
		lda  cmdbuf,y
		cmp  histbuf,x
		bne  add_ok
		iny
		bne  -

	+	lda  histbuf,x
		bne  add_ok
		rts						; no need to add same commandline twice
		
add_ok:
		ldx  hist_wr
		inx
		lda  cmdlen
		beq  +++
		ldy  #0

	-	lda  cmdbuf,y
		beq  +
		sta  histbuf,x
		inx
		iny
		cpy  cmdlen
		bne  -

	+	lda  #0
		sta  histbuf,x
		stx  hist_wr

	-	inx
		lda  histbuf,x
		beq  +
		cmp  #1
		bne  -

	+	lda  #1
		sta  histbuf,x
	+	rts

		;; try to complete string using history buffer
ccomplete:
		;; command completion
		ldy  cmdlen
		lda  #1
	-	sta  cmdbuf,y			; no completion yet
		iny
		bne  -

		ldx  hist_wr
csearch:
		lda  histbuf,x
		cmp  #1
		beq  endcsearch

	-	dex
		lda  histbuf,x
		beq  +
		cmp  #1
		bne  -
		beq  endcsearch

	+	ldy  #0
	-	inx
		cpy  cmdlen
		beq  +					; found candidate
		lda  cmdbuf,y
		cmp  histbuf,x
		bne  nextc
		iny
		bne  -
		rts

		;; complete as far as possible

	+ -	lda  histbuf,x
		beq  ++
		cmp  #" "
		beq  ++
	 	lda  cmdbuf,y
		cmp  #1
		beq  +
		cmp  histbuf,x
		bne  ++++
	+	lda  histbuf,x
		sta  cmdbuf,y
		inx
		iny
		bne  -
		rts
	+	lda  cmdbuf,y
		cmp  #" "
		beq  +
		cmp  #1
		bne  ++
	+	lda  #" "
		sta  cmdbuf,y
		iny
	+	lda  #0
		sta  cmdbuf,y
		
		;; step to next history element
nextc:	
	-	dex
		lda  histbuf,x
		bne  -
		dex
		jmp  csearch

endcsearch:
		ldy  cmdlen
	-	lda  cmdbuf,y
		beq  +
		cmp  #1
		beq  +
		jsr  putc
		iny
		bne  -
	+	sty  cmdlen
		rts

		;; added functions

print_prompt:	
		
		lda  options
		and  #SHOPT_NOPROMPT
		bne  +

		lda  #"#"
		jsr  putc
		lda  #" "

putc:
        tax
		lda  options
		and  #SHOPT_NOECHO
		bne  +

        txa
		sec						; forced (blocking) putc
		ldx  #stdout
		jsr  fputc
		nop
	+
		rts

 ;; stopanormal:
 ;; 		jmp  sendstop
 ;;
 ;; _sig.userbreak:					; catch break-signal and pass it to
 ;; 		pha						; running processes
 ;; 		bit  stat2
 ;; 		bmi  stopanormal		; if there are (!)
 ;; 		lda  #255				; else just remember
 ;; 		sta  stopflg			; (set stop-flag)
 ;; 		pla
 ;; 		rti
 ;;
 ;; sendstop: txa
 ;;           pha
 ;;           tya
 ;;           pha
 ;;           lda  #0
 ;;          sta  stat2
 ;;
 ;;         - ldx  stat2           ; sent signal 6 to all started processes
 ;;           cpx  stat            ; (6 = userbreak)
 ;;           beq  +
 ;;           lda  cmdbuf+1,x
 ;;           tay
 ;;           lda  cmdbuf,x
 ;;           inx
 ;;           inx
 ;;           stx  stat2
 ;;           jsr  lkf_getipid         ; get PID from IPID
 ;;           bcs  -
 ;;           ldx  #6
 ;; 		;; jsr  send_signal     ; send signal...
 ;;           jmp  -
 ;;
 ;;         + pla
 ;;           tay
 ;;           pla
 ;;           tax
 ;;           lda  #255
 ;;           sta  stat2
 ;;           pla
 ;;           rti
 ;; erroroutmin:
 ;; 		ldx  tmpoutfd
 ;; 		cpx  #stdout
 ;; 		beq  +
 ;; 		jsr  fclose				; close com's stdin channel
 ;; 		cli						; if it is a new opened channel
 ;; 	+	jmp  toerrrout


		RELO_END ; no more code to relocate

kiltext:
		.text  "exec-skiped/error $"
		.byte $00

hextab:
		.text  "0123456789ABCDEF"

d_tab_lo: .byte <1, <10, <100, <1000, <10000
d_tab_hi: .byte >1, >10, >100, >1000, >10000

;; table of internal commands
beftab:
		.text  "exit"
		.byte $00

txt0:	.text  "you have running jobs"
		.byte $0a,$00

txt_welcome:
		.text  "LUnix Shell Version 2.2beta (15Feb2000)"
		.byte $0a,$00

usage:
		.text "Usage: sh [-sr] [file]"
		.byte $0a,$00

child_message_txt:
		.text " terminated with error $"
		.byte $00

options:	.buf 1	; flag for options given on commandline
lasterr:	.buf 1
lastPID:	.buf 2	; PID of last started process
cmdlen:		.buf 1   ; number of chars in commandline-buffer
stopflg:	.buf 1   ; userbreak-flag
stat2:		.buf 1
len:		.buf 1
stat:		.buf 1   ; counts activated processes (num*2)
tmpinfd:	.buf 1   ; command's stdout channel
exitflag:	.buf 1   ; exit-flag, set with "you have runnig..." message

childcnt:	.buf 1   ; counts child processes
hlp:		.buf 2   ; hold integer (for decout)
bgrflag:	.buf 1   ; set, if background process

hist_wr:	.buf 1   ; pointer into history-buffer (write)
hist_rd:	.buf 1   ;            ''               (read)

wait_struct:	.buf 7			; 7 bytes
escape_flag:	.buf 1
quote_flag:		.buf 1

.newpage

histbuf:  .buf  256
cmdbuf:   .buf  256

end_of_code:
