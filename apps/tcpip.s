; For emacs: -*- MODE: asm; tab-width: 4; -*-

; TCP/IP stack for LNG
;
; needs packet driver installed (eg. slip)
; the interface of the packet driver
;   putpack  < a=address, x/y=length, c: 0=empty/1=filled
;           putpack may return with error (pack not sent) but
;           has to "mfree" the memory used by the packet.
;   getpack  > a=address, x/y=length, c=error

;; #define DEBUG

#include <stdio.h>
#include <slip.h>
#include <kerrors.h>
#include <debug.h>

; Constants you have to use, when calling TCP/IP routines

		tcp_clock equ lk_systic+1

#define IPV4_TCP    $01
#define IPV4_UDP    $02
#define IPV4_ICMP   $03

#define E_CONTIMEOUT $80
#define E_CONREFUSED $81
#define E_NOPERM     $82
#define E_NOPORT     $83
#define E_NOROUTE    $84
#define E_NOSOCK     $85
#define E_NOTIMP     lerr_notimp
#define E_PROT       $87
#define E_PORTINUSE  $88

;tcp_clock equ 161     ; counter that is incremented every 4 seconds

#define BUFNUM 16		; number of buffers (each up to 256*bufmax bytes!)
#define SOCKNUM 8		; number of sockets
#define BUFPREMAL 6		; number of pre-malloced buffers
#define BUFSIZEMAX 4	; max size of buffers in pages (256 byte)
#define SOCKBUFS 1		; max number of used buffers per socket
#define CONTIMEOUT 20	; connect-timeout minutes*15

#define TCP_LISTEN       $01
#define TCP_SYN_SENT     $42
#define TCP_SYN_RECEIVED $43
#define TCP_ESTABLISHED  $c4
#define TCP_FIN_WAIT1    $45
#define TCP_FIN_WAIT2    $46
#define TCP_CLOSE_WAIT   $87
#define TCP_CLOSING      $08
#define TCP_LAST_ACK     $09
#define TCP_TIMEWAIT     $0a

#define BUFMARKER	memown_netbuf

;------------------------------------------------------------------------
; magic header, API to other processes
;------------------------------------------------------------------------

		start_of_code equ $1000

		.org start_of_code
        
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		jmp  initialize

		RELO_JMP(+)

packet_api:
		SLIP_struct3			; Macro defined in slip.h
		
module_struct:
		.asc "ip4"				; module indentifier
		.byte 6					; module interface size
		.byte 1
		.byte 1
		.word 0
	+	jmp  ipv4_lock
		jmp  ipv4_unlock
		jmp  ipv4_connect
		jmp  ipv4_listen
		jmp  ipv4_accept
		jmp  ipv4_sockinfo
		jmp  ipv4_tcpinfo

ipv4_lock:
		clc
		rts						; alway succeed

ipv4_unlock:
		;; <== should do something in here!
		clc
		rts
		
;------------------------------------------------------------------------
; packet delivery subsystem
;------------------------------------------------------------------------

#ifdef DEBUG
	-	db("*** sent illegal MID")
		pla
		pla
		rts

	-	db("*** sent illegal buffer")
		rts
#endif

; send packet X
;         < X=buf

sendpacket:
#ifdef DEBUG
		cpx  #BUFNUM
		bcs  -
#endif
		txa
		pha
		inc  packid+1			; next packet ID
		bne  +
		inc  packid
	+	lda  buf_mid,x
		pha
#ifdef DEBUG
		tay
		lda  lk_memown,y
		cmp  #BUFMARKER
		bne  --
#endif
		ldy  buf_lenh,x
		lda  buf_lenl,x
		tax
		pla
		db("Putpack")
		sec
		jsr  slip_putpacket		; call lower layer A=MID, X/Y=length, c=1
		pla
		tax						; recall number of buffer
		jmp  addtofreelst

		
; look for received packets and allocate
; memory for new packets

	-	jmp  allocate_memory

	-	cli
		pla
		pla
		tax
		jsr  lkf_pfree		 ; throw away
		rts

pack_poll:
		lda  freelst
		bpl  +

		;; can't receive packet because no free slot available 
		db("free list is empty!")
		rts

	+	jsr  slip_getpacket		; call lower layer, get packet
		bcs  --					; no new packet received

		dec  availbuf			; (lower level has lost a receive buffer)

		cmp  #0
		beq  --				; new packet ? not really (address=0x00XX)
							; (this is a small workaround for the ppp driver)
		
		pha						; put A,X on stack (is MID and length-lo)
		txa
		pha

		sei						; get and remove item from
		ldx  freelst			; free-list (Atomic!)
		bmi  -					; (error - should never happen)
		lda  buf_l2nx,x
		sta  freelst
		cli

		db("Getpack")
		tya
		sta  buf_lenh,x			; slot->length hi-byte
		pla
		sta  buf_lenl,x			; slot->length lo-byte
		pla
		sta  buf_mid,x			; slot->MID (hi-byte of address)
		lda  #$ff
		sta  buf_l2nx,x			; slot->next=NIL
		stx  userzp+4			; remember buf

		lda  buf_lenl,x			; look for unused pages
		beq  +
		iny
	+	lda  buf_mid,x
	-	tax
		dey
		beq  +
		lda  lk_memnxt,x
		bne  -
		jmp  lkf_panic			; should never happen

	+	lda  lk_memnxt,x
		beq  +					; no need to free something
		tay
		lda  #0
		sta  lk_memnxt,x
		tya
		tax
		jsr  lkf_pfree			; free unused pages

	+	ldx  userzp+4			; recall number of buffer

		sei						; queue new packet in TCP-list (Atomic!)
		ldy  iplst+1			; (new last item)

		bpl  +
		stx  iplst
		bmi  ++
	+	txa
		sta  buf_l2nx,y
	+	stx  iplst+1
		cli
		db(" -> ip")

		;; allocate new buffer for receiving packets (if neccessary)
allocate_memory:
		lda  availbuf
#ifdef DEBUG
		sta  debug3+999
		bpl  +
		db("Availbuf went negative")
		ldx  #0
		stx  availbuf
        +
#endif
		cmp  #BUFPREMAL
		bcs  +					; enough buffers available, then skip

		lda  #BUFSIZEMAX
		ldx  #BUFMARKER
		ldy  #0
		jsr  lkf_mpalloc		; allocate internal memory (BUFSIZEMAX pages)
		txa
		bcs  ++					; (out of memory)
		inc  availbuf
		ldx  #0
		ldy  #BUFSIZEMAX
		db("Premalloc")
		clc
		jsr  slip_putpacket		; call lower layer - pass empty buffer
		bcc  +
		;; on error the lower layer MUST free the allocated memory
		db("got error from putpack")
		dec  availbuf
		;lda  #BUFPREMAL
		;sta  availbuf			; adapt availbuf counter, if packetdriver
	+	rts						; can't handle that many receive buffers

	+	db("can't alloc buffer")
		rts


		;; free buffer (X=buf) and add item to free-list
		
#ifdef DEBUG
-		db("tried to free illegal buffer")
		rts
#endif
		
killbuffer:
#ifdef DEBUG
		cpx  #BUFNUM
		bcs  -
#endif
		txa
		pha
		lda  buf_mid,x
		tax
		jsr  lkf_pfree			; free memory used for the buffer
		pla
		tax

		;; add buffer (number in X) to list of free buffers
		;; (Atomic!)
		
addtofreelst:
		sei
		lda  freelst
		sta  buf_l2nx,x
		stx  freelst
		db("Buffer freed")
	-	cli
		rts

; free all memory used by a socket.
; (userzp+2=socket)

freesocketmemory:
		db("Freesocketmemory")
	-	ldy  userzp+2
		sei
		ldx  reclstt,y
		bmi  --
		inc  recposh,x
		lda  buf_l2nx,x
		sta  reclstt,y
		bpl  +
		sta  reclstb,y
	+	cli
		jsr  killbuffer
		jmp  -

; allocate buffer and remove item from
; free-list
;  < A=length of buffer
;  > userzp=pointer to buffer, Y=0, userzp+3=buf, c=error
 
getbuffer:
		bit  freelst
		bmi  ++
		ldx  #BUFMARKER				; ??????????
		ldy  #0
		jsr  lkf_mpalloc
		txa
		sei
		bcs  ++
		ldx  freelst
		bmi  +
		sta  buf_mid,x
		sta  userzp+1
		lda  buf_l2nx,x
		sta  freelst
		cli
		stx  userzp+3
		ldy  #0
		sty  userzp
		rts

	+	tax
		jsr  lkf_pfree
	+	sec
		cli
		rts

; calculate sum of IP header
;  < X=buf
;  > .userzp+6=sum

sumheader:
		clc
		lda  buf_mid,x
		sta  userzp+5
		ldy  buf_offs,x      ; points to end of IP header
		ldx  #0
		stx  userzp+7
		stx  userzp+4

	-	dey
		txa
		adc  (userzp+4),y
		tax
		dey
		lda  userzp+7
		adc  (userzp+4),y
		sta  userzp+7
		tya
		bne  -

		stx  userzp+6

sumend:   
		bcc  +					; add carry to sum
	-	inc  userzp+6
		bne  +
		inc  userzp+7
		beq  -
	+	rts

; calculate sum of packet data (not including IP-header)
;  < X=buf

sumdata:  
		clc
		lda  buf_mid,x
		sta  userzp+5
		lda  #0
		sta  userzp+4
		sta  userzp+6
		sta  userzp+7
		ldy  buf_offs,x
		txa
		pha						; remember buf
		lda  buf_lenh,x
		beq  +

		;; check pages 1..n-1

		pha						; remember n
		ldx  userzp+6

	-	iny
		txa
		adc  (userzp+4),y
		tax
		dey
		lda  (userzp+4),y
		adc  userzp+7
		sta  userzp+7
		iny
		iny
		bne  -

	-	stx  userzp+6
		inc  userzp+5
		pla						; check n
		tay
		dey
		beq  +

		tya
		pha
		ldy  #0

	-	dey
		txa
		adc  (userzp+4),y
		tax
		dey
		lda  (userzp+4),y
		adc  userzp+7
		sta  userzp+7
		tya
		bne  -

		beq  --

	+	pla						; X=buf
		tax

		php						; last page to check
		sec
		tya
		eor  #255
		adc  buf_lenl,x			; A=buf_lenl - Y
		bcc  +					; skip if A<=0
		beq  +
		tax
		plp

	-	dex
		beq  ++
		iny
		lda  (userzp+4),y
		adc  userzp+6
		sta  userzp+6
		dey
		lda  (userzp+4),y
		adc  userzp+7
		sta  userzp+7
		iny
		iny
		dex
		bne  -

		SKIP_BYTE
	+	plp
		jmp  sumend

	+	lda  userzp+6		   ; odd length of packet
		adc  #0
		sta  userzp+6
		lda  (userzp+4),y
		adc  userzp+7
		sta  userzp+7
		jmp  sumend

;------------------------------------------------------------------------
; IP MODUL
;------------------------------------------------------------------------

	-	cli
		rts

ip_modul:
		sei						; remove top item from TCP-list
		ldx  iplst
		bmi  -					; skip if nothing queued
		lda  buf_l2nx,x
		sta  iplst
		bpl  +
		sta  iplst+1
	+	cli

		stx  userzp				; (userzp=buf)
		lda  buf_mid,x
		sta  userzp+3
		ldy  #0
		sty  userzp+2			; (.userzp+2=buffer)
		sty  userzp+4			; (.userzp+4=$0000)
		sty  userzp+5
		lda  (userzp+2),y		; look at protocol version
		and  #$f0
		cmp  #$40				; = ipv4 ?
		beq  ++

throwaway:
		db("IP-throwaway")
		inc  errcnt+1
		bne  +
		inc  errcnt
	+	ldx  userzp
		jmp  killbuffer

	+	lda  (userzp+2),y		; get size of IP header
		and  #$0f
		asl  a
		asl  a
		sta  buf_offs,x			; is pointer to sub header

		ldy  #3					; check IP-length field
		lda  (userzp+2),y
		cmp  buf_lenl,x
		bne  throwaway
		dey
		lda  (userzp+2),y
		cmp  buf_lenh,x
		bne  throwaway

		jsr  sumheader			; check IP sum
		ldx  userzp				; (X=buf for throwaway)
		lda  userzp+6
		and  userzp+7
		cmp  #$ff
		bne  throwaway

		ldy  #16				; check dest.IP field
		lda  (userzp+2),y		; (must match my own IP)
		cmp  ownip
		bne  throwaway2
		iny
		lda  (userzp+2),y
		cmp  ownip+1
		bne  throwaway2
		iny
		lda  (userzp+2),y
		cmp  ownip+2
		bne  throwaway2
		iny
		lda  (userzp+2),y
		cmp  ownip+3
		beq  +

throwaway2:						; IP address mismatch, might have to learn
		lda  ownip				; my IP address at this point
		ora  ownip+1
		ora  ownip+2
		ora  ownip+3
	-	bne  throwaway			; already have my IP, discard packet

		ldy  #16				; learn own IP from
		lda  (userzp+2),y		; dest field of incoming packet
		sta  ownip
		iny
		lda  (userzp+2),y
		sta  ownip+1
		iny
		lda  (userzp+2),y
		sta  ownip+2
		iny
		lda  (userzp+2),y
		sta  ownip+3

	+	ldy  #6					; check for IP fragments (not supported)
		lda  (userzp+2),y		; discard if either MF (more fragments) set
		and  #$3f				; or FramentOffset>0 (indicates last fragment)
		iny						; (Fix by Alexander Bluhm)
		ora  (userzp+2),y
		bne  -

		lda  #$ff
		sta  buf_l2nx,x

		ldy  #9					; check protocol field
		lda  (userzp+2),y
		cmp  #1
		beq  isicmp				; pass to ICMP-modul
		cmp  #6
		beq  istcp				; pass to TCP-modul
		cmp  #17
		bne  -					; unknown, then throwaway

		;; pass to  UDP-modul

		sei
		ldy  udplst+1
		bpl  +
		stx  udplst
		bmi  ++
	+	txa
		sta  buf_l2nx,y
	+	stx  udplst+1
		cli
		db("ip -> udp")
		rts

isicmp:	sei
		ldy  icmplst+1
		bpl  +
		stx  icmplst
		bmi  ++
	+	txa
		sta  buf_l2nx,y
	+	stx  icmplst+1
		cli
		db("ip -> icmp")
		rts

istcp:	sei
		ldy  tcplst+1
		bpl  +
		stx  tcplst
		bmi  ++
	+	txa
		sta  buf_l2nx,y
	+	stx  tcplst+1
		cli
		db("ip -> tcp")
		rts

;------------------------------------------------------------------------
; TCP-modul
;------------------------------------------------------------------------

; read one byte from a TCP stream
;  < X=socket
;  > A=byte, c=error

getbyte:
		ldy  reclstt,x
		bmi  e_tryagain
		lda  buf_mid,y
		clc
		adc  buf_offsh,y
		sta  [+]+2
		lda  buf_offs,y
		sta  [+]+1
		adc  #1
		sta  buf_offs,y
		lda  buf_offsh,y
		adc  #0
		sta  buf_offsh,y
		cmp  buf_lenh,y
		bne  +
		lda  buf_offs,y
		cmp  buf_lenl,y
		beq  ++
	- +	lda  $ffff
		clc
		rts

	+	inc  recposh,x			; increase available counter
		tya						; and switch to next
		pha						; rec-buffer
		lda  buf_l2nx,y
		sta  reclstt,x
		bpl  +
		sta  reclstb,x
	+	pla
		tax
		jsr  -
		pha
		jsr  killbuffer
		pla
		db("switched to next recbuf")
		clc
		rts

e_tryagain: 
		lda  #0
		sec
		rts

; write one byte to a TCP stream
;  < A=byte, X=socket
;  > c=error

putbyte:
		ldy  sockstat,x			; write enabled ?
		bpl  e_tryagain
		ldy  sndbufstat,x
		bmi  e_tryagain			; sendbuffer full ?
		sei
		ldy  sndbufpg,x
		sty  [+]+2
		ldy  sndwrnx,x
	+	sta  $ff00,y
		iny
		tya
		sta  sndwrnx,x
		cmp  sndrdnx,x
		clc
		beq  +
		rts

	+	lda  sndbufstat,x
		ora  #$c0				; bit7+6 = full+push
		sta  sndbufstat,x
		rts

; generate standard header of TCP packets
;  < X=socket, userzp=buffer


setnormipdat:
		ldy  #0
		lda  #$45				; protocol version+header length
		sta  (userzp),y
		tya
		iny
		sta  (userzp),y			; type of service
		;;   total length not set here !!!!
		ldy  #4
		lda  packid				; packet id
		sta  (userzp),y
		lda  packid+1
		iny
		sta  (userzp),y
		lda  #$40				; df+mf+fragment offset
		iny
		sta  (userzp),y
		lda  #0
		iny
		sta  (userzp),y
		lda  #$ff				; time to live
		iny
		sta  (userzp),y
		lda  #6					; protocol (tcp)
		iny
		sta  (userzp),y
		lda  #0					; header checksum
		iny
		sta  (userzp),y
		iny
		sta  (userzp),y
		lda  ownip				; source address (=own ip)
		iny
		sta  (userzp),y
		lda  ownip+1
		iny
		sta  (userzp),y
		lda  ownip+2
		iny
		sta  (userzp),y
		lda  ownip+3
		iny
		sta  (userzp),y
		lda  remipa,x			; remote ip....
		iny
		sta  (userzp),y
		lda  remipb,x
		iny
		sta  (userzp),y
		lda  remipc,x
		iny
		sta  (userzp),y
		lda  remipd,x
		iny
		sta  (userzp),y
		rts

; set timeout value (4*4=16 seconds)
;  < x=socket

settimeout:
		sta  sockstat,x
		lda  tcp_clock
		clc
		adc  #4
		adc  #0
		sta  timeout,x
		rts

; generate standard TCP header
;  < x=socket, userzp=buffer, y=offset

setnormtcpdat:
		lda  localporth,x		; local port
		sta  (userzp),y
		lda  localportl,x
		iny
		sta  (userzp),y
		lda  remporth,x			; remote port
		iny
		sta  (userzp),y
		lda  remportl,x
		iny
		sta  (userzp),y
		lda  sndunaa,x			; sequence number
		iny
		sta  (userzp),y
		lda  sndunab,x
		iny
		sta  (userzp),y
		lda  sndunac,x
		iny
		sta  (userzp),y
		lda  sndunad,x
		iny
		sta  (userzp),y
		lda  rcvnxta,x			; acknowledgment number
		iny
		sta  (userzp),y
		lda  rcvnxtb,x
		iny
		sta  (userzp),y
		lda  rcvnxtc,x
		iny
		sta  (userzp),y
		lda  rcvnxtd,x
		iny
		sta  (userzp),y
		lda  #$50				; data-offset
		iny
		sta  (userzp),y
		lda  sndbufstat,x		; flags
		and  #$48
		beq  +
		eor  sndbufstat,x
		ora  #$08
		sta  sndbufstat,x
		lda  #$08				; psh
	+	ora  #$10				; ack
		iny
		sta  (userzp),y
		iny						; window

		lda  freelst
		ora  recposh,x			; running out of buffs ?
		bmi  ++					; then send win=0 !

		lda  sndbufstat,x		; clear "snd win0"
		and  #$df
		sta  sndbufstat,x

		txa
		pha
		lda  recposh,x
		sec
		sbc  #1
		ldx  freelst
		ora  buf_l2nx,x
		asl  a
		pla
		tax
		bcs  +					; win=1*limit

		lda  #>1880				; win=1880 (2*limit)
		sta  (userzp),y
		lda  #<1880
		bne  +++

	+	lda  #>940				; win=940 (1*limit)
		sta  (userzp),y
		lda  #<940
		bne  ++

	+	lda  sndbufstat,x		; win=0
		ora  #$20
		sta  sndbufstat,x
		lda  #0
		sta  (userzp),y

	+	iny
		sta  (userzp),y
		lda  #0					; chksum
		iny
		sta  (userzp),y
		iny
		sta  (userzp),y
		iny						; urgptr
		sta  (userzp),y
		iny
		sta  (userzp),y
	-	rts

; send packet filled with data collected with
; putbyte calls.
;  < userzp+2=socket

senddatapacket:
		db("send datapacket")
		ldx  userzp+2
		lda  sndbufstat,x
		and  #128
		asl  a
		bcs  +					; skip on full buffer
		sec
		lda  sndwrnx,x
		sbc  sndrdnx,x
		cmp  #216				; 1 or 2 pages needed for packet ?
	+	sta  userzp+6			; store lo byte of length
		lda  #1
		adc  #0
		sta  userzp+7			; and hi byte
		jsr  getbuffer			; allocate buffer of that size
		;;  > userzp=buffer, Y=0, userzp+3=buf, c=error
		bcs  -
		lda  userzp+7
		sbc  #0
		sta  buf_lenh,x			; calculate size of packet (hi)
		ldy  #2
		sta  (userzp),y
		lda  userzp+6
		adc  #39
		sta  buf_lenl,x			; ...(lo)
		iny
		sta  (userzp),y
		lda  #20
		sta  buf_offs,x
		ldx  userzp+2
		lda  sndbufstat,x
		and  #$ef
		sta  sndbufstat,x
		jsr  setnormipdat		; create standard headers
		ldy  #20
		jsr  setnormtcpdat

		lda  sndwrnx,x
		sta  userzp+5
		lda  sndrdnx,x
		sta  userzp+4
		cmp  userzp+5
		bne  +
		lda  sndbufstat,x
		bpl  tcp_eod
	+	;   there will be new unacked data
		;;   so activate timeout
		jsr  settimeout+3
		lda  sndbufpg,x
		sta  [+]+2
		lda  #40
		sta  userzp
		ldy  #0
		ldx  userzp+4

      - + lda  $ff00,x			; copy data from rec-buf into
		sta  (userzp),y			; TCP-packet
		iny
		inx
		cpx  userzp+5
		bne  -

		ldy  #0
		sty  userzp
tcp_eod:  jsr  tcpsumsetup		; calculate checksum
		jsr  sendpacket			; and send packet
		clc
		rts

; calculate TCP checksum
;  < .userzp=buffer, userzp+3=buf

