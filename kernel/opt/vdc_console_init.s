		;; For emacs: -*- MODE: asm; tab-width: 4; -*-
	
		;; simple console driver for C128's VDC (8563)
		;; (initialisation part)
		;; supports many virtual consoles - depending
		;; on available VDC ram (16/64K)

		;; Maciej 'YTM/Alliance' Witkowiak
		;; ytm@friko.onet.pl
		;; 7,9,10,16,18.12.1999
		;; 17.1.2000, 23.12.2000
		;; derived from VIC console code by Daniel Dallmann

		;; uses hardware acceleration whenever possible
		;; - scrollup of whole screen costs ~16 rasterlines (2000 bytes)
		;; - cons_clear is a no-time :)

		;; I don't like lines with ';^' comments...

;+ console parameters within VDC ram - at offset $0800-32 
;- test for size of VDC ram -> number of consoles
;ram: $0000-$0fff - font, rest in 2k chunks for consoles (30/6 possible w/o attribute map)

;MULTIPLE_CONSOLES are always enabled

#include <console.h>

		;; Note:
		;;  the variables exported by vdc_console.s
		;; get a "lkf_" prefix in here !

		;; Note2:
		;;  variables declared ZEROpage in vdc_console.s
		;; don't get a prefix and *must* be initialised
		;; here!

console_init:
		ldx #0
	-	lda vdcinitab,x
		cpx #VDC_COUNT
		beq +
		cpx #VDC_DATA
		beq +
		jsr lkf_putvdcreg
	+	inx
		cpx #$25
		bne -

		lda VDC_REG		;vdc version
		and #%0000111
		ldx #0
		cmp #1
		bcc +
		ldx #7
	+	txa
		ldx #VDC_HSCROLL
		jsr lkf_putvdcreg

				;^ check memory size here
		lda #MAX_CONSOLES		; set number of consoles
		sta lk_consmax
		lda #0				; initialize fs_cons stuff
		sta usage_map
		sta usage_count

		jsr vdcinitfont

		lda #>CONSOLE_OFFS			;set first console
		sta sbase
		lda  #1
		jsr  lkf_console_toggle

		lda  #$80
		sta  cflag				; curor enabled (not yet drawn)
		lda  #0
		sta  esc_flag
		sta  rvs_flag
		sta  scrl_y1
		lda  #24
		sta  scrl_y2

		lda #0					; clone status to all consoles
		sta tmpzp
	-	jsr lkf_cons_clear			; clearing them
		jsr lkf_cons_home			; to update mapl/maph
		jsr lkf_cons_savestat
		lda sbase
		clc
		adc #8
		sta sbase
		inc tmpzp
		lda tmpzp
		cmp lk_consmax
		bne -

		lda #>CONSOLE_OFFS			; back to the first one
		sta sbase
		jsr lkf_cons_home

		jsr lkf_cons_showcsr

		;; print startup message
		ldx  #0
	-	lda  start_text,x
		beq  +
		jsr  lkf_printk
		inx
		bne  -

	+	rts

vdcinitfont:			; load ROM font into VDC ram ($0000)

		lda #0
		ldy #0
		jsr lkf_vdcsetdataddy

		php
		sei
		GETMEMCONF
		pha

		lda #<FONT_ROM
		ldy #>FONT_ROM
		sta tmpzp
		sty tmpzp+1

		jsr lkf_vdcmodefill			; set block mode to fill

		ldy #0
	-	ldx #0
		lda #VDC_DATA
		sta VDC_REG

	-
		lda #MEMCONF_FONT
		SETMEMCONF
		lda (tmpzp),y			; copy 8 bytes
		pha
		lda #MEMCONF_SYS
		SETMEMCONF
	-	bit VDC_REG
		bpl -
		pla
		sta VDC_DATA_REG
		iny
		inx
		cpx #8
		bne --
		lda #0				; and fill remaining 8
		jsr lkf_bputvdcreg
		lda #7
		ldx #VDC_COUNT
		jsr lkf_putvdcreg
		tya				; if Y!=0...
		bne ---

		inc tmpzp+1
		lda tmpzp+1
		cmp #(>FONT_ROM+8)
		bne ---

		pla
		SETMEMCONF
		plp
		rts

vdcinitab:	
		.byte $7e				; 0
		.byte size_x			; 1  - # of columns
		.byte $66, $49, $26, $00; 2-5
		.byte size_y			; 6  - # of lines
		.byte $20				; 7
		.byte %00000000			; 8  - interlace - none
		.byte %00000111			; 9  - 8 pixels for line
		.byte %00100000			; 10 - cursor not visible, start 0
		.byte %00000111			; 11 - cursor end 7 (block cursor)
		.byte >CONSOLE_OFFS,0	; 12/13 - current screen position
		.byte 0,0		; 14/15 - current cursor position
		.byte 0,0		; 16/17 - r/ - lightpen position
		.byte 0,0		; 18/19 - current data address
		.byte 0,0		; 20/21 - attribute map position (not used)
		.byte $78, $08	; 22-23
		.byte %00000000	; 24 - block mode fill
						;    - non-reversed display
		.byte %00000000	; 25 - text display
						;    - w/o attribute map
						;    - ???
						;    - pixel= 1dot clock
		.byte %11110000	; 26 - colors (text/back)
		.byte 0			; 27 - ???
		.byte 0			; 28 - A13-15 of font, bit 4 - ram size (0=16K)
		.byte $07		; 29
		.byte $4f, $20	; 30 - # of fill/copy cycles; 31 - data for write/fill
		.byte 0,0		; 32/33 - source address of block copy
		.byte $7d,$64	; 34/35 - start/end of display
		.byte $05		; 36 - # of refresh

start_text:
		.text "VDC console[s] (v0.2) by YTM/Elysium",$0a,0
