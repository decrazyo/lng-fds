		;; keyboard interface

#include <config.h>
#include <system.h>
#include MACHINE_H
#include <keyboard.h>
#include <zp.h>
		
.global keyb_scan
.global keyb_stat
.global keyb_joy0
.global keyb_joy1

;;; ZEROpage: altflags 1
;altflags:		.buf 1			; altflags (equal to $28d in C64 ROM)

joy0result:		.byte $ff		; current state of joy0
joy1result:		.byte $ff		; current state of joy1

; Keycodes:
; $00-$7f - legal keycodes, passed directly to console driver
; $81-$84 - cursors
; $df     - previous console
; $e0-$ef - internal (machine-dependend) for toggling altflags through locktab
; $f0     - next console
; $f1-$f7 - goto console 1..7
; $f8-$ff - reserved (go console 8..15 currently)

		;; include machine-dependent code with _keytab_normal
		;; and _keytab_shift tables as well as locktab table

#ifdef PCAT_KEYB
# include "opt/pcat_keyboard.s"
#else
# include MACHINE(keyboard.s)
#endif

		;; machine-dependent code falls here (with keycode offset in X register)
		;; or jumps to _addkey with keycode in A
		;; queue key into keybuffer

_queue_key:
		lda  altflags
		tay
		and  #keyb_lshift | keyb_rshift
		bne  +++
		tya
		and  #keyb_ctrl
		bne  +
		tya
		and  #keyb_caps
		bne  ++
		lda  _keytab_normal,x
		jmp  _addkey

	+	lda  _keytab_normal,x	; keytab_ctrl ? (not yet)
		and  #$1f
		jmp  _addkey

	+	lda  _keytab_normal,x	; CAPS
		cmp  #$61		; if >='a'
		bcc  _addkey
		cmp  #$7b		; and =<'z'+1
		bcs  _addkey
		and  #%11011111		; lower->UPPER
		jmp  _addkey

	+	lda  _keytab_shift,x

		;; adds a keycode to the keyboard buffer
		;; (has to expand csr-movement to esacape codes)

_addkey:
		tax
		and #%11110000
		cmp #$e0				; keyboard 'lock' keys?
		bne +					; no - continue
		txa
		and #%00001111
		tay
		lda altflags
		eor locktab,y				; update flags information
		sta altflags
		rts					; and leave
	+	txa

		cmp  #$80
		bcc  +
		cmp  #$f0
		bcs  to_toggle_console
		cmp  #$df				; one special key...
		beq  ++

		cmp  #$85				; $81/$82/$83/$84 - csr codes
		bcs  +
		;; generate 3byte escape sequence
		pha
		lda  #$1b
		jsr  console_passkey			; (console_passkey is defined in fs_cons.s)
		lda  #$5b
		jsr  console_passkey
		pla
		eor  #$c0				; $8x becomes $4x
	+ 	jmp  console_passkey			; pass ascii code to console driver

	+	lda  #$88
		bne  +
to_toggle_console:
		and  #$07
	+	jmp  console_toggle			; call function of console driver
							; (console_toggle is defined is console.s)

		;; get state of keyboard
keyb_stat:
		lda  altflags				; bit2..0= CTRL,right_SHIFT,left_SHIFT
		rts

		;; get state of joystick 0
keyb_joy0:
		lda  joy0result
		eor  #$ff
		rts

		;; get state of joystick 1
keyb_joy1:
		lda  joy1result
		eor  #$ff
		rts
