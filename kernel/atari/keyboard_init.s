;
; Atari keyboard init
; Maciej 'YTM/Alliance' Witkowiak <ytm@friko.onet.pl>
; 25.12.2000
;

#include <config.h>
#include <system.h>
#include MACHINE_H
#include <keyboard.h>
#include <zp.h>

		;; initialize and install keyboard scanning routine
keyboard_init:

		lda #%00000011
		sta POKEY_SKCTL			; reset serial, init keyboard scan

		;; no need to hook-in, we're already there
;		ldx  #<lkf_keyb_scan
;		ldy  #>lkf_keyb_scan
;		jsr  lkf_hook_irq		; hook into system

		ldx #0
		stx altflags

	-	lda  _startmsg,x
		beq  +
		jsr  lkf_printk
		inx
		bne  -
	+	rts

_startmsg:
		.text "Atari keyboard module version 0.1"
		.byte $0a,$00
