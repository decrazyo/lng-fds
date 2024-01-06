		;; For emacs: -*- MODE: asm; tab-width: 8; -*-
	
		;; simple console driver for C128's VDC (8563)
		;; supports many virtual consoles - depending
		;; on available VDC ram (16/64K)

		;; Maciej 'YTM/Alliance' Witkowiak
		;; ytm@friko.onet.pl
		;; 7,9,10,15,20.12.1999
		;; 7.1.2000, 14.5.2000, 23.12.2000
		;; derived from VIC console code by Daniel Dallmann

		;; uses hardware acceleration whenever possible
		;; - scrollup of whole screen costs ~16 rasterlines (2000 bytes)
		;; - cons_clear is a no-time :)

; comparison to VIC console (c64/console.s):
; D - completely different
; B - a bit different
; S - same

; console_toggle etc.		D (many consoles)
; console_init	cons_clear	D/B
; cons_home			S
; cons_setpos			B (y_pos_table_xx)
; cons_csr(xxxx)		S
; cons_scrollup			D
; cons_showcsr,	cons_hidecsr	B (direct handling)
; cons_a2p			S
; cons_out			B (direct output, also in _del and esc_com3)

;- console parameters are within VDC ram - at SCREEN_BASE+$0800-32 offset
;- test for size of VDC ram -> number of consoles, with 6 of them we are safe
;ram: $0000-$0fff - font, rest in 2k chunks for consoles (30/6 possible w/o attribute map)

;MULTIPLE_CONSOLES always works here

#include <console.h>

	;; additional globals that are needed
	;; by the initialisation code
	;; vdc_console_init.s

	.global cons_home
	.global cons_clear
	.global vdcmodefill
	.global vdcsetdataddy
	.global putvdcreg
	.global bputvdcreg
	.global cons_showcsr
	.global cons_savestat

	;; switch to next virtual console
	;; A: $00 - next console, $01-$7f - set number, >$80 - previous console

console_toggle:
		beq  do_next
		bmi  do_prev
		bpl  do_set

do_next:	lda cons_visible
		clc
		adc #1
		cmp lk_consmax
		bcs ++
		bne +

do_prev:	lda cons_visible
do_set:		sec
		sbc #1
		bmi ++
	+	sta cons_visible

		asl a				; *$0800
		asl a
		asl a
		clc
		adc #>CONSOLE_OFFS
		tay
		lda #0
		jmp vdcsetscraddy
	+	rts

cons_clear:
		ldy sbase
		lda #0
		jsr vdcsetdataddy
		lda #32				; space
		jsr bputvdcreg
		jsr vdcmodefill			; set block mode to fill
		lda #0				; 256 byte chunks
		ldy #7				;  *8 times=2048 - too much
		ldx #VDC_COUNT
	-	jsr putvdcreg
		dey
		bne -
		lda #207			; 1+(7*256)+207=2000, is it good or 206?
		ldx #VDC_COUNT
		jmp putvdcreg

cons_home:		
		ldx  #0
		ldy  #0

cons_setpos:
		cpx  #size_x
		bcs  +
		cpy  #size_y
		bcs  +					; ignore invalid settings
		stx  csrx
		sty  csry
		;; calculate position in RAM
		clc
		txa
		adc  ypos_table_lo,y
		sta  mapl
		lda  ypos_table_hi,y
		adc  sbase				; start of screen
		sta  maph
	+	rts

cons_csrup:
		ldx  csry
		beq  err				; error
		dex
		stx  csry
		sec
		lda  mapl
		sbc  #size_x
		sta  mapl
		bcs  +
		dec  maph
		clc
	+	rts

err:		sec
		rts

cons_csrdown:	
		ldx  csry
		cpx  #size_y-1
		beq  err
		inx
		stx  csry
		clc
		lda  mapl
		adc  #size_x
		sta  mapl
		bcc  +
		inc  maph
		clc
	+	rts

cons_csrleft:
		ldx  csrx
		beq  err				; error
		dex
		stx  csrx
		lda  mapl
		bne  +
		dec  maph
	+	dec  mapl
		clc
		rts

cons_csrright:	
		ldx  csrx
		cpx  #size_x-1
		beq  err
		inx
		stx  csrx
		inc  mapl
		bne  +
		inc  maph
	+	clc
		rts

cons_scroll_up:
		jsr vdcmodecopy

		ldy scrl_y1
		lda ypos_table_lo,y
		tax
		lda ypos_table_hi,y
		ora sbase
		tay
		txa
		jsr vdcsetdataddy

		ldy scrl_y1
		iny
		lda ypos_table_lo,y
		tax
		lda ypos_table_hi,y
		ora sbase
		tay
		txa
		jsr vdcsetsouaddy

		ldy scrl_y1
	-	lda #size_x
		ldx #VDC_COUNT
		jsr putvdcreg
		iny
		cpy scrl_y2
		bne -

		jsr vdcmodefill				; erase the last line
		lda #32					; space
		jsr bputvdcreg
		lda #size_x-1
		ldx #VDC_COUNT
		jmp putvdcreg		

cons_showcsr:
		bit  cflag
		bvs  +					; already shown
		bpl  +					; cursor disabled
		jsr cons_updatecsr
		ldx #VDC_CSRMODE
		jsr getvdcreg
		and #%10011111
	;^	ora #%01000000		;000 - noblink	; 010 - blink 1/16; 011 - blink 1/32;
		jsr putvdcreg
		lda  #$c0
		sta  cflag
	+	rts

cons_updatecsr:							; update cursor position
		ldy maph
		lda mapl
		jmp vdcsetcuraddy

cons_hidecsr:
		bit  cflag
		bvc  +						; no cursor there
		ldx #VDC_CSRMODE
		jsr getvdcreg
		and #%10011111
		ora #%00100000					; turn off cursor
		jsr putvdcreg
		lda  cflag
		and  #%10111111
		sta  cflag
	+	rts

		;; convert ascii to screencodes
cons_a2p:
		cmp  #32
		bcc  _is_special
		cmp  #64
		bcc  _keepit			; <64, then no change
		beq  _is_special
		cmp  #91
		bcc  _keepit			; big letter (no change)
		cmp  #97
		bcc  _is_special		; 91..96
		cmp  #123
		bcc  _sub96				; small letters (-96)
_is_special:
		ldx  #_no_of_specials
	-	cmp  special_mapping-1,x
		beq  +
		dex
		bne  -
		;; not found
		lda  #102
		sec
		rts

	+	lda  special_code-1,x
		SKIP_WORD

_sub96:
		sbc  #95
_keepit:	
		clc
	-	rts

special_mapping:
		.byte $40,$7b,$7d,$5c,$7e,$60,$5b,$5d,$a7,$5e,$7c,$5f,$1c,$1e
_no_of_specials equ *-special_mapping

special_code:
		.byte   0,115,107,127,113,109, 27, 29, 92, 30, 93,100, 94, 28

		;; save console status (9 bytes after mapl), basing on sbase
cons_savestat:	jsr vdc_setregbufaddr
		ldy #8
	-	lda mapl,y
		jsr bputvdcreg
		dey
		bpl -
		rts

		;; load console status (9 bytes after mapl), basing on sbase
cons_loadstat:	jsr vdc_setregbufaddr
		ldy #8
	-	jsr bgetvdcreg
		sta mapl,y
		dey
		bpl -
		rts

cons1out:
		ldx  #0

		;; print char to console, X=number of console
