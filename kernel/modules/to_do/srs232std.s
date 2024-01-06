;;; low-level driver for commodore64-standard-userport-rs232-interace
;; PAL version
		
#include <system.h>
#include <jumptab.h>
#include <stdio.h>
#include <c64/c64.h>

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

#define B_RXD $01				; received data
#define B_RTS $02				; 1=enabled
#define B_CTS $40				; 1=active
#define A_TXD $04				; transmitt data
		
		SELFMOD equ $fe00		; placeholder
		
		RELO_JMP(+)			; relocator jump

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

nmi_struct:
		jmp  nmi_handler
		jmp  nmi_disable
		jmp  nmi_enable
		
		bit  nmi_struct
rs232_lock:
		;; (re-)initialize 
		
		jsr  lkf_disable_nmi
		ldx  #<nmi_struct
		ldy	 rs232_lock-1		; #>nmi_struct
		jsr  lkf_hook_nmi		; hook into system
		nop
		
		;; now nmizp[0..7] can be used...
		
		lda  #1					; allocate receive buffer in context
		jsr  lkf_palloc			; of calling process
		nop						; error is not allowed
		stx  r_buf_ptr1+2		; update absolute pointers into buffer
		stx  r_buf_ptr2+2
		
		lda  #0
		sta  nmizp+2			; write pointer into receive buffer
		sta  nmizp+3			; read pointer into receive buffer
		sta  nmizp+6			; $80 if receive buffer if full

		jsr  port_setup
		jmp  lkf_enable_nmi		; (will call nmi_enable)

rs232_unlock:
		jsr  lkf_disable_nmi
		ldx  r_buf_ptr1+2
		jsr  lkf_free			; free receive buffer
		ldx  #lsem_nmi
		jsr  lkf_unlock			; unlock NMI system semaphore (will call nmi_disable)
		jmp  lkf_enable_nmi		; (will call nmi_enable)
		
port_setup:		
		;; setup CIA
		lda  CIA2_DDRA
		ora  #A_TXD
		sta  CIA2_DDRA			; TXD - output
		
		lda  CIA2_DDRB
		and  #~(B_RXD|B_CTS)	; RXD,CTS - input
		ora  #B_RTS				; RTS - output
		sta  CIA2_DDRB
		
		lda  CIA2_PRA
		ora  #A_TXD
		sta  CIA2_PRA
		
		lda  CIA2_PRB
		and  #~(B_RTS)			; disable RTS
		sta  CIA2_PRB

		lda  #%00010001			; disable FLAG/timer interrupt
		sta  CIA2_ICR
		
		ldx  #0					; default baudrate
		
rs232_ctrl:						; set baud reate
		cpx  #6
		bcs  illbaud
		lda  baudtab_l,x
		sta  CIA2_TALO
		lda  baudtab_h,x
		sta  CIA2_TAHI
		clc
illbaud:		
		rts
		
nmi_enable:
		bit  CIA2_ICR			; clear pending interrupts
		lda  #%10010000			; enable FLAG interrupt
		sta  CIA2_ICR
		lda  CIA2_PRB
		ora  #B_RTS
		sta  CIA2_PRB
		plp
		rts
		
nmi_disable:
		lda  CIA2_PRB
		and  #~(B_RTS)			; disable RTS
		sta  CIA2_PRB
		lda  #%00010001			; disable FLAG/timer interrupt
		sta  CIA2_ICR
		plp
		rts
				
nmi_handler:
		lda  CIA2_ICR
		bpl  nmi_ret
		lsr  a
		bcc  notimer
		lda  CIA2_PRB
		lsr  a
		ror  nmizp				; data
		bcc  nmi_ret
		lda  #0
		sta  CIA2_CRA			; stop timer
		lda  #%00000001
		sta  CIA2_ICR			; disable timer interrupt
		lda  #%10010000
		sta  CIA2_ICR			; enable flag interrupt
		jsr  putbyte
nmi_ret:				
		pla						; restore memory-configuration
		SETMEMCONF
		pla						; restore register and return
		tay
		pla
		tax
		pla
		rti

notimer:
		lda  #$80
		sta  nmizp
		lda  #%00010001
		sta  CIA2_CRA			; restart timer
		lda  #%00010000
		sta  CIA2_ICR			; disable flag interrupt
		lda  #%10000001
		sta  CIA2_ICR			; enable timer interrupt
		jmp  nmi_ret

putbyte:
		lda  nmizp
		ldx  nmizp+2
r_buf_ptr1:		
		sta  SELFMOD,x
		inx
		txa
		sec
		sbc  nmizp+3
		beq  +
		stx  nmizp+2
	+	cmp  #WATER_HI
		bcc  +
		lda  CIA2_PRB
		and  #~B_RTS
		sta  CIA2_PRB
	+	rts
		
		
rs232_getc:
		ldx  nmizp+3
		cpx  nmizp+2
		beq  ++
r_buf_ptr2:		
		lda  SELFMOD,x
		pha
		inx
		stx  nmizp+3
		txa
		sec
		sbc  nmizp+2
		cmp  #$100-WATER_LO
		bcc  +
		lda  CIA2_PRB
		ora  #B_RTS
		sta  CIA2_PRB
	+	pla
		clc
		rts

	+	sec
		rts
		
rs232_putc:
		rts

		RELO_JMP(+)		; (don't relocate data-inlay)

		;; PAL timer values
		;;  for    300    600  1200  2400  4800  9600 baud
baudtab_l: .byte <3284, <1642, <822, <410, <205, <103
baudtab_h: .byte >3284, >1642, >822, >410, >205, >103
		
	+	;; initialisation

		bit  module_struct
initialize:
		;; check for interface
		jsr  port_setup
		;; an idle interface should pass this
lda  #"1"
jsr  out		
		lda  CIA2_PRB
		and  #B_RXD
		beq  not_detected
		lda  CIA2_ICR			; clear pending interrupts
		
lda  #"2"
jsr  out		
		lda  CIA2_DDRB
		ora  #B_RXD				; confg for output (temporary)
		sta  CIA2_DDRB
		lda  CIA2_PRB
		and  #~B_RXD
		sta  CIA2_PRB			; see if we can sink it
		lda  CIA2_PRB
		and  #B_RXD
		bne  not_detected
lda  #"3"
jsr  out		
		lda  CIA2_ICR			; clear pending interrupts
		and  #$10				; sinking RXD should generate a flag int.
		beq  not_detected
		lda  CIA2_DDRB
		and  #~B_RXD
		sta  CIA2_DDRB

lda  #"4"
jsr  out		
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
		;; allocate receive buffer (256 byte)
		ldx  #stdout
		bit  ok_txt
		jsr  lkf_strout
		nop
		
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
		
		RELO_END ; no more code to relocate

not_txt:
		.text "sorry, no RS232-std-interface detected"
		.byte $0a,$00
		
ok_txt:
		.text "RS232-std-interface (NMI) registered"
		.byte $0a,$00

end_of_code:
