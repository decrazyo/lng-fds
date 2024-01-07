;; for emacs: -*- MODE: asm; tab-width: 4; -*-
	
#include <console.h>

	-	jmp  lkf_panic

; initialise console driver.
; (and set lk_consmax value)
console_init:

		; the PPU has enough VRAM for 2 consoles.
		; we'll just use a single console for now.
		lda  #1
		sta  lk_consmax

		lda #0				; initialize fs_cons stuff
		sta usage_count

		; initialize PPU

		; BGR = 000 no particular color emphasis.
		; s = 0 disable sprites. don't need them.
		; b = 0 disable the background to disable rendering while we setup the PPU.
		; M = 0 disable left column sprites. we still aren't using sprites.
		; m = 1 enable left column background. we need all the horizontal resolution we can get.
		; G = 0 greyscale disabled. we want color.
		;     BGRsbMmG
		lda #%00000010
		sta ppu_mask
		sta PPU_MASK


		; V = 1 enable NMI here
		; P = 0 PPU master mode, as usual.
		; H = 0 8x8 sprites. we'll probably disable sprites
		; B = 0 pattern table 0 for english characters.
		;     1 pattern table 1 for japanese kana.
		;     this makes english and japanese mutually exclusive but it's super easy to implement.
		; S = 0 sprite pattern table doesn't really matter. leaving at 0.
		; I = 0 auto-increment VRAM address by 1.
		; NN = 00 select nametable 0. console 1.
		;      01 select nametable 1. console 2.
		; VPHBSINN
		; 10000000
		; we will want to store this data in system RAM as we may change it later.
		; this should probably be initialized in irqinit.s
		lda #%10000000
		sta ppu_ctrl
		sta PPU_CTRL

		lda #0
		sta PPU_SCROLL
		sta PPU_SCROLL

		lda #$20
		sta PPU_ADDR
		lda #$00
		sta PPU_ADDR

		; TODO: set attribute data
		; TODO: set the pallet data
		; background color $10 (dark grey)
		; foreground color $1A (green)

		; finished setting up the PPU.
		; enable the background to resume rendering.
		lda #%00001010
		sta ppu_mask
		sta PPU_MASK


		; TODO: figure out exactly what this is doing.
		;       it was copied from "vic_console_init.s".
		;       in any case, it doesn't seem to hurt.
		lda  #$80
		sta  cflag				; curor enabled (not yet drawn)
		lda  #0
		sta  esc_flag
		sta  rvs_flag
		sta  scrl_y1
		lda  #24
		sta  scrl_y2

		jsr  lkf_cons_home
		jsr  lkf_cons_clear

		; print startup message
		ldx  #0
	-	lda  start_text,x
		beq  +
		jsr  lkf_printk
		inx
		bne  -
	+	rts

start_text:
		.text "PPU console (v0.1)",$0a,0
