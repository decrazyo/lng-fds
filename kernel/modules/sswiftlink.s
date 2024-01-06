		;; For emacs: -*- MODE: asm; tab-width: 4; -*-
		;;; low-level driver for swiftlink
		
#include <system.h>
#include <jumptab.h>
#include <stdio.h>
#include <config.h>
#include MACHINE_H

#begindef debug_putc(char)
		lda  #char
		ldx  #stdout
		sec
		jsr  fputc
		nop
#enddef
		
		;; nmizp+2 write offset
		;; nmizp+3 read offset
		;; nmizp+6 status
		
		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		jmp  initialize

#define WATER_LO	40 
#define WATER_HI    200

#define CMDVAL_NOI  %00001011
#define CMDVAL_HALT %00000001
#define CMDVAL_GO   %00001001

		SELFMOD equ $fe00		; placeholder
		
		RELO_JMP(+)				; relocator jump

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
		;;  8:  57600 (16x external clock for swiftlink)

		;; base address of swiftlink is hardcoded (for fast/short code)
		swift_base equ $de00
		
		swift_io      equ swift_base+0
		swift_status  equ swift_base+1
		swift_command equ swift_base+2
		swift_control equ swift_base+3
		
nmi_struct:
		jmp  nmi_handler
		jmp  nmi_disable
		jmp  nmi_enable
		
rs232_lock:
		;; (re-)initialize swiftlink
		
		jsr  lkf_disable_nmi
		ldx  #<nmi_struct
_haddr_hi:
		ldy  #>nmi_struct
		jsr  lkf_hook_nmi		; hook into system
		nop
		
		;; now nmizp[0..7] can be used...
		
		lda  #1					; allocate receive buffer in context
		jsr  lkf_palloc			; of calling process
		nop						; error is not allowed
		stx  r_buf_ptr1			; update absolute pointers into buffer
		stx  r_buf_ptr2		
		lda  #0
		sta  nmizp+2			; write pointer into receive buffer
		sta  nmizp+3			; write pointer into receive buffer
		sta  nmizp+6				; $80 if receive buffer if full
		;; (check if swiftlink is already in use ?)
		sta  swift_status		; reset of swiftlink
		lda  swift_status		; clear interrupt flag
		lda  swift_io			; clear rx-interrupt
		jmp  lkf_enable_nmi		; (will call nmi_enable)

rs232_unlock:
		jsr  lkf_disable_nmi
		ldx  r_buf_ptr1
		jsr  lkf_free			; free receive buffer
		ldx  #lsem_nmi
		jsr  lkf_unlock			; unlock NMI system semaphore (will call nmi_disable)
		jmp  lkf_enable_nmi		; (will call nmi_enable)
		
rs232_ctrl:						; set baud reate
		cpx  #9
		bcs  +					; (return with error if >=9)
		lda  baudtable,x
		ora  #%00010000			; (8N1, receiver clock = baud rate generator)
		sta  brate+1
		sta  swift_control
		clc
	+	rts
		
nmi_enable:
		lda  nmizp+6
		ora  #$40
		sta  nmizp+6
		bmi  +					; skip if receive buffer is already full
brate:	lda  #%00011100			; 1 stopbit, 8 databits, 9600 baud (internal)
		sta  swift_control
		lda  #CMDVAL_GO			; no parity, no echo, no XMIT-IRQ,
								;  RECV-IRQ enabled, RTS on, DTR low
		sta  cmdval+1
		sta  swift_command
	+	plp
		rts
		
nmi_disable:
		lda  swift_status
		and  #%00010000			; test bit 4
		beq  nmi_disable		; wait until current byte is sent
		
		lda  #CMDVAL_NOI		; no parity, no echo, no XMIT-IRQ,
								;  no RECV-IRQ, RTS off, DTR low
		sta  cmdval+1
		sta  swift_command
		lda  nmizp+6
		and  #$ff-$40
		sta  nmizp+6
		plp
		rts
				
nmi_handler:
		lda  swift_command
		ora  #%00000010
		sta  swift_command		; prevent any more interrupts
		lda  swift_status
		and  #%00001000			; test bit 3 of status
		beq  nmi_ret			; skip, if nothing has been received

	-	lda  swift_io			; read byte from swiftlink
		ldx  nmizp+2

r_buf_ptr1 equ *+2
		sta  SELFMOD,x			; store byte in receive buffer
		
		inx				
		cpx  nmizp+3		; prevent puffer overflows
		bne  +
		dex
	+	stx  nmizp+2

		txa
		sbc  nmizp+3
		cmp  #WATER_HI			; high water mark
		bcs	 +					; buffer is (nearly) full

		;; next_char:
		lda  swift_status
		and  #%00001000
		bne  -

