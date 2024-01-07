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

		lda #$20
		sta PPU_ADDR
		; TODO: determine the low byte of the address based on the active console
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

		lda #0
		sta PPU_SCROLL
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
		lda ppu_mask
		and ~PPU_MASK_b
		sta PPU_MASK

		; TODO: implement scrolling.
		; lda x_scroll
		; sta PPU_SCROLL
		; lda y_scroll
		; sta PPU_SCROLL

		; restore previous rendering state.
		lda ppu_mask
		sta PPU_MASK
		rts


cons_showcsr:
		; TODO: implement this.
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

cons_out:
		; save char
		sta cchar

		lda #0
		sta tmpzp ; high byte
		lda csry
		sta tmpzp+1 ; low byte

		; multiply cursor y by 32 tiles per row (left shift by 5)
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

		; disable rendering.
		lda ppu_mask
		and ~PPU_MASK_b
		sta PPU_MASK

		; set VRAM write address
		lda tmpzp
		sta PPU_ADDR
		lda tmpzp+1
		sta PPU_ADDR

		; write char to VRAM
		lda cchar
		sta PPU_DATA

		; reset scrolling.
		lda #0
		sta PPU_SCROLL
		sta PPU_SCROLL

		; restore previous rendering state.
		lda ppu_mask
		sta PPU_MASK

		lda cchar
		cmp #$0a ; \n
		bne +
		lda #31
		sta csrx

		; advance the cursor.
	+	inc csrx
		lda csrx
		cmp #32
		bne +

		; carriage return if needed.
		lda #0
		sta csrx

		; line feed.
		inc csry
		lda csry
		cmp #30
		bne +

		; wrap around if needed.
		lda #0
		sta csry

		; TODO: scroll the screen instead of just wrapping to the top of the screen.

	+	rts


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

;esc_flag:		.byte 0			; escape-statemachine-flag
;esc_parcnt:		.byte 0			; number of parameters read
esc_par:		.buf 8			; room for up to 8 parameters
