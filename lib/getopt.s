;   getopt - Parse command line options
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


#include <system.h>
#include <stdio.h>
#include <jumptab.h>

.global getopt

argc		equ	userzp+0	; number of arguments
argv		equ	userzp+1	; high address of arguments
arglow		equ	userzp+2	; allways 0, pointer with arghigh
arghigh		equ	userzp+3	; allways argv
optind		equ	userzp+4	; parsed arguments
optopt		equ	userzp+5	; option character
nextchar	equ	userzp+6	; next option

		.byte	$0c
		.word	+
str_opterr:	.text	"illegal option -- ",0
str_argerr:	.text	"option requires an argument -- ",0
	+

getoptinit:
		;; init zero page
		lda	#7
		jsr	lkf_set_zpsize	; X is not changed
		lda	#0
		ldy	argv
		sta	arglow
		sty	arghigh
		stx	optind
		sta	optopt
		;; bypass commandname
		ldy	#$ff
		jsr	getnextarg
		ldx	optind
		;; getopt again

		;; getopt
		;; parse one commandine argument and remember position
		;; < bit optstring after "jsr getopt" command
		;; < X=0 on first call, do not change X between calls
		;; > A=0 no more options, X=optind, Y=optarg
		;; > A=option character, X=optind, Y=optarg(optional)
		;; reads userzp+0,+1 changes userzp+2...+6

getopt:		stx	optind
		;; out of arguments ?
		cpx	argc
		bcs	endopt		; optind >= argc

		;; is this the first call ?
		cpx	#0
		beq	getoptinit

		;; find next option
		ldy	nextchar
		lda	(arglow),y
		bne	multiopt	; several options after one -
		iny
		sty	nextchar
		lda	(arglow),y
		cmp	#"-"
		bne	endopt		; not an option
		iny
		lda	(arglow),y
		beq	endopt		; a single - is not an option
		sty	nextchar
		cmp	#"-"
		bne	readopt		; first option after - 
		jsr	getnextarg	; find next arg after --
		inc	nextchar

endopt:		ldx	optind
		lda	nextchar
		pha
		;; free zero page
		lda	#2
		jsr	lkf_set_zpsize	; X is not changed
		;; no more options
		pla			; nextchar
		tay
		lda	#0
		rts

multiopt:	;; we allready read from a - option
		inx			; optint
		iny
		sty	nextchar
		lda	(arglow),y
		beq	getopt
		dex			; was not last option, undo inx

readopt:	;; search option in optstring
		sta	optopt
		jsr	lkf_get_bitadr
		stx	tmpzp
		sty	tmpzp+1
		ldy	#$ff
	-	iny
		bmi	opterr		; avoid infinite loop
		lda	(tmpzp),y
		beq	opterr		; end of optstring
		cmp	optopt
		bne	-
		iny
		lda	(tmpzp),y
		cli
		cmp	#":"
		beq	argoptfound
		;; option without argument
		ldx	optind
		lda	optopt
		ldy	#0		; optarg, not valid
		rts

opterr:		;; unknown option
		cli
		ldx	#stderr
		bit	str_opterr
		jsr	lkf_strout
		lda	optopt
		sec
		jsr	lkf_fputc
		lda	#$0a
		sec
		jsr	lkf_fputc
		ldx	optind
		lda	#"?"
		ldy	#0
		rts

argerr:		;; argument missing
		ldx	#stderr
		bit	str_argerr
		jsr	lkf_strout
		lda	optopt
		sec
		jsr	lkf_fputc
		lda	#$0a
		sec
		jsr	lkf_fputc
		ldx	optind
		lda	#":"
		ldy	#0
		rts


argoptfound:	;; option which needs an argument
		ldy	nextchar
		iny
		lda	(arglow),y
		bne	+
		ldx	optind
		inx
		cpx	argc
		bcs	argerr		; optind >= argc
		stx	optind
		iny
	+	tya
		pha			; optarg
		jsr	getnextarg
		ldx	optind
		pla			; optarg
		tay
		lda	optopt
		rts
		
getnextarg:	;; search next argument and store to nextchar
	-	iny
		lda	(arglow),y
		bne	-
		inc	optind
		sty	nextchar
		rts