cons_out:
		cpx  lk_consmax
		bcs  -				; (silently ignore character, when X>1)
		jsr  locktsw			; (this code isn't reentrant!!)
		sta  cchar

		cpx  cons_visible		; is it currently visible console?
		beq  +

		txa
		pha
		jsr vdc_setmarkaddr		; no - mark (79,0) here
		jsr bgetvdcreg
		eor #$80
		pha
		jsr vdc_setmarkaddr
		pla
		jsr bputvdcreg
		pla
		tax

	+	cpx  current_output		; do we have variables now?
		beq  +

		txa
		pha
		;; save current screen variables
		jsr cons_savestat


		pla
		sta current_output
		asl a				; *$0800
		asl a
		asl a
		clc
		adc #>CONSOLE_OFFS
		sta sbase

		;; load variables of alternate screen
		jsr cons_loadstat

	+	ldx  esc_flag
		bne  jdo_escapes

		;; print normal character
		lda  cchar
		cmp  #32
		bcc  special_chars
		jsr  cons_a2p
		eor  rvs_flag
		pha
		lda mapl					; write character code
		ldy maph					; to char_map
		jsr vdcsetdataddy
		pla
		jsr bputvdcreg
		jsr  cons_csrright
_back:		jsr  cons_updatecsr				; update cursor position
		jmp  unlocktsw

jdo_escapes:	
		jmp  do_escapes
		
special_chars:

		;; UNIX ascii (default)
		cmp  #10
		beq  _crlf
		cmp  #13
		beq  _cr
		cmp  #27				; escape
		beq  _esc
		cmp  #9
		beq  _tab
		cmp  #8
		beq  _del
		cmp  #7
		beq  _beep
		jmp  _back
				
_crlf:		lda  csry
		cmp  scrl_y2
		bne  +
		jsr  cons_scroll_up
		jmp  _cr
		
	+	jsr  cons_csrdown
_cr:		ldx  #0
		ldy  csry
		jsr  cons_setpos
		jmp  _back
_esc:		lda  #1
		sta  esc_flag
		jmp  _back
_tab:		lda  csrx				; tab-width=4
		lsr  a
		lsr  a
		clc
		adc  #1
		asl  a
		asl  a
		tax
		ldy  csry
		jsr  cons_setpos			; (only done, if position is valid)
		jmp  _back
_del:		ldx  csrx
		beq  +					; skip if already on left border
		dex
		ldy  csry
		jsr  cons_setpos
		lda mapl
		ldy maph
		jsr vdcsetdataddy
		lda #32					; space
		jsr bputvdcreg
	+	jmp  _back

_beep:		jsr beep
		jmp _back

do_escapes:
		cpx  #2
		beq  do_esc2				; state2
		lda  cchar
		
		;; waiting for escape command (character)
		cmp  #91
		bne  +

		;; <ESC>[...
		lda  #2
		sta  esc_flag
		lda  #0
		sta  esc_parcnt
		lda  #$ff
		sta  esc_par		
		jmp  _back

	+	cmp  #68
		bne  leave_esc
		
		;; <ESC>D
		lda  csry
		cmp  scrl_y2
		beq  +
		jsr  cons_csrdown
		jmp  leave_esc
	+	jsr  cons_scroll_up
		
		;; ignore unknown escapes

leave_esc:
		lda  #0
		sta  esc_flag

		jmp  _back

		;; digit -> add to current parameter
		;; ";"   -> step to next parameter
		;; else  -> command!
do_esc2:
		lda  cchar
		cmp  #";"				; equal to "9"+2 !
		beq  do_esc_nextpar
		bcs  do_esc_command			; most likely a command
		;; most likely a digit
		and  #15
		sta  cchar
		ldx  esc_parcnt
		lda  esc_par,x
		bpl  +
		lda  #0
		beq  ++					; note, that c=0 !
	+	asl  a
		asl  a
		adc  esc_par,x
		asl  a
	+	adc  cchar
		sta  esc_par,x
		jmp  _back				; state doesn't change

do_esc_nextpar:
		ldx  esc_parcnt				; increase par-counter (if possible)
		cmp  #7
		beq  +
		inx
		stx  esc_parcnt
	+	lda  #255				; initialize parameter
		sta  esc_par,x
		jmp  _back				; state doesn't change again

do_esc_command:
		lda  cchar
		cmp  #72
		bne  esc_com2

		;; cursor positioning <ESC>[#y;#xH
		ldy  esc_par
		bpl  +					; parameter defaults to 0
		ldy  #1
	+	dey
		lda  esc_parcnt
		beq  +
		ldx  esc_par+1
		bpl  ++					; parameter defaults to 0
	+	ldx  #1
	+	dex
		jsr  cons_setpos
		jmp  leave_esc

esc_com2:
		cmp  #74
		bne  esc_com3

		;; clear screen <ESC>[2J
		lda  esc_par
		cmp  #2
		bne  +
		jsr  cons_clear
	+	jmp  leave_esc

esc_com3:
		cmp  #75
		bne  esc_com4

		;; erase rest of line <ESC>[K
		lda  esc_par
		cmp  #255
		bne  +
		
		jsr vdcmodefill
		lda mapl
		clc
		adc csrx
		tax
		lda maph
		adc #0
		tay
		txa
		jsr vdcsetdataddy
		lda #32
		jsr bputvdcreg
		lda #size_x-1
		sec
		sbc csrx
		beq +				;don't want to clear next 256 bytes...
		ldx #VDC_COUNT
		jsr putvdcreg
		
	+	jmp  leave_esc
		
esc_com4:		
		cmp  #114
		bne  esc_com5
		
		;; change scroll-region <ESC>[#y1;#y2r
		lda  esc_parcnt
		cmp  #1
		bne  +					; skip (illegal parameter)
		ldx  esc_par
		bmi  +
		beq  +
		cmp  #size_y
		bcs  +
		dex
		ldy  esc_par+1
		bmi  +
		cmp  #size_y+1
		bcs  +
		dey
		sty  cchar
		cpx  cchar
		bcs  +
		stx  scrl_y1			; valid !
		sty  scrl_y2
	+	jmp  leave_esc

esc_com5:
		cmp  #109
		bne  esc_com6

		;; change attributes <ESC>[#a1;...m
		ldy  #$ff
	-	iny
		lda  esc_par,y
		bmi  +					; clear all attributes
		beq  +					; clear all attributes
		cmp  #7
		bne  ++					; skip
		lda  #$80				; activate RVS
		SKIP_WORD
	+	lda  #$00				; de-activate RVS
		sta  rvs_flag
	+	cpy  esc_parcnt
		bne  -
		jmp  leave_esc
		
esc_com6:
		cmp  #$41
		bne  esc_com7
		
		;; cursor step up one position <ESC>[A
		lda  esc_par
		cmp  #255
		bne  +
		jsr  cons_csrup
	+	jmp  leave_esc

esc_com7:
		cmp  #$42
		bne  esc_com8
		
		;; cursor step down one position <ESC>[B
		lda  esc_par
		cmp  #255
		bne  +
		jsr  cons_csrdown
	+	jmp  leave_esc

esc_com8:
		cmp  #$43
		bne  esc_com9
		
		;; cursor step forw one position <ESC>[C
		lda  esc_par
		cmp  #255
		bne  +
		jsr  cons_csrright
	+	jmp  leave_esc

esc_com9:
		cmp  #$44
		bne  esc_com10
		
		;; cursor step backw one position <ESC>[D
		lda  esc_par
		cmp  #255
		bne  +
		jsr  cons_csrleft
	+	jmp  leave_esc

esc_com10:		
		;; unknown sequence, just ignore
		jmp  leave_esc


;-----------------------------------------------------------------------
; Direct I/O
;-----------------------------------------------------------------------

vdc_setmarkaddr:
		lda cons_visible
		asl a
		asl a
		asl a
		clc
		adc #>(CONSOLE_OFFS+size_x-1)
		tay
		lda #<(CONSOLE_OFFS+size_x-1)
		jmp vdcsetdataddy

vdc_setregbufaddr:
		lda sbase
		clc
		adc #>(CONSOLE_OFFS+$0800-32)
		tay
		lda #<(CONSOLE_OFFS+$0800-32)
		jmp vdcsetdataddy

vdcmodecopy:	lda #$80			; set block mode to copy
		SKIP_WORD
vdcmodefill:	lda #0				; set block mode to fill
		ldx #VDC_VSCROLL
		jmp putvdcreg

vdcsetscraddy:	ldx #VDC_DSPLO
		SKIP_WORD
vdcsetsouaddy:	ldx #VDC_SRCLO
		SKIP_WORD
vdcsetcuraddy:	ldx #VDC_CSRLO
		SKIP_WORD
vdcsetdataddy:	ldx #VDC_DATALO

		; A=LSB, Y=MSB, X=MSB_vdc_reg
		stx VDC_REG
	-	bit VDC_REG
		bpl -
		sta VDC_DATA_REG
		dex
		tya
		stx VDC_REG
		sta VDC_DATA_REG
		rts

bputvdcreg:
		ldx #VDC_DATA
putvdcreg:
		stx VDC_REG
	-	bit VDC_REG
		bpl -
		sta VDC_DATA_REG
		rts

bgetvdcreg:
		ldx #VDC_DATA
getvdcreg:
		stx VDC_REG
	-	bit VDC_REG
		bpl -
		lda VDC_DATA_REG
		rts

;-------------------------------------------------------------------------------

ypos_table_lo:
		.byte <   0, <  80, < 160, < 240, < 320
		.byte < 400, < 480, < 560, < 640, < 720
		.byte < 800, < 880, < 960, <1040, <1120
		.byte <1200, <1280, <1360, <1440, <1520
		.byte <1600, <1680, <1760, <1840, <1920

ypos_table_hi:
		.byte >   0, >  80, > 160, > 240, > 320
		.byte > 400, > 480, > 560, > 640, > 720
		.byte > 800, > 880, > 960, >1040, >1120
		.byte >1200, >1280, >1360, >1440, >1520
		.byte >1600, >1680, >1760, >1840, >1920

;----------------------------------------------------------------------------
;
; console driver status

;;unused for now...
;;vdcmemsize:	.byte 0			;^ 16/64K of VDC ram, =0 - 16K, !=0 - 64K

;;; ZEROpage: sbase 1
;;; ZEROpage: cchar 1
;;; ZEROpage: current_output 1
;;; ZEROpage: cons_visible 1
;;; ZEROpage: mapl 1
;;; ZEROpage: maph 1
;;; ZEROpage: csrx 1
;;; ZEROpage: csry 1
;;; ZEROpage: buc 1
;;; ZEROpage: cflag 1
;;; ZEROpage: rvs_flag 1
;;; ZEROpage: scrl_y1 1
;;; ZEROpage: scrl_y2 1

;sbase:			.byte 0	; base address of screen (hi byte)
;cchar:			.byte 0
;current_output:	.byte 0
;cons_visible:		.byte 0

		;; variables to store, when switching screens
;mapl:			.byte 0
;maph:			.byte 0
;csrx:			.byte 0
;csry:			.byte 0
;buc:			.byte 0	; byte under cursor
;cflag:			.byte 0	; cursor flag (on/off)
;rvs_flag:		.byte 0	; bit 7 - RVS ON
;scrl_y1:		.byte 0	; scroll region first line
;scrl_y2:		.byte 0	; scroll region last line

;;; ZEROpage: esc_flag 1
;;; ZEROpage: esc_parcnt 1

		;; escape decoding related
;esc_flag:		.byte 0	; escape-statemachine-flag
;esc_parcnt:		.byte 0	; number of parameters read
esc_par:		.buf 8	; room for up to 8 parameters
