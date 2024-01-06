		;; Hey emacs, look at this: -*- MODE: asm; tab-width: 4; -*-
		
		;; simple (very simple) console driver

#include <config.h>
#include <system.h>
#include MACHINE_H
#include <zp.h>
#include <console.h>

#ifdef HAVE_REU
# include <reu.h>
#endif
		
		.global cons_home
		.global cons_clear

		cursor equ 100
		size_x equ 40
		size_y equ 25

		
		;; clear screen
		;; NOTE:
		;;		better not clear $7f8..$7ff (TODO)
cons_clear:
		jsr  cons_hidecsr
#ifndef HAVE_REU
		lda  #32
		ldx  #0
	-	sta  screenA_base,x
		sta  screenA_base+$100,x
		sta  screenA_base+$200,x
		sta  screenA_base+$300,x
		inx
		bne  -
		lda  #5					; text color
	-	sta  $d800,x
		sta  $d900,x
		sta  $da00,x
		sta  $db00,x
		inx
		bne  -
#else
		;; clear screen using REU
		lda  #REUcontr_fixreuadr
		sei						; (must sei until REU command is issued)
		sta  REU_control
		lda  #<screenA_base
		sta  REU_intbase
		lda  #>screenA_base
		sta  REU_intbase+1
		lda  #$20				; fill with $000420 which is $20 (space)
		sta  REU_reubase
		lda  #$04
		sta  REU_reubase+1
		lda  #$00
		sta  REU_reubase+2
		lda  #$f8
		sta  REU_translen
		lda  #$03
		sta  REU_translen+1
		lda  #REUcmd_reu2int|REUcmd_load|REUcmd_noff00|REUcmd_execute
		sta  REU_command
		lda  #5					; fill with $000405 which is $05 (green)
		sta  REU_reubase
		lda  #>$d800
		sta  REU_intbase+1
		lda  #REUcmd_reu2int|REUcmd_noff00|REUcmd_execute
		sta  REU_command
		cli
#endif
		jsr  cons_showcsr
		rts

		;; move cursor to the upper left corner of the screen
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
		adc  #>screenA_base		; start of screen
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
#ifndef HAVE_REU
		;; scrolling without REU
		jsr  locktsw			; scrolling should be atomic
		ldy  scrl_y1
		
	-	clc
		lda  ypos_table_lo,y
		sta  scrl_loop+4
		adc  #size_x
		sta  scrl_loop+1
		lda  ypos_table_hi,y
		ora  #>screenA_base
		sta  scrl_loop+5
		adc  #0
		sta  scrl_loop+2
		ldx  #size_x-1
scrl_loop:
		lda  .0,x
		sta  .0,x
		dex
		bpl  scrl_loop
		iny
		cpy  scrl_y2
		bne  -

		;; erase the last line
		lda  ypos_table_lo,y
		sta  scrl_loop2+1
		lda  ypos_table_hi,y
		ora  #>screenA_base
		sta  scrl_loop2+2
		lda  #32
		ldx  #size_x-1
scrl_loop2:
		sta  .0,x
		dex
		bpl  scrl_loop2
		jmp  unlocktsw
#else
		;; scrolling with REU
		ldy  scrl_y1
		lda  ypos_table_lo+1,y
		sei						; (must sei until REU command is issued)
		sta  REU_intbase
		lda  ypos_table_hi+1,y
		ora  #>screenA_base		; base of screen
		sta  REU_intbase+1
		lda  #0
		sta  REU_reubase
		sta  REU_reubase+1
		sta  REU_reubase+2
		sta  REU_control		; no fixed addresses
		sec
		lda  scrl_y2
		sbc  scrl_y1
		tay
		lda  ypos_table_lo,y	; (ypos_table holds just y*40 !)
		sta  REU_translen
		lda  ypos_table_hi,y
		sta  REU_translen+1
		lda  #REUcmd_int2reu|REUcmd_load|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; copy portion of screen into REU

		ldy  scrl_y1
		lda  ypos_table_lo,y
		sta  REU_intbase
		lda  ypos_table_hi,y
		ora  #>screenA_base		; base of screen
		sta  REU_intbase+1
		lda  #REUcmd_reu2int|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; copy portion back to screen (one line above)

		lda  #$20
		sta  REU_reubase
		lda  #$04				; (reu@$000420 holds $20)
		sta  REU_reubase+1		; (reubase+2 already is $00)
		lda  #40
		sta  REU_translen
		lda  #0
		sta  REU_translen+1
		lda  #REUcontr_fixreuadr
		sta  REU_control
		lda  #REUcmd_reu2int|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; erase lowest line (fill with $20)
		cli
		rts	
#endif

cons_showcsr:
		bit  cflag
		bvs  +					; already shown
		bpl  +					; cursor disabled
		sei
		lda  mapl
		sta  tmpzp
		lda  maph
		sta  tmpzp+1
		ldy  #0
		lda  (tmpzp),y
		sta  buc
		lda  #cursor
		sta  (tmpzp),y
		cli
		lda  #$c0
		sta  cflag
	+	rts

cons_hidecsr:
		bit  cflag
		bvc	 +					; no cursor there
		sei
		lda  mapl
		sta  tmpzp
		lda  maph
		sta  tmpzp+1
		ldy  #0
		lda  buc
		sta  (tmpzp),y
		cli
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
		;; switch to next virtual console
console_toggle:
		rts

special_mapping:
		.byte $40,$7b,$7d,$5c,$7e,$60,$5b,$5d,$a7,$5e,$7c,$5f,$1c,$1e
_no_of_specials equ *-special_mapping

special_code:
		.byte   0,115,107,127,113,109, 27, 29, 92, 30, 93,100, 94, 28
		
cons_out:
		sta  cchar
		jsr  cons_hidecsr
		
		ldx  esc_flag
		bne  jdo_escapes

		;; print normal character
		lda  cchar
		cmp  #32
		bcc  special_chars
		jsr  cons_a2p
		eor  rvs_flag
		tax
		php						; write character code
		sei						; to char_map
		lda  mapl
		sta  tmpzp
		lda  maph
		sta  tmpzp+1
		ldy  #0
		txa
		sta  (tmpzp),y
		plp
		jsr  cons_csrright
_back:		jmp  cons_showcsr

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
_tab:		lda  csrx			; tab-width=4
		lsr  a
		lsr  a
		clc
		adc  #1
		asl  a
		asl  a
		tax
		ldy  csry
		jsr  cons_setpos		; (only done, if position is valid)
		jmp  _back
_del:		ldx  csrx
		beq  +				; skip if already on left border
		dex
		ldy  csry
		jsr  cons_setpos
		php
		sei
		lda  mapl
		sta  tmpzp
		lda  maph
		sta  tmpzp+1
		lda  #32
		ldy  #0
		sta  (tmpzp),y
		plp
	+	jmp  _back

_beep:		jsr beep
		jmp _back

do_escapes:
		cpx  #2
		beq  do_esc2			; state2
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
		bcs  do_esc_command		; most likely a command
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
		ldx  esc_parcnt			; increase par-counter (if possible)
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
		php
		sei
		lda  mapl
		sta  tmpzp
		lda  maph
		sta  tmpzp+1
		ldy  #0
		ldx  csrx
		lda  #32
	-	sta  (tmpzp),y
		iny
		inx
		cpx  #size_x
		bne  -
		plp
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

;esc_flag:		.byte 0			; escape-statemachine-flag
;esc_parcnt:		.byte 0			; number of parameters read
esc_par:		.buf 8			; room for up to 8 parameters
