;; For emacs: -*- MODE: asm; tab-width: 4; -*-
	
;;; low-level driver for standard userport RS232 interface
;;; Version 1.1 by Daniel Dallmann Sep29 1999
;;; Version 1.2 by Daniel Dallmann Nov17 1999
;;;   added -f switch to bypass hardware detection
;;; Version 1.3 by Daniel Dallmann Jan10 2000
;;;   different timer values for PAL/NTSC, C64/C128/SCPU
;;; many thanks to Errol Smith for providing some sample code

#include <system.h>
#include <jumptab.h>
#include <stdio.h>
#include <kerrors.h>
#include <config.h>
#include MACHINE_H

#begindef debug_putc(char)
		lda  #char
		ldx  #stdout
		sec
		jsr  fputc
		nop
#enddef
		
#define B_RXD $01		; received data
#define B_RTS $02		; 1=enabled
#define B_CTS $40		; 1=active
#define A_TXD $04		; transmitt data

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		jmp  initialize

		SELFMOD equ $fe00		; placeholder

		send_flag  equ nmizp
		recv_flag  equ nmizp+1
		txbits1    equ nmizp+2
		txbits2    equ nmizp+3
		txbitcount equ nmizp+4
		rxbits     equ nmizp+5
		semaphore  equ nmizp+6
						
		RELO_JMP(+)				; relocator jump

		;; times (comments please!):
		;;  Event-to-NMIHandler      48..50 (+43) mean=49
		;;  NMIHandler-to-TimerStart 59..92 (+43) mean=75
		;;  NMIHandler-to-ReadPort   14     (+43)

		;; start value for timer is:  constant - (49+75+49+14 + 43/2)

		;; baud constants (PAL - 985248 Hz)
		;; (subtract 208 for 1MHz, 93 for 2MHz, 9 for 20MHz)
		;; (NTSC constants are defined at the end of this file)
pal_const:	 .word 3283, 1641, 820, 409, 204, 102,  51
;ntsc_const: .word 3408, 1704, 851, 425, 212, 106,  53
		;;          300   600  1k2  2k4  4k8  9k6  19k2 <- baud rates

		;; API for higher layer
module_struct:
		.asc "ser"      ; module identifier
		.byte 2         ; module interface size
		.byte 2         ; module interface version number
		.byte 1         ; weight (number of available virtual devices)
		.word 0000      ; (reserved, used by kernel)
        
		;; functions provided by low-level serial driver
		;;  rs232_lock   (exclusive open)
		;;  rs232_unlock
		;;  rs232_ctrl   (X=command)

	+	jmp rs232_lock
		jmp rs232_unlock
		jmp rs232_ctrl
		
		;; interface speed for rs232_ctrl (passed in A, with X=0)
		;;  0:  300
		;;  1:  600
		;;  2:  1200
		;;  3:  2400
		;;  4:  4800
		;;  5:  9600
		;;  6:  19200
		;;  ... higher baudrates are not supported

;;; NMI handler -------------------------------------------------------------

nmi_struct:
		jmp  nmi_handler
		jmp  nmi_disable
		jmp  nmi_enable
		
trigrecv:
		sei
		bit  recv_flag
		bpl  +
		
		lda  #<rxstate_ws		; reset state of receiver
		sta  rxstate
		ldx  #%10010000
		stx  imap1
		
		lda  #0					; enable receiver
		sta  recv_flag
		
		lda  lk_nmidiscnt
		bne  +
		lda  CIA2_PRB			; activate RTS
		ora  #B_RTS
		sta  CIA2_PRB
		bit  CIA2_ICR			; clear pending NMIs
		stx  CIA2_ICR
	+	clc
		cli
		rts

port_setup:		
		;; setup CIA
		lda  CIA2_DDRA
		ora  #A_TXD
		sta  CIA2_DDRA			; TXD - output
		
		lda  CIA2_DDRB
		and  #~(B_RXD|B_CTS)	; RXD,CTS - input
		ora  #B_RTS				; RTS - output
		sta  CIA2_DDRB
		
		lda  CIA2_PRA			; TXD high (inactive)
		ora  #A_TXD
		sta  CIA2_PRA
		
		lda  CIA2_PRB
		and  #~(B_RTS)			; disable RTS
		sta  CIA2_PRB

		lda  #%01111111			; disable (FLAG/timerA+B) all interrupts
		sta  CIA2_ICR
		
		lda  #3					; set default baudrate (3 => 2400 baud)
		ldx  #0
		;jmp rs232_ctrl (fall through)

		;; rs223_ctrl
		;;  X=0:		set baudrate (X=baud code)
		;;  X=1:		set receivebyte_handler (bit$xxxx=address)
		;;  X=2:		set sendbyte_handler (bit$xxxx=address)
		;;  X=3:		trigger start of send
		;;  X=4:		trigger start of receive
		
rs232_ctrl:						; set baud reate
		cpx  #0
		beq  set_baud
		dex
		beq  set_rechndl
		dex
		beq  set_sndhndl
		dex
		beq  trigsnd
		dex
		beq  trigrecv
		lda  #lerr_notimp
_err:	
		jmp  lkf_catcherr

set_baud:
		tax
		lda  #lerr_illarg
		cpx  #6					; just 300...9600 is supported
		bcs  _err
		txa
		asl  a
		tay

		lda  pal_const+1,y
		sta  TMR_HI
		sta  SNDTMh
		lsr  a
		tax
		lda  pal_const,y
		sta  TMR_LO
		sta  SNDTMl
		ror  a
		adc  pal_const,y
		sta  STRTLO
		txa
		adc  pal_const+1,y
		tax						; value * 1.5

		sec
		lda  STRTLO
timer_offset equ *+1
		sbc  #<SELFMOD
		sta  STRTLO				; value - offset
		txa
		sbc  #0
		sta  STRTHI
		bcc  _err				; underflow, then error
		bne  +

		lda  STRTLO
		cmp  #40
		bcc  _err				; (shouldn't be less than 40)

	+	clc
default_handler:
		rts
		
set_rechndl:
		jsr  lkf_get_bitadr
		stx  rech_ptr+1
		sty  rech_ptr+2
		clc
		rts

set_sndhndl:
		jsr  lkf_get_bitadr
		stx  sndh_ptr1+1
		sty  sndh_ptr1+2
		stx  sndh_ptr2+1
		sty  sndh_ptr2+2
		clc
	-	cli
		rts

trigsnd:
		sei
		bit  send_flag
		bpl  -
		
		;; actually trigger sending
sndh_ptr2:
		jsr  SELFMOD			; look for byte to send
		bcs  +					; (nothing to send?)
		
		asl  a
		sta  txbits1
		lda  #$ff
		rol  a
		sta  txbits2
		lda  #9
		sta  txbitcount
		lda  #$00
		sta  send_flag
		
SNDTMl equ *+1
		lda  #0
		sta  CIA2_TALO
SNDTMh equ *+1
		lda  #0
		sta  CIA2_TAHI
		lda  #$11
		sta  CIA2_CRA			; start timerA (with forced reloading)
		lda  #$81
		sta  imap2
		ldx  lk_nmidiscnt
		bne  +
		bit  CIA2_ICR			; clear pending NMIs
		sta  CIA2_ICR			; enable timerA interrupts
	+	cli
		rts

;;; API --------------------------------------------------------------------
		
rs232_lock:
		;; (re-)initialize hardware
		
		jsr  lkf_disable_nmi
		lda  #$ff
		sta  semaphore
		ldx  #<nmi_struct
_haddr_hi:
		ldy  #>nmi_struct
		jsr  lkf_hook_nmi		; hook into system
		bcs  +


#ifdef EXPERIMENTAL
		;; direct modification of reset-vector for extra low latency
		;; (just for those who really know what they are doing)
		;; saves 16 cycles each NMI, not tested!
		ldx  #<nmi_hh
		ldy  nmi_hh-1		; #>nmi_hh
		stx  $fffa
		sty  $fffb
#endif

		;; now nmizp[0..7] can be used...
		lda  #$80
		sta  send_flag
		sta  recv_flag
		ldx  #1
		bit  default_handler
		jsr  rs232_ctrl
		ldx  #2
		bit  default_handler
		jsr  rs232_ctrl
		
		jsr  lkf_enable_nmi		; (will call nmi_enable)
		clc
	+	rts

rs232_unlock:
		jsr  lkf_disable_nmi
		ldx  #lsem_nmi
		jsr  lkf_unlock	; unlock NMI system semaphore (will call nmi_disable)
		jmp  lkf_enable_nmi

;;; ********************* start of imported code *****************************

#ifdef EXPERIMENTAL
		bit  nmi_hh
nmi_hh:
        pha                     ; old kernal jumps in here
        txa
        pha
        tya
        pha
        GETMEMCONF              ; remeber memory-configuration
        pha
        lda  #MEMCONF_SYS       ; value for (IRQ/NMI memory configuration)
        SETMEMCONF              ; switch to LUnix memory configuration
		;; (16 cycles saved)
#endif

		;; CIA2 - timerA used for send-interrupts
		;; CIA2 - timerB used for receive-interrupts

nmi_handler:
		lda  #$7f
		sta  CIA2_ICR			; disable further interrupts
		ldy  CIA2_PRB			; read RXD
		lda  CIA2_ICR
		bpl  leave
		lsr  a
		and  #$09
		tax
		bcc  ++
		
		;; send next bit
		bit  send_flag
		bmi  ++
		lda  CIA2_PRA
		ora  #A_TXD
		ror  txbits2
		ror  txbits1			; (filled with 1s - for stopbits!)
		bcs  +
		eor  #A_TXD
	+	sta  CIA2_PRA
		dec  txbitcount
		
	+	bit  recv_flag
		bmi  leave
		txa
rxstate equ *+1
		bne  got_startbit		; (default is rxstate_ws)
rxstate_ws equ got_startbit-*	; value for "wating for startbit"
rxstate_wd equ got_databit-*	; value for "waiting for databit"
		beq  leave
		
		;; receive next bit
got_databit:
		and  #$01
		beq  leave
		tya
		lsr  a
		ror  rxbits
		bcc  leave
		lda  rxbits
		sta  rxbyte
		lda  #<rxstate_ws
		ldx  #$90
		stx  rxflag
		stx  CIA2_CRB			; stop timerB
		bne  swp				; (always jump)

		;; received start bit
got_startbit:
		tya
		lsr  a
		bcs  leave
STRTLO equ *+1
		lda  #$42
		sta  CIA2_TBLO
STRTHI equ *+1
		lda  #$04
		sta  CIA2_TBHI
		lda  #$11
		sta  CIA2_CRB			; start timer B (force loading start values)
TMR_LO equ *+1
		lda  #$4D
		sta  CIA2_TBLO
TMR_HI equ *+1
		lda  #$03
		sta  CIA2_TBHI
		lda  #$80				; reset bit-counter
		sta  rxbits
		lda  #<rxstate_wd
		ldx  #$82
swp:	sta  rxstate		
		stx  imap1
		
leave:
imap1 equ *+1					; interrupt map for receiving
		lda  #$00
imap2 equ *+1					; interrupt map for sending
		ora  #$00
		sta  CIA2_ICR			; re-enable interrupts
		
		;; some further processing of what has happened
		;; (maybe interrupted by new NMIs)

		inc  semaphore			; only one instance may walk in here!
		bne  exit
		
rxflag equ *+1
		lda  #0
		beq  +
		
		;; need to store a received byte
		lda  #0
		sta  rxflag
rxbyte equ *+1
		lda  #0
rech_ptr:
		jsr  SELFMOD
		bcc  +
		lda  #$80
		sta  recv_flag
		sta  imap1
		lda  #$12
		sta  CIA2_ICR
		lda  CIA2_PRB			; deactivate RTS
		and  #~B_RTS
		sta  CIA2_PRB

	+	bit  txbitcount
		bpl  exit
		lda  #$80
		sta  send_flag

		;; need to get a byte to send
sndh_ptr1:
		jsr  SELFMOD
		bcs  stop_snd
		
		asl  a
		sta  txbits1
		lda  #$ff
		rol  a
		sta  txbits2
		lda  #9
		sta  txbitcount
		lda  #$00
		sta  send_flag

exit:	dec  semaphore
		
		pla						; restore memory-configuration
		SETMEMCONF
		pla						; restore register and return
		tay
		pla
		tax
		pla
		rti
		
stop_snd:
		lda  #$80
		sta  imap2
		lda  #$01
		sta  txbitcount
		sta  CIA2_ICR
		bne  exit
		
;-----  DISABLE RS232 NMI

nmi_disable:
	-	lda  imap2
		and  #$7f
		bne  -					; wait until current data is sent

		lda  #$7f				; disable all NMIs
		sta  CIA2_ICR

		lda  imap1
		and  #$7f
		beq  +
		
		lda  #<rxstate_ws		; reset state of receiver
		sta  rxstate
		lda  #$90
		sta  imap1
		sta  CIA2_CRB			; stop timerB

		lda  CIA2_PRB
		and  #~(B_RTS)			; disable RTS
		sta  CIA2_PRB
		
	+	plp
		rts

		;; enable NMI
nmi_enable:
		lda  imap1
		and  #$7f
		beq  +
		
		lda  CIA2_PRB			; activate RTS
		ora  #B_RTS
		sta  CIA2_PRB
		
	+	lda  imap1
		ora  imap2
		bit  CIA2_ICR			; clear pending interrupts
		sta  CIA2_ICR	
		plp
		rts


;;; **************************************************************************
end_of_permanent_code:	

		
		;; initialisation

		bit  module_struct
initialize:
		;; initialize I/O port
		jsr  port_setup
		
		;; parse commandline
		ldx  userzp
		cpx  #1
		beq  normal_mode
		cpx  #2
		beq  +
		
HowTo:	ldx  #stdout
		bit  howto_txt
		jsr  lkf_strout
		lda  #1
		rts						; exit(1)
		
	+	ldy  #0
		sty  userzp
	-	iny						; skip first argument (command name)
		lda  (userzp),y
		bne  -
		iny
		lda  (userzp),y
		cmp  #"-"
		bne  HowTo
		iny
		lda  (userzp),y
		cmp  #$66				; "f"
		bne  HowTo
		beq  bypass_hwd			; bypass hardware detection

normal_mode:
		;; check for interface
		;; an idle interface should pass this
		lda  CIA2_PRB
		and  #B_RXD
		beq  not_detected
		lda  CIA2_ICR			; clear pending interrupts

		lda  CIA2_DDRB
		ora  #B_RXD				; confg for output (temporary)
		sta  CIA2_DDRB
		lda  CIA2_PRB
		and  #~B_RXD
		sta  CIA2_PRB			; see if we can sink it
		lda  CIA2_PRB
		and  #B_RXD
		bne  not_detected
		lda  CIA2_ICR			; clear pending interrupts
		and  #$10				; sinking RXD should generate a flag int.
		beq  not_detected

bypass_hwd:
		lda  CIA2_DDRB
		and  #~B_RXD
		sta  CIA2_DDRB

		ldx  userzp+1
		jsr  lkf_pfree			; free memory used for commandline arguments
		
		ldx  #<module_struct
		ldy  initialize-1		; #>module_struct 
		jsr  lkf_add_module
		bcc  is_available

		lda  #$01
		rts						; return with error
		
not_detected:

		lda  #0
		sta  CIA2_DDRB
		ldx  #stderr
		bit  not_txt
		jsr  lkf_strout
		nop
		lda  #1
		rts
				
is_available:
		ldx  #stdout
		bit  ok_txt
		jsr  lkf_strout
		nop

		jsr  set_timeroffset
		
		;; run-time reallocation
		
		lda  start_of_code
		clc
		adc  #>(nmi_struct-start_of_code)
		sta  _haddr_hi+1
		
		;; finished, free unused memory and exit
		
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

out:	sec
		ldx  #stdout
		jsr  fputc
		nop
		rts
		
		;; timer-offset depends on machine (and VIC/VDC)
set_timeroffset:
		lda  lk_archtype
		and  #larchf_pal
		bne  +
		
		;; replace pal by ntsc values
		ldx  #6
	-	lda  ntsc_const,x
		sta  pal_const,x
		dex
		bpl  -
		
		;; choose offset
	+	lda  lk_archtype
		and  #larchf_type
		cmp  #larch_c64
		bne  +
		ldx  #208				; (C64 @ 1MHz with VIC)
		bne  ++
	+	ldx  #93				; (C128 @ 2MHz without VIC)

	+	lda  lk_archtype
		and  #larchf_scpu
		beq  +
		ldx  #9					; (C64/128 @ 20MHz)	
		
	+	stx  timer_offset
		rts
		
		RELO_END ; no more code to relocate

		;; baud constants (NTSC - 1022727 Hz)
ntsc_const:	.word 3408, 1704,  851,  425,  212,  106,  53
		;;         300   600   1k2   2k4   4k8   9k6  19k2 <- baud rates

howto_txt:
		.text "usage: rs232std [-f]",$0a
		.text "  -f  force loading",$0a
		.text "      (bypass hardware detection)",$0a,0
		
not_txt:
		.text "sorry, no RS232-std-interface detected"
		.byte $0a,$00
		
ok_txt:
		.text "RS232-std-driver v1.3 (NMI) registered",$0a
		.text " baudrates: 300 600 1200 2400",$0a
		.text "            (4800 9600 19200)"
		.byte $0a,$00

end_of_code:
