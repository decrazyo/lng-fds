;; For emacs: -*- MODE: asm; tab-width: 4; -*-

; Errol's first coding in Lunix. definately alpha code!
; A hacked version of slip.s

; Packetdriver for LNG-TCP/IP
; using serial driver and PPP encapsulation
; (lcp, ncp, pap and IP)

; packetdriver MUST keep the order of the packets
; in both, send and receive direction !

;; 	#define DEBUG

#include <system.h>
#include <jumptab.h>
#include <rs232.h>
#include <kerrors.h>
#include <stdio.h>
#include <debug.h>
	
#begindef print_string(pointer)
	ldx  #stdout
	bit  pointer
	jsr  lkf_strout
	nop
#enddef

#define SELFMOD    $ff00		
#define MAXBUFS    12			; max number of handled buffers

		;; some PPP related constants

#define PROTO_IP   $0021
#define PROTO_IPCP $8021
#define PROTO_LCP  $c021
#define PROTO_PAP  $c023
#define PROTO_CHAP $c223

#define CP_CONFREQ 1
#define CP_CONFACK 2
#define CP_CONFNAK 3
#define CP_CONFREJ 4
#define CP_TERMREQ 5
#define CP_TERMACK 6
#define CP_ECHOREQ 9
#define CP_ECHOREP 10

#define PPPSTAT_INIT 0
#define PPPSTAT_LCP  1
#define PPPSTAT_AUTH 2
#define PPPSTAT_NCP  3
#define PPPSTAT_UP   4
#define PPPSTAT_DOWN 5

		;; simple test application for the new serial driver API		
		  				
		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		jmp  initialize

		RELO_JMP(+)             ; (don't try to relocate data)

module_struct:
		.asc "pkg"				; module identifier
		.byte 3					; module interface size
		.byte 1					; module interface version number
		.byte 1					; weight (num. of available virtual devices)
		.word $0000				; (reserved)
	+	jmp  ppp_lock
		jmp  ppp_unlock
		jmp  ppp_putpacket
		jmp  ppp_getpacket

;;; ------------------------------------------------------------------------
		
		;; called within NMI-handler
		;; (NOT in conext of this task!! don't use userzp)
		;; < A=received byte
		;; > c=1 means no more bufferspace left, don't call me again
		;;       until "trigger receive"

rec_handler:
		cmp  #$7e
		beq  recendframe
		cmp  #$7d
		beq  recesc
		
		bit  recstat			; this byte escaped?
		bpl  recdofcs
		bvc  ignore_input
		eor  #$20				; (recstat should be $ff here)
		inc  recstat
				
recdofcs:	
		tay
		;; calculate fcs
		eor  recfcs
		tax 
		lda  fcstab_lo,x 
		eor  recfcs+1 
		sta  recfcs 
		lda  fcstab_hi,x 
		sta  recfcs+1 
		tya		
		
		bit  recstat2			; inside frame header?
		bmi  recframing
		
		;; store recvd byte & inc pointer
				
dest_addr equ  *+1
		;; mem_write
		sta  SELFMOD
		inc  dest_addr
		beq  +					; crossed page boundary
ignore_input:
		clc
		rts

	+	clc						; ... next page
		lda  dest_addr+1
		adc  #1
		sta  dest_addr+1
		sec
		ldx  reclst_c
		sbc  buf_mid,x			; i assume buf_lenl is $00 !!!!!
		cmp  buf_lenh,x
		bcc  isnotfull

		;; ignoreRest						; packet is too big ! (discard)
		lda  #$80				; bit -> bmi,bvc (ignore further input)
		sta  recstat
recend:	clc
isnotfull:
		rts

recesc:	lda  recstat
		cmp  #$80
		beq  +					; (if all input has to be ignored)
		lda  #$ff
		sta  recstat
	+	clc
		rts

recframing:
		;; transparently handle address/control field compression
		;; & protocol field compression
		cmp  #$ff				; address
		beq  recend
		cmp  #$03				; control
		beq  recend
		;tay  - Y already the byte
		lsr  a
		bcs  +
		sty  recprot			; protocol MSB=xxxxxxx0
		clc
		rts

	+	sty  recprot+1			; protocol LSB=xxxxxxx1
		lda  #0
		sta  recstat2			; end of frame header
		clc
		rts
		
recendframe:
#ifdef DEBUG
		inc  debug3+4
#endif

		bit  recstat2
		bmi  recnewframe		; between frames
#ifdef DEBUG
		dec  debug3+4
		inc  debug3+3
#endif
		lda  recstat
		cmp  #$80
		beq  recnewframe		; (after discarded packet)
		
#ifdef DEBUG
		dec  debug3+3
		inc  debug3+2
#endif
		;; check the fcs
		lda	 recfcs
		cmp  #$b8
		bne  recbadframe		; error
		lda  recfcs+1
		cmp  #$f0
		bne  recbadframe		; ditto
		
#ifdef DEBUG
		dec  debug3+2
#endif
		;; subtract 2 from frame length
		sec
		lda  dest_addr
		sbc  #$02
		sta  dest_addr
		bcs  +					; crossed page boundary
		dec  dest_addr+1
		;; need check in case of <2byte packet!?!
		
	+	
		;; save protocol info
		ldx  reclst_c			; x=current rec buf
		lda  recprot
		sta  buf_proth,x
		lda  recprot+1
		sta  buf_protl,x	
	
		;; setup for new packet
		ldy  #$ff
		sty  recfcs
		sty  recfcs+1			; needed for receiving frames with a single
		sty  recstat2			; $7e inbetween !!
								; (otherwise every second packet fails fcs)
		iny
		sty  recstat
		sty  recprot
		sty  recprot+1
		jmp  reckeep
		

		;; setup for a new frame (discard current)
recbadframe:
#ifdef DEBUG
		inc debug1				; shows if we got an error..
#endif
recnewframe:	
		ldy  #$ff
		sty  recfcs
		sty  recfcs+1
		sty  recstat2
		iny
		sty  recstat
		sty  recprot
		sty  recprot+1
		jmp  setpage			; do this or just clc/rts?
		
		;; completed packet code
reckeep:
		          
#ifdef DEBUG
		inc  debug3
#endif
		ldx  reclst_c			; x=current rec buf
		lda  dest_addr+1
		sec
		sbc  buf_mid,x
		bne  +
		lda  #0
	+	sta  buf_lenh,x			; set lengths
		lda  dest_addr
		sta  buf_lenl,x
		lda  buf_protl,x
		cmp  #<PROTO_IP
		bne  +
		lda  buf_proth,x
		cmp  #>PROTO_IP
		bne  +
		lda  #$41				; (done + "is IP")
		SKIP_WORD				; (bit $40xx is ok - not relocated)
	+	lda  #$40
		sta  buf_stat,x			; mark buffer ("done")
		lda  buf_l2nx,x			; switch current to next buffer
		sta  reclst_c
		bmi  endof_reclst

setpage:  
		ldx  reclst_c			; prepare for writing into current buffer
		bmi  nomorebuffer
		lda  buf_mid,x
		sta  dest_addr+1
		lda  #0
		sta  dest_addr
		sta  recstat
		clc
		rts

endof_reclst:
nomorebuffer:
		lda  #$80
		sta  recstat			; ignore further input
		;; sec <================== change later
		clc
		rts

		;; -------------------------------------------------------
		
		;; called within NMI-handler
		;; (NOT in conext of this task!! don't use userzp)
		;; > A=byte to send
		;; > c=1 means no more bytes to send, don't call me again
		;;       until "trigger send"

		;; sndstat:
		;;  $00=normal chars from buffer
		;;  $01-$05 - head (end/addr/ctrl/prot1/prot2)
		;;  $10-$12 - tail(fcs1/fcs2/end)
		;;  msb of sndstat = escaped char
		;;  $13 = finished packet, look for a new one
		;;  $40 = idle

send_handler:
		lda  sndstat
		bne  sndframe
		
		;; read the next byte to send

source_addr equ *+1
		lda  SELFMOD
		inc  source_addr
		bne  +
		inc  source_addr+1
	+	inc  sndlenl
		bne  snddofcs
		inc  sndlenh
		bne  snddofcs
		;; end of packet
		ldx  #$10
		stx  sndstat

snddofcs:	
		tay
		;; calculate fcs
		eor  sndfcs
		tax 
		lda  fcstab_lo,x 
		eor  sndfcs+1 
		sta  sndfcs 
		lda  fcstab_hi,x 
		sta  sndfcs+1 
		tya

sndescchk:	
		cmp  #$7e				; end
		beq  snddoesc
		cmp  #$7d				; esc
		beq  snddoesc
		cmp  #$20				; fix for bitmask when acm compression done
		bcc  snddoesc
		clc
		rts
		
snddoesc:	
		sta  sndtemp
		lda  sndstat
		ora  #$80
		sta  sndstat
		lda  #$7d
		clc
		rts

sndframe:	
		bpl  sndframe2
		;; escaped char
		and  #$7f
		sta  sndstat
		lda  sndtemp
		eor  #$20
		clc
		rts

sndframe2:	
		cmp  #$01				; 1st end
		beq  sndend
		cmp  #$02				; address
		beq  sndaddr
		cmp  #$03				; control
		beq  sndctrl
		cmp  #$04				; protocol 1st byte
		beq  sndprot
		cmp  #$05				; protocol 2nd byte
		beq  sndprot1

		cmp  #$10				; fcs
		beq  sndfcs1
		cmp  #$11				; fcs+1
		beq  sndfcs2		
		cmp  #$12
		beq  sndendlast			; final end
		cmp  #$13
		beq  snp				; look for a new packet

		;; A should be $40
		jmp  sndidle			; idling, we shouldn't be called (?)

		;; send end marker (HDLC flag $7e) - start of new frame
sndend:	inc  sndstat
		lda  #$7e
		clc
		rts

		;; send HDLC address ($ff)
sndaddr:	
		inc  sndstat
		lda  #$ff
		sta  sndfcs				; initialize FCS algorithm
		sta  sndfcs+1
		bne  snddofcs			; (always jump)


		;; send HDLC control ($03)
sndctrl:	
		inc  sndstat
		lda  #$03
		jmp  snddofcs

		;; send HDLC protocol ($0021 for IP) first byte ($00)
sndprot:	
		inc  sndstat
		;lda  #$00				; sndprot
		ldx  sndlst_c
		lda  buf_proth,x
		jmp  snddofcs


		;; send HDLC protocol ($0021 for IP) second byte ($21)
sndprot1:	
		lda  #$00
		sta  sndstat			; next byte is from buffer
		;lda  #$21				; sndprot+1
		ldx  sndlst_c
		lda  buf_protl,x
		jmp  snddofcs

		;; send HDLC FCS first byte
sndfcs1:
		inc  sndstat
		lda  sndfcs
		eor  #$ff
		jmp  sndescchk

		;; send HDLC FCS second byte
sndfcs2:	
		inc  sndstat
		lda  sndfcs+1
		eor  #$ff
		jmp  sndescchk

		;; send HDLC flag sequence to mark the end of this frame ($7e)
sndendlast:
		inc  sndstat
		lda  #$7e
		clc
		rts

		;; packet sent, mark it done??
snp:	bit  sndlock			; get next buffer
		bmi  eloo				; dont if lock is <>0 (api is running)
						; is this buggy? what does eloo do?
						; what if the packet never got marked done?

		;; mark previous packet done
		ldx  sndlst_c			; x=current send buf
		lda  buf_stat,x
		and  #1					; (keep recycle-bit)
		ora  #$40
		sta  buf_stat,x			; mark buffer ("done")
		lda  buf_l2nx,x			; get the next buffer in list
		sta  sndlst_c			; make the current one that buf
#ifdef DEBUG
		inc  debug2
#endif

		;; start a new packet
news:	ldx  sndlst_c
		bmi  nompage			; no more buffers to send!

		;; we have a buffer, so set it up
		lda  buf_mid,x
		sta  source_addr+1
		lda  #0
		sta  source_addr
		clc
		lda  buf_lenl,x
		eor  #255
		adc  #1
		sta  sndlenl
		lda  buf_lenh,x
		eor  #255
		adc  #0
		sta  sndlenh
		lda  #$02				; next is addr - sending the end now!
		sta  sndstat

eloo:	lda  #$7e				; just an additional inter frame fill byte
		clc						; (HDLC flag = $7e)
		rts

sndidle:	;kludge

nompage:
		lda  #$40				; idle!
		sta  sndstat
		sec
		rts

;-------------------------------------------------------------------
; API
;-------------------------------------------------------------------

ppp_unlock:
		sei
		lda  lk_ipid
		cmp  user_ipid
		bne  +               ; no permission
		lda  #$ff
		sta  user_ipid
		clc
		cli
		rts

ppp_lock:
		sei
		lda  user_ipid
		bpl  +               ; can't handle 2 users
		lda  lk_ipid
		sta  user_ipid
		clc
		cli
		rts

	+ 	cli
		sec
	-	rts

		;; get packet from ppp-driver
		;; > c=1: error, no packet available
		;; > c=0: A=startpage, X/Y=length of packet

ppp_getpacket:
#ifdef DEBUG
		inc  debug3+1
#endif
		lda  #$41				; (wana have an IP buffer)
		jsr  get_filledbuf
		bcs  -
		
		;; return ip packet
		sei
		ldy  freelst			; y=old freelist start
		stx  freelst			; make current start of free list
		tya
		sta  buf_l2nx,x			; point current to old freelist

		lda  buf_mid,x			; get a/x/y & return..
		pha
		ldy  buf_lenh,x
		lda  buf_lenl,x
		tax
		pla
		clc
		cli
		
		db("got pack")
		rts
		

		;; pass packet to ppp-driver
		;; < A=startpage, X/Y=length of packet
		;; < c=0: empty buffer, c=1: filled buffer (packet)
		
		;; > c=0: ok packet accepted for delivery
		;; > c=1: error, too many packet in queue
		
ppp_putpacket:
		sei
		;bit  freelst	;to make it compile with debug! fix!
		;bmi  --
		pha
		txa
		pha
		ldx  freelst
		tya
		sta  buf_lenh,x			; save length
		pla
		sta  buf_lenl,x			; " "
		pla
		sta  buf_mid,x			; save start page
		lda  buf_l2nx,x			; get next free buf pointed to from this one
		sta  freelst			; & save it in freelst
		lda  #$80
		sta  buf_stat,x			; a waiting-to-send block
		sta  buf_l2nx,x			; mark as end of queue??
		
		lda  #>PROTO_IP
		sta  buf_proth,x		; ip packets
		lda  #<PROTO_IP
		sta  buf_protl,x
		sta  ppp_go				; (A <> 0!)
		
		bcc  _putinreclst		; add it to recieve list if empty

_putinsndlst:
		;; otherwise add to bottom of send queue
		sei
		ldy  sndlst_b
		bmi  +
		txa
		sta  buf_l2nx,y			; make current bottom point to new one
		bpl  ++
	+	stx  sndlst_t
	+	stx  sndlst_b			; make our new one the new bottom buf
		
		dec  sndlock
		bit  sndstat
		bvc  +
		;; sending has been disabled, must enable it again
		stx  sndlst_c
		jsr  news

		;; 'news' sets sndstat to $02, so end wont get sent:
		lda  #$01
		sta  sndstat

	+	ldx  #3					; trigger start of send
		jsr  rs232_ctrl
		inc  sndlock

		clc
		cli
		db("put snd pack")
		rts

		;; add buffer to receive-buffer-list
		;; < X=ptr to buffer
_putinreclst:
		ldy  reclst_b			; y=bottom of rec list
		bmi  +
		txa
		sta  buf_l2nx,y			; make current bottom point to new one
		bpl  ++
	+	stx  reclst_t
	+	stx  reclst_b			; make our new one the new bottom buf
		bit  reclst_c
		bpl  +
		stx  reclst_c			; make it current if no current set
	+	clc
		cli
		db("put rec pack")
		rts

		;; get next IP packet from reclst
		;; < A=buf_stat value to search for
		;; > c=0, X=buf (also in cur_buf)
		;; > c=1 (error)
get_filledbuf:
		sei
		sta  tmpzp
		lda  #$ff
		sta  tmpzp+1			; (pointer to previous buffer)
		ldx  reclst_t
		bmi  +
	-	lda  buf_stat,x
		beq  +					; (no more filled buffers left)
		cmp  tmpzp
		beq  ++
		lda  buf_l2nx,x
		stx  tmpzp+1
		tax
		bpl  -
	+	cli						; no (matching) buffer found
		sec
		rts
		
		;; got buffer, remove it from reclst
	+	lda  buf_l2nx,x			; adapt l2nx of prev buffer
		ldy  tmpzp+1
		bmi  +
		sta  buf_l2nx,y
	+	cpx  reclst_t			; adapt butlst_t if it is the found buffer
		bne  +
		sta  reclst_t
	+	cpx  reclst_b			; adapt buflst_b if it is the found buffer
		bne  +
		sta  reclst_b
	+	lda  #$80
		sta  buf_l2nx,x			; next points to NIL
		cli
		clc
		stx  cur_buf
		rts						; return first matching buffer
		
;-------------------------------------------------------------------
; PPP protocol stack
;-------------------------------------------------------------------

		;; main PPP function
		;; the ppp protocol functions all run in context of the ppp
		;; process, a normal user process - so userzp is free to use.
		;; (but there are atomic sections, e.g. access to sndlst and reclst)

	-	jmp  mntppp				; (=> handle timeouts)
		
process_ppp:
		lda  #$40				; (wana have a non-IP buffer)
		jsr  get_filledbuf
		bcs  -					; (got nothing)

		;; check protocol, demultiplex or reject

		ldy  buf_proth,x		; ($00)/$80/$c0
		lda  buf_protl,x		; $21/$23
		cmp  #$21
		bne  ++
		
		cpy  #$c0
		bne  +
		jmp  process_lcp
	+	cpy  #$80
		bne  ++					; (reject)
		jmp  process_ncp

	+	cmp  #$23
		bne  +					; (reject)
		cpy  #$c0
		bne  +					; (reject)
		jmp  process_pap

	+
		;; unknown protocol, send lcp protocol reject
		;; send a protocol reject

		lda  buf_proth,x
		sta  lcpprt+4
		lda  buf_protl,x
		sta  lcpprt+5

		lda  #$c0
		sta  buf_proth,x		; send lcp packets
		lda  #$21
		sta  buf_protl,x

		lda  buf_mid,x			; get a/x/y & return..
		sta  userzp+1
		lda  #$00
		sta  userzp
		sta  buf_lenh,x
		tay

	-	lda  lcpprt,y
		sta  (userzp),y
		iny
		cpy  #$06
		bne  -					; (was lcpprs1)

		tya
		sta  buf_lenl,x

		inc  lcpident
		lda  lcpident
		sta  lcpprt+1			; ident
		;; fall through to sendnonip
		sec						; (recycle)

		;; this adds buffer X to the bottom of the send list
		;; needs X to be current buffer..
		;; < c=0 -> delete packet after sending it
		;; < c=1 -> recycle packet after sending it (re-insert into reclst)
sendnonip:
		lda  #$80
		sta  buf_l2nx,x			; fix these for _putinsndlst to work
		adc  #0
		sta  buf_stat,x

		db("send non-ip packet")

		;; add it to the bottom of snd list		
		jmp  _putinsndlst		; add to sndlst


		;; -----------------------------------------------------

		;; handle lcp packets	
process_lcp:	
		db("got lcp packet")

		lda  #>PROTO_LCP
		sta  buf_proth,x		; send lcp packets (if any)
		lda  #<PROTO_LCP
		sta  buf_protl,x

		lda  buf_mid,x
		sta  userzp+1
		sta  userzp+3
		lda  #$00
		sta  userzp
		sta  userzp+2

		sta  lcplen+1
		lda  buf_lenl,x
		sta  lcplen

		ldy  #0					; demultiplex on LCP type
		lda  (userzp),y
		cmp  #CP_CONFREQ		; config request
		beq  lcp_confreq

		cmp  #CP_CONFACK		; config ack
		bne  +
		jmp  lcpak

	+	cmp  #CP_TERMREQ		; term req
		bne  +
		jmp  lcptr

	+	cmp  #CP_ECHOREQ		; echo req
		bne  +
		jmp  lcper

	+	jmp  release_buf		; drop/discard rest


lcp_confreq:	
		lda  #PPPSTAT_LCP				; recieved cr (ConfReq)
		sta  ppp_status
		ora  lcpflg
		sta  lcpflg
		db("got ConfReq")

		;; check for anything to reject
		;; lcpcr10:  
		ldy  #$04
		sty  lcpry
		sty  lcpty

lcpcr11:	
		ldy  lcpry
		cpy  lcplen
		beq  lcpcr20

		lda  (userzp),y
		iny
		sty  lcpry

		cmp  #$02				; acm	;accept all these
		beq  lcpcr15
		cmp  #$03				; auth
		beq  lcpcr15
		cmp  #$05				; mag
		beq  lcpcr15
		cmp  #$07				; pfc
		beq  lcpcr15
		cmp  #$08				; acfc
		beq  lcpcr15

		;; reject
		ldy  lcpty
		sta  (userzp+2),y		; code
		iny
		sty  lcpty

		ldy  lcpry
		lda  (userzp),y			; len
		iny
		sty  lcpry

		ldy  lcpty
		sta  (userzp+2),y		; len
		iny
		sty  lcpty

		tax
		dex

	-	dex
		beq  lcpcr11

		ldy  lcpry
		lda  (userzp),y
		iny
		sty  lcpry

		ldy  lcpty
		sta  (userzp+2),y
		iny
		sty  lcpty

		jmp  -					; (was "lcpcr13")


		;; accept this
lcpcr15:
		lda  (userzp),y			; len
		tax
		dex
		
	-	iny
		dex
		bne  -					; (was "lcpcr16")
		sty  lcpry

		;; special handling?
		jmp  lcpcr11


		;; gone through LCP packet
lcpcr20:
		lda  lcpty				; check if we rejected anything
		cmp  #$04
		beq  +					; no rejects

		ldx  cur_buf
		sta  buf_lenl,x
		
		ldy  #$03
		sta  (userzp+2),y		; len

		lda  #$00
		sta  buf_lenh,x
		tay
		lda  #$04				; crej type
		sta  (userzp+2),y
		sec						; (recycle)
		jmp  sendnonip			; send a config reject


		;; naks - check for anything to nack
	+	ldy  #$04				; (was "lcpcr30")
		sty  lcpry
		sty  lcpty

lcpcr31:	
		ldy  lcpry
		cpy  lcplen
		beq  lcpcr40

		lda  (userzp),y
		iny
		sty  lcpry

		cmp  #$03				; auth
		bne  lcpcr35

		;; is it pap?
		iny
		lda  (userzp),y
		cmp  #$c0
		bne  +
		iny
		lda  (userzp),y
		cmp  #$23
		bne  +
		ldy  lcpry
		jmp  lcpcr35

		;; send nak pap
	+	ldy  lcpty				; (was "lcpcr33")
		lda  #$03
		sta  (userzp+2),y		; code
		iny
		lda  #$04
		sta  (userzp+2),y		; len
		iny
		lda  #$c0
		sta  (userzp+2),y		; pap
		iny
		lda  #$23
		sta  (userzp+2),y
		iny
		sty  lcpty

		ldy  lcpry
		;; fall through to skip auth

		;; accept this
lcpcr35:
		lda  (userzp),y			; len
		tax
		dex

	-	iny
		dex
		bne  -					; (was "lcpcr36")
		sty  lcpry
		jmp  lcpcr31

lcpcr40: 
		lda  lcpty				; check if we nacked anything
		cmp  #$04
		beq  +					; no naks

		ldx  cur_buf		
		sta  buf_lenl,x
			
		ldy  #$03
		sta  (userzp+2),y		; len

		lda  #$03				; cnak type
		ldy  #$00
		sta  (userzp+2),y
		tya
		sta  buf_lenh,x
		sec						; (recycle)
		jmp  sendnonip			; send a config nack
		
		;; we didnt reject or nack anything, so send ak
	+	lda  lcpflg				; (was "lcpcr50")
		ora  #$08				; flag sent ak
		sta  lcpflg

		ldy  #$00
		lda  #$02
		sta  (userzp+2),y		; cak type

		ldx  cur_buf
		lda  lcplen
		sta  buf_lenl,x
		lda  lcplen+1
		sta  buf_lenh,x
		sec						; (recycle)
		jmp  sendnonip

		;; configure ack
lcpak:	lda  lcpflg
		ora  #$04				; flag that we receved an ack
		sta  lcpflg
		;; and release buffer...

		;; release buffer (cur_buf)
		;; (free memory and add empty slot to list of free slots)
release_buf:
		ldx  cur_buf
		lda  buf_mid,x
		tax
		jsr  lkf_pfree
		ldx  cur_buf
		
		sei
		lda  freelst
		stx  freelst
		sta  buf_l2nx,x
		cli
		rts

		;; terminate request
lcptr:	ldy  #$00
		sty  ncpflg				; reset
		sty  lcpflg

		lda  #PPPSTAT_DOWN
		sta  ppp_status

		;; send a terminate ack
		lda  #$06
		sta  (userzp+2),y		; termack
		iny
		;; leave ident
		iny
		lda  #$00				; length
		sta  (userzp+2),y
		
		ldx  cur_buf
		sta  buf_lenh,x
		iny
		lda  #$04
		sta  (userzp+2),y
		sta  buf_lenl,x
		sec						; (recycle)
		jsr  sendnonip
		jmp  ip_stop

		;; echo request - send an echo reply
lcper:	ldy  #$00
		lda  #$0a
		sta  (userzp+2),y		; echo reply
		ldy  #$04

		lda  #$00				; 0 magic#
lcper2:	sta  (userzp+2),y
		iny
		cpy  #$08
		bne  lcper2

		ldx  cur_buf
		lda  lcplen
		sta  buf_lenl,x
		lda  lcplen+1
		sta  buf_lenh,x
		sec						; (recycle)
		jmp  sendnonip

		
		;; -----------------------------------------------------
		
		;; handle ncp packets	

process_ncp:
		lda  #$80
		sta  buf_proth,x		; send lcp packets
		lda  #$21
		sta  buf_protl,x
		
		lda  buf_mid,x
		sta  userzp+1
		sta  userzp+3
		lda  #$00
		sta  userzp
		sta  userzp+2
		sta  lcplen+1
		lda  buf_lenl,x
		sta  lcplen
		
		db("got ncp packet")

		lda  #PPPSTAT_NCP
		sta  ppp_status
		
		ldy  #0
		lda  (userzp),y
		cmp  #$01				; config request
		beq  ncpcr

		cmp  #$02				; config ack
		bne  +
		jmp  ncpak

	+	cmp  #$03				; config nak
		bne  +
		jmp  ncpnk

	+	jmp  release_buf		; drop rest

ncpcr:	lda	 ncpflg
		ora	 #$01				; receved cr
		sta	 ncpflg

		;; ncpcr10:  	
		ldy  #$04
		sty  ncpry
		sty  ncpty

ncpcr11:
		ldy  ncpry
		cpy  ncplen
		beq  ncpcr20

		lda  (userzp),y
		iny
		sty  ncpry

		cmp  #$03				; address
		beq  ncpcr15

		;; reject
		ldy  ncpty
		sta  (userzp+2),y		; code
		iny
		sty  ncpty

		ldy  ncpry
		lda  (userzp),y			; len
		iny
		sty  ncpry

		ldy  ncpty
		sta  (userzp+2),y		; len
		iny
		sty  ncpty

		tax
		dex

	-	dex
		beq  ncpcr11

		ldy  ncpry
		lda  (userzp),y
		iny
		sty  ncpry

		ldy  ncpty
		sta  (userzp+2),y
		iny
		sty  ncpty

		jmp  -					; (was "ncpcr13")

		;; accept this
ncpcr15:
		lda  (userzp),y			; len
		tax
		dex

	-	iny
		dex
		bne  -					; (was "ncpcr16")
		sty  ncpry

		;; special handling?
		jmp  ncpcr11

ncpcr20:	
		lda  ncpty
		cmp  #$04
		beq  +					; no rejects

		
		ldx  cur_buf
		sta  buf_lenl,x
		
		ldy  #$03
		sta  (userzp+2),y		; len

		lda  #$00
		sta  buf_lenh,x
		tay
		lda  #$04				; crej type
		sta  (userzp+2),y
		sec						; (recycle)
		jmp  sendnonip			; send a config reject

		;; no nak code!
	+							; (was "ncpcr30")
		;; send ak
		;; ncpcr50:
		lda  ncpflg
		ora  #$08				; flag sent ak
		sta  ncpflg

		ldy  #$00
		lda  #$02
		sta  (userzp+2),y		; cak type

		ldx  cur_buf
		lda  ncplen
		sta  buf_lenl,x
		lda  ncplen+1
		sta  buf_lenh,x
		sec						; (recycle)
		jmp  sendnonip
		
		;; configure ack
ncpak:	lda  ncpflg
		ora  #$04				; receved ak
		sta  ncpflg
		jmp  release_buf
	
		;; config nak - contains our allocated ip address
ncpnk:
		ldx  #$00
		ldy  #$06
	-	lda  (userzp),y
		sta  ncpcrt+6,x
		iny
		inx
		cpx  #4
		bne  -

		jmp  release_buf

		;; -----------------------------------------------------
		
		;; ak/nak?
process_pap:
		lda  buf_mid,x
		sta  userzp+1
		lda  #$00
		sta  userzp		
		
		ldy  #0
		lda  (userzp),y
		cmp  #$02
		bne  pap1
		
 		db("pap authenticate OK")
		
		lda  papflg
		ora  #$01				; got ak
		sta  papflg
		bne  +
		
		;; got nak
pap1:
		db("pap authenticate failed!")
		;; we should probably do something here..
		
	+	jmp  release_buf

		
		;; -----------------------------------------------------
		
		;; get 256 byte buffer for newly created packets
		;; > c=0, X=ptr to buffer (also in cur_buf)
		;; > c=1 -> error
		
alloc_minibuffer:
		ldx  freelst			; get pointer to top of freelst
		bmi  g_err				; no slot available
		
		lda  buf_l2nx,x			; get next free buf pointed to from this one
		sta  freelst			; & save it as start of new freelst
		stx  cur_buf			; (i hope this don't cause races)

		;; (x holds number of slot to use)

		ldx  #memown_netbuf
		ldy  #$80				; not underneath I/O
		jsr  lkf_spalloc		; allocate a single page (fast)
		bcs  g_err2

		txa
		ldx  cur_buf
		sta  buf_mid,x
		lda  #0
		sta  buf_lenl,x
		sta  buf_stat,x
		lda  #1
		sta  buf_lenh,x
		lda  #$80
		sta  buf_l2nx,x			; next-pointer points to NIL
		rts						; (carry is cleared!)
		
g_err2:	ldx  cur_buf			; release slot
		lda  freelst
		sta  buf_l2nx,x
		stx  freelst
g_err:	sec
	-	rts
		
		
		;; -----------------------------------------------------
		;; some code to do timeouts for PPP handling
		;; 
		;; ppp_getpacket jumps here if there are no packets ready

mntppp:
		;; LCP/PAP/NCP initial transmits & retransmits/timeouts
		lda  ppp_go
		beq  -			; (delay LCP ConfReq until start of TCP/IP layer)
		
		lda  ppp_status
		cmp  #PPPSTAT_DOWN		; link down ?
		bne  +
	-	rts

	+	lda  ncpflg
		beq  +
		cmp  #$0f
		bne  mntncp
		lda  #PPPSTAT_UP		
		cmp  ppp_status
		beq  -
		sta  ppp_status
		jmp  ip_start

	+	lda  lcpflg
		cmp  #$0f
		bne  mntlcp

		lda  ppp_auth
		beq  mntncp				; (jump, if pap disabled)

		lda  papflg
		cmp  #$03
		beq  mntncp
		bne  mntpap

mntlcp:	lda  lcpflg
		and  #$02				; sent cr?
		bne  +

		lda  lk_systic
		adc  #$80
		lda  lk_systic+1
		adc  #1
		sta  lcp_timer
		jmp  lcp_snd_confreq
		;; timer check..

	+	lda  lk_systic+1
		cmp  lcp_timer
		bmi  +
		lda  lk_systic
		adc  #$80
		lda  lk_systic+1
		adc  #1
		sta  lcp_timer
		jmp  lcp_snd_confreq

	+	rts

mntpap:	lda  papflg
		and  #$02				; sent ar?
		bne  +
		lda  lk_systic
		adc  #$80
		lda  lk_systic+1
		adc  #1
		sta  pap_timer
		jmp  paptr
		;; timer check..

	+	lda  lk_systic+1
		cmp  pap_timer
		bmi  +
		lda  lk_systic
		adc  #$80
		lda  lk_systic+1
		adc  #1
		sta  pap_timer
		jmp  paptr

	+	rts

mntncp:	lda  ncpflg
		and  #$02				; sent cr?
		bne  +
		lda  lk_systic
		adc  #$80
		lda  lk_systic+1
		adc  #1
		sta  ncp_timer
		jmp  ncpcrs
		
		;; timer check..
	+	lda  lk_systic+1
		cmp  ncp_timer
		bmi  +
		lda  lk_systic
		adc  #$80
		lda  lk_systic+1
		adc  #1
		sta  ncp_timer
		jmp  ncpcrs
		
	+
	-	rts
		
		;; -----------------------------------------------------
		;; send an lcp config request	
lcp_snd_confreq:
		jsr  alloc_minibuffer
		bcs  -
		
		lda  lcpflg
		ora  #$02				; flag sent cr
		sta  lcpflg

		;; put some crap into the buffer
		lda  buf_mid,x			; setup the buf address
		sta  lcp_sm+1
		
		lda  #$c0
		sta  buf_proth,x		; send lcp packets
		lda  #$21
		sta  buf_protl,x
		
		inc  lcpident
		lda  lcpident
		sta  lcpcrt+1			; ident
				
		lda  #0
		sta  lcp_sm
		sta  buf_lenh,x
		tay
		
	-	lda  lcpcrt,y			; default config request		
lcp_sm equ *+1
		sta  SELFMOD,y
		iny
		cpy  #$04
		bne  -					; (was lcpcrs1)
		
		tya
		sta  buf_lenl,x
		clc						; (delete after send)
		jmp  sendnonip

	-	rts
	
		;; -----------------------------------------------------
		;; send an ncp config request	
ncpcrs:	jsr  alloc_minibuffer
		bcs  -
		
		lda  ncpflg
		ora  #$02				; flag sent cr
		sta  ncpflg

		lda  buf_mid,x			; setup the buf address
		sta  ncp_sm+1
		
		lda  #$80
		sta  buf_proth,x		; send ncp packets
		lda  #$21
		sta  buf_protl,x

		inc  ncpident
		lda  ncpident
		sta  ncpcrt+1			; ident

		lda  #0
		sta  ncp_sm
		sta  buf_lenh,x
		tay

	-	lda ncpcrt,y			; default config request
ncp_sm equ *+1
		sta  SELFMOD,y
		iny
		cpy  #$0a
		bne  -					; (was ncpcrs1)
		
		tya
		sta  buf_lenl,x
		clc						; (delete after send)
		jmp  sendnonip

	-	rts

		;; -----------------------------------------------------
		;; send a pap authenticate request	
paptr:	jsr  alloc_minibuffer
		bcs  -
		
		lda  #PPPSTAT_AUTH		; sent ar
		sta  ppp_status
		ora  papflg
		sta  papflg

		lda  #$c0
		sta  buf_proth,x		; send pap packets
		lda  #$23
		sta  buf_protl,x
	
		lda  buf_mid,x
		sta  userzp+3
		lda  #$00
		sta  userzp+2

		inc  papident
		
		clc						; find length of pap packet
		lda  #$06
		adc  papidl
		adc  pappassl
		sta  paplen+1

		ldy  #$00				; copy header + useridl
		sty  paplen

	-	lda  paptrt,y
		sta  (userzp+2),y
		iny
		cpy  #$05
		bne  -					; (was paptrs1)

		ldx  #$00				; copy userid

	-	lda  papid,x
		sta  (userzp+2),y
		iny
		inx
		cpx  papidl
		bne  -					; (was paptrs2)

		lda  pappassl			; passl
		sta  (userzp+2),y
		iny

		ldx  #$00				; copy pass

	-	lda  pappass,x
		sta  (userzp+2),y
		iny
		inx
		cpx  pappassl
		bne  -					; (was paptrs3)

		ldx  cur_buf
		lda  paplen+1
		sta  buf_lenl,x
		lda  #$00
		sta  buf_lenh,x
		clc						; (delete after send)
		jmp  sendnonip

		;; enter link established phase
ip_start:
		ldx  #stdout
		bit  link_up_txt
		jsr  lkf_strout
		jsr  print_ip
		lda  #$0a
		jsr  putc
		lda  tcpip_configured
		bne  +
		;; send faked IP packet only once
		lda  #1
		sta  tcpip_configured
		jmp  send_faked_ip

		;; leave link established phase
ip_stop:
		ldx  #stdout
		bit  link_down_txt
		jsr  lkf_strout
	+	rts
				
;-------------------------------------------------------------------
; main
;-------------------------------------------------------------------

; main loop

	-	cli
		rts
		
		;; deallocate ram for all buffers that have been sent (buf_stat=$40)
clean_sndlst:
		;; starts at top of list and loops till no more free buffers
		sei
		ldx  sndlst_t
		bmi  -
		lda  buf_stat,x
		cmp  #$40
		bne  ++
		
		;; delete buffer that has already been sent
		lda  buf_l2nx,x
		sta  sndlst_t
		bpl  +
		sta  sndlst_b
	+	txa
		pha
		lda  buf_mid,x
		tax
		jsr  lkf_pfree
		pla
		tax
		sei
		ldy  freelst
		stx  freelst
		tya
		sta  buf_l2nx,x
		cli
		jmp  clean_sndlst

	+	cmp  #$41
		bne  -
		
		;; recycle input-buffer that has been used for sending
		;; a ppp-protocol response

		;; first get size of buffer
		ldy  #1					; (at least one page)
		lda  buf_mid,x
		tax
	-	lda  lk_memnxt,x
		beq  +
		iny
		inx						; (note: we assume concurrent pages!)
		bne  -					; (always jump)
		
	+	ldx  sndlst_t			; set size
		tya
		sta  buf_lenh,x
		lda  #0
		sta  buf_lenl,x
		
		lda  buf_l2nx,x
		sta  sndlst_t
		bpl  +
		sta  sndlst_b
		
	+	lda  #$80
		sta  buf_stat,x			; a waiting-to-send block
		sta  buf_l2nx,x			; mark as end of queue??
		
		lda  #>PROTO_IP
		sta  buf_proth,x		; ip packets
		lda  #<PROTO_IP
		sta  buf_protl,x
		
		jsr  _putinreclst		; (does cli)
		jmp  clean_sndlst


		;; -----------------------------------------------------
		
main_loop:
		jsr  clean_sndlst		; free mem from sent buffers
		
		jsr  process_ppp		; process PPP protocol stack

		lda  reclst_c			; fix up current rec buf??
		bpl  +
		lda  reclst_t
		bmi  +
		sta  reclst_c
		db("PPP:reclst reactivated")

	+	lda  sndlst_c			; fix up current snd buf??
		bpl  +
		lda  sndlst_t
		bmi  +
		sta  sndlst_c
		db("PPP:sndlst reactivated")

	+	lda  loss_count
		beq  +
		db("PPP:lost incoming packet")
		dec  loss_count
		lda  reclst_c
		bmi  +
		db("PPP:strange, buffer is avail")

	+	lda  freelst
		bpl  +
		db("PPP:freelist is empty")

	+	;; check for blocked processes ??

		jsr  lkf_force_taskswitch
		jmp  main_loop

		RELO_JMP(tab_end)
		
;-------------------------------------------------------------------
; variables
;-------------------------------------------------------------------

ppp_go: .byte 0					; <>0 if tcpip layer is up
tcpip_configured: .byte 0		; <>0 if faked IP packet already sent

;added by me(Errol)
		
ppp_status:
		;; 0=init, 1=lcp, 2=auth(pap), 3=ncp, 4=active(IP), 5=down/disabled
		.byte PPPSTAT_INIT

ppp_auth:
		;; 0=no auth, 1=PAP
		.byte 0
				
cur_buf:  
		.byte 0

lcpflg:	.byte 0	; xxx1=got cr, xx1x=sent cr, x1xx=got ack, 1xxx=sent ack
ncpflg:	.byte 0	; " " for ncp
papflg:	.byte 0	; x1=got auth ack, 1x=sent auth requ

lcpry:
ncpry:	.byte 0
lcpty:
ncpty:	.byte 0

lcpident: .byte 0
ncpident: .byte 0

;; lcp config request
lcpcrt:	.byte $01,$00,$00,$04

;; prot reject
lcpprt:	.byte $08,$01,$00,$06,$00,$00

;; ncp config request
ncpcrt: .byte $01,$01,$00,$0a,$03,$06,$00,$00,$00,$00

lcp_timer:
pap_timer:
ncp_timer:	.byte 0

lcplen:	
ncplen:		.byte 0,0

paptrt:		.byte 1
papident:	.byte 0
paplen:		.byte 0,0

papidl:		.byte 4				; length of userid
papid:		.text "test            "	; these need to be NVT ascii!

pappassl:	.byte 4				; length of password
pappass:	.text "pass            "    ; (terminate with CR LF - RFC 959)

recstat2:	.byte $ff		; was 0 !?
recprot:	.byte 0,0
recfcs:		.byte 0,0
sndfcs:		.byte 0,0
sndtemp:	.byte 0

recstat:   .byte 0
loss_count: .byte 0
sndstat:   .byte $40	;was 0
sndlenl:   .byte 0
sndlenh:   .byte 0
sndlock:   .byte 0

user_ipid: .byte $ff

freelst:   .byte 0   ; list of free slots

sndlst_t:  .byte $ff ; top of send-list
sndlst_c:  .byte $ff ; pointer into send-list (to current buffer)
sndlst_b:  .byte $ff ; bottom of send-list

reclst_t:  .byte $ff ; top of receive-list
reclst_c:  .byte $ff ; pointer into receive-list (to current buffer)
reclst_b:  .byte $ff ; bottom of receive-list


moddesc:
	RS232_struct2	; MACRO defined in rs232.h (rs232_{unlock,ctrl,getc,putc})

		;; buf_stat:	
		;;  for buffers part of sndlst: $40=done (sent), $80=waiting to be sent
		;;  for buffers part of reclst: $40=done (filled) non-IP, $41=done, IP
buf_stat:  .buf MAXBUFS

		;; buf_mid:
		;;  pointer to address of buffer memory (hi-byte only)
buf_mid:   .buf MAXBUFS

		;; buf_lenl, buf_lenh:
		;;  length of buffer
buf_lenl:  .buf MAXBUFS
buf_lenh:  .buf MAXBUFS

		;; buf_l2nx:
		;;  pointer to next buffer (for creating linked lists of buffers)
		;;  (<0 means "no next buffer")
buf_l2nx:  .buf MAXBUFS

		;; buf_prol, buf_proh:
		;;  PPP protocol ID related with buffer
buf_protl: .buf MAXBUFS	;protocol lsb ($21 usually, $23 for PAP) 
buf_proth: .buf MAXBUFS ;protocol msb ($00=ip, $80=ncp $c0=lcp) 


;;; fcstab (from RFC1662) for calculating the 16bit FCS
fcstab_lo:
        .byte $00, $89, $12, $9b, $24, $ad, $36, $bf 
        .byte $48, $c1, $5a, $d3, $6c, $e5, $7e, $f7 
        .byte $81, $08, $93, $1a, $a5, $2c, $b7, $3e 
        .byte $c9, $40, $db, $52, $ed, $64, $ff, $76 
        .byte $02, $8b, $10, $99, $26, $af, $34, $bd 
        .byte $4a, $c3, $58, $d1, $6e, $e7, $7c, $f5 
        .byte $83, $0a, $91, $18, $a7, $2e, $b5, $3c 
        .byte $cb, $42, $d9, $50, $ef, $66, $fd, $74 
        .byte $04, $8d, $16, $9f, $20, $a9, $32, $bb 
        .byte $4c, $c5, $5e, $d7, $68, $e1, $7a, $f3 
        .byte $85, $0c, $97, $1e, $a1, $28, $b3, $3a 
        .byte $cd, $44, $df, $56, $e9, $60, $fb, $72 
        .byte $06, $8f, $14, $9d, $22, $ab, $30, $b9 
        .byte $4e, $c7, $5c, $d5, $6a, $e3, $78, $f1 
        .byte $87, $0e, $95, $1c, $a3, $2a, $b1, $38 
        .byte $cf, $46, $dd, $54, $eb, $62, $f9, $70 
        .byte $08, $81, $1a, $93, $2c, $a5, $3e, $b7 
        .byte $40, $c9, $52, $db, $64, $ed, $76, $ff 
        .byte $89, $00, $9b, $12, $ad, $24, $bf, $36 
        .byte $c1, $48, $d3, $5a, $e5, $6c, $f7, $7e 
        .byte $0a, $83, $18, $91, $2e, $a7, $3c, $b5 
        .byte $42, $cb, $50, $d9, $66, $ef, $74, $fd 
        .byte $8b, $02, $99, $10, $af, $26, $bd, $34 
        .byte $c3, $4a, $d1, $58, $e7, $6e, $f5, $7c 
        .byte $0c, $85, $1e, $97, $28, $a1, $3a, $b3 
        .byte $44, $cd, $56, $df, $60, $e9, $72, $fb 
        .byte $8d, $04, $9f, $16, $a9, $20, $bb, $32 
        .byte $c5, $4c, $d7, $5e, $e1, $68, $f3, $7a 
        .byte $0e, $87, $1c, $95, $2a, $a3, $38, $b1 
        .byte $46, $cf, $54, $dd, $62, $eb, $70, $f9 
        .byte $8f, $06, $9d, $14, $ab, $22, $b9, $30 
        .byte $c7, $4e, $d5, $5c, $e3, $6a, $f1, $78 
         
fcstab_hi: 
        .byte $00, $11, $23, $32, $46, $57, $65, $74 
        .byte $8c, $9d, $af, $be, $ca, $db, $e9, $f8 
        .byte $10, $01, $33, $22, $56, $47, $75, $64 
        .byte $9c, $8d, $bf, $ae, $da, $cb, $f9, $e8 
        .byte $21, $30, $02, $13, $67, $76, $44, $55 
        .byte $ad, $bc, $8e, $9f, $eb, $fa, $c8, $d9 
        .byte $31, $20, $12, $03, $77, $66, $54, $45 
        .byte $bd, $ac, $9e, $8f, $fb, $ea, $d8, $c9 
        .byte $42, $53, $61, $70, $04, $15, $27, $36 
        .byte $ce, $df, $ed, $fc, $88, $99, $ab, $ba 
        .byte $52, $43, $71, $60, $14, $05, $37, $26 
        .byte $de, $cf, $fd, $ec, $98, $89, $bb, $aa 
        .byte $63, $72, $40, $51, $25, $34, $06, $17 
        .byte $ef, $fe, $cc, $dd, $a9, $b8, $8a, $9b 
        .byte $73, $62, $50, $41, $35, $24, $16, $07 
        .byte $ff, $ee, $dc, $cd, $b9, $a8, $9a, $8b 
        .byte $84, $95, $a7, $b6, $c2, $d3, $e1, $f0 
        .byte $08, $19, $2b, $3a, $4e, $5f, $6d, $7c 
        .byte $94, $85, $b7, $a6, $d2, $c3, $f1, $e0 
        .byte $18, $09, $3b, $2a, $5e, $4f, $7d, $6c 
        .byte $a5, $b4, $86, $97, $e3, $f2, $c0, $d1 
        .byte $29, $38, $0a, $1b, $6f, $7e, $4c, $5d 
        .byte $b5, $a4, $96, $87, $f3, $e2, $d0, $c1 
        .byte $39, $28, $1a, $0b, $7f, $6e, $5c, $4d 
        .byte $c6, $d7, $e5, $f4, $80, $91, $a3, $b2 
        .byte $4a, $5b, $69, $78, $0c, $1d, $2f, $3e 
        .byte $d6, $c7, $f5, $e4, $90, $81, $b3, $a2 
        .byte $5a, $4b, $79, $68, $1c, $0d, $3f, $2e 
        .byte $e7, $f6, $c4, $d5, $a1, $b0, $82, $93 
        .byte $6b, $7a, $48, $59, $2d, $3c, $0e, $1f 
        .byte $f7, $e6, $d4, $c5, $b1, $a0, $92, $83 
        .byte $7b, $6a, $58, $49, $3d, $2c, $1e, $0f 

tab_end:
		
;;; ************************ initialization *****************************

pr_error2:
		jsr  rs232_unlock
pr_error:
		print_string(term_err_txt)
		lda  #$ff				; return -1
		rts

initialize:
	hibyte_moddesc equ *+2
		bit  moddesc
	hibyte_modstruct equ *+2
		bit  module_struct
		
		lda  #$ff
		ldx  #MAXBUFS-1

	-	sta  buf_l2nx,x
		txa
		dex
		bpl  -

		lda  userzp
		cmp  #2
		bcs  +
		
		jmp  HowTo				; (argc must be >= 2)
		
	+	jsr  get_baudrate
		pha						; (baudcode)
		jsr  get_namenpw		; (set auth name and password)
		
		pla
		sta  userzp				; remember baudcode
		ldx  userzp+1
		jsr  lkf_free			; free argument-memory

		lda  #0
		ldx  #<moddesc
		ldy  hibyte_moddesc
		jsr  lkf_get_moduleif
		bcs  pr_error

		lda  #$80
		sta  recstat			; ignore incomming packets(state to start from)

		ldx  #1					; (ctrl - set receivebyte handler)
		bit  rec_handler
		jsr  rs232_ctrl
		ldx  #2					; (ctrl - set sendbyte handler)
		bit  send_handler
		jsr  rs232_ctrl
		
		lda  userzp				; (baudcode)
		ldx  #0					; (ctrl - setbaud)
		jsr  rs232_ctrl			; set selected baudrate
		bcs  pr_error2			; skip with error

		print_string(welc_txt)

		;; add ppp API to system
		ldx  #<module_struct
		ldy  hibyte_modstruct
		jsr  lkf_add_module
		bcc  +

		jsr  rs232_unlock
		lda  #1
		rts						; exit(1)
		
	+	ldx  #4
		jsr  rs232_ctrl			; start receiver
		
		print_string(txt_running)

		lda  #4
		jsr  lkf_set_zpsize		; need 4 bytes zeropage
		
		jmp  main_loop

		;; -----------------------------------------------------

get_baudrate:
		ldx  #0
sloop:
		ldy  #0
		sty  userzp
	-	iny
		lda  (userzp),y
		bne  -
		iny
		
	-	lda  (userzp),y
		cmp  baud_rates,x
		bne  +
		iny
		inx
		lda  baud_rates,x
		bne  -
		beq  found1

	+ -	lda  baud_rates,x
		beq  +
		inx
		bne  -

	+ -	inx
		inx
		lda  baud_rates,x
		bne  sloop

HowTo:
		print_string(txt_howto)
		lda  #1
		jmp  lkf_suicide

found1:	lda  (userzp),y
		bne  -
		lda  baud_rates+1,x
		rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; need to add passing of userid/password
	;; from commandline for PAP (or similar)
		
	-	sta  ppp_auth			; force pap off
		rts
		
get_namenpw:
		iny						; set y to beginning of username (if any)
		lda  (userzp),y
		beq  -
		sta  ppp_auth			; (pap on)
		
		ldx  #0
	-	lda  (userzp),y
		beq  +
		sta  papid,x
		iny
		inx
		cpx  #16
		bne  -					; (limit to 16 chars)
	-	iny
		lda  (userzp),y
		bne  -
	+	stx  papidl				; set length of ID (username)
		
		iny						; set y to beginning of password
		lda  (userzp),y
		beq  HowTo
		
		ldx  #0
	-	lda  (userzp),y
		beq  +
		sta  pappass,x
		iny
		inx
		cpx  #16
		bne  -					; (limit to 16 chars)
		SKIP_BYTE 			; skip iny
	-	iny
		lda  (userzp),y
		bne  -
	+	stx  pappassl			; set length of ID (username)

		iny
		lda  (userzp),y
		bne  HowTo				; no further arguments!
		
		rts

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

		
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

		;; print IP address to stdout
print_ip:
		lda  #252				; 256-4
		sta  userzp
		bne  +

	-	lda  #"."
		jsr  putc
		
	+	ldx  userzp
		lda  ncpcrt+6-252,x		; IP address sent in IPCP-ConfReq message
		jsr  print_decimal
		inc  userzp
		bne  -

		rts

		;; send a faked IP packet, it is used by the TCP/IP layer
		;; to (probably) learn the machines IP-address
		
send_faked_ip:
		;; write IP address into faked packet
		
		ldx  #$03
	-	lda  ncpcrt+6,x
		sta  ownip,x			; set IP-address in fake-packet
		dex
		bpl  -
		
		;; calculate IP checksum
		clc
		ldy  #20
		ldx  #0
		stx  userzp+1

	-	dey
		txa
		adc  dat_fake,y
		tax
		dey
		lda  userzp+1
		adc  dat_fake,y
		sta  userzp+1
		tya
		bne  -
		
		bcc  +					; add carry to sum
	-	inx
		bne  +
		inc  userzp+1
		beq  -
		
	+	ldy  #10				; write sum into IP-header
		lda  userzp+1
		eor  #$ff
		sta  dat_fake,y
		txa
		eor  #$ff
		iny
		sta  dat_fake,y

		;; steal empty packet from reclst (this is ugly!)
	-	cli
		sei						; (doesn't help if there are NMIs!)
		ldx  reclst_c
		bmi  -
		lda  buf_l2nx,x
		bmi  -
		tax
		lda  buf_l2nx,x
		bmi  -
		tay
		;; take this one
		lda  buf_l2nx,y
		sta  buf_l2nx,x
		cli						; now we're save
		tya
		
		;; fill packet with faked IP data
		
		tax
		lda  buf_mid,x
		sta  userzp+1
		lda  #0
		sta  userzp
		ldy  #19
	-	lda  dat_fake,y
		sta  (userzp),y
		dey
		bpl  -
		lda  #20
		sta  buf_lenl,x
		lda  #0
		sta  buf_lenh,x
		lda  #$41				; mark as filled with IP packet
		sta  buf_stat,x

		;; queue packet back into reclst (top of queue!)
		sei
		ldy  reclst_t			; (old top element)
		stx  reclst_t			; this is the new top element
		bpl  +
		stx  reclst_b
	+	tya
		sta  buf_l2nx,x			; new element links to old top element
		cli

		rts
		
		RELO_END ; no more code to relocate

		;; -----------------------------------------------------

		;; faked IP packet used to carry the IP address to the TCP/IP layer
dat_fake:
		.word $0045,$1400
		.word 0,0
		.word 0,0
		.word 0,0
ownip:
		.word 0,0

txt_howto:
		.text "usage:  ppp <baudrate> [<id> <pw>]",$0a
		.text "  baudrates: 300 600 1200 2400",$0a
		.text "   4800 9600 19200 38400 57600",$0a
		.text "  id: ppp user id",$0a
		.text "  pw: ppp password",$0a,0

txt_running:
		.text "up and running"
		.byte $0a,$00

welc_txt:
		.text "PPP - packet driver V0.1alpha"
		.byte $0a,$00
		
term_err_txt:
		.text "Error initializing RS232-interface"
		.byte $0a,$00

baud_rates:
		.text "300"  : .byte $00, RS232_baud300
		.text "1200" : .byte $00, RS232_baud1200
		.text "2400" : .byte $00, RS232_baud2400
		.text "4800" : .byte $00, RS232_baud4800
		.text "9600" : .byte $00, RS232_baud9600
		.text "19200" : .byte $00, RS232_baud19200
		.text "38400" : .byte $00, RS232_baud38400
		.text "57600" : .byte $00, RS232_baud57600
		.byte 0
		
dec_tab:
		.byte 10,100
		
link_up_txt:
		.text "ppp connection established",$0a
		.text " IP-address=",0
		
link_down_txt:
		.text "ppp connection terminated",$0a,0
		
end_of_code:
