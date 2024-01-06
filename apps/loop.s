; Packetdriver for LNG-TCP/IP
; loop back driver

; packetdriver MUST keep the order of the packets
; in both, send and receive direction !


;;  #define DEBUG

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

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		jmp  initialize

		RELO_JMP(+)    ; (don't try to relocate data)

module_struct:
		.asc "pkg"				; module identifier
		.byte 3					; module interface size
		.byte 1					; module interface version number
		.byte 1					; weight (num. of available virtual devices)
		.word $0000				; (reserved)
	
	+	jmp  loop_lock
		jmp  loop_unlock
		jmp  loop_putpacket
		jmp  loop_getpacket

;-------------------------------------------------------------------
; API
;-------------------------------------------------------------------

loop_unlock:
		sei
		lda  lk_ipid
		cmp  user_ipid
		bne  +               ; no permission
		lda  #$ff
		sta  user_ipid
		clc
		cli
		rts

loop_lock:
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

		;; get packet from loop back
		;; > c=1: error, no packet available
		;; > c=0: A=startpage, X/Y=length of packet
		
loop_getpacket:	
		sei
		ldx  looplst_t			; get top of queue
		bmi  -					; (empty queue?)
		lda  buf_l2nx,x			; remove top element
		sta  looplst_t
		bpl  +
		sta  looplst_b
		
	+	ldy  freelst			; get pointer to list of free slots
		stx  freelst			; new item to top of free list
		tya
		sta  buf_l2nx,x			; append old free list
		
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

		;; pass packet to loop
		;; < A=startpage, X/Y=length of packet
		;; < c=0: empty buffer, c=1: filled buffer (packet)
		
		;; > c=0: ok packet accepted for delivery
		;; > c=1: error, too many packet in queue
		
loop_putpacket:
		bcc  discard			; empty buffer are simply discarded
		
		sei
		bit  freelst			; check for free slot
		bmi  --
		
		pha
		txa
		pha
		ldx  freelst			; get top item from free list
		tya
		sta  buf_lenh,x
		pla
		sta  buf_lenl,x
		pla
		sta  buf_mid,x
		lda  buf_l2nx,x
		sta  freelst
		lda  #$80
		sta  buf_l2nx,x

		ldy  looplst_b			; add to bottom of queue
		bmi  +
		txa
		sta  buf_l2nx,y
		bpl  ++
	+	stx  looplst_t
	+	stx  looplst_b
				
		clc
		cli
		db("put snd pack")
		rts

discard:		
		tax
		jsr  lkf_pfree
		clc
		rts
	
		RELO_JMP(+)
			
user_ipid:		.byte $ff
		
freelst:   .byte 0   ; list of free slots

looplst_t:  .byte $ff ; top of queue
looplst_b:  .byte $ff ; bottom of queue

buf_mid:   .buf maxbufs
buf_lenl:  .buf maxbufs
buf_lenh:  .buf maxbufs
buf_l2nx:  .buf maxbufs

	+	;; end of data inlay

;;; ************************ initialization *****************************
		
initialize:	
	hibyte_modstruct equ *+2
		bit  module_struct
		
		lda  #$ff
		ldx  #maxbufs-1

	-	sta  buf_l2nx,x
		txa
		dex
		bpl  -

		lda  userzp
		cmp  #1
		bne  HowTo				; no arguments accepted
		
		ldx  userzp+1
		jsr  lkf_free			; free argument-memory
		
		print_string(welc_txt)

		;; add slip API to system
		ldx  #<module_struct
		ldy  hibyte_modstruct
		jsr  lkf_add_module
		bcc  +

		lda  #1
		rts						; exit(1)
		
	+	print_string(txt_running)
		
		; cut off unneccessary tail of (initialization) code and
		; terminate locking used pages for ever (?)

		lda  #>(initialize+255-start_of_code)
		cmp  #>(end_of_code-start_of_code)
		beq  +
		bcs  ++
	+	clc
		adc  start_of_code
		tax
		jmp  lkf_fix_module
		
		;; nothing to free
	+	ldx  #0
		jmp  lkf_fix_module		

HowTo:
		print_string(txt_howto)
		lda  #1
		jmp  lkf_suicide

		.byte 2					; end of code marker

txt_howto:
		.text "usage:  loop", $0a
		.text "  install loop back packet driver",$0a,0

txt_running:
		.text "up and running"
		.byte $0a,$00

welc_txt:
		.text "loop back - packet driver V1.0"
		.byte $0a,$00

end_of_code:
