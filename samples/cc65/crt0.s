;
; Startup code for cc65 (LUnix)
;
; By Groepaz/Hitmen <groepaz@gmx.net> and Ullrich von Bassewitz <uz@cc65.org>
;
; This must be the *first* file on the linker command line
;

	.export		_exit
	.import		initlib, donelib
	.import	     	push0, _main, zerobss

	;;.import		__RAM_START__, __RAM_SIZE__	; Linker generated
                

	.export main

        .importzp       sp

		.include "../../include/jumptab.ca65.h"

; ------------------------------------------------------------------------
; Create an empty LOWCODE segment to avoid linker warnings

;.segment        "LOWCODE"

; ------------------------------------------------------------------------
; Place the startup code in a special segment.

.segment       	"CODE"

main:

		; tell the system how many zeropage
		; bytes we need
		;set_zeropage_size(14)
		lda  #40
		jsr  lkf_set_zpsize


; Set argument stack ptr
	lda #<(stackspace+512)
	sta	sp
	lda	#>(stackspace+512)
   	sta	sp+1

; Clear the BSS data

;;	jsr	zerobss

; Call module constructors

;;	jsr	initlib

; Pass an empty command line

   	jsr push0		; argc
	jsr	push0		; argv

	ldy	#4    		; Argument size

	; call the users code
	jsr _main

; Call module destructors. This is also the _exit entry.

_exit:

	; Run module destructors
;;  	jsr	donelib

; Back to LUnix - suicide

	rts

; ------------------------------------------------------------------------
; Data

.bss
stackspace:
		.res 1024
stacktop:

