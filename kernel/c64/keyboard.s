;; for emacs: -*- MODE: asm; tab-width: 4; -*-

;********************************************
; LUnix - keyscanning
;   invented for old and dusty keyboards :-)
;
; this will become a module in a later version
; (a module that is inserted at startup) 
;********************************************

; C128 extension by Maciej 'YTM/Elysium' Witkowiak <ytm@elysium.pl>
; 31.12.1999
; for now there's no difference between keypad and numkeys although IIRC
; there's special keypad mode, so these should probably emit some ESC-sequences
; 14.05.2000
; added more flags to 'altflags', CAPS is special (checked before table lookup), but
; other can be placed in tables - $e0-$e3 are modyfing higher nibble of altflags
; these are 'lock' keys - twostate
; that stuff is unconditional and will be assembled to both C64 and C128 configurations
; 23.12.2000
; added $df keycode handler for previous console
; 04.03.2003
; moved common stuff to machine-independent code

		;; additional global needed by
		;; keyboard_init which is run at boottime
		;; (they will get a "lkf_" prefix there!)

		.global keyb_scan

btab2i:		.byte $fe, $fd, $fb, $f7, $ef, $df, $bf, $7f

#ifdef C128
btab2i2:
		.byte $ff, $ff, $ff		;these 3 are common for both tables
		.byte $ff, $ff, $ff, $ff, $ff, $fe, $fd, $fb

#endif
locktab:	;; table for $e? keys
		.byte keyb_alt, keyb_ex1, keyb_ex2, keyb_ex3

		;; UNIX (ascii) decoding tables (default)

#define dunno $7f
#define f1_c            $f1		;  internal code! -> switch to console 1
#define f2_c            $f5
#define f3_c            $f2		;  internal code! -> switch to console 2 (..7)
#define f4_c            $f6
#define f5_c            $f3
#define f6_c            dunno
#define f7_c            $f4
#define f8_c            dunno
#define pound_c         $1e
#define home_c          dunno
#define arrow_left_c    $1b     ; arrow_left = escape
#define arrow_up_c      $5e		; arrow up = ^
#define csr_up_c         $81	;  internal codes! -> ESC[A
#define csr_down_c       $82	;  internal codes! -> ESC[B
#define csr_left_c       $84	;  internal codes! -> ESC[D
#define csr_right_c      $83	;  internal codes! -> ESC[C
#define commo_c         $09		; commodore key is tab ?! (you may change it)
#define rs_c            $03		; run/stop = CTRL+c
#define sdel_c          dunno
#define snull_c         $7c     ; shift + 0 = |
#define splus_c         $7b     ; shift + "+" = {
#define smin_c          $7d     ; shift + "-" = }
#define sat_c           $5f     ; shift + @ = _
#define spound_c        $5c     ; shift + pound = \   !
#define sstar_c         $7e     ; shift + * = ~
#define shome_c         dunno
#define sequ_c          dunno
#define sarrow_up_c     $1c     ; shift + arrow_up = pi
#define sarrow_left_c   $60     ; shift + arrow_left = ` (reverse quote)
#define sspc_c          $20     ; shift + space = space
#define scommo_c        $df	;  internal code! -> prev console
#define srs_c		$f0	;  internal code! -> next console

# ifdef C128
; these are for C128 keys

#define tab_c		$09
#define esc_c		$1b	; esc is truly ESC
#define lf_c		$0a	; linefeed is LF and life is life
#define cr_c		$0a	; enter is also LF
#define alt_c		$e0	; alt~=meta?
#define help_c		$e1	; help
#define noscrl_c	$e2	; no-scroll - this should start/stop line 
				; scrolling on screen, probably blocking console
# endif ; C128

_keytab_normal:
# ifdef DIN
  .byte  $08,$0a,csr_right_c,f7_c,f1_c,f3_c,f5_c,csr_down_c
  .byte  "3",$77,$61,"4",$79,$73,$65,~keyb_lshift
  .byte  "5",$72,$64,"6",$63,$66,$74,$78
  .byte  "7",$7a,$67,"8",$62,$68,$75,$76
  .byte  "9",$69,$6a,"0",$6d,$6b,$6f,$6e
  .byte  $2b,$70,$6c,$2d,$2e,$3a,$40,$2c
  .byte  "[","+",$3b,home_c,~keyb_rshift,"#","]","-"
  .byte  "1","<",~keyb_ctrl,"2"," ",commo_c,$71,rs_c
# else
  .byte  $08,$0a,csr_right_c,f7_c,f1_c,f3_c,f5_c,csr_down_c
  .byte  $33,$77,$61,$34,$7a,$73,$65,~keyb_lshift
  .byte  $35,$72,$64,$36,$63,$66,$74,$78
  .byte  $37,$79,$67,$38,$62,$68,$75,$76
  .byte  $39,$69,$6a,$30,$6d,$6b,$6f,$6e
  .byte  $2b,$70,$6c,$2d,$2e,$3a,$40,$2c
  .byte  pound_c, $2a,$3b,home_c,~keyb_rshift,$3d,arrow_up_c,$2f
  .byte  $31,arrow_left_c,~keyb_ctrl,$32,$20,commo_c,$71,rs_c
# endif ; DIN
# ifdef C128
  ; for C128
  .byte help_c, $38, $35, tab_c, $32, $34, $37, $31
  .byte esc_c, $2b, $2d, lf_c, cr_c, $36, $39, $33
  .byte alt_c, $30, $2e, csr_up_c, csr_down_c, csr_left_c, csr_right_c, noscrl_c
# endif ; C128

_keytab_shift:
# ifdef DIN
  .byte  sdel_c,$0a,csr_left_c,f8_c,f2_c,f4_c,f6_c,csr_up_c
  .byte  $40,$57,$41,"$",$59,$53,$45,$ff
  .byte  "%",$52,$44,"&",$43,$46,$54,$58
  .byte  "/",$5a,$47,"(",$42,$48,$55,$56
  .byte  ")",$49,$4a,"=",$4d,$4b,$4f,$4e
  .byte  "?",$50,$4c,smin_c,":",$ff,sat_c,";"
  .byte  arrow_up_c,"*",$ff,shome_c,$ff,snull_c,spound_c,arrow_left_c
  .byte  "!",">",$ff,"\"",sspc_c,scommo_c,$51,srs_c
# else
  .byte  sdel_c,$0a,csr_left_c,f8_c,f2_c,f4_c,f6_c,csr_up_c
  .byte  $23,$57,$41,$24,$5a,$53,$45,$ff
  .byte  $25,$52,$44,$26,$43,$46,$54,$58
  .byte  $27,$59,$47,$28,$42,$48,$55,$56
  .byte  $29,$49,$4a,snull_c,$4d,$4b,$4f,$4e
  .byte  splus_c,$50,$4c,smin_c,$3e,$5b,sat_c,$3c
  .byte  spound_c,sstar_c,$5d,shome_c,$ff,sequ_c,sarrow_up_c,$3f
  .byte  $21,sarrow_left_c,$ff,$22,sspc_c,scommo_c,$51,srs_c
# endif ; DIN
# ifdef C128
  ; for C128 - for now exactly the same as unshifted
  .byte help_c, $38, $35, tab_c, $32, $34, $37, $31
  .byte esc_c, $2b, $2d, lf_c, cr_c, $36, $39, $33
  .byte alt_c, $30, $2e, csr_up_c, csr_down_c, csr_left_c, csr_right_c, noscrl_c
# endif ; C128

#ifdef C128
;;; ZEROpage: done 11
;;; ZEROpage: last 11
;done:			.buf 11			; map of done keys
;last:			.buf 11			; map as it was scanned the last time
#else
;;; ZEROpage: done 8
;;; ZEROpage: last 8
;done:			.buf 8			; map of done keys
;last:			.buf 8			; map as it was scanned the last time
#endif

;;; ZEROpage: keycode 1
;keycode:		.buf 1			; keycode (equal to $cb in C64 ROM)

ljoy0:			.byte $ff		; last state of joy0
ljoy1:			.byte $ff		; last state of joy1

flag:			.byte 0			; must be zero at startup
lst:			.byte $ff		; must be $ff at startup


		;; interrupt routine, that scans for keys

	-	lda  port_row
		cmp  port_row
		bne  -
		tax
		and  ljoy0
		sta  joy0result
		stx  ljoy0
	-	lda  port_col
		cmp  port_col
		bne  -
		tax
		and  ljoy1
		sta  joy1result
		stx  ljoy1
		rts

keyb_scan:
		ldx  #0
		lda altflags
		and #%11110000			; higher 4 keys are toggled
		sta altflags
#ifndef C128
		ldy  #$40
#else
		ldy  #(64+24)
#endif
		sty  keycode
		lda  #$ff
		sta  port_row			; make sure all lines are high  
#ifdef C128
		sta port_row2
		lda $01				; do CAPS check here
		and #%01000000
		bne +				; =1 - not pressed
		lda #keyb_caps
		ora altflags
		sta altflags
	+
#endif
		lda  port_row
		and  port_col
		cmp  #$ff				; joystick ??
		bne  --					; skip keysacn and go scanning joysticks

		lda  ljoy0
		sta  joy0result
		lda  ljoy1
		sta  joy1result
		lda  #$ff
		sta  ljoy0
		sta  ljoy1

		ldy  #0
		sty  port_row
#ifdef C128
		sty port_row2
#endif
	-	lda  port_col				; pressed keys ?
		cmp  port_col
		bne  -
		tax
		and  lst				; maybe at last scan ?
		cmp  #$ff
		beq  +					; no, then skip scanning
		stx  lst				; remember summary
		ldx  #0
		jmp  _keyscan_main


	+	bit  flag				; if flag is null, skip
		bmi  +
#ifndef C128
		ldy  #7
#else
		ldy  #10
#endif
		stx  flag				; else flag=null;

	-	txa
		sta  last,y
		lda  #0
		sta  done,y
		dey
		bpl  -					; clear maps

	+	rts						; return to system

_keyscan_main:
		lda  btab2i,x			; prepare for scanning one line
		sta  port_row

#ifdef C128
		lda btab2i2,x
		sta port_row2
#endif

	-	lda  port_row
		cmp  port_row
		bne  -
		cmp  btab2i,x
		beq  ++					; there are definetely no ghostkeys !

	-	lda  port_col			; take a closer look  
		cmp  port_col			; maybe there are ghostkeys !
		bne  -
		pha						; remember line-pattern
		eor  #$ff
		beq  +					; no cleared bit, then its ok

	-	asl  a
		bcc  -

		beq  +					; only one bit cleared, thats ok too.
								; skip scanning, if there are ghostkeys

		pla						; cleanup stack
		rts						; back to system

	+	pla
		jmp  ++					; some little artwork, to prevent reading
								; port_col a second time

	+ -	lda  port_col
		cmp  port_col
		bne  -
	+	pha						; remember line-pattern
		and  last,x				; add last time result
		pha						; remember this too
		and  done,x				; clear done keys, that are released
		eor  done,x
		sta  done,x
		pla
		ora  done,x				; remove old keys (that are pressed before)
		eor  #$ff
		beq  contnxtline		; no key left, then continue with next line

	-	lsr  a
		bcc  contnxtbit			; not pressed
		pha						; found pressed key
		lda  _keytab_normal,y
		cmp  #$f8				; some keys are treated more equal !!
		bcc  +
		eor  #$ff
		ora  altflags
		sta  altflags			; altflags contains pattern of shift,commo,..
		bit  flag				; (be sure, flag doesn't stay $ff)
		bpl  ++
		lda  #$40
		sta  flag				; if flag is null, set it to none
		jmp  ++

	+	sty  keycode			; remember key if it is not shift or commo
	+	pla
		beq  contnxtline

contnxtbit:		
		iny
		bne  -					; loop should not be left this way
		;; jsr  panic				; (just for debugging :)

contnxtline:	
		pla						; line is completed
		sta  last,x				; remember result of scan

		inx
#ifndef C128
		cpx  #8					; next line
#else
		cpx  #11
#endif
		beq  +					; all done !

		tya					; increase keycounter to next lines base
		and  #$f8
		clc
		adc  #8

		tay
		jmp  _keyscan_main

	+	lda  #$ff
		sta  port_row				; reset port_row
#ifdef C128
		sta port_row2
#endif
		lda  port_row
		and  port_col
		cmp  #$ff				; disturbed by joystick ?
		beq  +					; shit, then throw it all away
	-	rts

	+	lda  keycode				; look at what we've found
#ifndef C128
		cmp  #$40
#else
		cmp  #(64+24)
#endif
		bcs  -					; nothing ? So lets leave!
		sta  flag
		lsr  a
		lsr  a
		lsr  a
		tax
		lda  keycode
		and  #7
		tay
		lda  btab2i,y
		eor  #$ff
		ora  done,x				; mark this key, to ignore it next time
		sta  done,x

		; queue key into keybuffer
		;; machine-dependent code returns with keycode offset in X register
		ldx  keycode
