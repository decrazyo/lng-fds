;; For emacs: -*- MODE: asm; tab-width: 4; -*-

;;; low-level driver for swiftlink
;;; bugs:		no hardware flowcontrol (partially done)
;;; Version 1.1 by Daniel Dallmann Nov17 1999
;;;   added -f switch to bypass hardware detection
;;; Version 1.2 by Daniel Dallmann Jan5 2000
;;;   simplified detection algorithm
;;;   some turbo232 related add-ons
;;; Version 1.3 by Maciej Witkowiak Dec17 2000
;;;   some hardware flow support (RTS is set inactive during receive handler call,
;;;   CTS is handled by swiftlink internally)

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

		start_of_code equ $1000

		.org start_of_code

		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		jmp  initialize

#define CMDVAL_NOI  %00000011	; no interrupts
#define CMDVAL_GO2  %00000101	; both, transmitt and receive interrupts
#define CMDVAL_INHNDL %00001011	; no transmit interrupts
#define CMDVAL_GO   %00001001   ; just receive interrupts

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
		;;  8:  57600 (Ext/16 for swiftlink / 57600 for turbo232)
		;;  9:	115200 (turbo232 only)
		;;  10:	230400 (turbo232 only)

		;; base address of swiftlink is hardcoded (for fast/short code)
		swift_base equ $de00

		swift_io      equ swift_base+0
		swift_status  equ swift_base+1
		swift_command equ swift_base+2
		swift_control equ swift_base+3
		turbo232_clk  equ swift_base+7 ; access to external baudrate generator

;;; NMI handler -------------------------------------------------------------

		#define SND_IRQ %00010000
		#define REC_IRQ %00001000

nmi_struct:
		jmp  nmi_handler
		jmp  nmi_disable
		jmp  nmi_enable

nmi_enable:
brate:		lda  #%00011100			; 1 stopbit, 8 databits, 9600 baud (internal)
		sta  swift_control
		bit  send_flag
		bmi  +
		lda  #CMDVAL_GO2
		SKIP_WORD
	+	lda  #CMDVAL_GO			; no parity, no echo, no XMIT-IRQ,
		sta  swcom+1
		sta  swift_command		; RECV-IRQ enabled, RTS on, DTR low
		plp
		rts

nmi_disable:
		ldx  #CMDVAL_NOI
		stx  swcom+1
		stx  swift_command		; no more send interrupts
		lda  #%00010000			; test bit 4
	-	bit  swift_status
		beq  -				; wait until current byte is sent		
		plp
		rts

nmi_handler:
		lda  #CMDVAL_INHNDL
		sta  swift_command		; prevent any more interrupts
		lda  swift_status
ckloop:
		sta  nmizp+2
		and  #REC_IRQ
		beq  cksend			; skip, if nothing has been received

	-	lda  swift_io			; read byte from swiftlink
		bit  recv_flag
		bmi  next_char			; skip byte

		ldx  #CMDVAL_NOI		; no interrupts, ask remote to stop transmit
		stx  swift_command
rech_ptr:	jsr  SELFMOD
		bcc  +
		lda  #$80			; stop receiving
		sta  recv_flag
	+	lda  #CMDVAL_INHNDL
		sta  swift_command		; no interrupts, may transmit again

next_char:
		lda  nmizp+2
		and  #SND_IRQ
		ora  swift_status
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
		sta  swift_io
send_done:		
		lda  #REC_IRQ
		SKIP_WORD			; ( bit $18a9 is ok here)

cklast:
		lda  #SND_IRQ|REC_IRQ
		and  swift_status  
		bne  ckloop

		pla				; restore memory-configuration
		SETMEMCONF
		pla				; restore register and return
		tay
		pla
		tax
swcom:		lda  #CMDVAL_GO2		; value for command register
		sta  swift_command
		pla
		rti

stopsnd:
		lda  #CMDVAL_GO
		sta  swift_command
		sta  swcom+1
		lda  #$80
		sta  send_flag
		bne  send_done

;;; API --------------------------------------------------------------------

rs232_lock:
		;; (re-)initialize swiftlink

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

		sta  swift_status		; reset of swiftlink
		lda  swift_status		; clear interrupt flag
		lda  swift_io			; clear rx-interrupt

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
		cpx  #11
		bcs  _err			; (return with error if >=11)
		bit  turbo232_flag
		bmi  +
		cpx  #9
		bcs  _err			; (9,10 only for turbo232)
	+	lda  baudtable,x
		and  #%00001111
		ora  #%00010000			; (8N1, receiver clock = baud rate generator)
		sta  brate+1
		sta  swift_control
		bit  turbo232_flag
		bpl  +
		lda  baudtable,x
		lsr  a
		lsr  a
		lsr  a
		lsr  a
		sta  turbo232_clk
	+	clc
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
		sta  swcom+1
		sta  swift_command
	+	cli
		rts

trigrecv:
		lda  #0
		sta  recv_flag
		clc
		rts

		RELO_JMP(+)

turbo232_flag:	.byte 0				; defaults to off
baudtable:	.byte $05, $06, $07, $08, $0a, $0c, $0e, $0f, $20
		.byte $10, $00
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

not_swiftlink:
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
		;; check for swiftlink
		;; first, non destructive check (read-only) (RAM at $02/$03)
		lda  swift_control
		ldx  swift_command
		ldy  #$f0			; check 16 times ?! (good idea?)
	-	cmp  swift_control
		bne  not_swiftlink
		cpx  swift_command
		bne  not_swiftlink
		iny
		bpl  -

		lda  swift_status
		sta  swift_status		; reset device

		;; check swift_status reset functionality
		lda  swift_command
		and  #$e2
		sta  swift_command		; (disable all interrupts)
		lda  #$10
		bit  swift_command		; (logical and)
	-	bne  not_swiftlink
		ora  swift_command
		sta  swift_command
		lda  swift_command
		and  #$10
		beq  not_swiftlink

		sta  swift_status		; should clear bit 4-0 of swift_command
		lda  swift_command
		and  #$1f
		bne  -

		;; check 4 byte cycle (swiftlink or turbo232)

		ldx  #$ff
		stx  swift_control		; check, if swift_control is read/write
		cpx  swift_control
		bne  -
		inx
		stx  swift_control
		cpx  swift_control
		bne  -
		cmp  swift_control+4
		beq  bypass_hwd
		dec  turbo232_flag

bypass_hwd:
		ldx  #<module_struct
		ldy  initialize-1		; #>module_struct 
		jsr  lkf_add_module
		bcc  is_available

		lda  #1
		rts				; return with error

is_available:

		ldx  #stdout
		lda  turbo232_flag
		bne  +

		bit  ok_txt
		jsr  lkf_strout
		jmp  ++

	+	bit  ok_turbo_txt
		jsr  lkf_strout

	+	;; runtime - code relocation

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
		.text "usage: swiftlink [-f]",$0a
		.text "  -f  force loading",$0a
		.text "      (bypass hardware detection)",$0a,0

not_txt:
		.text "sorry, no swiftlink/turbo232 detected"
		.byte $0a,$00

ok_txt:
		.text "Swiftlink ("
		.digit swift_base>12
		.digit (swift_base>8) & 15
		.digit (swift_base>4) & 15
		.digit swift_base & 15
		.text ",NMI) v1.3 registered"
		.byte $0a,$00

ok_turbo_txt:
		.text "Turbo232 ("
		.digit swift_base>12
		.digit (swift_base>8) & 15
		.digit (swift_base>4) & 15
		.digit swift_base & 15
		.text ",NMI) v1.3 registered"
		.byte $0a,$00

end_of_code:
