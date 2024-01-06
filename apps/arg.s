;   arg - Example for parsing commandline arguments with getopt
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
#include <jumptab.h>
#include <stdio.h>

#define SELFMOD $ff00

		.byte	>LNG_MAGIC, <LNG_MAGIC
		.byte	>LNG_VERSION, <LNG_VERSION
		.word	0

		;; print arguments as they are given by kernel

		ldx	#stdout
		bit	str_argc
		jsr	lkf_strout
		nop
		lda	userzp
		jsr	print_hex8
		nop
		lda	#$0a
		sec
		jsr	lkf_fputc
		nop

		bit	str_argv
		jsr	lkf_strout
		nop
		lda	userzp+1
		sta	+ +2		; selfmod
		ldy	userzp
		sty	count
	+ -	lda	SELFMOD
		bne	+
		dec	count
		lda	#"."
	+	inc	- +1
		sec
		jsr	lkf_fputc
		nop
		ldy	count
		bne	-
		lda	#$0a
		sec
		jsr	lkf_fputc
		nop

		;; parse arguments with getopt

		ldx	#0
		bit	optstring
	-	jsr	getopt
		cmp	#"a"
		bne	+
		sty	arga
		jmp	-
	+	cmp	#"b"
		bne	+
		sty	argb
		jmp	-
	+	cmp	#"c"
		bne	+
		sty	argc
		jmp	-
	+	cmp	#"x"
		bne	+
		inc	optx
		jmp	-
	+	cmp	#"y"
		bne	+
		inc	opty
		jmp	-
	+	cmp	#"z"
		bne	+
		inc	optz
		jmp	-
	+	cmp	#0
		beq	+
		; default ? or :
		jmp	-
	+	stx	optind
		sty	optarg

		;; print options

		ldx	#stdout
		lda	userzp+1
		sta	+ +2		; selfmod
		ldy	#0
	-	sty	count
		tya
		clc
		adc	#"a"
		sta	str_arg+3
		bit	str_arg
		jsr	lkf_strout
		nop
		ldy	count
		lda	arga,y
		beq	++
		sta	+ +1		; selfmod
	+	bit	SELFMOD
		jsr	lkf_strout
		nop
	+	lda	#$0a
		sec
		jsr	lkf_fputc
		nop
		ldy	count
		iny
		cpy	#3
		bne	-

		ldy	#0
	-	sty	count
		tya
		clc
		adc	#"x"
		sta	str_opt+3
		bit	str_opt
		jsr	lkf_strout
		nop
		ldy	count
		lda	optx,y
		jsr	print_hex8
		nop
		lda	#$0a
		sec
		jsr	lkf_fputc
		nop
		ldy	count
		iny
		cpy	#3
		bne	-

		;; print argc-optind arguments

		bit	str_optind
		jsr	lkf_strout
		nop
		lda	optind
		jsr	print_hex8
		nop
		lda	#$0a
		sec
		jsr	lkf_fputc
		nop

		bit	str_optarg
		jsr	lkf_strout
		nop
		lda	optarg
		jsr	print_hex8
		nop
		lda	#$0a
		sec
		jsr	lkf_fputc
		nop

		bit	str_argv
		jsr	lkf_strout
		nop
		lda	optarg
		sta	+ +1		; selfmod
		lda	userzp+1
		sta	+ +2		; selfmod
		ldy	userzp
		sty	count
		jmp	+++
	+ -	lda	SELFMOD
		bne	+
		dec	count
		lda	#"."
	+	inc	- +1
		sec
		jsr	lkf_fputc
		nop
		ldy	count
	+	cpy	optind
		bne	-
		lda	#$0a
		sec
		jsr	lkf_fputc
		nop

		;; free resources

		ldx	userzp+1
		jsr	lkf_free
		nop
		lda	#0
		jsr	lkf_set_zpsize
		nop

		lda	#$00
		rts


		.byte	$0c
		.word	+

optstring:	.text	"a:xb:yzc:",0
arga:		.byte	0
argb:		.byte	0
argc:		.byte	0
optx:		.byte	0
opty:		.byte	0
optz:		.byte	0
optind:		.byte	0
optarg:		.byte	0

count:		.byte	0
str_argc:	.text	"argc: ",0
str_argv:	.text	"argv: ",0
str_arg:	.text	"arg?: ",0
str_opt:	.text	"arg?: ",0
str_optind:	.text	"optind: ",0
str_optarg:	.text	"optarg: ",0

	+