sumtcp:
		ldx  userzp+3
		jsr  sumdata
		;;   add pseudo header to chksum
		sec
		ldx  userzp+3
		lda  buf_lenl,x
		sbc  #14
		sta  userzp+4
		lda  buf_lenh,x
		sbc  #0
		sta  userzp+5			; packet length is also part of checksum
		clc
		lda  userzp+6
		adc  userzp+4
		sta  userzp+6
		lda  userzp+7
		adc  userzp+5
		sta  userzp+7
		ldy  #19

	-	lda  (userzp),y			; add pseudo header
		adc  userzp+6
		sta  userzp+6
		dey
		lda  (userzp),y
		adc  userzp+7
		sta  userzp+7
		dey
		tya
		eor  #11
		bne  -

		jmp  sumend

; calculate TCP checksum and update checksum field in packet
;  < userzp=buffer, userzp+3=buf

tcpsumsetup:
		ldx  userzp+3
		lda  #0
		sta  userzp
		jsr  sumheader			; calculate IP checksum
		ldy  #10				; write sum into IP-header
		lda  userzp+7
		eor  #$ff
		sta  (userzp),y
		lda  userzp+6
		eor  #$ff
		iny
		sta  (userzp),y
		jsr  sumtcp				; calculate TCP checksum
		ldx  userzp+3			; write sum into TCP header
		lda  buf_offs,x
		sta  userzp
		ldy  #16
		lda  userzp+7
		eor  #$ff
		sta  (userzp),y
		lda  userzp+6
		eor  #$ff
		iny
		sta  (userzp),y
		rts

; extract data from incomming TCP packets
;  < userzp+2=socket, userzp+3=buf, userzp=buffer
;  > c = 0 : A > $00 new information in this packet
;    c = 0 : A = $00 : packet is okay, but no new information in it
;    c = 1 : packet's sequencenumber is invalid
;    if packet is passed to another packet queue userzp+3 inreased by $80 !!

extractdata:
		ldx  userzp+3
		lda  buf_offs,x
		sta  userzp
		ldy  #13
		lda  (userzp),y
		sta  tcpflags			; remember flags for later
		ldx  userzp+2
		ldy  #7
		sec						; outgoing ack.num - incomming seq.num
		lda  rcvnxtd,x
		sbc  (userzp),y
		sta  userzp+4
		dey
		lda  rcvnxtc,x
		sbc  (userzp),y
		sta  userzp+5
		dey
		lda  rcvnxtb,x
		sbc  (userzp),y
		sta  userzp+6
		dey
		lda  rcvnxta,x
		sbc  (userzp),y
		beq  _extract2			; result is >= 0 !
		;; result is <0 for future use ??
		cmp  #255
		bne  _noextr
		cmp  userzp+6
		bne  _noextr			; skip if the difference is too big
		lda  userzp+5
		cmp  #$f8				; more than 2048 bytes ahead, then send RST
		bcc  _noextr			; (winsize is less than 1900 bytes!)

		;;   this packet may be stored for
		;;   future use (maybe 2 packets arrived
		;;   out of order or too fast) (not implemented!)
		lda  sndbufstat,x
		ora  #$00
		sta  sndbufstat,x
		db("packet from future")

		;;  jmp$<dontpanic
		;;   disabled for now
		;;  ldyx<queueddatlst
		;;  bmi$<storeit
		;;  lday<buf_mid
		;;  sta$<userzp+7
		;;  lday<buf_offs
		;;  sta$<userzp+6
		;;  ldy##7
		;;  ldii<userzp
		;;  - ii<userzp+6
		;;  dey
		;;  ldii<userzp
		;;  - ii<userzp+6
		;;  dey
		;;  ldii<userzp
		;;  - ii<userzp+6
		;;  dey
		;;  ldii<userzp
		;;  - ii<userzp+6
		;;  bpl$<_noextr
		;;  ldax<queueddatlst
		;;  sta$!!undefined!!
		;;  <storeit
		;;  lda$<userzp+3
		;;  stax<queueddatlst
		;;  sec
		;;  rts
		jmp  _discard

_noextr:  db("Packet with illegal seq.num")
		sec
		rts

_discard:
		db("Packet without data")
		lda  #0
		clc
		rts

_extract2:
		lda  userzp+6
		bne  _noextr			; discard, if difference too big
		
 ;;		lda  tcpflags
 ;;		and  #$03				; mask flags that count (syn,fin)
 ;;		lsr  a
 ;;		adc  #0
 ;;		sta  userzp+6
 ;;		eor  #$ff				; and subtract from new-byte-offset
 ;;		sec
 ;;		adc  userzp+4
 ;;		sta  userzp+4
		lda  userzp+5
 ;;		adc  #$ff
 ;;		sta  userzp+5
		
		cmp  #4					; more than 4*256 bytes behind, then skip
		bcs  _discard
		
		ldy  #12
		lda  (userzp),y			; calculate offset to new data
		and  #$f0
		lsr  a
		lsr  a
		ldy  userzp+3
		adc  userzp
		adc  userzp+4
		sta  buf_offs,y
		lda  userzp+5
		adc  #0
		sta  buf_offsh,y
		cmp  buf_lenh,y      ; new informations in packet ?
		bcc  +		     ; (yes)
		bne  _discard        ; (no)
		lda  buf_offs,y
		cmp  buf_lenl,y
		beq  nulldata        ; (no, seems to be a resent packet)
		bcs  _discard        ; (no)
	+	lda  sockipid,x
		bmi  _noextr         ; received data for a terminated process
						 ; treat like a stray packet (send rst back)

		;; now check if there is new data in this packet

 ;;		clc
		lda  buf_offs,y
 ;;		adc  userzp+6
 ;;		sta  buf_offs,y
 ;;		bcc  +
 ;;		lda  buf_offsh,y
 ;;		adc  #1
 ;;		sta  buf_offsh,y
 ;;		lda  buf_offs,y
 ;; +
		cmp  buf_lenl,y
		bne  isokgoon
		lda  buf_offsh,y
		cmp  buf_lenh,y
		bne  isokgoon

		lda  #$ff
		clc
		rts		        ; only flags delivered with this packet

nulldata: lda  userzp+4
		ora  userzp+5
		bne  +
		lda  tcpflags
		and  #$03
		bpl  ++
	+	jsr  setflag
	+	clc
		lda  #0
		rts

isokgoon: ;   decrement available counter and add packet to rcv-list
		db("TCP -> reclst")
		dec  recposh,x
		;;   put in receive-list
		lda  userzp+3
		sei
		ldy  reclstb,x
		bmi  +
		sta  buf_l2nx,y
	+	sta  reclstb,x
		ldy  reclstt,x
		bpl  +
		sta  reclstt,x
		;;   refresh rcv-nxt
	+	tay
		lda  #$ff
		sta  buf_l2nx,y			; keep IRQ disabled until "computeack"

		tya
		ora  #$80
		sta  userzp+3			; mark buf ("passed")

		sec						; calculate number of extracted bytes
		lda  buf_lenl,y
		sbc  buf_offs,y
		sta  userzp+4
		lda  buf_lenh,y
		sbc  buf_offsh,y
		sta  userzp+5
		clc		        ; increase ack.num
		lda  rcvnxtd,x
		adc  userzp+4
		sta  rcvnxtd,x
		lda  rcvnxtc,x
		adc  userzp+5
		sta  rcvnxtc,x
		bcc  setflag
		inc  rcvnxtb,x
		bne  +
		inc  rcvnxta,x
	+	clc

setflag:  lda  sndbufstat,x    ; set flag 'ACK needed'
		ora  #$10
		sta  sndbufstat,x
		rts

; check ACK field of incomming packets
; and remove acked data from buffer
;  < userzp+2=socket, userzp+3=buf, userzp=buffer (+TCP)

	-	cli
		rts

computeack:
		ldy  #13
		lda  (userzp),y         ; check ACK flag
		and  #$10
		beq  -		     ; nothing acked, then exit
		ldy  #11
		ldx  userzp+2
		sec
		lda  (userzp),y
		sbc  sndunad,x
		sta  userzp+4
		dey
		lda  (userzp),y
		sbc  sndunac,x
		sta  userzp+5
		dey
		lda  (userzp),y
		sbc  sndunab,x
		sta  userzp+6
		dey
		lda  (userzp),y
		sbc  sndunaa,x
		cli
		beq  +
		cmp  #255
		bne  unsyned
		cmp  userzp+6
		bne  unsyned
		clc		        ; not acked new data
		rts

	+	lda  userzp+6
		bne  unsyned
		lda  userzp+5
		beq  +		     ; acked less than 256 bytes
		cmp  #2
		bcs  unsyned
		lda  userzp+4
		bne  unsyned
		lda  sndbufstat,x    ; acked 256 bytes
		bpl  unsyned
		and  #$77
		sta  sndbufstat,x
		;;   all acked so skip timeout
		;;     and clr rem.pushflag
		lda  #0
		sta  timeout,x       ; all acked, no timeout
		jmp  _ack256

unsyned:  db("Unsynced packet")
		sec
		rts

	+	lda  sndbufstat,x
		bmi  +
		sec
		lda  sndwrnx,x
		sbc  sndrdnx,x
		cmp  userzp+4
		bcc  unsyned
	+	clc
		lda  sndrdnx,x
		adc  userzp+4
		sta  sndrdnx,x
		cmp  sndwrnx,x
		bne  +
		lda  sndbufstat,x
		bmi  +
		;;   all acked so skip timeout
		lda  #0
		sta  timeout,x
		;;     ..and clr rem.pushflag
		lda  sndbufstat,x
		and  #$f7
		sta  sndbufstat,x
	+	lda  userzp+4
		beq  +
		lda  sndbufstat,x
		and  #$7f
		sta  sndbufstat,x
	+	clc
		lda  sndunad,x
		adc  userzp+4
		sta  sndunad,x
		bcc  +
_ack256:  inc  sndunac,x
		bne  +
		inc  sndunab,x
		bne  +
		inc  sndunaa,x
	+	lda  #255
		clc
	-	rts

; JOB: active open (TCP connection)
;  userzp+2=socket

activeopen:
		db("JOB activeopen")
		lda  #1		    ; get buffer for initial packet
		jsr  getbuffer
		bcs  -
		lda  #44		   ; 40+4 bytes
		ldy  #3
		sta  buf_lenl,x
		sta  (userzp),y
		dey
		lda  #0
		sta  buf_lenh,x
		sta  (userzp),y
		lda  #20
		sta  buf_offs,x
		ldx  userzp+2
		jsr  setnormipdat
		ldy  #20
		jsr  setnormtcpdat
		;;   switch to syn-sent
		lda  #TCP_SYN_SENT
		;;    write stat and set timeout
		jsr  settimeout
		;;    and clear job
		lda  sockjob,x
		and  #$fe
		sta  sockjob,x
		lda  #$02		  ; syn
 _open_wflags:
		ldy  #33
		sta  (userzp),y
		;;   reset bufferptr
		;;    increase sndwrnx (syn)
		lda  #1
		sta  sndwrnx,x       ; (syn sent!)
		lda  #0
		sta  sndrdnx,x
		sta  sndbufstat,x
		dey
		lda  #$60
		sta  (userzp),y
		ldy  #40		   ; add option
		lda  #2
		sta  (userzp),y
		iny
		lda  #4
		sta  (userzp),y
		iny
		lda  #>884		 ; MTU=884
		sta  (userzp),y
		iny
		lda  #<884
		sta  (userzp),y
		jsr  tcpsumsetup
		jmp  sendpacket

