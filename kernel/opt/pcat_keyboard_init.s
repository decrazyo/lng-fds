;; for emacs: -*- MODE: asm; tab-width: 4; -*-
	
;********************************************
; excerpt of keyscanning routine  
; this code should be included in the boot
; strapping code as it is not needed any more
; after the keyboard is initialised
;********************************************

; PC AT compatible version by Maciej 'YTM/Alliance' Witkowiak <ytm@friko.onet.pl>
; 11/12.2.2000

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

		lda 0				; prevent keyboard from sending data
		ora #%00011000			; until next scan, keyboard will buffer
		sta 0				; everything internally
		lda 1
		and #%11100111
		ora #%00010000
		sta 1

		lda CIA1_ICR			; clear pending FLAG1 signals (keyb. CLOCK)

		ldx  #$ff
		stx  port_row
		stx  port_col
		stx  port_row+2			; row is output

		inx
		stx altflags
		stx keycode
		stx port_col+2

	-	lda  _startmsg,x
		beq  +
		jsr  lkf_printk
		inx
		bne  -
	+	rts

_startmsg:
		.text "PC/AT Keyboard module version 0.2"
		.byte $0a,$00
