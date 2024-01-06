		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; simple console driver

#include <config.h>
#include MACHINE_H

#define BEEP_FREQ $3000		; beep frequency

.global	console_toggle

		;; function: beep
		;; no parameters
		;; do beep (the same as in C128 rom)
		;; changes: A
.global beep

beep:
#ifdef HAVE_SID
		lda #%00011001
		sta SID_VOL		; set volume
		lda #$09		; attack 2ms, decay 750ms
		sta SID_ATDCY1
		lda #$00		; sustain 2ms, release 6ms
		sta SID_SUREL1
		lda #<BEEP_FREQ
		sta SID_FRELO1
		lda #>BEEP_FREQ
		sta SID_FREHI1
		lda #%00100000		; turn off any previous sound on channel #1
		sta SID_VCREG1
		lda #%00100001		; turn on sound
		sta SID_VCREG1
#endif
		rts

		;; function: printk
		;; < A=char
		;; print (kernel) messages to console directly all registers
		;; (A, X and Y) are unchanged !!
		;; calls: cons_out
.global printk

printk:
		pha
		sta  dirty
		txa
		pha
		tya
		pha
dirty equ *+1
		lda  #0					; (self modifying code)
		ldx  #0		
		jsr  cons_out
		pla
		tay
		pla
		tax
		pla
		rts

		;; function: cons_out
		;; < A=char, X=number of console
		;; print character to console
		;; calls: locktsw
		;; calls: untocktsw
		;; changes:	tmpzp(0,1)
.global cons_out

#ifdef VDC_CONSOLE
# include "opt/vdc_console.s"
#endif
		;; default is to use VIC for console output
#ifdef VIC_CONSOLE
# ifdef MULTIPLE_CONSOLES

		;; variable reflects which console currently is visible to
		;; the user (keyboad input will go there!) (in zp.h!)
;.global cons_visible

		;; console_single is the old (working) version of the
		;; console driver (just to have something to fall back)
#  include "opt/vic_console.s"
# else
#  include "opt/vic_console_single.s"
# endif
#endif

#ifdef VIC_CONSOLE80
# include "opt/vic_console80.s"
#endif

#ifdef ANTIC_CONSOLE
# include "opt/antic_console.s"
#endif
