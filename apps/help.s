		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; simple help browser

		;; 20.2.2001 <br> tag added by Stefan A. Haubenthal
		;; (loosely based on xhtml)
	
#include <system.h>
#include <stdio.h>
#include <kerrors.h>
#include <ident.h>
		
		start_of_code equ $1000

		.org start_of_code

		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION,	<LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

;;; supported XHTML tags
#define TAG_TITLE  1
#define TAG_IMG    2
#define TAG_HR     3
#define TAG_P      4
#define TAG_A      5
#define TAG_B      6
#define TAG_BR     7

#define LINELENMAX    80			; (change later)

		;; (task is entered here)
		
		jsr  parse_commandline
		
		ldx  userzp+1			; address of commandline (hi byte)
		jsr  lkf_free			; free used memory
								; (commandline not needed any more)

		lda  #7
		jsr  lkf_set_zpsize

		ldy  #tsp_termwx
		lda  (lk_tsp),y			; get terminal width
		cmp  #LINELENMAX+1
		bcc  +
		lda  #LINELENMAX		; (upper limit)
	+	sta  linelen
		
		jmp  main_code
		
		;; print howto message and terminate with error (code 1)
		
howto:	ldx  #stdout
		bit  txt_howto
		jsr  lkf_strout
		lda  #1
		jmp  lkf_suicide

		;; commandline
		;;  first argument is the command name itself
		;;  so userzp (argc = argument count) is at least 1
		
parse_commandline:
		;; check for correct number of arguments
		lda  userzp				; (number of given arguments)
		cmp  #1
		beq  show_man_man

		cmp  #2					; need exactly one argument
		bne  howto				; (if argc != 2 goto howto)

		;; get pointer to first option (skip command name)

		ldy  #0
		sty  userzp
	-	iny
		lda  (userzp),y
		bne  -
		iny

		;; now (userzp),y points to first char of first option string
		sty  userzp+2
	-	iny
		lda  (userzp),y
		bne  -
		ldx  #0
	-	lda  default_file+4,x	; (points to ".html",$00)
		sta  (userzp),y
		iny
		inx
		cpx  #6
		bne  -
		lda  userzp+2
		ldy  userzp+1
	-	ldx  #fmode_ro
		jsr  fopen				; open file
		nop
		stx  instream
		rts

		bit  default_file
show_man_man:
		lda  #<default_file
		ldy  show_man_man-1		; #>default_file
		jmp  -
		
		;; main programm code
main_code:


nline:
		lda  #0
		sta  userzp+5			; (length of visible line)
		sta  userzp+6			; (length of current line)

		;; get next item
		
nchar:	jsr  get_schar
		bcs  got_tag
				
		;; got printable char
		ldy  userzp+6
		sta  linebuf,y
		iny
		sty  userzp+6
		cmp  #64
		bcs  print_char
		
		;; may break the line right after this char (update screen)
		jsr  update_line
		cpy  linelen
		bcc  nchar
		bcs  break_line

break_line2:
		lda  #$0a
		sec
		ldx  #stdout
		jsr  fputc

break_line:
		lda  #$0a
		sec
		ldx  #stdout
		jsr  fputc
		ldy  #$80
		sty  spaceflag
		jmp  nline
		
update_line:
		ldy  userzp+5
	-	cpy  userzp+6
		bcs  +
		lda  linebuf,y
		sec
		ldx  #stdout
		jsr  fputc
		iny
		bne  -
	+	sty  userzp+5
		rts

print_char:
		cpy  linelen
		bcc  nchar
		;; line got too long, insert newline
		lda  #$0a
		sec
		ldx  #stdout
		jsr  fputc
		
		ldx  #0
		ldy  userzp+5
	-	lda  linebuf,y
		sta  linebuf,x
		inx
		iny
		cpy  userzp+6
		bcc  -
		stx  userzp+6
		lda  #0
		sta  userzp+5
		jmp  nchar

got_tag:		
		cmp  #TAG_P
		beq  got_ptag
		cmp  #TAG_HR
		beq  got_hrtag
		cmp  #TAG_TITLE
		beq  got_titletag
		cmp  #TAG_BR
		beq  got_brtag
	-	jmp  nchar
		
		lda  #0					; (error code, 0 for "no error")
		rts						; return with no error
		
		;; paragraph
got_ptag:
		tya
		bne  -
		jsr  update_line
		jmp  break_line2
		
		;; title
got_titletag:
		tya
		beq  -					; (do <hr> on </title>)
		bne  +

		;; horizontal ruler
got_hrtag:
		tya
		bne  -
	+	jsr  update_line
		lda  #$0a
		sec
		ldx  #stdout
		jsr  fputc		
		ldy  linelen
	-	lda  #"-"
		sec
		ldx  #stdout
		jsr  fputc
		dey
		bne  -
		jmp  break_line

		;; break
got_brtag:
		tya
		bne  -
		jsr  update_line
		jmp  break_line
		
build_line:
		
getc:	sec
		ldx  instream
		jsr  fgetc
		bcs  +
		rts

	+	cmp  #lerr_eof
		bne  +
		lda  #$0a
		sec
		ldx  #stdout
		jsr  fputc
end:	lda  #0
	+	jmp  lkf_suicide
		
get_schar:
		jsr  getc
		cmp  #"<"
		beq  gettag
		cmp  #33
		bcc  isspace
		ldy  #0
		sty  spaceflag
		clc
		rts

isspace:
		bit  spaceflag
		bmi  get_schar
		ldy  #$80
		sty  spaceflag
		lda  #32
		clc
		rts

gettag:
		ldy  #0
	-	jsr  getc
		cmp  #">"
		beq  endtag
		sta  currenttag,y
		iny
		bne  -
		;; tag too long
	-	jsr  getc
		cmp  #">"
		bne  -
		dey
endtag:	lda  #0
		sta  currenttag,y

		;; which type of tag is it ?

		ldy  #0
		lda  currenttag,y
		cmp  #$2f				; "/"
		bne  +
		iny
	+	sty  userzp
		
		ldx  #0
		stx  userzp+1
		
sloop:	inc  userzp+1
		ldy  userzp
		
	-	lda  currenttag,y
		beq  might
		cmp  #32
		beq  might
		eor  taglist,x
		and  #$bf
		bne  isnot
		inx
		iny
		bne  -					; (always jump)
		
isnot:	lda  taglist,x
		beq  +
	-	inx
		bne  isnot				; (always jump)
		
	+	inx
		lda  taglist,x
		bne  sloop
		;; is unknown tag (just ignore)
		jmp  get_schar

might:	lda  taglist,x
		bne  -					; isnot
		;; i know this tag
		ldy  userzp				; 0=begin, 1=end
		lda  userzp+1			; tag code (from taglist)
	-	sec
		rts
		
		;; hunt for attribute for current tag
		;; x=offset in attrlist
hunt_attribute:
		ldy  #0
		
	-	lda  currenttag,y
		beq  --					; jump if tag wasn't found
		eor  attrlist,x
		and  #$bf
		beq  might2
min:	iny
		bne  -					; (always jump)

might2:	stx  userzp
		
	-	inx
		iny
		lda  attrlist,x
		beq  found
		eor  currenttag,y
		and  #$bf
		beq  -

		txa
		ldx  userzp
		sec
		sbc  userzp
		sta  userzp
		tya		
		sbc  userzp				; (c=1)
		tay
		jmp  min

found:	sty  userzp
		lda  #34
	-	cmp  currenttag,y
		beq  +
		iny
		bne  -
		;; error reading attribute value
		sec
		rts
		
	+	lda  #0
		sta  currenttag,y
		ldy  userzp
		clc						; return with Y=offset to value 
		rts						; (zero terminated string)
		
		RELO_END ; no more code to relocate

		ident(help,2.0)
instream:		.byte 0
spaceflag:		.byte 0
				
taglist:
		.text "title",0			; 1 - title text
		.text "img",0			; 2 - embedded image
		.text "hr",0			; 3 - horizontal ruler
		.text "p",0				; 4 - paragraph
		.text "a",0				; 5 - hyperlink
		.text "b",0				; 6 - bold
		.text "br",0			; 7 - break
		.byte 0

attrlist:
		.text "href=",34,0		; <a href="..."> (destination of hyperlink)
		.text "alt=",34,0		; <img src="..." alt="text"> (image descript.)
		.byte 0

default_file:
		.text "help.html",0
		
		;; help text to print on error
		
txt_howto:
		.text "Usage: man [topic]",$0a
		.text "  print help on given command or topic",$0a
		.text "  (prints a file named ",34,"topic.html",34,")",$0a,0

linelen:		.buf 1
linebuf:		.buf LINELENMAX
currenttag:		.buf 128
end_of_code:
