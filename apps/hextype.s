;   hextype - Print stdin to stdout as hexadecimal digits and ascii
;   Copyright (C) 2000 Alexander Bluhm
;
;   This program is free software; you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation; either version 2 of the License, or
;   (at your option) any later version.
;
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License
;   along with this program; if not, write to the Free Software
;   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
;

; Alexander Bluhm <mam96ehy@studserv.uni-leipzig.de>

#include <stdio.h>

start_of_code:
		.byte >LNG_MAGIC, <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.word 0

		jmp	initialize

;;; main data---------------------------------------------------------------

		RELO_JMP(+)

count:		.byte	0,0
data:		.buf	8
cnt:		.byte	0

	+

;;; main -------------------------------------------------------------------

#begindef HEX 
		jsr	print_hex8
		nop
#enddef
#begindef CHAR 
		ldx	#stdout
		sec
		jsr	lkf_fputc
		nop
#enddef
#begindef SPACE
		lda	#$20
		CHAR
#enddef
#begindef LINE
		lda	#$0a
		CHAR
#enddef

error_in:
		beq	+
		LINE
		lda	count
		and	#$07
		tay
		lda	data,y		; errorcode
	+	jmp	lkf_suicide

main:

main_loop:
		;; read data
		ldx	#stdin
		sec
		jsr	lkf_fgetc
		tax
		lda	count
		and	#$07
		tay
		txa
		sta	data,y
		tya			; restore flags
		bcs	error_in

		;; print address every 8 bytes
		bne	+
		lda	count+1
		HEX
		lda	count
		HEX
		SPACE
		SPACE
	+

		;; print hex byte
		lda	count
		and	#$07
		tay
		lda	data,y
		HEX
		SPACE

		;; increment count
		inc	count
		bne	+
		inc	count+1
	+

		;; middle or end of line
		lda	count
		and	#$03
		bne	main_loop
		SPACE
		lda	count
		and	#$07
		bne	main_loop

		;; print ascii
		ldy	#0
	-	sty	cnt
		ldx	#"."
		lda	data,y
		bmi	+
		cmp	#$20
		bcc	+
		cmp	#$7f
		beq	+
		tax
	+	txa
		CHAR
		ldy	cnt
		iny
		cpy	#8
		bcc	-
		LINE

		jmp	main_loop
		
end_of_permanent_code:
;;; initialisation data ----------------------------------------------------

		RELO_JMP(+)

howto_txt:      .text   "usage: hextype",$0a,0

	+

;;; initialisation ---------------------------------------------------------
		
initialize:
		;; parse commandline
		ldx     userzp
		cpx     #1
		beq     normal_mode
		
HowTo:          ldx     #stderr
		bit     howto_txt
		jsr     lkf_strout
		lda     #1
		rts
		
normal_mode:
		;; free memory used for commandline arguments
		ldx     userzp+1
		jsr     lkf_free
		nop

		;; need no userzp
		lda     #0
		jsr     lkf_set_zpsize
		nop

		jmp     main

end_of_code:
