;// addresses that can be altered (eg. incremented) for debugging

#ifndef _DEBUG_H
#define _DEBUG_H

#include <config.h>
#include MACHINE_H

;// "visible" addresses that maybe used for debugging

#ifdef C64
# define debug1       VIC_BC    ; foreground color
# define debug2       VIC_GC0   ; background color
# define debug3       $400      ; upper left corner of the screen
#endif

#ifdef C128
;// these will be seen only on 40 column screen
# define debug1       VIC_BC    ; foreground color
# define debug2       VIC_GC0   ; background color
# define debug3       $400      ; upper left corner of the screen
#endif

#ifdef ATARI
# define debug1       GTIA_COLBK    ; foreground color
# define debug2       GTIA_COLPF1   ; background color
# define debug3       $420  	    ; upper left corner of the screen
#endif

#ifdef DEBUG
# begindef db(textstring)
	php
	pha
	txa
	pha
	tya
	pha
	ldx  #stdout
	bit  db%%next,push,next,pcur%%
	jsr  lkf_strout
	nop
	jmp  db%%ptop%%
	.byte $0c
	.word db%%ptop%%
db%%pcur%%:
	.text "textstring"
	.byte $0a,$00
db%%ptop,pop%%:		
	pla
	tay
	pla
	tax
	pla
	plp
# enddef
#else
# define db(text)
#endif

#endif
