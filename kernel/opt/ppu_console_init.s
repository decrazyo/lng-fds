
#include <console.h>

	-	jmp  lkf_panic

; initialise console driver.
; (and set lk_consmax value)
console_init:
		; the PPU has enough VRAM for 2 consoles.
#ifdef MULTIPLE_CONSOLES
		lda  #MAX_CONSOLES
#else
		lda  #1
#endif
		sta  lk_consmax

		lda #0 ; initialize fs_cons stuff
		sta usage_count

		; set mirroring mode to vertical
		lda fds_ctrl
		and #~FDS_CTRL_M
		sta FDS_CTRL

		; initialize PPU

		; BGR = 000 no particular color emphasis.
		; s = 0 disable sprites. don't need them.
		; b = 0 disable the background to disable rendering while we setup the PPU.
		; M = 0 disable left column sprites. we still aren't using sprites.
		; m = 1 enable left column background. we need all the horizontal resolution we can get.
		; G = 0 greyscale disabled. we want color.
		lda #PPU_MASK_m
		sta ppu_mask
		sta PPU_MASK

		; V = 1 NMI should already be enabled by "irqinit.s" but we don't have a good way to check.
		; P = 0 PPU master mode, as usual.
		; H = 0 8x8 sprites. sprites are disables.
		; B = 0 pattern table 0 for japanese kana. (TODO)
		;     1 pattern table 1 for english characters. (default after RESET)
		;     this makes english and japanese mutually exclusive but it's super easy to implement.
		; S = 0 sprite pattern table doesn't really matter. leaving at 0.
		; I = 0 auto-increment VRAM address by 1.
		; NN = 00 select nametable 0. (console 1)
		;      01 select nametable 1. (console 2)
		lda #PPU_CTRL_V | PPU_CTRL_B
		sta ppu_ctrl
		sta PPU_CTRL


#ifdef MULTIPLE_CONSOLES
		; init the second console
		ldx #1
		jsr lkf_cons_select

		; clear the screen.
		jsr  lkf_cons_clear

		; PPU_ADDR should be pointing at the attribute table after clearing the screen.
		; configure the whole screen to use palette 0.
		ldx #64 ; attribute table length
		lda #0
	-	sta PPU_DATA
		dex
		bne -

		; init the first console
		ldx #0
		jsr lkf_cons_select
#endif

		; clear the screen.
		jsr  lkf_cons_clear

		; PPU_ADDR should be pointing at the attribute table after clearing the screen.
		; configure the whole screen to use palette 0.
		ldx #64 ; attribute table length
		lda #0
	-	sta PPU_DATA
		dex
		bne -

		; set the address of the palette data.
		lda #$3f
		sta PPU_ADDR
		lda #$00
		sta PPU_ADDR

		; set the 2 colors that the screen will use.
		; using a color scheme similar to the C64.
		lda #$0f ; universal background color (black).
		sta PPU_DATA
		lda #$1a ; text color (green).
		sta PPU_DATA

		; reset scrolling to the start of console 1.
		lda #0
		sta ppu_scroll_x
		sta PPU_SCROLL
		sta ppu_scroll_y
		sta PPU_SCROLL

		; move cursor to the upper left corner of the screen.
		jsr  lkf_cons_home

		; display the cursor
		jsr lkf_cons_csr_show

		; finished setting up the PPU.
		; enable the background to resume rendering.
		lda ppu_mask
		ora #PPU_MASK_b
		sta ppu_mask
		sta PPU_MASK

		; print startup message
		ldx #0
	-	lda start_text,x
		beq +
		jsr lkf_printk
		inx
		bne -
	+	rts

start_text:
#ifdef MULTIPLE_CONSOLES
		.text "PPU console (v0.3) @ VRAM $2000,$2400",$0a,0
#else
		.text "PPU console (v0.3) @ VRAM $2000",$0a,0
#endif