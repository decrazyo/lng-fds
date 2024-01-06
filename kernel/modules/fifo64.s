;; For emacs: -*- MODE: asm; tab-width: 4; -*-

;;; low-level driver for FIFO64 (16550 based interface)
;;; (detection algorithm based on Linux-Sources)

#include <system.h>
#include <jumptab.h>
#include <stdio.h>

#include <config.h>
#include MACHINE_H

		;; base address of fifo64link
		fifo64_base equ UART_BASE

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		jmp  initialize

		SELFMOD equ $fe00		; placeholder
		
		RELO_JMP(+)				; relocator jump

rcv_errcnt:			.buf 1		; receiver error count
		
		;; variables, that are initialized by the hardware detection
xmit_fifo64_size:	.buf 1
uart_type:			.buf 1
		
;;  0:  300
;;  1:  600
;;  2:  1200
;;  3:  2400
;;  4:  4800
;;  5:  9600
;;  6:  19200
;;  7:  38400
;;  8:  57600

#ifdef UART_OSC_1843

;; baudrates for use with a 1.8432MHz oszillator
baud_tab_lo:
		.byte <96, <96, <96, <48, <24, <12, <6, <3, <3
baud_tab_hi:
		.byte >96, >96, >96, >48, >24, >12, >6, >3, >3

#else

#ifdef UART_OSC_7373

;; baudrates for use with a 7,3728MHz oszillator
baud_tab_lo:
		.byte <1536,<768,<384,<192,<96,<48,<24,<12,<8
baud_tab_hi:
		.byte >1536,>768,>384,>192,>96,>48,>24,>12,>8

#else

#error "unknown UART Oscillator Frequency"

#endif

#endif


		send_flag equ nmizp
		recv_flag equ nmizp+1


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

		;; base address of uart is hardcoded (for fast/short code)

nmi_struct:
		jmp  nmi_handler
		jmp  nmi_disable
		jmp  nmi_enable
		
		;; linux' detection algorithm

		fifo64_data equ fifo64_base+0
		fifo64_ier  equ fifo64_base+1
		fifo64_iir  equ fifo64_base+2 ; (read access only)
		fifo64_fcr  equ fifo64_base+2 ; (write access only)
		fifo64_lcr  equ fifo64_base+3
		fifo64_mcr  equ fifo64_base+4
		fifo64_lsr  equ fifo64_base+5
		fifo64_msr  equ fifo64_base+6
		fifo64_scr  equ fifo64_base+7

		bit  nmi_struct


		;; rs232_lock
		;; gain exclusive access to the rs232 device
rs232_lock:
		jsr  lkf_disable_nmi
		ldx  #<nmi_struct
		ldy	 rs232_lock-1		; #>nmi_struct
		jsr  lkf_hook_nmi		; hook into system
		nop

		lda  #$80
		sta  send_flag
		sta  recv_flag

		ldx  #1
		bit  default_handler
		jsr  rs232_ctrl
		ldx  #2
		bit  default_handler
		jsr  rs232_ctrl

		;; initialize 16550A chip
		lda  #0
		sta  fifo64_ier			; disale all interrupts
		sta  _intmask

		lda  #%00000001			; Loop=0, Out2=0, Out1=0, RTS=0, DTR=1
		sta  fifo64_mcr

		ldx  #0
		jsr  rs232_ctrl			; set default baudrate

		lda  #%10000111			; rectrigger=8, DMA=0, FIFO reset, FIFO ena
		sta  fifo64_fcr
		lda  fifo64_ier			; clear all errors and interrupts
		lda  fifo64_lsr
		lda  fifo64_msr
		jmp  lkf_enable_nmi


		;; rs232 unlock
		;; release exclusive access
rs232_unlock:
		jsr  lkf_disable_nmi

		ldx  #lsem_nmi
		jsr  lkf_unlock		; unlock NMI system semaphore (calls nmi_disable)

		lda  #%00000000			; Loop=0, Out2=0, Out1=0, RTS=0, DTR=0
		sta  fifo64_mcr

		jmp  lkf_enable_nmi

		
		;; rs223_ctrl
		;;  X=0:		set baudrate (A=baud code)
		;;  X=1:		set receivebyte_handler (bit$xxxx=address)
		;;  X=2:		set sendbyte_handler (bit$xxxx=address)
		;;  X=3:		trigger start of send
		;;  X=4:		trigger start of receive

rs232_ctrl:
		cpx  #0
		beq  set_baudrate
		dex
		beq  set_recvhndl
		dex
		beq  set_sendhndl
		dex
		beq  trig_startsend
		dex
		beq  trig_startrecv
		sec						; error
	-	rts

		;; set baudrate and do some basic initialisations
set_baudrate:
		tax
		cpx  #9					; (highest possible baud rate is 8)
		bcs  -
		lda  #%10000011			; DLAB=1, noBreak, noParity, 1 Stopbit, 8 Data
		sta  fifo64_lcr
		lda  baud_tab_lo,x
		sta  fifo64_data		; (set divisor byte lo)
		lda  baud_tab_hi,x
		sta  fifo64_data+1		; (set divisor byte hi)
		lda  #%00000011			; DLAB=0, noBreak, noParity, 1 Stopbit, 8 Data
		sta  fifo64_lcr
		rts						; (return with carry cleared)

		;; set address of receive handler
		;; (called every time a byte has been received)
set_recvhndl:
		jsr  lkf_get_bitadr
		stx  rech_ptr+1
		sty  rech_ptr+2
		clc
default_handler:
		rts

		;; set address of send handler
		;; (called every time a byte is ready to be sent)
set_sendhndl:
		jsr  lkf_get_bitadr
		stx  sndh_ptr+1
		sty  sndh_ptr+2
		clc
		rts

trig_startsend:
		bit  send_flag
		bpl  +					; already enabled, skip
		sei
		lda  #0
		sta  send_flag
		sta  fifo64_ier			; disable all interrupts
		lda  _intmask
		ora  #%00000010			; (will) enable THRE interrupt
		sta  _intmask
		ldx  lk_nmidiscnt
		bne  +					; respect diabled NMI state
		sta  fifo64_ier			; re-enable interrupts
	+	cli
		clc
		rts

trig_startrecv:
		bit  recv_flag
		bpl  +					; already enabled, skip
		sei
		lda  #0
		sta  recv_flag
		sta  fifo64_ier			; disable all interrupts
		lda  _intmask
		ora  #%00000001			; (will) enable Received data interrupt
		sta  _intmask
		lda  lk_nmidiscnt
		bne  +					; don't set RTS, if NMI is disabled
		lda  fifo64_mcr
		ora  #%00000010			; set RTS
		sta  fifo64_mcr
		lda  _intmask
		sta  fifo64_ier			; re-enable interrupts
	+	clc
		cli
		rts


		;; NMI handler

nmi_handler:
		lda  #%0000				; switch to polled mode!
		sta  fifo64_ier			; disable all interrupts

ckloop:
		lda  fifo64_lsr			; check line status register
		lsr  a
		bcc  no_data_ready

		;; there are bytes in the receive FIFO

	-	lda  fifo64_data		; (read receive buffer register (RBR))
		bit  recv_flag
		bmi  ckloop				; skip, if receive handler is busy

rech_ptr:	jsr  SELFMOD
		bcc  +

		;; receive-handler has no more bufferspace left
		lda  #$80				; set recv_flag
		sta  recv_flag
		lda  fifo64_mcr
		and  #%11111101			; clear RTS
		sta  fifo64_mcr
		lda  _intmask
		and  #%11111110			; disable receive data interrupt
		sta  _intmask
		;; (what about lost bytes???)

	+	lda  fifo64_lsr			; check Data Ready (DR), it is set until
		lsr  a					; receive buffer is emptied
		bcs  -
		;; fall through to no_data_ready

no_data_ready:
		and  #%00110000			; look at "THRE" and "TEMT" bits (1xLSR)
		;;  THRE = transmitter holding register empty
		;;  TEMT = transmitter empty
		beq  no_job_todo

		;; transmitter FIFO is empty
		;; (could write up to 16/32 bytes at once !!)

		bit  send_flag
		bmi  no_job_todo

sndh_ptr: jsr  SELFMOD
		bcs  wrstop
		sta  fifo64_data		; write to transmitter holding register (THR)
		jmp  ckloop				; check for other pending interrupts

wrstop:
		lda  #$80
		sta  send_flag
		lda  _intmask
		and  #%11111101			; disable THRE interrupt
		sta  _intmask

no_job_todo:
_intmask equ *+1
		lda  #<SELFMOD
		sta  fifo64_ier			; enable interrupts
		
		pla						; restore memory-configuration
        sta  1
		pla						; restore register and return
		tay
		pla
		tax
		pla
		rti


		;; disable NMI
nmi_disable:
		lda  #0
		sta  fifo64_ier			; disable all interrupts
		lda  fifo64_mcr
		and  #%11111101			; clear RTS
		sta  fifo64_mcr
		plp		
		rts
		
		;; enable NMI
nmi_enable:
		lda  #%00000001			; Loop=0, Out2=0, Out1=0, RTS=0, DTR=1
		bit  recv_flag			; check, if receive-handler is ready
		bmi  +
		ora  #%00000010			; RTS=1
	+	sta  fifo64_mcr
		lda  _intmask
		sta  fifo64_ier			; re-enable interrupts
		plp
		rts

;;; -----------------------------------------------------------------------
;; end_of_permanent_code:

initialize:   

		#ifdef HAVE_SILVERSURFER
        ; enable ssurfer-port
		lda $de01
		ora #$01
		sta $de01
		#endif

		;; parse commandline
		ldx  userzp
		cpx  #1
		beq  normal_mode
		cpx  #2
		beq  goon1

HowTo:	ldx  #stdout
		bit  howto_txt
		jsr  lkf_strout
		lda  #1
		rts						; exit(1)

normal_mode:
		sei
		jsr  detect
		cli
		bcc  is_detected

		; print error message and exit

		ldx  #stderr
		bit  txt_errdetect
		jsr  lkf_strout
		nop
		lda  #1
		rts

goon1:	ldy  #0
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

		;; forced loading ...
		jsr  uart_reset

		bit  module_struct
		;; hardware detected ...
is_detected:
		ldx  #<module_struct
		ldy  is_detected-1		; #>module_struct
		jsr  lkf_add_module
		bcc  is_available

		; print error message and exit

		ldx  #stderr
		bit  txt_errmodins
		jsr  lkf_strout
		nop
		lda  #1
		rts

is_available:
		ldx  #stdout
		bit  txt_ok1
		jsr  lkf_strout
		nop

		ldx  uart_type
		lda  uarttype_index,x
		tay
	-	lda  uarttype_text,y
		beq  +
		jsr  out
		iny
		bne  -					; (always jump)

	+	ldx  #stdout
		bit  txt_ok2
		jsr  lkf_strout
		nop

		lda  xmit_fifo64_size
		jsr  hexout
		lda  #$0a
		jsr  out

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

not_found:
		sec
		rts
		
detect:
		lda  fifo64_ier
		ldx  #0
		stx  fifo64_ier
		ldx  fifo64_ier
		bne  not_found

		lda  fifo64_mcr
		tay
		ora  #%00010000
		sta  fifo64_mcr
		ldx  fifo64_msr
		lda  #%00011010
		sta  fifo64_mcr
		lda  fifo64_msr
		and  #$f0
		sty  fifo64_mcr
		stx  fifo64_msr
		cmp  #$90
		bne  not_found

		ldx  fifo64_lcr
		txa
		ora  #%10000000
		sta  fifo64_lcr
		lda  #0
		sta  fifo64_fcr			; =fifo64_efr
		stx  fifo64_lcr
		lda  #%00000001
		sta  fifo64_fcr
		lda  #1
		sta  xmit_fifo64_size
		lda  fifo64_iir
		and  #%11000000
		beq  port_16450

		cmp  #$40
		beq  port_unknown

		cmp  #$80
		beq  port_16550

		;; 16650 or 16550A
		txa
		ora  #%10000000
		sta  fifo64_lcr
		lda  fifo64_fcr
		bne  +

		lda  #32
		sta  xmit_fifo64_size
		stx  fifo64_lcr
		jmp  port_16650

	+	lda  #16
		sta  xmit_fifo64_size
		stx  fifo64_lcr

		;; port_16550A
		lda  #3
		bne  +
		
port_16450:
		lda  #1
		bne  +

port_unknown:
		lda  #0
		beq  +

port_16550:
		lda  #2
		bne  +

port_16650:
		lda  #4
	+	sta  uart_type

uart_reset:
		;; reset UART
		lda  #$00
		sta  fifo64_mcr
		lda  #%00000110
		sta  fifo64_fcr
		lda  fifo64_data

		clc
		rts

hexout:
		pha
		lsr  a
		lsr  a
		lsr  a
		lsr  a
		jsr  +
		pla
		and  #7
	+	tax
		lda  hextab,x		
out:
		ldx  #stdout
		sec
		jsr  fputc
		nop
		rts

.endofcode		; end of relocated code

hextab:	.text "0123456789abcdef"

txt_ok1:
		.text "UART (",0
txt_ok2:
		.text ") @ "
		.digit fifo64_base>12
		.digit (fifo64_base>8) & 15
		.digit (fifo64_base>4) & 15
		.digit fifo64_base & 15
		.text "/NMI detected", $0a
		.text "size of hardware XmitFIFO=0x"
		.byte 0

txt_errmodins:
		.text "error: can't add module"
		.byte $0a,$00
		
txt_errdetect:
		.text "error: can't detect uart"
		.byte $0a,$00

howto_txt:
		.text "usage: fifo64 [-f]",$0a
		.text "  -f  force loading",$0a
		.text "      (bypass hardware detection)",$0a,0

uarttype_text:
subtype0:	.text "unknown type",0
subtype1:	.text "16450",0
subtype2:	.text "16550",0
subtype3:	.text "16550A",0
subtype4:	.text "16650",0

uarttype_index:
		.byte subtype0 - uarttype_text
		.byte subtype1 - uarttype_text
		.byte subtype2 - uarttype_text
		.byte subtype3 - uarttype_text
		.byte subtype4 - uarttype_text

end_of_code:
