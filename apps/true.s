; true
;	Return true

; v1.0	(c) 2001 Paul Daniels <pauld_sourceforge.net>
;	Initial release

#include <system.h>

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		lda #0
		rts

		.byte $02		; End Of Code - marker !

end_of_code:
