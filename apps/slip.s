;; For emacs: -*- MODE: asm; tab-width: 4; -*-
	
; Packetdriver for LNG-TCP/IP
; using serial driver and SLIP encapsulation

; packetdriver MUST keep the order of the packets
; in both, send and receive direction !

;; #define DEBUG

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

#define SELFMOD     $ff00		
#define maxbufs     12         ; max number of handled buffers

		
		;; simple test application for the new serial driver API		
		  				
		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		jmp  initialize

		RELO_JMP(+)				; (don't try to relocate data)

module_struct:
		.asc "pkg"				; module identifier
		.byte 3					; module interface size
		.byte 1					; module interface version number
		.byte 1					; weight (num. of available virtual devices)
		.word $0000				; (reserved)
	+	jmp  slip_lock
		jmp  slip_unlock
		jmp  slip_putpacket
		jmp  slip_getpacket

;;; ------------------------------------------------------------------------
		
		;; called within NMI-handler
		;; (NOT in conext of this task!! don't use userzp)
		;; < A=received byte
		;; > c=1 means no more bufferspace left, don't call me again
		;;       until "trigger receive"
rec_handler:
		bit  recstat
		bmi  esced
		cmp  #192
		beq  packend
		cmp  #219
		beq  isesc

dest_addr equ  *+1
mem_write:
		sta  SELFMOD
		inc  dest_addr
		beq  +              ; crossed page boundary
		clc
		rts		

isesc:	lda  #128
		sta  recstat
		clc
		rts
          
	+	clc                  ; ... next page
		lda  dest_addr+1
		adc  #1
		sta  dest_addr+1
		sec
		ldx  reclst_c
		sbc  buf_mid,x       ; i assume buf_lenl is $00 !!!!!
		cmp  buf_lenh,x
		bcc  isnotfull

ignoreRest:                    ; packet is too big ! (disard)
		lda  #192
		sta  recstat
isnotfull:
recend:	clc
		rts

esced:	bvs  ignore2
		cmp  #221
		beq  convtoesc
		cmp  #220
		bne  ignoreRest
		lda  #192
		SKIP_WORD				; ( "bit $dba9" is ok)

convtoesc:
		lda  #219
		ldx  #0
		stx  recstat
		jmp  mem_write

ignore2:  
		cmp  #192
		bne  recend
          
packend:  
		bit  recstat
		bvc  isvalid1

skip:	inc  errcnt
		bne  +
		inc  errcnt+1
	+	inc  loss_count
		jmp  setpage

isvalid1: 
		inc  reccnt
		bne  +
		inc  reccnt+1
		bne  +
		inc  reccnt+2
	+
#ifdef DEBUG
		inc  debug3+10
#endif
		ldx  reclst_c
		lda  dest_addr+1
		sec
		sbc  buf_mid,x
		bne  +
		lda  dest_addr
		cmp  #20
		bcc  skip            ; discard packets smaller than 20 bytes
		lda  #0
	+	sta  buf_lenh,x
		lda  dest_addr
		sta  buf_lenl,x
		lda  #$40
		sta  buf_stat,x      ; mark buffer ("done")
		lda  buf_l2nx,x      ; switch no next buffer
		bmi  endof_reclst
		sta  reclst_c

setpage:  
		ldx  reclst_c        ; prepare for writing into current buffer
		bmi  nomorebuffer
		lda  buf_mid,x
		sta  dest_addr+1
		lda  #0
		sta  dest_addr
		sta  recstat
		clc
		rts

endof_reclst:
		sta  reclst_c

nomorebuffer:
		lda  #192
		sta  recstat
		;; sec <================== change later
		clc
		rts
		
		;; called within NMI-handler
		;; (NOT in conext of this task!! don't use userzp)
		;; > A=byte to send
		;; > c=1 means no more bytes to send, don't call me again
		;;       until "trigger send"

		;; sndstat:
		;;     $00 - idle
		;;     $08 - next char is from new packet
		;;     $10 - next char marks end of packet
		;;     $20 - next is (esc-) esc
		;;     $40 - next is (esc-) end
		;;     $60 - next char to be set from buffer
		
send_handler:
		lda  #$20
		bit  sndstat
		bvc  _00xx
		beq  _010x
		;; _011x is snd next

source_addr equ *+1
		ldx  SELFMOD
		cpx  #192
		beq  escend
		cpx  #219
		beq  escesc
aftlda:	stx  snd_retok+1			; remember char
		inc  source_addr
		bne  +
		inc  source_addr+1
	+	lda  #$60
		sta  sndstat
		inc  sndlenl
		bne  snd_retok
		inc  sndlenh
		bne  snd_retok
		;; end of packet
		lda  #$10
		sta  sndstat
snd_retok:
		lda  #<SELFMOD
		clc
		rts
          
escend:	lda  #$40
		SKIP_WORD
escesc:	lda  #$20
		sta  sndstat
		lda  #219
		clc
		rts
		
_010x:	;; is esced end  
		ldx  #220
		SKIP_WORD
		
_001x:	;; is esced esc   
		ldx  #221
		jmp  aftlda
          
_00xx:	bne  _001x
		;; _000x
		lda  sndstat
		beq  +
		and  #$10
		beq  snp
          
		lda  #$08
		sta  sndstat
	+	lda  #$c0				; (end)
		clc
		rts
          
snp:	bit  sndlock         ; get next buffer
		bmi  eloo
		
		ldx  sndlst_c
		lda  #$40
		sta  buf_stat,x      ; mark buffer ("done")
		lda  buf_l2nx,x
		sta  sndlst_c
#ifdef DEBUG
		inc  debug3+11
#endif

news:	ldx  sndlst_c
		bmi  nompage
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
		lda  #$60
		sta  sndstat

eloo:	lda  #$c0
		clc
		rts

nompage:  
		lda  #0
		sta  sndstat
		sec
		rts

;-------------------------------------------------------------------
; API
;-------------------------------------------------------------------

slip_unlock:
		sei
		lda  lk_ipid
		cmp  user_ipid
		bne  +               ; no permission
		lda  #$ff
		sta  user_ipid
		clc
		cli
		rts

slip_lock:
		sei
		lda  user_ipid
		bpl  +               ; can't handle 2 users
		lda  lk_ipid
		sta  user_ipid
		clc
		cli
		rts

	-	db("putpack overrun")
		tax
		jsr  lkf_pfree
		
	+ -	sec
		cli
		rts

		;; get packet from slip-driver
		;; > c=1: error, no packet available
		;; > c=0: A=startpage, X/Y=length of packet
		
slip_getpacket:	
		sei
		ldx  reclst_t
		bmi  -
		lda  buf_stat,x
		cmp  #$40
		bne  -
		lda  buf_l2nx,x
		sta  reclst_t
		bpl  +
		sta  reclst_b
	+	ldy  freelst
		stx  freelst
		tya
		sta  buf_l2nx,x
		lda  buf_mid,x
		pha
		ldy  buf_lenh,x
		lda  buf_lenl,x
		tax
		pla
		clc
		cli
		db("got pack")
		rts

		;; pass packet to slip-driver
		;; < A=startpage, X/Y=length of packet
		;; < c=0: empty buffer, c=1: filled buffer (packet)
		
		;; > c=0: ok packet accepted for delivery
		;; > c=1: error, too many packet in queue
		
slip_putpacket:
		sei
		bit  freelst
		bmi  --
		pha
		txa
		pha
		ldx  freelst
		tya
		sta  buf_lenh,x
		pla
		sta  buf_lenl,x
		pla
		sta  buf_mid,x
		lda  buf_l2nx,x
		sta  freelst
		lda  #$80
		sta  buf_stat,x
		sta  buf_l2nx,x
		bcc  _putinreclst

		ldy  sndlst_b
		bmi  +
		txa
		sta  buf_l2nx,y
		bpl  ++
	+	stx  sndlst_t
	+	stx  sndlst_b
		
		dec  sndlock
		lda  sndstat
		bne  +
		;; sending has been disabled, must enable it again
		stx  sndlst_c
		jsr  news
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
		ldy  reclst_b
		bmi  +
		txa
		sta  buf_l2nx,y
		bpl  ++
	+	stx  reclst_t
	+	stx  reclst_b
		bit  reclst_c
		bpl  +
		stx  reclst_c
	+	clc
		cli
		db("put rec pack")
		rts

;-------------------------------------------------------------------
; main
;-------------------------------------------------------------------

; main loop

clean_sndlst:
		sei
		ldx  sndlst_t
		bmi  ++
		lda  buf_stat,x
		cmp  #$40
		bne  ++
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

	+	cli
		rts

main_loop:
		jsr  clean_sndlst

		lda  reclst_c
		bpl  +
		lda  reclst_t
		bmi  +
		sta  reclst_c
		db("SLIP:reclst reactivated")

	+	lda  sndlst_c
		bpl  +
		lda  sndlst_t
		bmi  +
		sta  sndlst_c
		db("SLIP:sndlst reactivated")

	+	lda  loss_count
		beq  +
		db("SLIP:lost incoming packet")
		dec  loss_count
		lda  reclst_c
		bmi  +
		db("SLIP:strange, buffer is avail")

	+	lda  freelst
		bpl  +
		db("SLIP:freelist is empty")

	+	;; check for blocked processes ??

		jsr  lkf_force_taskswitch
		jmp  main_loop

		RELO_JMP(out)
		
;-------------------------------------------------------------------
; variables
;-------------------------------------------------------------------

recstat:   .byte 0
reccnt:    .byte 0,0,0
loss_count: .byte 0
errcnt:    .byte 0,0
sndstat:   .byte 0
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
		
buf_stat:  .buf maxbufs
buf_mid:   .buf maxbufs
buf_lenl:  .buf maxbufs
buf_lenh:  .buf maxbufs
buf_l2nx:  .buf maxbufs

;;; ************************ initialization *****************************
		
out:	sec
		ldx  #stdout
		jsr  fputc
		nop
		rts

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
		ldx  #maxbufs-1

	-	sta  buf_l2nx,x
		txa
		dex
		bpl  -

		jsr  parse_commandline
		sta  userzp						; remember baudcode
		ldx  userzp+1
		jsr  lkf_free			; free argument-memory
		
		lda  #0
		ldx  #<moddesc
		ldy  hibyte_moddesc
		jsr  lkf_get_moduleif
		bcs  pr_error

		lda  #192
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

		;; add slip API to system
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

		jmp  main_loop


parse_commandline:
		lda  userzp
		cmp  #2
		bne  HowTo
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
		
.endofcode 

txt_howto:
		.text "usage:  slip [<baudrate>]" : .byte $0a
		.text "  baudrates: 300 600 1200 2400" : .byte $0a
		.text "   4800 9600 19200 38400 57600" : .byte $0a,0

txt_running:
		.text "up and running"
		.byte $0a,$00

welc_txt:
		.text "SLIP - packet driver V1.0"
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
		
end_of_code:
