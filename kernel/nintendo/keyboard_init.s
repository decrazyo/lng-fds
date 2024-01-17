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
		ldx  #<lkf_keyb_scan
		ldy  #>lkf_keyb_scan
		jsr  lkf_hook_irq		; hook into system

		; reset the keyboard to the 0th row, 0th column.
		lda #$05
		sta JOYPAD1

		ldx  #0
	-	lda  _startmsg,x
		beq  +
		jsr  lkf_printk
		inx
		bne  -
	+	rts

_startmsg:
		.text "Family BASIC Keyboard module version 0.2"
		.byte $0a,$00