; calculate total number of items that need to be acked
;  < .userzp=buffer (TCP)
;  > .userzp+6=#

calcplen: ldy  #12
		ldx  userzp
		lda  (userzp),y
		and  #$f0
		lsr  a
		lsr  a
		adc  userzp
		eor  #$ff
		sec
		ldy  #0
		sty  userzp
		ldy  #3
		adc  (userzp),y
		sta  userzp+6
		dey
		lda  (userzp),y
		sbc  #0
		sta  userzp+7
		stx  userzp
		ldy  #13
		lda  (userzp),y
		and  #3
		lsr  a
		adc  #0
		adc  userzp+6
		sta  userzp+6
		bcc  +
		inc  userzp+7
	+	rts

ignore:		ldx  userzp+3
		jmp  killbuffer

	-	jmp  listen_success

; TCP-state: listen for TCP connection
;  < userzp=buffer (TCP)

do_listen:
		db("JOB: listen")
		ldy  #13
		lda  (userzp),y
		;;   chkflags
		and  #$17
		cmp  #$02		  ; syn
		beq  -
		and  #$04		  ; rst
		bne  ignore
		;; [syn] ack

sendrst:  ;   send rst in response to a
		;;   unsynced incomming packet
		;;   (overwrite old packet)
		;;   userzp=ptr to tcp-header
		db("sendrst")
		jsr  calcplen
		lda  (userzp),y
		and  #$10
		beq  +		     ; no ack field in incoming packet
		;;   set rcvnxt pointer (ack field)
		;;   of rst-packet
		ldy  #11
	-	lda  (userzp),y
		sta  seq-8,y
		dey
		cpy  #7
		bne  -
		jmp  ++

	+	ldy  #3		    ; no ack, then seq=$00000000
	-	sta  seq,y
		dey
		bpl  -

		;;  set ack field of rst-packet, ack.out=seq.in + ack
	+	clc
		ldy  #7
		lda  (userzp),y
		adc  userzp+6
		sta  ack+3
		dey
		lda  (userzp),y
		adc  userzp+7
		sta  ack+2
		dey
		lda  (userzp),y
		adc  #0
		sta  ack+1
		dey
		lda  (userzp),y
		adc  #0
		sta  ack
		;;   init rest of packet
		lda  #0
		sta  userzp
		ldy  #2
		sta  (userzp),y         ; total length (hi)
		ldx  userzp+3
		sta  buf_lenh,x
		lda  #40
		iny
		sta  buf_lenl,x
		sta  (userzp),y         ; total length (lo)
		lda  #20
		sta  buf_offs,x
		lda  #$45
		ldy  #0
		sta  (userzp),y         ; protocol + length of IP header (20 bytes)
		lda  #0
		ldy  #7
		sta  (userzp),y         ; fragment offset
		ldy  #10
		sta  (userzp),y         ; IP checksum
		iny
		sta  (userzp),y
		ldy  #34
	-	sta  (userzp),y         ; window, TCP checksum, Urgent pointer
		iny
		cpy  #40
		bne  -
		lda  #$40
		ldy  #6
		sta  (userzp),y         ; don't fragment
		lda  #$ff
		ldy  #8
		sta  (userzp),y         ; ttl
		lda  #$50
		ldy  #32
		sta  (userzp),y         ; data offset (40)
		lda  #$14
		iny
		sta  (userzp),y         ; flags (ack rst)
		;;   set all 4byte fields
		ldx  #3
		stx  userzp

	-	lda  ack,x
		ldy  #28
		sta  (userzp),y         ; acknowledge number
		lda  seq,x
		ldy  #24
		sta  (userzp),y         ; sequence number
		ldy  #12
		lda  (userzp),y
		ldy  #16
		sta  (userzp),y         ; destIP = sourceIP
		lda  ownip,x
		ldy  #12
		sta  (userzp),y         ; sourceIP = myID
		dec  userzp
		dex
		bpl  -

		;;   swap ports
		lda  #0
		sta  userzp
		ldy  #20
		lda  (userzp),y
		pha
		iny
		lda  (userzp),y
		pha
		iny
		lda  (userzp),y
		ldy  #20
		sta  (userzp),y         ; source port = dest. port (hi)
		ldy  #23
		lda  (userzp),y
		ldy  #21
		sta  (userzp),y         ; source port = dest. port (lo)
		ldy  #23
		pla
		sta  (userzp),y         ; dest. port = source port (lo)
		dey
		pla
		sta  (userzp),y         ; dest. port = source port (hi)
		;;   set id
		lda  packid
		ldy  #4
		sta  (userzp),y         ; packIP (hi)
		lda  packid+1
		iny
		sta  (userzp),y         ; packID (lo)

		lda  #0
		ldy  #1
		sta  (userzp),y         ; type of service
		lda  #6
		ldy  #9
		sta  (userzp),y         ; protocol (TCP)

		jsr  tcpsumsetup
		jmp  sendpacket

listen_success:
		ldx  userzp+2
		ldy  #7
		;;   store initial seqnum+1
		lda  (userzp),y
		clc
		adc  #1
		sta  rcvnxtd,x
		dey
		lda  (userzp),y
		adc  #0
		sta  rcvnxtc,x
		dey
		lda  (userzp),y
		adc  #0
		sta  rcvnxtb,x
		dey
		lda  (userzp),y
		adc  #0
		sta  rcvnxta,x
		;;   generate own initial seqencenumber
		sec
		jsr  lkf_random
		sta  sndunad,x
		jsr  lkf_random
		sta  sndunac,x
		jsr  lkf_random
		sta  sndunab,x
		jsr  lkf_random
		sta  sndunaa,x
		;;   store remoteport and ip
		ldy  #1
		lda  (userzp),y
		sta  remportl,x
		dey
		lda  (userzp),y
		sta  remporth,x
		;;   ip...
		sty  userzp
		ldy  #15
		lda  (userzp),y
		sta  remipd,x
		dey
		lda  (userzp),y
		sta  remipc,x
		dey
		lda  (userzp),y
		sta  remipb,x
		dey
		lda  (userzp),y
		sta  remipa,x
		;;  switch to synreceived
		lda  #TCP_SYN_RECEIVED
		jsr  settimeout

; send standard packet with SYN and ACK flag present

sendsynack:
		lda  #0
		sta  userzp
		ldx  userzp+3
		sta  buf_lenh,x
		ldy  #2
		sta  (userzp),y
		iny
		lda  #44
		sta  buf_lenl,x
		sta  (userzp),y
		lda  #20
		sta  buf_offs,x
		ldx  userzp+2
		jsr  setnormipdat
		ldy  #20
		jsr  setnormtcpdat
		lda  #$12		  ; ack, syn
		jmp  _open_wflags

	-	jmp abort		  ; got rst so abort connection

; TCP-state SYN-SENT
;  < userzp=buffer (TCP), userzp+2=socket, userzp+3=buf

syn_sent: 
		db("TCP: syn_sent")
		ldy  #13
		;;   chk falgs
		lda  (userzp),y
		and  #$17		  ; (mask for ack,rst,syn,fin)
		cmp  #$12
		beq  +		     ; ACK + SYN
		cmp  #$02
		beq  ++		    ; SYN
		and  #4
		bne  -		     ; don't respond to rst packets
	-	jmp  sendrst

	+	jsr  computeack
		ldx  userzp+2
		lda  sndrdnx,x
		beq  -
		lda  #TCP_ESTABLISHED		  ; switch to established
		sta  sockstat,x
		bne  ++
	+	lda  #TCP_SYN_RECEIVED ; switch to syn_received
		ldx  userzp+2
		jsr  settimeout
		;;   extract initial seqnum
	+	ldy  #7
		lda  (userzp),y
		clc
		adc  #1
		sta  rcvnxtd,x
		dey
		lda  (userzp),y
		adc  #0
		sta  rcvnxtc,x
		dey
		lda  (userzp),y
		adc  #0
		sta  rcvnxtb,x
		dey
		lda  (userzp),y
		adc  #0
		sta  rcvnxta,x

; send stadard packet with ACK flag set
;  < .userzp=buffer, userzp+2=socket, userzp+3=buf

sendack:  db("send ack")
		lda  #0
		sta  userzp
		ldx  userzp+3
		sta  buf_lenh,x
		ldy  #2
		sta  (userzp),y
		lda  #40
		sta  buf_lenl,x
		iny
		sta  (userzp),y
		lda  #20
		sta  buf_offs,x
		ldx  userzp+2
		jsr  setnormipdat
		ldy  #20
		jsr  setnormtcpdat
		jsr  tcpsumsetup
		jmp  sendpacket

refbyrst: jmp  sendrst

rmpack:	ldx  userzp+3
		bmi  +					; skip, if buffer is gone (eg. TCP -> reclst)
		jsr  killbuffer
		lda  userzp+3
		ora  #$80
		sta  userzp+3
	- +	rts

; TCP-State SYN-RECEIVED
;

syn_received:
		db("TCP:syn-recvd")
		jsr  extractdata
		bcs  refbyrst        ; send rst back if not in window

		lda  tcpflags
		and  #4		    ; rst ?
		bne  abort
		lda  tcpflags
		;;  chk flags
		and  #$17
		cmp  #$10		  ; ack only ?
		bne  rmpack		; if not then discard
		jsr  computeack
		jsr  rmpack
		ldx  userzp+2
		lda  sndrdnx,x
		beq  -
		;;   wrong !! should send syn
		;;   but to difficult to implement
		;;   (..yet)
		lda  #TCP_ESTABLISHED
		ldx  userzp+2
		;;   switched to established
		jmp  settimeout

abort:    lda  #$ff

errclose: ;   switch to timewait and set err
		ldx  userzp+2
		sta  sndrdnx,x
		lda  #TCP_TIMEWAIT
		sta  sockstat,x
		;;   set long timeout
		lda  tcp_clock
		adc  #40		   ; 40*4=160 seconds
		adc  #0
		sta  timeout,x
		jsr  rmpack
	-	rts

; TCP-State ESTABLISHED

estab:	db("TCP: estab")
		jsr  extractdata
		bcs  refbyrst
		;;   in window
		jsr  computeack
		lda  tcpflags
		and  #$04
		bne  abort
		;;   react to a fin
		jsr  rmpack
		lda  tcpflags
		and  #$01
		beq  -
		;;   switch to closew
		ldx  userzp+2
		lda  #TCP_CLOSE_WAIT
		sta  sockstat,x
		lda  sndbufstat,x
		ora  #$10
		sta  sndbufstat,x
		inc  rcvnxtd,x
		bne  +
		inc  rcvnxtc,x
		bne  +
		inc  rcvnxtb,x
		bne  +
		inc  rcvnxta,x
	+	lda  #1
		jsr  getbuffer
		bcs  -
		jmp  sendack

; JOB: FIN-WAIT0

