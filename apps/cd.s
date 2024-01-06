; cd directory
;

; v1.0	(c) 2002 Maciej Witkowiak <ytm@elysium.pl>

#include <system.h>
#include <kerrors.h>
#include <stdio.h>
#include <cstyle.h>

		start_of_code equ $1000

		.org start_of_code

		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		;; process cmd lines options

		lda userzp
		cmp #2			; need only one argument
		bne HowTo

		;; get pointer to first option (skip command name)
		ldy #0
		sty userzp

	-	inc userzp
		lda (userzp),y
		bne -
		inc userzp

		lda userzp
		ldy userzp+1
		ldx #fcmd_chdir
		jmp fcmd

HowTo:		ldx  #stderr
		bit  howto_txt
		jsr  lkf_strout
		exit(1)

		RELO_END				; End Of Code - marker !

howto_txt:
		.text "Usage: cd directory"
		.byte $0a,$00

end_of_code:
