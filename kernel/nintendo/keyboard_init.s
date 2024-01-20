;; for emacs: -*- MODE: asm; tab-width: 4; -*-

;********************************************
; excerpt of keyscanning routine  
; this code should be included in the boot
; strapping code as it is not needed any more
; after the keyboard is initialised
;********************************************

#include <config.h>
#include <system.h>
#include MACHINE_H
#include <keyboard.h>
#include <zp.h>

		;; initialize and install keyboard scanning routine
keyboard_init:
		; check that a keyboard is attached.

		; reset the keyboard to the 0th row, 0th column.
		lda #$05
		sta JOYPAD1

		; toggle the column select bit until we reach the keyless 10th row.
		lda #$06
		ldx #$04
		ldy #18
	-	sta JOYPAD1
		stx JOYPAD1
		dey
		bne -

		; check that the keyboard responds correctly to enable/disable signals.
		lda JOYPAD2
		and #$1e
		eor #$1e
		bne _printmsg ; branch on error
		sta JOYPAD1
		lda JOYPAD2
		and #$1e
		bne _printmsg ; branch on error

		; truncate the start message to omit the error message.
		sta _errormsg

		; reset the keyboard to the 0th row, 0th column again.
		lda #$05
		sta JOYPAD1

		ldx  #<lkf_keyb_scan
		ldy  #>lkf_keyb_scan
		jsr  lkf_hook_irq		; hook into system

_printmsg:
		ldx  #0
	-	lda  _startmsg,x
		beq  +
		jsr  lkf_printk
		inx
		bne  -
	+	rts

_startmsg:
		.text "Family BASIC Keyboard module version 0.3"
		.byte $0a
_errormsg:
		.text "No Keyboard"
		.byte $0a,$00