fin_wait0: ;  is a *JOB* not a state of TCP
		;;    !! must first wait for ack of
		;;       all sent data !!
		;;   send a fin packet and switch to
		;;   fin_wait1
		;;   userzp+2=socket
		;;   retry if there was not enough
		;;   memory !
		db("JOB: finwait")
		ldx  userzp+2
		lda  sndwrnx,x
		cmp  sndrdnx,x
		bne  +
		lda  #1
		jsr  getbuffer
		bcs  ++
		lda  #0
		sta  buf_lenh,x
		ldy  #2
		sta  (userzp),y
		lda  #40
		sta  buf_lenl,x
		iny
		sta  (userzp),y
		lda  #20
		sta  buf_offs,x
		ldx  userzp+2
		;;   add one pseudo byte in buffer
		inc  sndwrnx,x
		;;   clear job
		lda  sockjob,x
		and  #$ff-$02
		sta  sockjob,x
		jsr  setnormipdat
		ldy  #20
		jsr  setnormtcpdat
		ldy  #33
		lda  #$11		  ; ack fin
		sta  (userzp),y
		jsr  tcpsumsetup
		ldx  userzp+3
		jsr  sendpacket
		ldx  userzp+2
		sei
		lda  sockstat,x
		and  #$0f
		cmp  #($0f & TCP_CLOSE_WAIT)
		;; was it in state 'close wait' ?
		beq  _lastack
		lda  #TCP_FIN_WAIT1
		SKIP_WORD
_lastack:
		lda  #TCP_LAST_ACK
		jsr  settimeout
		cli
		clc
		SKIP_BYTE
	+	sec
	+	rts

;TCP-state FIN-WAIT1

fin_wait1: ;  wait for a ack of fin
		;;   or a fin
		db("TCP: fin-wait1")
		jsr  extractdata
		bcs  _fw1_err
		jsr  computeack
		jsr  rmpack
		lda  tcpflags
		and  #4
		bne  _fw1_reset
		ldx  userzp+2
		lda  sndwrnx,x
		cmp  sndrdnx,x
		bne  _fw1_noack
		lda  tcpflags
		and  #$01
		beq  _to_finwait2
_to_timewait:
		lda  sndrdnx,x
		jsr  ack_one
		lda  #TCP_TIMEWAIT
		;;   dest=time wait
		SKIP_WORD
_to_closing:
		lda  #TCP_CLOSING
		;;   send ack of fin
		ldx  userzp+2
		jsr  settimeout
		lda  #1
		jsr  getbuffer
		bcs  +
		jsr  sendack
		ldx  userzp+2
		lda  sockstat,x
		cmp  #TCP_TIMEWAIT
		beq  longtimeout
		jmp  settimeout+3

longtimeout:
		lda  tcp_clock
		adc  #40
		adc  #0
		sta  timeout,x
	+	rts

_fw1_noack:
		lda  tcpflags
		and  #1
		beq  +
		jsr  ack_one
		jmp  _to_closing

_fw1_err: jmp  sendrst

		;;   if no ack and no fin...ignore
_to_finwait2:
		lda  #TCP_FIN_WAIT2
		sta  sockstat,x
      - + rts

;TCP-state FIN-WAIT2

fin_wait2:;   wait for fin and send ack
		;;   (continue receiving data)
		db("TCP: fin-wait2")
		jsr  extractdata
		bcs  _fw1_err
		jsr  computeack
		jsr  rmpack
		lda  tcpflags
		and  #$05
		beq  -
		cmp  #$01
		beq  _to_timewait
_fw1_reset: 
		;;   was a rst-packet so goto
		;;    time_wait no ack to send
		jmp  abort

; TCP-state TIMEWAIT

time_wait:;   wait for a special time
		;;   donno yet.. wait for ever
		db("TCP: timewait")
		ldy  #13
		lda  (userzp),y
		and  #$04
		bne  +
		jmp  sendrst

		;;    every packet exept rst will
		;;   cause a rst packet
	+	jmp  rmpack

ack_one:  inc  rcvnxtd,x
		bne  +
		inc  rcvnxtc,x
		bne  +
		inc  rcvnxtb,x
		bne  +
		inc  rcvnxta,x
	+	rts

;TCP-state CLOSE-WAIT

close_wait:
		;;   nothing to do but waiting for
		;;   a userfin
		;;   but sending is still possible so
		;;   the ack-field has to be computed
		;;   and therefor the seq-num must be
		;;   checked
		db("TCP:close wait")
		jsr  extractdata
		bcs  _cw_err
		jsr  computeack
		jsr  rmpack
		lda  tcpflags
		and  #4
		beq  +
		jmp  abort

;TCP-state LAST-ACK

last_ack: ;   wait for ack of fin then closed
		;;   (mostly identical to closing)
		;;   all data is sent + a fin is sent
		db("TCP: last ack")
		jsr  chkfinack
		bne  +
		lda  #$00
		ldx  userzp+2
		sta  sockstat,x
		sta  timeout,x
		sta  sndrdnx,x
	+	rts

;TCP-state CLOSING

closing:  ;   wait for ack of fin then time-w
		db("TCP: closing")
		jsr  chkfinack
		bne  +
		lda  #TCP_TIMEWAIT
		ldx  userzp+2
		sta  sockstat,x
		lda  tcp_clock
		clc
		adc  #60		  ; 60*4=240s = 4min timeout
		adc  #0
		sta  timeout,x
		lda  #0
		sta  sndrdnx,x
      + - rts

_cw_err:  beq  -
		jmp  sendrst

; check incoming packet for FIN+ACK

chkfinack:
		jsr  extractdata
		bcs  +		     ; skip on invalid seq.num
		jsr  computeack
		jsr  rmpack
		lda  tcpflags
		and  #4
		bne  ++		    ; RST set !
		ldx  userzp+2
		lda  sndwrnx,x
		cmp  sndrdnx,x
		rts

	+	jmp  sendrst

	+	pla
		pla
		jmp  abort

; USER CALL:
;  close TCP-stream
;  < X=socket

close:
		;;   del process-conection and
		;;   set job-shutdown also free memory
		cpx  #SOCKNUM        ; check for valid socket num.
		bcs  +
		lda  sockipid,x      ; check process ID
		cmp  lk_ipid
		bne  +
raw_close:
		lda  #$80
		sta  sockipid,x
		lda  #0
		sta  socktype,x			; (not listening)
		sei
		lda  #4		    ; add JOB: ??
		ora  sockjob,x
		and  #$ff-$03
		sta  sockjob,x
		lda  sndbufpg,x      ; free memory used by sendbuffer
		tax
		jsr  lkf_pfree
		cli
		rts

; USER CALL:
;  fin, send EOF to TCP-stream
;  < X=socket

	-	clc
		rts

ipv4_fin: ;   x=socket
		cpx  #SOCKNUM        ; check for valid socket num.
		bcs  +
		lda  sockipid,x      ; check process ID
		eor  lk_ipid
		bne  +
ipv4_fin2:
		lda  sockstat,x
		and  #$7f
		sta  sockstat,x
		and  #$0f
		cmp  #($0f & TCP_SYN_RECEIVED)
		beq  _dofin
		cmp  #($0f & TCP_ESTABLISHED)
		beq  _dofin
		cmp  #($0f & TCP_CLOSE_WAIT)
		bne  -
_dofin:
		lda  #2		    ; add JOB:??
		ora  sockjob,x
		sta  sockjob,x
		rts

	+	sec
	-	rts

; JOB: shutdown (cut opened TCP-stream, no FIN use RST)
; < userzp+2=socket 

shutdown: ;   is a *JOB* not a state of TCP
		ldx  userzp+2
		lda  sockstat,x
		and  #$0f
		beq  +		     ; arrived in state closed ?
		cmp  #($0f & TCP_TIMEWAIT)
		beq  -		     ; arrived in state time_wait ?
		lda  #TCP_TIMEWAIT   ; switch to time_wait
		sta  sockstat,x
		lda  #1
		jsr  getbuffer
		bcs  -
		lda  #0
		sta  buf_lenh,x
		ldy  #2
		sta  (userzp),y
		iny
		lda  #40
		sta  buf_lenl,x
		sta  (userzp),y
		lda  #20
		sta  buf_offs,x
		ldx  userzp+2
		jsr  longtimeout
		;;   clear job
		lda  #0
		sta  sockjob,x
		jsr  setnormipdat
		ldy  #20
		jsr  setnormtcpdat
		ldy  #33
		lda  (userzp),y
		ora  #$04		  ; set RST flag
		sta  (userzp),y
		jsr  tcpsumsetup
		jmp  sendpacket

	+	jsr  freesocketmemory      ; done, then free other used memory
		ldx  userzp+2
		lda  #$ff		  ; release slot
		sta  sockipid,x
		lda  #0
		sta  sockstat,x
		rts

; USER CALL:
;  get socket, allocate socket no other action
;  > X=socket, c=error

ipv4_getsock:
		sei
		ldx  #SOCKNUM-1
	-	lda  sockipid,x      ; search for unused slot
		cmp  #$ff
		beq  +
		dex
		bpl  -
		cli
	-	sec
		rts

	+	lda  #$00		  ; reset socket data
		sta  sockstat,x
		sta  sockjob,x
		sta  sndwrnx,x       ; reset bufptr
		sta  sndrdnx,x
		sta  sndbufstat,x
		sta  socktype,x      ; (active open per default)
		lda  #$ff
		sta  reclstt,x
		sta  reclstb,x
		lda  lk_ipid		  ; set process ID
		sta  sockipid,x
		jsr  lkf_random		   ; set initial local port (for passive open)
		sta  localportl,x
		jsr  lkf_random
		and  #$7f
		ora  #$04				; just use ports 1024..32767
		sta  localporth,x ;(don't know, if this is needed, but it doesn't hurt)
		cli
		;;   allocate bufferpage
		txa
		pha
		ldx  #BUFMARKER			; allocate sendbuffer (256 bytes)
		ldy  #0					; (may use IO)
		jsr  lkf_spalloc
		nop						; ????
		txa
		tay
		pla
		tax
		tya
		sta  sndbufpg,x
		clc
		rts

; USER CALL:
;  open TCP-stream
;  < X=socket, Y: $00=passive, $ff=active 

ipv4_open:
		cpx  #SOCKNUM			; check for valid stream num
		bcs  [-]+1				; (rts)
		lda  sockipid,x			; check process ID
		cmp  lk_ipid
		bne  -					; (sec:rts)

		;;   init available counter
		lda  #SOCKBUFS
		sta  recposh,x
		lda  sockstat,x
		bne  -
		lda  #0
		sta  timeout,x       ; no timeout
		tya
		bne  +

		;;   passive open-
		;;   just switch to listen

		lda  #TCP_LISTEN
		sta  sockstat,x
		clc
		rts

		;;   active open-
		;;    start job
	+	lda  sockjob,x
		bne  -
		lda  #1		    ; add JOB ??
		sta  sockjob,x
		jsr  lkf_random		   ; set initial seq-num
		sta  sndunaa,x
		jsr  lkf_random
		sta  sndunab,x
		jsr  lkf_random
		sta  sndunac,x
		jsr  lkf_random
		sta  sndunad,x
		clc
		rts

; examine an incoming packet and find the socket
; to use
;  < .userzp=buffer, userzp+4=IP header offset, userzp+5=TCP header offset
;  > X=socket, c=error

findsock: 
		;;   find a socket with perfect match
		;;   buf in state listen
		;;   there can't be a'perfect' match
		;;   of ports and ip
		ldx  #SOCKNUM-1

	-	lda  sockstat,x
		and  #15
		cmp  #2
		bcc  +		     ; skip if socket closed or listen
		lda  userzp+4		   ; check source (remote) ip
		sta  userzp
		ldy  #12
		lda  (userzp),y
		cmp  remipa,x
		bne  +
		iny
		lda  (userzp),y
		cmp  remipb,x
		bne  +
		iny
		lda  (userzp),y
		cmp  remipc,x
		bne  +
		iny
		lda  (userzp),y
		cmp  remipd,x
		bne  +
		lda  userzp+5		 ; check source (remote) port
		sta  userzp
		ldy  #0
		lda  (userzp),y
		cmp  remporth,x
		bne  +
		iny
		lda  (userzp),y
		cmp  remportl,x
		bne  +
		iny		        ; check destination (local) port
		lda  (userzp),y
		cmp  localporth,x
		bne  +
		iny
		lda  (userzp),y
		cmp  localportl,x
		bne  +
		lda  sockipid,x      ; check for process
		bmi  +

	-	clc		        ; found socket!
		rts

	+	dex		        ; doesn't match
		bpl  --		    ; try next socket

		;;   now try to find a non syned
		;;   socket
		lda  userzp+5
		sta  userzp
		ldx  #SOCKNUM-1

	-	lda  sockstat,x
		and  #15
		cmp  #1		    ; skip if socket closed
		bne  +
		ldy  #2		    ; check local port
		lda  (userzp),y
		cmp  localporth,x
		bne  +
		iny
		lda  (userzp),y
		cmp  localportl,x
		bne  +
		lda  sockipid,x      ; check ipid
		bmi  +
		jmp  --		    ; found!

	+	dex
		bpl  -

		;; can't find anything
		sec
		rts

;tcp jumptable

tcp_jmptab:
		jmp  do_listen
		nop
		jmp  syn_sent
		nop
		jmp  syn_received
		nop
		jmp  estab
		nop
		jmp  fin_wait1
		nop
		jmp  fin_wait2
		nop
		jmp  close_wait
		nop
		jmp  closing
		nop
		jmp  last_ack
		nop
		jmp  time_wait


	-	cli
		rts

; TCP-modul

tcp_modul:
		;;   gets packets from ip-modul
		;;   and trys to find a suitable
		;;   socket

		sei
		ldx  tcplst		; skip if there is no packet
		bmi  -
		stx  userzp+3		 ; remove from TCP-list
		lda  buf_l2nx,x
		sta  tcplst
		bpl  +
		sta  tcplst+1
	+	cli
		lda  buf_mid,x
		sta  userzp+1
		stx  userzp+3
		;;   check chksum
		lda  #0
		sta  userzp
		jsr  sumtcp
		lda  userzp+6
		and  userzp+7
		cmp  #$ff
		beq  +
		db("wrong tcp checksum")
	-	jmp  rmpack

	+	lda  #0
		sta  userzp+4
		ldx  userzp+3
		lda  buf_offs,x
		sta  userzp+5
		jsr  findsock
		bcs  ++		    ; no socket found!

		;;  passthrough
		;;  call tcp-subroutine
		;;  check ipid
		stx  userzp+2
		lda  sockstat,x
		and  #15
		beq  -		     ; discard packet for closed stream ??
		cmp  #11
		bcs  -		     ; dicard if illegal state
		asl  a
		asl  a
		tax
		lda  tcp_jmptab-3,x
		sta  [+]+1
		lda  tcp_jmptab-2,x
		sta  [+]+2
	+	jmp  $ffff

	+	jmp  sendrst

; timeout related stuff....

timeout_closed:
timeout_listen:
timeout_finwait2:
		db("illegal timeout")
		lda  #0
		sta  sockstat,x
		rts

timeout_estab:
timeout_closewait:
		jsr  settimeout+3
		jmp  senddatapacket

timeout_timewait:
		lda  #0
		sta  sockstat,x
		sta  timeout,x
		lda  sockipid,x
		cmp  #$ff
		beq  +
		jsr  freesocketmemory
		ldx  userzp+2
	+	lda  #$ff
		sta  sockipid,x
	-	rts

timeout_synrecved:
		;;   send syn+ack
		txa
		pha
		jsr  settimeout+3
		lda  #1
		jsr  getbuffer
		pla
		bcs  -
		tax
		jmp  sendsynack

timeout_synsent:
		jmp  activeopen

snd_finack:
		sta  sndwrnx,x
		sta  sndrdnx,x
		jmp  fin_wait0

timeout_finwait1:
		jsr  snd_finack
		lda  #TCP_FIN_WAIT1
		ldx  userzp+2
		jmp  settimeout

timeout_closing:
		jsr  snd_finack
		lda  #TCP_CLOSING
		ldx  userzp+2
		jmp  settimeout

timeout_lastack:
		jsr  snd_finack
		lda  #TCP_LAST_ACK
		ldx  userzp+2
		jmp  settimeout

timeout_jmptab: 
		jmp  timeout_closed
		nop
		jmp  timeout_listen
		nop
		jmp  timeout_synsent
		nop
		jmp  timeout_synrecved
		nop
		jmp  timeout_estab
		nop
		jmp  timeout_finwait1
		nop
		jmp  timeout_finwait2
		nop
		jmp  timeout_closewait
		nop
		jmp  timeout_closing
		nop
		jmp  timeout_lastack
		nop
		jmp  timeout_timewait

; check for timeouts on all opened TCP sockets/streams

tout_check:
		ldx  #SOCKNUM-1
		;;  ldaxsockipid
		;;  bmi$<no
	-	lda  sockstat,x
		beq  +
		lda  timeout,x
		bne  ++
      - + dex
		bpl  --

		rts

	+	sec
		sbc  tcp_clock
		cmp  #100
		bcc  -
		;;   time is out !
		lda  sockstat,x
		and  #15
		cmp  #$0b		  ; avoid illegal jumps
		bcs  -
		stx  userzp+2
		asl  a
		asl  a
		tax
		lda  timeout_jmptab+1,x
		sta  [+]+1
		lda  timeout_jmptab+2,x
		sta  [+]+2
		ldx  userzp+2
	+	jmp  $ffff

		;; check socket and do JOBs if neccessary
		;; <  userzp+2 = socket

sockserv:
		ldx  userzp+2
		lda  sockstat,x
		and  #$0f
		cmp  #($0f & TCP_SYN_RECEIVED)
		bcc  +++
		cmp  #($0f & TCP_LAST_ACK)
		bcs  +++

		;; states established, fin_wait1, fin_wait2, close_wait, closing

		lda  sndbufstat,x
		;;   first look if we have to send
		;;   data or an acknowledge
		and  #$50
		bne  +

		;;   check if we have sent win=0
		;;   and window rised
		lda  sndbufstat,x
		and  #$20
		beq  +++
		lda  freelst
		ora  recposh,x
		bmi  +++
	+	lda  sockstat,x
		and  #$0f
		cmp  #($0f & TCP_SYN_RECEIVED)
		beq  +
		jmp  senddatapacket

	+	jmp  timeout_synrecved

		;;   are there some jobs to do ?
	+	lda  sockjob,x
		and  #1
		bne  +		     ; job: active open
		lda  sockjob,x
		and  #2
		bne  ++		    ; job: fin-wait0
		lda  sockjob,x
		and  #4
		bne  +++		   ; job: shutdown
		rts

	+	jmp  activeopen
	+	jmp  fin_wait0
	+	jmp  shutdown

;------------------------------------------------------------------------
; ICMP modul
;------------------------------------------------------------------------

; calculate icmp sum and send packet

icmpsumnsnd:
		jsr  sumheader
		lda  userzp+6
		eor  #255
		ldy  #11
		sta  (userzp),y
		lda  userzp+7
		eor  #255
		dey
		sta  (userzp),y
		ldx  userzp+3
		lda  buf_offs,x
		sta  userzp
		jsr  sumdata
		lda  userzp+6
		eor  #255
		ldy  #3
		sta  (userzp),y
		lda  userzp+7
		eor  #255
		dey
		sta  (userzp),y
		ldx  userzp+3
		jmp  sendpacket

icmp_type3:
		;;   no contact because of
		;;      code
		;;       0       net unreachable
		;;       1       host unreachable
		;;       2       protocol unreachable
		;;       3       port unreachable
		;;       4       fragmentation needed
		;;       5       source route failed

		ldy  #1
		lda  (userzp),y
		sta  userzp+6
		lda  userzp
		clc
		adc  #8
		sta  userzp+4
		sta  userzp
		ldy  #0
		lda  (userzp),y
		and  #$0f
		asl  a
		asl  a
		adc  userzp
		sta  userzp+5
		ldx  #4

	-	ldy  #16
		lda  (userzp),y
		ldy  #12
		sta  (userzp),y
		inc  userzp
		dex
		bne  -

		ldx  #2
		lda  userzp+5
		sta  userzp

	-	ldy  #2
		lda  (userzp),y
		pha
		ldy  #0
		lda  (userzp),y
		ldy  #2
		sta  (userzp),y
		pla
		ldy  #0
		sta  (userzp),y
		inc  userzp
		dex
		bne  -

		jsr  findsock
		bcs  +
		stx  userzp+2
		ldx  userzp+3
		jsr  killbuffer
		lda  userzp+6
		ora  #$80
		jmp  errclose

	+	ldx  userzp+3
		jmp  killbuffer

icmp_type11:
		;;   lost packet because of
		;;      code
		;;       0    time to live exceeded
		;;       1 fr.reassembly tm exceeded
		;;   put a message out would be much
		;;   better. something like
		;;   icmp; sock #x <message>
		;;  ldx$<userzp+3
		;;  jmp$<killbuffer

icmp_type12:
		;;   parameter problem message
		;;   should put something out
		;;   .. later !!
		;;  ldx$<userzp+3
		;;  jmp$<killbuffer

icmp_type4:
		;;   source quench message
		;;   seems our little commi was to
		;;   fast !!? sorry slowing down is
		;;   not implemented
		;;  ldx$<userzp+3
		;;  jmp$<killbuffer

icmp_type5:
		;;   redirect message
		;;    just ignore it
		;;  ldx$<userzp+3
		;;  jmp$<killbuffer

icmp_type13:
icmp_type14:
		;;   ignore both timestamp
		;;    massage and reply massage
		;;  ldx$<userzp+3
		;;  jmp$<killbuffer

icmp_type15:
icmp_type16:
		;;   also ignore information
		;;   request and reply message

icmp_typeunknown:
		db("unknown icmp type")
		ldx  userzp+3
		jmp  killbuffer

icmp_type8:
		;;   echo message
		;;   send a echo reply message
		lda  #3
		sta  userzp

	-	ldy  #12
		lda  (userzp),y
		tax
		ldy  #16
		lda  (userzp),y
		ldy  #12
		sta  (userzp),y
		txa
		ldy  #16
		sta  (userzp),y
		dec  userzp
		bpl  -

		ldy  #10
		lda  #0
		sta  userzp
		sta  (userzp),y
		iny
		sta  (userzp),y
		ldx  userzp+3
		lda  buf_offs,x
		sta  userzp
		ldy  #0
		lda  #0
		sta  (userzp),y
		ldy  #2
		sta  (userzp),y
		iny
		sta  (userzp),y
		sta  userzp
		jmp  icmpsumnsnd

icmp_type0:
		;;   echo reply message
		;;   should be notifyed to the
		;;   process that sent the
		;;   echo message...LATER !!
		db("got echo reply")
		ldx  userzp+3
		jmp  killbuffer

