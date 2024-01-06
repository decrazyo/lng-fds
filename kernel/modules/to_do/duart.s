;; For emacs: -*- MODE: asm; tab-width: 4; -*-

;;; low-level driver for IDE64 DUART (68C6861)
;;; based on Swiftlink driver by Daniel Dallman
;;; and Novaterm DUART driver by Josef Soucek and Tomas Pribyl
;;;
;;; by Maciej 'YTM/Elysium' Witkowiak <ytm@elysium.pl>
;;; v0.1 08.12.2001
;;;	 - never tested
;;;      - uses only channel A

#include <system.h>
#include <jumptab.h>
#include <stdio.h>
#include <kerrors.h>
#include <config.h>
#include MACHINE_H

		start_of_code equ $1000

		.org start_of_code

		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		jmp  initialize

#define CMDVAL_NOI  %00000000	; no interrupts
#define CMDVAL_GO2  %00000011	; both, transmit and receive interrupts
#define CMDVAL_INHNDL %00000010 ; no transmit interrupts
#define CMDVAL_GO   %00000010   ; just receive interrupts

#define SND_IRQ	    %00000001	; was TxIRQ
#define REC_IRQ	    %00000010	; was RxIRQ

		SELFMOD equ $fe00		; placeholder

		send_flag equ nmizp
		recv_flag equ nmizp+1

		RELO_JMP(+)				; relocator jump

module_struct:
		.asc "ser"      ; module identifier
		.byte 2         ; module interface size
		.byte 2         ; module interface version number
		.byte 1         ; weight (number of available virtual devices)
		.word 0000      ; (reserved, used by kernel)

		;; functions provided by low-level serial driver
		;;  rs232_lock   (exclusive open)
		;;  rs232_unlock
		;;  rs232_ctrl   (X=baud rate)
		;;  rs232_getc
		;;  rs232_putc
		;;               (status?)

	+	jmp rs232_lock
		jmp rs232_unlock
		jmp rs232_ctrl

		;; interface speed for rs232_ctrl (passed in X register)
		;;  0:  300
		;;  1:  600
		;;  2:  1200
		;;  3:  2400
		;;  4:  4800
		;;  5:  9600
		;;  6:  19200
		;;  7:  38400
		;;  8:  57600
		;;  9:	115200

		;; DUART XR68C681 registers
		duart	equ $de00	;base address in IDE64
		MR1A	equ duart	;Mode register, channel A(1)
		MR2A	equ duart	;Mode register, channel A(2)
		SRA	equ duart+1	;Status register, channel A
		CSRA	equ duart+1	;Clock select register, channel A
		MISR	equ duart+2	;Masked interrupt status register
		CRA	equ duart+2	;Command register, channel A
		RHRA	equ duart+3	;Rx holding register, channel A
		THRA	equ duart+3	;Tx holding register, channel A
		IPCR	equ duart+4	;Input port change register
		ACR 	equ duart+4	;Auxiliary control register
		ISR	equ duart+5	;Interrupt status register
		IMR	equ duart+5	;Interrupt mask register
		CTU	equ duart+6	;Counter/timer Upper byte register
		CTL	equ duart+7	;Counter/timer Lower byte register

		MR1B	equ duart+8	;Mode register, channel B(1)
		MR2B	equ duart+8	;Mode register, channel B(2)
		SRB	equ duart+9	;Status register, channel B
		CSRB	equ duart+9	;Clock select register, channel B
		CRB	equ duart+10	;Command rgister, channel B
		RHRB	equ duart+11	;Rx holding register, channel B
		THRB	equ duart+11	;Tx holding register, channel B
		IVR	equ duart+12	;Interrupt vector register
		IP	equ duart+13	;Input port
		OPCR	equ duart+13	;Output port configuration register
		SCC	equ duart+14	;Start counter/timer command
		SOPBC	equ duart+14	;Set output port bit command
		STC	equ duart+15	;Stop counter/timer command
		COPBC	equ duart+15	;Clear output port bits 1 command


;;; NMI handler -------------------------------------------------------------


nmi_struct:
		jmp  nmi_handler
		jmp  nmi_disable
		jmp  nmi_enable

nmi_enable:
brate:		lda  #%10111011			; 9600 baud
		sta  CSRA
		lda  #%00010011			;8bit no par
		sta  MR1A
		lda  #%00000111			;1 stop bit
		sta  MR2A
		lda  #%00000001			;OP0 RTS CH_A
		sta  SOPBC			;set RTS=1
		bit  send_flag
		bmi  +
		lda  #CMDVAL_GO2
		bne  ++
	+	lda  #CMDVAL_GO			; no XMIT-IRQ
	+	sta  duartcom+1
		sta  IMR			; RECV-IRQ enabled
		plp
		rts

nmi_disable:
		ldx  #CMDVAL_NOI
		stx  duartcom+1
		stx  IMR			; no more send interrupts
	-	lda  SRA
		and  #%00000100			; input port
		beq  -
		lda  IP
		and  #%00000100			; IP2 test DSR_A
		bne  -				; wait until current byte is sent
		plp
		rts

nmi_handler:
		lda  #CMDVAL_INHNDL
		sta  IMR			; prevent any more interrupts
		lda  ISR
ckloop:
		sta  nmizp+2
		and  #REC_IRQ
		beq  cksend			; skip, if nothing has been received

	-	lda  RHRA			; read byte from DUART
		bit  recv_flag
		bmi  next_char			; skip byte

		ldx  #CMDVAL_NOI		; no interrupts, ask remote to stop transmit
		stx  IMR
		ldx  #%00000001			; drop RTS
		stx  COPBC
rech_ptr:	jsr  SELFMOD
		bcc  +
		lda  #$80			; stop receiving
		sta  recv_flag
	+	lda  #CMDVAL_INHNDL
		sta  IMR			; no interrupts, may transmit again
		lda  #%00000001
		sta  SOPBC			; raise RTS

next_char:
		lda  nmizp+2
		and  #SND_IRQ
		ora  ISR
		sta  nmizp+2
		and  #REC_IRQ
		bne  -

cksend:	
		lda  nmizp+2
		and  #SND_IRQ
		beq  cklast
		bit  send_flag
		bmi  send_done

sndh_ptr:	jsr  SELFMOD
		bcs  stopsnd
		sta  THRA
send_done:		
		lda  #REC_IRQ
		bne  +

cklast:		lda  #SND_IRQ|REC_IRQ
	+	and  ISR
		bne  ckloop

		pla				; restore memory-configuration
		SETMEMCONF
		pla				; restore register and return
		tay
		pla
		tax
duartcom:	lda  #CMDVAL_GO2		; value for command register
		sta  IMR
		pla
		rti

stopsnd:
		lda  #CMDVAL_GO
		sta  IMR
		sta  duartcom+1
		lda  #$80
		sta  send_flag
		bne  send_done

;;; API --------------------------------------------------------------------

rs232_lock:
		;; (re-)initialize duart

		jsr  lkf_disable_nmi
		ldx  #<nmi_struct
_haddr_hi:
		ldy  #>nmi_struct
		jsr  lkf_hook_nmi		; hook into system
		bcs  +

		lda  #0
		sta  need_sndtrig		

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

		lda  #%00100000			; reset rx
	        sta  CRA	      
		lda  #%00110000			; reset tx
		sta  CRA
		lda  #%00000101			; enable tx,rx
	        sta  CRA
		lda  #%00000101			; DTR = 1, RTS = 1 CH_A
		sta  SOPBC
		lda  ISR

		jsr  lkf_enable_nmi		; (will call nmi_enable)
		clc
	+	rts

rs232_unlock:
		jsr  lkf_disable_nmi
		ldx  #lsem_nmi
		jsr  lkf_unlock	; unlock NMI system semaphore (will call nmi_disable)
		jmp  lkf_enable_nmi

set_baud:
		tax
		lda  #lerr_illarg		
		cpx  #10
		bcs  _err			; (return with error if >=10)
		lda  baudrate_2, x
		beq  +
		lda  #%10100000			;tr X=1
	        sta  CRA
		lda  #%10000000			;rx X=1
		sta  CRA
		jmp  ++
	+	lda  #%10110000			;tr X=0
		sta  CRA
		lda  #%10010000			;rx X=0
		sta  CRA
	+	lda  baudrate, x		;low=tx hi=rx
		sta  CSRA
		sta  brate+1
		lda  #%00000000			;Bit R.Set #1
		sta  ACR			;ACR [bit 7]											  																       
		clc
default_handler:
		rts

		;; rs223_ctrl
		;;  X=0:		set baudrate (X=baud code)
		;;  X=1:		set receivebyte_handler (bit$xxxx=address)
		;;  X=2:		set sendbyte_handler (bit$xxxx=address)
		;;  X=3:		trigger start of send
		;;  X=4:		trigger start of receive

rs232_ctrl:					; set baud reate
		cpx  #0
		beq  set_baud
		txa
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

set_rechndl:
		jsr  lkf_get_bitadr
		stx  rech_ptr+1
		sty  rech_ptr+2
		clc
		rts

set_sndhndl:
		jsr  lkf_get_bitadr
		stx  sndh_ptr+1
		sty  sndh_ptr+2
		clc
	-	cli
		rts

trigsnd:
		sei
		bit  send_flag
		bpl  -
		lda  #0
		sta  send_flag
		lda  lk_nmidiscnt
		bne  +
		lda  #CMDVAL_GO2
		sta  duartcom+1
		sta  IMR
	+	cli
		rts

trigrecv:
		lda  #0
		sta  recv_flag
		clc
		rts

		RELO_JMP(+)

baudrate:	; X,lo=tx hi=rx
		.byte %01000100   ;300
		.byte %01100110   ;1200
		.byte %10001000   ;2400
		.byte %10011001   ;4800
		.byte %10111011   ;9600
		.byte %11001100   ;19200
		.byte %11001100   ;38400
		.byte %01110111   ;57600
		.byte %10001000   ;115200
baudrate_2:	.byte 0, 0, 0, 0, 0, 1, 0, 1, 1
	+

;;; **************************************************************************
end_of_permanent_code:	


		;; initialisation

		bit  module_struct
initialize:
		;; parse commandline
		ldx  userzp
		cpx  #1
		beq  normal_mode
		cpx  #2
		beq  goon1

HowTo:		ldx  #stdout
		bit  howto_txt
		jsr  lkf_strout
		lda  #1
		rts				; exit(1)

not_duart:
		ldy  #0
	-	lda  not_txt,y
		beq  +
		sec
		ldx  #stdout
		jsr  fputc
		nop
		iny
		bne  -
	+	lda  #1
		rts

goon1:		ldy  #0
		sty  userzp
	-	iny				; skip first argument (command name)
		lda  (userzp),y
		bne  -
		iny
		lda  (userzp),y
		cmp  #"-"
		bne  HowTo
		iny
		lda  (userzp),y
		cmp  #$66			; "f"
		bne  HowTo
		beq  bypass_hwd			; bypass hardware detection

normal_mode:
		;; check for DUART
		lda #%00010000			; Reset MR pointer
		sta CRA
		lda #%00010011			; 8bit no par
		sta MR1A
		lda #%00000111			; 1 stop bit
		sta MR2A
		lda #%00010000			; Reset MR pointer
		sta CRA
		lda MR1A			; test MR1A register
		cmp #%00010011
		bne not_duart
		lda MR2A			; test MR2A register
		cmp #%00000111
		bne not_duart

bypass_hwd:
		ldx  #<module_struct
		ldy  initialize-1		; #>module_struct 
		jsr  lkf_add_module
		bcc  is_available

		lda  #1
		rts				; return with error

is_available:

		ldx  #stdout
		bit  ok_txt
		jsr  lkf_strout

		;; runtime - code relocation

		lda  start_of_code
		clc
		adc  #>(nmi_struct-start_of_code)
		sta  _haddr_hi+1

		;; finished, free unused memory and exit

		lda  #>(end_of_permanent_code+255-start_of_code)
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

		RELO_END ; no more code to relocate

need_sndtrig:	.buf 1

howto_txt:
		.text "usage: duart [-f]",$0a
		.text "  -f  force loading",$0a
		.text "      (bypass hardware detection)",$0a,0

not_txt:
		.text "sorry, no DUART detected"
		.byte $0a,$00

ok_txt:
		.text "DUART ("
		.digit duart>12
		.digit (duart>8) & 15
		.digit (duart>4) & 15
		.digit duart & 15
		.text ",NMI) v0.1 registered"
		.byte $0a,$00

end_of_code:
