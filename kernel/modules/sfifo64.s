		;; For emacs: -*- MODE: asm; tab-width: 4; -*-

		;;; low-level driver for FIFO64 (16550 based interface)

#include <system.h>
#include <jumptab.h>
#include <stdio.h>
#include <config.h>
#include MACHINE_H

#define WATER_LO	40
#define WATER_HI    200

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

		;; nmizp+2  - write offset
		;; nmizp+3  - read offset
		;; nmizp+6  - status

rcv_errcnt:			.buf 1		; receiver error count
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

module_struct:
		.asc "ser"      ; module identifier
		.byte 4         ; module interface size
		.byte 1         ; module interface version number
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
		jmp rs232_getc
		jmp rs232_putc

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
rs232_lock:
		jsr  lkf_disable_nmi
		ldx  #<nmi_struct
		ldy	 rs232_lock-1		; #>nmi_struct
		jsr  lkf_hook_nmi		; hook into system
		nop
		lda  #1					; allocate receive buffer in context
		jsr  lkf_palloc			; of calling process
		nop						; error is not allowed
		stx  _bufptr1+2			; update absolute pointers into buffer
		stx  _bufptr2+2		
		
		;; initialize 16550A chip
		lda  #0
		sta  fifo64_ier			; disale all interrupts
		sta  nmizp+2
		sta  nmizp+3
		sta  nmizp+6
		sta  rcv_errcnt
		lda  #%00000			; Loop=0, Out2=0, Out1=0, RTS=0, DTR=0
		sta  fifo64_mcr
		ldx  #0
		jsr  rs232_ctrl			; set default buadrate
		lda  #%10000111			; rectrigger=8, DMA=0, FIFO reset, FIFO ena
		sta  fifo64_fcr
		lda  fifo64_ier			; clear all errors and interrupts
		lda  fifo64_lsr
		lda  fifo64_msr
		jmp  lkf_enable_nmi

rs232_unlock:
		jsr  lkf_disable_nmi
		ldx  _bufptr1
		jsr  lkf_free			; free receive buffer
		ldx  #lsem_nmi
		jsr  lkf_unlock		; unlock NMI system semaphore (calls nmi_disable)
		jmp  lkf_enable_nmi
		
rs232_ctrl:
		lda  #%10000011			; DLAB=1, noBreak, noParity, 1 Stopbit, 8 Data
		sta  fifo64_lcr
		lda  baud_tab_lo,x
		sta  fifo64_data			; (set divisor byte lo)
		lda  baud_tab_hi,x
		sta  fifo64_data+1		; (set divisor byte hi)
		lda  #%00000011			; DLAB=0, noBreak, noParity, 1 Stopbit, 8 Data
		sta  fifo64_lcr
		rts

rs232_getc:
		sei
		stx  tmpzp
		ldx  nmizp+3
		cpx  nmizp+2
		beq  _fifo64_empty
_bufptr1:
		lda  SELFMOD,x
		pha
		inx
		stx  nmizp+3
		cpx  nmizp+2
		beq  _rtsup
		
	-	ldx  tmpzp
		pla
		clc
		cli
		rts

_fifo64_empty:
		ldx  tmpzp
		sec
		cli
		rts

_rtsup:
		bit  nmizp+6
		bpl  +
		lda  fifo64_ier			; clear interrupt (?)
		lda  #%00000001			; enable receiver-interrupts
		sta  nmizp+6
		sta  fifo64_ier
	+	lda  #%00011			; Loop=0, Out2=0, Out1=0, RTS=1, DTR=1
		sta  fifo64_mcr
		bne  -
		
rs232_putc:
		pha
	-	lda  fifo64_lsr
		and  #%00100000
		beq  -
		pla
		sta  fifo64_data
		rts
		
nmi_handler:
		ldx  nmizp+2
		
	-	lda  fifo64_iir
		lda  fifo64_lsr
		and  #%10011111
		lsr  a
		bne  rcv_error
		bcc  _nmi_done
		lda  fifo64_data
_bufptr2:
		sta  SELFMOD,x
		inx
		inx
		cpx  nmizp+3
		beq  _fifo64_full
		dex
		jmp  -
		
_fifo64_full:
		lda  #0
		sta  fifo64_ier			; disale all further interrupts
		lda  #$80
		sta  nmizp+6
		dex

_nmi_done:
		txa
		eor  #$ff
		adc  nmizp+3
		cmp  #20				; less than 20 left ?
		bcs  +
		lda  #%00001			; Loop=0, Out2=0, Out1=0, RTS=0, DTR=1
		sta  fifo64_mcr
	+	stx  nmizp+2
		pla						; restore memory-configuration
        SETMEMCONF
		pla						; restore register and return
		tay
		pla
		tax
		pla
		rti

rcv_error:
		inc  rcv_errcnt
		jmp  -

nmi_disable:	
		plp		
		rts

nmi_enable:
		;; enable NMI
		lda  #%00000001			; enable receiver-interrupts
		sta  fifo64_ier
		lda  #%00011			; Loop=0, Out2=0, Out1=0, RTS=1, DTR=1
		sta  fifo64_mcr
		plp
		rts

;;; -----------------------------------------------------------------------
;; end_of_permanent_code:

initialize:

		sei

		#ifdef HAVE_SILVERSURFER
        ; enable ssurfer-port
		lda $de01
		ora #$01
		sta $de01
		#endif

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

		bit  module_struct	
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
		bit  txt_trail
		jsr  lkf_strout
		nop

		lda  uart_type
		ora  #"0"
		jsr  out
		lda  #"/"
		jsr  out
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
		SKIP_WORD
port_16450:
		lda  #1
		SKIP_WORD
port_unknown:
		lda  #0
		SKIP_WORD
port_16550:
		lda  #2
		SKIP_WORD
port_16650:
		lda  #4
		sta  uart_type
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
		
		RELO_END ; no more code to relocate

hextab:	.text "0123456789abcdef"
				
txt_trail:		
		.text "UART detected @ "
		.digit fifo64_base>12
		.digit (fifo64_base>8) & 15
		.digit (fifo64_base>4) & 15
		.digit fifo64_base & 15
		.text "/nmi : "
		.byte 0

txt_errmodins:
		.text "error: can't add module"
		.byte $0a,$00
		
txt_errdetect:
		.text "error: can't detect uart"
		.byte $0a,$00

end_of_code:
		