icmp_jmptab:
		jmp  icmp_type0
		nop
		jmp  icmp_typeunknown
		nop
		jmp  icmp_typeunknown
		nop
		jmp  icmp_type3
		nop
		jmp  icmp_type4
		nop
		jmp  icmp_type5
		nop
		jmp  icmp_typeunknown
		nop
		jmp  icmp_typeunknown
		nop
		jmp  icmp_type8
		nop
		jmp  icmp_typeunknown
		nop
		jmp  icmp_typeunknown
		nop
		jmp  icmp_type11
		nop
		jmp  icmp_type12
		nop
		jmp  icmp_type13
		nop
		jmp  icmp_type14
		nop
		jmp  icmp_type15
		nop
		jmp  icmp_type16

	-	cli
		rts

; ICMP-modul

icmp_modul:
		sei
		ldx  icmplst         ; remove top element from icmp-list
		bmi  -
		stx  userzp+3
		lda  buf_l2nx,x
		sta  icmplst
		bpl  +
		sta  icmplst+1
	+	cli
		lda  buf_mid,x
		sta  userzp+1
		lda  buf_offs,x
		sta  userzp
		jsr  sumdata
		lda  userzp+6
		and  userzp+7
		cmp  #$ff
		bne  ++		    ; wrong checksum
		ldy  #0
		lda  (userzp),y
		cmp  #17
		bcs  +++		   ; unknown type
		asl  a
		asl  a
		tax
		lda  icmp_jmptab+1,x
		sta  [+]+1
		lda  icmp_jmptab+2,x
		sta  [+]+2
	+	jmp  $ffff

	+	db("wrong ICMP checksum")
		ldx  userzp+3
		jmp  killbuffer

	+	jmp  icmp_typeunknown

		
		;;  UDP protocol modul (for now it just discards all packets)
		
udp_modul:
		sei
		ldx  udplst         ; remove top element from icmp-list
		bmi  -
		stx  userzp+3
		lda  buf_l2nx,x
		sta  udplst
		bpl  +
		sta  udplst+1
	+	cli
		
		db("discarding UDP")
		ldx  userzp+3
		jmp  killbuffer
		
;------------------------------------------------------------------------
; USER CALLs
;------------------------------------------------------------------------

create_fd:
		txa						; minor is socket number
		pha
		bit  ipv4_io_stub
		jsr  lkf_ufd_open
		bcs  ++
		txa
		pha
		jsr  lkf_fdup
		bcs  +
		pla
		tay						; X/Y are fds
		pla						; A=socket (unused)
		clc
		rts

	+	pla
		tax
		jsr  fclose
	+	pla
		tax
		sec
		rts
		
; connect
;  <- bit$ address of 4 byte inet addr (+2 byte port for TCP/UDP)
;     x = protocol (IPV4_TCP, IPV4_UDP, ...)
;  -> c = 0: X/Y = fd of write/read stream
;     c = 1: a = error code	  
;				       E_NOTIMP, E_PROT, E_NOROUTE, E_NOPERM

con_cleanup0:
		jsr  close
		lda  #0
		SKIP_WORD
err_notimp:
		lda  #E_NOTIMP
		SKIP_WORD
err_nosock:
		lda  #E_NOSOCK
		jmp  lkf_catcherr

ipv4_connect:
		cpx  #IPV4_TCP
		bne  err_notimp
		jsr  ipv4_getsock
		bcs  err_nosock
		txa
		jsr  lkf_get_bitadr		; ->tmpzp is pointer to struct (A unchanged)
		stx  tmpzp
		sty  tmpzp+1
		tax
		ldy  #0
		lda  (tmpzp),y
		sta  remipa,x
		iny
		lda  (tmpzp),y
		sta  remipb,x
		iny
		lda  (tmpzp),y
		sta  remipc,x
		iny
		lda  (tmpzp),y
		sta  remipd,x
		iny
		lda  (tmpzp),y
		sta  remportl,x
		iny
		lda  (tmpzp),y
		sta  remporth,x
		cli
		
		ldy  #$ff
		jsr  ipv4_open
		bcs  con_cleanup0
		ldy  tcp_clock

	-	jsr  lkf_force_taskswitch
		lda  sockstat,x
		and  #$0f
		beq  con_broken
		cmp  #9
		bcs  con_broken
		cmp  #($0f & TCP_ESTABLISHED)
		beq  +
		sec
		tya
		eor  #$ff
		adc  tcp_clock
		cmp  #CONTIMEOUT
		bcc  -
		jsr  close
		lda  #E_CONTIMEOUT
		jmp  lkf_catcherr

		;; get fd
	+	jsr  create_fd
		bcs  +
		rts
		
	+	jsr  close
		lda  #lerr_toomanyfiles
		jmp  lkf_catcherr



con_broken:
		jsr  close
		lda  #E_CONREFUSED
		jmp  lkf_catcherr
		

	-	jsr  lkf_force_taskswitch
getc_stub:
		ldy  #fsmb_minor
		lda  (syszp),y
		tax
		jsr  getbyte
		bcs  +
		jmp  lkf_io_return

		;; error or eof ?
	+	ldy  #fsmb_minor
		lda  (syszp),y
		tax
		lda  sockstat,x
		and  #$0f
		cmp  #4
		bcc  +
		cmp  #7
		bcs  +
		bit  syszp+4
		bmi  -					; wait
		lda  #lerr_tryagain
		SKIP_WORD
	+	lda  #lerr_eof
		jmp  lkf_io_return_error

	-	jsr  lkf_force_taskswitch
putc_stub:
		ldy  #fsmb_minor
		lda  (syszp),y
		tax
		lda  syszp+5
		jsr  putbyte
		bcs  +
		lda  sndbufstat,x
		ora  #$40
		sta  sndbufstat,x
		jmp  lkf_io_return
		
	+	ldy  #fsmb_minor
		lda  (syszp),y
		tax
		lda  sockstat,x
		bpl  +
		bit  syszp+4
		bmi  -
		lda  #lerr_tryagain
		SKIP_WORD
	+	lda  #lerr_ioerror
		jmp  lkf_io_return_error

	-	lda  #lerr_notimp
		jmp  lkf_catcherr

		;; fgetc/fputc/fclose stream - function
ipv4_io_stub:
		cpx  #fsuser_fgetc
		beq  getc_stub
		cpx  #fsuser_fputc
		beq  putc_stub
		cpx  #fsuser_fclose
		bne  -
		;; fclose stream
		ldy  #fsmb_minor
		lda  (syszp),y
		tax
		jsr  ipv4_fin2
		jmp  +
		
; close
;  <- x = socket-nr

ipv4_close:
		jsr  ipv4_fin
		bcs  -					; (should never happen)
	+	ldy  tcp_clock

	 -	jsr  lkf_force_taskswitch
		lda  sockstat,x
		and  #$0f
		cmp  #($0f & TCP_LISTEN)+1
		bcc  +
		cmp  #($0f & TCP_TIMEWAIT)
		bcs  +
		sec
		tya
		eor  #$ff
		adc  tcp_clock
		cmp  #CONTIMEOUT
		bcc  -

	+	lda  socktype,x
		bpl  +
		lda  localportl,x
		pha
		lda  localporth,x
		pha
		lda  #$ff
	+	pha
		jsr  raw_close
		pla
		bmi  +		     ; listen, then reopen socket
		clc
		rts

; listen
;  (open)
;  <- c = 0: a/y = 2 byte port number (TCP/UDP)
;     x = protocol
;  -> c = 0: ok, x = listenport
;     c = 1: a = error code
;				       E_NOTIMP, E_PROT, E_PORTINUSE
;  (close)
;  <- c = 1: x = listenport 
;  -> c = 0: ok
;     c = 1: a = error code
;				       E_NOTIMP, E_NOPORT

	-	pla
		pla
		jmp  err_nosock
	-	jmp  err_notimp

	+	pla
		tay
		pla
		ldx  #IPV4_TCP
		clc

ipv4_listen:
		bcs  end_listen
		cpx  #IPV4_TCP
		bne  -
		pha
		tya
		pha
		jsr  ipv4_getsock
		bcs  --
		pla
		sei
		sta  tmpzp
		pla
		sta  tmpzp+1
		ldy  #SOCKNUM-1

	-	lda  sockipid,y      ; check, if port is already used
		bmi  +
		lda  socktype,y
		bpl  +
		lda  tmpzp
		cmp  localporth,y
		bne  +
		lda  tmpzp+1
		cmp  localportl,y
		bne  +
		jsr  close
		lda  #E_NOPORT
		jmp  lkf_catcherr

	+	dey
		bpl  -

		lda  tmpzp
		sta  localporth,x
		lda  tmpzp+1
		sta  localportl,x
		cli
		lda  #$80
		sta  socktype,x
		ldy  #0
		jsr  ipv4_open
		clc
		rts

to_e_noperm:		
		pla
		lda  #E_NOPERM
		jmp  lkf_catcherr

end_listen:
		pha
		ldx  #SOCKNUM-1
	-	lda  sockipid,x      ; search for used slot
		bpl  +
	-	dex
		bpl  --
		cli
		pla
		lda  #E_NOSOCK
		jmp  lkf_catcherr
		
	+	tya
		cmp  localporth,x
		bne  -
		pla
		pha
		cmp  localportl,x
		bne  -
		pla
		;; found socket number		
		lda  socktype,x
		bpl  to_e_noperm+1
		lda  #0
		sta  socktype,x
		jmp  ipv4_close

; accept
;  <- bit$ = address of buffer for 4 byte IP address + 2 byte port
;     A/Y = listen port
;     c = 0: don't block
;     c = 1: block
;  -> c = 0: x = file-nr for read
;     y = file-nr for write

ipv4_accept:
		php
		pha
		ldx  #SOCKNUM-1
	-	lda  sockipid,x      ; search for used slot
		bpl  +
	-	dex
		bpl  --
		cli
		pla
		pla
		lda  #E_NOSOCK
		jmp  lkf_catcherr
		
	+	tya
		cmp  localporth,x
		bne  -
		pla
		pha
		cmp  localportl,x
		bne  -
		pla
		;; found socket number		
		lda  socktype,x
		bpl  to_e_noperm

	-	jsr  lkf_force_taskswitch
		lda  sockstat,x
		and  #$0f
		beq  +
		cmp  #9
		bcs  +
		cmp  #($0f & TCP_ESTABLISHED)
		bcs  +++
	-	plp
		php
		bcs  --					; wait for connection
		lda  #lerr_tryagain
		bne  ++

	+	jsr  ipv4_close
		bcc  -
	+	plp
		jmp  lkf_catcherr
		
	+	plp
		jsr  create_fd
		bcs  +  ; too many files!
		rts

	+	lda  socktype,x
		and  #$7f
		sta  socktype,x
		jsr  ipv4_close
		lda  #lerr_toomanyfiles
		jmp  lkf_catcherr


		;; function:	ipv4_tcpinfo
		;; status of tcp/ip stack in general
		;; < bit$ pointer to struct	{own.IP.l, used_sockets.b, avail_sockets.b,
		;;							 used_buffers.b, avail_buffers.b,
		;;							 IP-chksum-errors.w}

ipv4_tcpinfo:
		jsr  lkf_get_bitadr
		stx  tmpzp
		sty  tmpzp+1
		;; own.IP
		ldy  #3
	-	lda  ownip,y
		sta  (tmpzp),y
		dey
		bpl  -
		;; sockets
		iny
		ldx  #SOCKNUM
		lda  #$ff
	-	cmp  sockipid,x
		bne  +
		iny						; (counts number of available sockets)
	+	dex
		bpl  -
		tya
		ldy  #5
		sta  (tmpzp),y
		dey
		eor  #$ff
		sec
		adc  #SOCKNUM
		sta  (tmpzp),y
		;; buffers
		ldy  #0
		ldx  freelst
		bmi  +
	-	iny
		tax
		lda  buf_l2nx,x
		bpl  -
	+	tya
		ldy  #7
		sta  (tmpzp),y
		dey
		eor  #$ff
		sec
		adc  #BUFNUM
		sta  (tmpzp),y
		lda  errcnt+1			; (lo byte)
		ldy  #8
		sta  (tmpzp),y
		lda  errcnt				; (hi byte)
		iny
		sta  (tmpzp),y
		cli
		rts
		
	-	lda  #E_NOPERM
		jmp  lkf_catcherr

; sockinfo
;  <- X=socket, bit$ pointer to struct (localport,rem.IP,rem.port)
;  -> A=sockstat 0..10 (bit7=listen), X/Y=PID

ipv4_sockinfo:
		cpx  #SOCKNUM
		bcs  -
		lda  sockipid,x
		cmp  #$ff
		beq  -
		txa
		jsr  lkf_get_bitadr
		stx  tmpzp
		sty  tmpzp+1
		ldy  #0
		tax
		lda  localportl,x
		sta  (tmpzp),y
		lda  localporth,x
		iny
		sta  (tmpzp),y
		lda  remipa,x
		iny
		sta  (tmpzp),y
		lda  remipb,x
		iny
		sta  (tmpzp),y
		lda  remipc,x
		iny
		sta  (tmpzp),y
		lda  remipd,x
		iny
		sta  (tmpzp),y
		lda  remportl,x
		iny
		sta  (tmpzp),y
		lda  remporth,x
		iny
		sta  (tmpzp),y
		lda  sockstat,x
		and  #$0f
		ldy  socktype,x
		bpl  +
		ora  #$80
	+	pha
		lda  sockipid,x
		tax
;		ldy  $c1c0,x ; PID hi ?????????????
;		lda  $c1a0,x ; PID lo
; LAME!
		ldy #0
;		lda #0
;		tax
		pla
		clc
		cli
		rts

;------------------------------------------------------------------------
; other stuff
;------------------------------------------------------------------------

enter_main_loop:
		jsr  lkf_pfree			; free memory used by init code
		
	-	jsr  lkf_force_taskswitch

main_loop:
		cli
		jsr  pack_poll
		jsr  tout_check
		
		lda  #SOCKNUM-1
		sta  userzp+2

	-	ldx  userzp+2
		lda  sockipid,x
		cmp  #$ff
		beq  +
		jsr  sockserv
	+	dec  userzp+2
		bpl  -

		sei
		lda  iplst
		and  icmplst
		and  udplst
		cli
		bmi  --

#ifdef DEBUG
		inc  debug1
#endif

		;; another core loop
		;;  (process incoming packets as fast as possible)

	-	jsr  ip_modul
		jsr  tcp_modul
		jsr  udp_modul
		jsr  icmp_modul
		
		lda  #SOCKNUM-1
		sta  userzp+2

	-	ldx  userzp+2
		lda  sockipid,x
		cmp  #$ff
		beq  +
		jsr  sockserv
	+	dec  userzp+2
		bpl  -

		jsr  pack_poll

		sei
		lda  iplst
		and  tcplst
		and  icmplst
		and  udplst
		cli
		bpl  --

		jmp  main_loop
		
;; 
;; _prockilled:
;; 		;; this is called eyervtime a process is going to be killed
;; 		;; A=ipid of that process
;; 
;; 		bit  globflags
;; 		bmi  ->rts
;; 
;; 		ldx  #SOCKNUM-1
;; 
;; 	-	cmp  sockipid,x
;; 		bne  +
;; 		txa
;; 		pha
;; 		jsr  raw_close
;; 		pla
;; 		tax
;; 	+	dex
;; 		bpl  -
;; 		rts
;; 
;; _cleanup:
;; 		ldx  mydrvnum
;; 		bmi  +
;; 		lda  #0
;; 		sta  $c2a0,x			; ??????????????????
;; 	+	bit  globflags
;; 		bvs  ->rts
;; 		clc
;; 		jmp  slip_unlock

		RELO_JMP(+)				; (skip data-inlay)

;------------------------------------------------------------------------
; global variables
;------------------------------------------------------------------------

slip_ipid:		.buf 1
packid:     .word 0
;; globflags:  .byte $ff
freelst:    .byte 0
iplst:      .word $ffff
icmplst:    .word $ffff
tcplst:     .word $ffff
udplst:     .word $ffff
errcnt:     .word 0
availbuf:   .byte 0
;; mydrvnum:   .byte $ff

ownip:      .byte 0,0,0,0

ack:        .buf 4
seq:        .buf 4

tcpflags:   .buf 1

; per buffer data (BUFNUM = 16)

buf_offsh:  .buf BUFNUM
buf_l2nx:   .buf BUFNUM
buf_mid:    .buf BUFNUM
buf_lenl:   .buf BUFNUM
buf_lenh:   .buf BUFNUM
buf_offs:   .buf BUFNUM

; per socket data (SOCKNUM = 8)

sockstat:   .buf SOCKNUM
localportl: .buf SOCKNUM
localporth: .buf SOCKNUM
remportl:   .buf SOCKNUM
remporth:   .buf SOCKNUM
remipa:     .buf SOCKNUM
remipb:     .buf SOCKNUM
remipc:     .buf SOCKNUM
remipd:     .buf SOCKNUM
reclstb:    .buf SOCKNUM
;recposl:    .buf SOCKNUM
recposh:    .buf SOCKNUM
sndbufpg:   .buf SOCKNUM
sndwrnx:    .buf SOCKNUM
sndrdnx:    .buf SOCKNUM
sndbufstat: .buf SOCKNUM
sndunaa:    .buf SOCKNUM ; = sequence number in sent packet
sndunab:    .buf SOCKNUM
sndunac:    .buf SOCKNUM
sndunad:    .buf SOCKNUM
rcvnxta:    .buf SOCKNUM ; = acknowledge number
rcvnxtb:    .buf SOCKNUM
rcvnxtc:    .buf SOCKNUM
rcvnxtd:    .buf SOCKNUM
timeout:    .buf SOCKNUM
sockipid:   .buf SOCKNUM
reclstt:    .buf SOCKNUM
;queueddatlst: .buf SOCKNUM
sockjob:    .buf SOCKNUM
socktype:   .buf SOCKNUM ; bit7:listen, bit6:accepted

		+						; end of data-inlay
		
;------------------------------------------------------------------------
end_of_permanent_code:
;------------------------------------------------------------------------

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

; read IP address from commandline

	-	rts						; unspecified IP address
								; learn it from first received packet
		
	-	ldx  #stderr
		bit  txt_howto
		jsr  lkf_strout
		jmp  lkf_suicide

read_IP:
		lda  userzp
		cmp  #1
		beq  --
		
		cmp  #2					; need exactly one argument
		bne  -
		
		ldy  #0
		sty  userzp
	-	iny
		lda  (userzp),y
		bne  -					; skip commandname
		iny
		
		lda  (userzp),y			; kludge for printing howto on -h
		cmp  #"-"
		beq  --
		
		jsr  read_decimal
		bcs  err_syntax
		sta  ownip
		ldx  #1

	-	lda  (userzp),y
		cmp  #"."
		bne  err_syntax
		iny
		beq  err_syntax
		jsr  read_decimal
		bcs  err_syntax
		sta  ownip,x
		inx
		cpx  #4
		bne  -

		rts

err_syntax:
		ldx  #stderr
		bit  txt_syntax
		jsr  lkf_strout
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

putc:	sec
		stx  [+]+1
		ldx  #stdout
		jsr  fputc
		nop
	+	ldx  #0
		rts

print_ip:
		lda  ownip
		ora  ownip+1
		ora  ownip+2
		ora  ownip+3
		beq  +					; "auto"
				
		lda  ownip
		jsr  print_decimal
		ldx  #1

	-	stx  userzp+4
		lda  #"."
		jsr  putc
		ldx  userzp+4
		lda  ownip,x
		jsr  print_decimal
		ldx  userzp+4
		inx
		cpx  #4
		bne  -

		rts

	+	ldx  #stdout
		bit  txt_auto
		jsr  lkf_strout
		rts
			
		
;;; ***********************************************************************
		
initialize:
		bit  packet_api
		bit  module_struct
		;; initialize used variables

		ldx  #stdin
		jsr  fclose

		lda  #8
		jsr  lkf_set_zpsize		; need 8 bytes of userzeropage

		jsr  read_IP
		
		ldx  userzp+1
		jsr  lkf_pfree			; free argument memory
		
		ldx  #stdout
		bit  txt_startup
		jsr  lkf_strout

		ldx  #SOCKNUM-1
	-	lda  #$ff
		sta  sockipid,x
		lda  #0
		sta  sockstat,x
		dex
		bpl  -
		ldx  #BUFNUM-1
		lda  #$ff
	-	sta  buf_l2nx,x
		txa
		dex
		bpl  -
		jsr  lkf_random
		tay
		jsr  lkf_random
		jsr  lkf_srandom		; initialize seed of random number generator

		lda  lk_ipid
		sta  slip_ipid
		
		;; search for packet interface

		lda  #0					; select first found device
		ldx  #<packet_api
		ldy  initialize+2		; #>packet_api
		jsr  lkf_get_moduleif
		bcc  +

		ldx  #stderr
		bit  txt_packnotavail
		jsr  lkf_strout
		lda  #1
		rts						; exit(1)

		;; add driver to system
	+	ldx  #<module_struct
		ldy  initialize+5		; #>module_struct
		jsr  lkf_add_module
		nop

		ldx  #stdout
		bit  txt_ok
		jsr  lkf_strout

		jsr  print_ip
		
		lda  #$0a
		jsr  putc
		sei
		
		;; <=== remove init code
		lda  #>(end_of_permanent_code+255-start_of_code)
		clc
		adc  start_of_code		; ( #>start_of_code )
		tax
		lda  #0
		sta  lk_memnxt-1,x		; ( memnxt of last page should be 0)
		jmp  enter_main_loop

.endofcode

dec_tab:
		.byte 10,100

		;; ...0123456789012345678901234567890123456789...
txt_startup:
		.text "TCP/IP for LNG (v2.2)",$0a
		.text "  by Poldi 1995 - Dec 22 1999",$0a,0
txt_packnotavail:
		.text "packetdriver refused to connect",$0a,0
txt_howto:
		.text "usage:  tcpip [<IP>]",$0a
		.text "  IP is current internet",$0a
		.text "  address in dotted decimal notation",$0a
		.text "  omitt for auto assignment",$0a,0
txt_syntax:
		.text "format of IP must match",$0a
		.text "<num>.<num>.<num>.<num> with each",$0a
		.text "number in the range of 0 to 255 !",$0a,0
txt_ok:
#ifdef DEBUG
		.text " (debug version)",$0a
#endif
		.text "TCP/IP started with IP=",0

txt_auto:
		.text "auto",0

end_of_code:
