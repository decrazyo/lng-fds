		;; Hey emacs, look at this: -*- MODE: asm; tab-width: 4; -*-
		
		;; simple (very simple) console driver

#include <config.h>
#include <system.h>
#include MACHINE_H
#include <zp.h>
#include <console.h>

		.global cons_home
		.global cons_clear

		;; clear screen
cons_clear:
		; disable rendering.
		lda ppu_mask
		and ~PPU_MASK_b
		sta PPU_MASK

		; set VRAM address
		lda #$20
		sta PPU_ADDR
		lda #0
		sta PPU_ADDR

		; zero out VRAM.
		ldx #240
	-	sta PPU_DATA
		sta PPU_DATA
		sta PPU_DATA
		sta PPU_DATA
		dex
		bne -

		jsr cons_showcsr

		lda ppu_scroll_x
		sta PPU_SCROLL
		lda ppu_scroll_y
		sta PPU_SCROLL

		; restore previous rendering state.
		lda ppu_mask
		sta PPU_MASK
		rts


		;; move cursor to the upper left corner of the screen
cons_home:
		ldx  #0
		ldy  #0

		;; move cursor to an arbitrary position
cons_setpos:
		cpx  #size_x
		bcs  + ; branch if new cursor position is off the screen.
		cpy  #size_y
		bcs  + ; branch if new cursor position is off the screen.
		stx  csrx
		sty  csry
	+	rts

cons_csrup:
		ldx  csry
		beq  err				; error
		dex
		stx  csry
		clc
	+	rts

err:
		sec
		rts

cons_csrdown:
		ldx  csry
		cpx  #size_y-1
		beq  err
		inx
		stx  csry
		clc
	+	rts

cons_csrleft:
		ldx  csrx
		beq  err				; error
		dex
		stx  csrx
		clc
		rts

cons_csrright:
		ldx  csrx
		cpx  #size_x-1
		beq  err
		inx
		stx  csrx
		clc
		rts

cons_scroll_up:
		; disable rendering.
		;lda ppu_mask
		;and ~PPU_MASK_b
		;sta PPU_MASK

		;lda ppu_scroll_x
		;sta PPU_SCROLL
		lda ppu_scroll_y
		clc
		adc #8
		cmp #240
		bcc +
		lda #0
	+	sta ppu_scroll_y
		;sta PPU_SCROLL

		;; restore previous rendering state.
		;lda ppu_mask
		;sta PPU_MASK
		rts


cons_showcsr:
		jsr csr_to_vram_addr
		lda #"_"
		sta PPU_DATA
		rts
;		bit  cflag
;		bvs  +					; already shown
;		bpl  +					; cursor disabled
;		sei
;		lda  mapl
;		sta  tmpzp
;		lda  maph
;		sta  tmpzp+1
;		ldy  #0
;		lda  (tmpzp),y
;		sta  buc
;		lda  #cursor
;		sta  (tmpzp),y
;		cli
;		lda  #$c0
;		sta  cflag
;	+	rts

cons_hidecsr:
		jsr csr_to_vram_addr
		lda #" "
		sta PPU_DATA
		; TODO: implement this.
		rts
;		bit  cflag
;		bvc	 +					; no cursor there
;		sei
;		lda  mapl
;		sta  tmpzp
;		lda  maph
;		sta  tmpzp+1
;		ldy  #0
;		lda  buc
;		sta  (tmpzp),y
;		cli
;		lda  cflag
;		and  #%10111111
;		sta  cflag
;	+	rts
				
		;; convert ascii to screencodes
cons_a2p:
		; no conversion needed.
		; the pattern table matches ascii.
		clc
		;; switch to next virtual console
console_toggle:
		; only supporting one console for now.
		rts


csr_to_vram_addr:
		lda #0
		sta tmpzp ; high byte
		lda csry
		sta tmpzp+1 ; low byte

		; multiply cursor y by 32 tiles per row.
		ldx #5
	-	asl tmpzp+1
		rol tmpzp
		dex
		bne -

		; add x offset
		lda csrx
		ora tmpzp+1
		sta tmpzp+1

		; add VRAM base address
		clc
		lda tmpzp
		adc #$20
		sta tmpzp

		lda tmpzp
		sta PPU_ADDR
		lda tmpzp+1
		sta PPU_ADDR

		rts


cons_out:
		tay ; save the character for later.

		; disable rendering.
		lda ppu_mask
		and ~PPU_MASK_b
		sta PPU_MASK

		jsr cons_hidecsr

		cpy #"\n"
		beq _new_line ; branch if the character is a new line.

		; write char to VRAM at cursor position.
		jsr csr_to_vram_addr
		sty PPU_DATA

		; advance the cursor.
		inc csrx
		lda csrx
		cmp #size_x
		bne _cons_out_done; branch if we haven't reached the end of a line.

_new_line:
		; carriage return.
		lda #0
		sta csrx

		; line feed.
		inc csry
		lda csry
		cmp #size_y
		bne + ; branch if we haven't reached the last line in VRAM.

		; wrap the cursor around to the start of VRAM.
		lda #0
		sta csry

		; multiply the cursor y position by 8 pixels per line.
	+	asl a
		asl a
		asl a
		cmp ppu_scroll_y
		bne _cons_out_done ; branch if we don't need to scroll yet.

		; set VRAM write address to cursor position.
		jsr csr_to_vram_addr

		; clear the next line before scrolling to it.
		lda #" "
		ldx csrx
	-	sta PPU_DATA ; VRAM address increments after each write.
		inx
		cpx #size_x
		bne -

		; compute the new scroll position to display the next line.
		lda ppu_scroll_y
		clc
		adc #8 ; tile size in pixels.
		cmp #240 ; screen height in pixels. (30 tiles x 8 pixels per tile)
		bne +
		lda #0
	+	sta ppu_scroll_y

_cons_out_done:
		jsr cons_showcsr

		; set scrolling position.
		lda ppu_scroll_x
		sta PPU_SCROLL
		lda ppu_scroll_y
		sta PPU_SCROLL

		; the FDS BIOS changes various registers to their default values during RESET.
		; we're changing them here to make kernel panics due to RESET print correctly.
		lda ppu_ctrl
		sta PPU_CTRL
		lda tmp_fds_ctrl
		and #~FDS_CTRL_M
		sta FDS_CTRL

		; restore previous rendering state.
		lda ppu_mask
		sta PPU_MASK

		rts


; TODO: assess how much of the following is actually needed.
;       it's mostly copied from another driver.

ypos_table_lo:
		.byte <  0, < 40, < 80, <120, <160
		.byte <200, <240, <280, <320, <360
		.byte <400, <440, <480, <520, <560
		.byte <600, <640, <680, <720, <760
		.byte <800, <840, <880, <920, <960
		
ypos_table_hi:
		.byte >  0, > 40, > 80, >120, >160
		.byte >200, >240, >280, >320, >360
		.byte >400, >440, >480, >520, >560
		.byte >600, >640, >680, >720, >760
		.byte >800, >840, >880, >920, >960

		;; variables moved to zeropage:	

;;; ZEROpage: mapl 1
;;; ZEROpage: maph 1
;;; ZEROpage: csrx 1
;;; ZEROpage: csry 1
;;; ZEROpage: buc 1
;;; ZEROpage: cflag 1
;;; ZEROpage: cchar 1
;;; ZEROpage: rvs_flag 1
;;; ZEROpage: scrl_y1 1
;;; ZEROpage: scrl_y2 1
;;; ZEROpage: esc_flag 1
;;; ZEROpage: esc_parcnt 1
;;; ZEROpage: ppu_addr_lo 1
;;; ZEROpage: ppu_mask 1
;;; ZEROpage: ppu_ctrl 1
;;; ZEROpage: ppu_scroll_y 1
;;; ZEROpage: ppu_scroll_x 1

;mapl:			.byte 0
;maph:			.byte 0
;csrx:			.byte 0
;csry:			.byte 0
;buc:			.byte 0			; byte under cursor
;cflag:			.byte 0			; cursor flag (on/off)
;cchar:			.byte 0
;rvs_flag:		.byte 0			; bit 7 - RVS ON
;scrl_y1:		.byte 0			; scroll region first line
;scrl_y2:		.byte 0			; scroll region last line
;ppu_addr_lo:	.byte 0
;ppu_mask:		.byte 0
;ppu_ctrl:		.byte 0
;ppu_scroll_y:		.byte 0
;ppu_scroll_x:		.byte 0

;esc_flag:		.byte 0			; escape-statemachine-flag
;esc_parcnt:		.byte 0			; number of parameters read
esc_par:		.buf 8			; room for up to 8 parameters
