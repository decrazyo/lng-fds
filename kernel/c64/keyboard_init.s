;; for emacs: -*- MODE: asm; tab-width: 4; -*-

;********************************************
; excerpt of keyscanning routine  
; this code should be included in the boot
; strapping code as it is not needed any more
; after the keyboard is initialised
;********************************************

; C128 extension by Maciej 'YTM/Alliance' Witkowiak <ytm@friko.onet.pl>

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
		lda  #$ff
		sta  port_row
		sta  port_col
		sta  port_row+2			; row is output
#ifdef C128
		sta  port_row2			; C64 lookalike by default
#endif
		lda  #0
		sta  port_col+2			; column is input (default after reset)
		ldx  #0
	-	lda  _startmsg,x
		beq  +
		jsr  lkf_printk
		inx
		bne  -
	+	rts

_startmsg:
#ifndef C128
		.text "C64-Keyboard module version 1.0"
#else
		.text "C128-Keyboard module version 1.1"
#endif
		.byte $0a,$00