nmi_ret:				
		pla						; restore memory-configuration
		SETMEMCONF
		pla						; restore register and return
		tay
		pla
		tax
cmdval:	lda  #CMDVAL_NOI			; value for command register
		sta  swift_command
		pla
		rti


	+	lda  #CMDVAL_HALT			; no parity, no echo, no XMIT-IRQ,
								;  no RECV-IRQ, RTS off, DTR low
		sta  cmdval+1
		lda  nmizp+6
		ora  #$80
		sta  nmizp+6
		jmp  nmi_ret
		
rs232_getc:
		sei
		stx  tmpzp+1
		ldx  nmizp+3
		cpx  nmizp+2
		beq  null				; no char available
		
r_buf_ptr2 equ *+2		
		lda  SELFMOD,x		
		sta  tmpzp
		inx
		stx  nmizp+3
		
		lda  nmizp+6
		and  #%01000000			; NMI allowed?
		beq  +
		txa
		sbc  nmizp+2
		cmp  #$100-WATER_LO
		bcs  reactivate			; check low water mark
		bpl  +
		
reactivate:
		ldx  #CMDVAL_GO			; no parity, no echo, no XMIT-IRQ,
								;  RECV-IRQ enabled, RTS on, DTR low
		stx  cmdval+1
		stx  swift_command
		lda  nmizp+6
		and  #$ff-$80			; buffer is not full anymore
		sta  nmizp+6
		
	+	ldx  tmpzp+1
		lda  tmpzp
		clc
		cli
		rts

null:	ldx  tmpzp+1
		sec						; leave with c=1, when no char available
		cli
		rts

		
	-	lda  tmpzp
		cli
		
rs232_putc:
		sei
		sta  tmpzp
		lda  swift_status
		and  #%00010000			; test bit 4
		beq  -					; wait until current byte is sent
		lda  tmpzp
		sta  swift_io			; send byte
		cli
		rts

		RELO_JMP(+)				; (don't relocate data-inlay)
		
baudtable:		.byte 5, 6, 7, 8, 10, 12, 14, 15, 0
		
	+	;; initialisation

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
				
		bit  module_struct
initialize:
		;; check for swiftlink

		;; first, non destructive check (read-only) (RAM at $02/$03)

		lda  swift_control
		ldx  swift_command
		ldy  #0
	-	cmp  swift_control
		bne  not_swiftlink
		cpx  swift_command
		bne  not_swiftlink
		iny
		bpl  -

		sta  swift_status
		lda  swift_status
		tax
		eor  #$ff
		tay

		;; check swift_status reset functionality
		lda  swift_command
		and  #$ef
		sta  swift_command
		lda  swift_command
		and  #$10
		bne  not_swiftlink
		
		cpx  swift_status
		bne  not_swiftlink
		
		lda  swift_command
		ora  #$10
		sta  swift_command
		lda  swift_command
		and  #$10
		beq  not_swiftlink
		
		cpx  swift_status
		bne  not_swiftlink
		
		sty  swift_status		; should clear bit 4-0 of swift_command
		lda  swift_command
		and  #$1f
		bne  not_swiftlink

		cpx  swift_status
		bne  not_swiftlink
		
		;; check 4 byte cycle and swift_controll r/w
		
		lda  swift_control		; check, if swift_control is read/write
		cmp  swift_control+4
	-	bne  not_swiftlink
		
		eor  #$f0
		sta  swift_control
		cmp  swift_control
		bne  not_swiftlink
		cmp  swift_control+4
		bne  -					; not_swiftlink
		
		eor  #$ff
		sta  swift_control
		cmp  swift_control
		bne  -					; not_swiftlink
		cmp  swift_control+4
		bne  -					; not_swiftlink

		ldx  #<module_struct
		ldy  initialize-1		; #>module_struct 
		jsr  lkf_add_module
		bcc  is_available

		lda  #$ff
		rts						; return with error
		
is_available:
		;; allocate receive buffer (256 byte)
		ldy  #0
	-	lda  ok_txt,y
		beq  +
		sec
		ldx  #stdout
		jsr  fputc
		nop
		iny
		bne  -

	+	;; runtime - code relocation
		
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

		RELO_END ; no more code to relocate

not_txt:
		.text "sorry, no swiftlink detected"
		.byte $0a,$00
		
ok_txt:
		.text "Swiftlink ("
		.digit swift_base>12
		.digit (swift_base>8) & 15
		.digit (swift_base>4) & 15
		.digit swift_base & 15
		.text ",NMI) registered"
		.byte $0a,$00

end_of_code:
