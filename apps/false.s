; false
;	Return false

; v1.0	(c) 2001 Paul Daniels <paul_d@sourceforge>
;	Initial release

; Usage: false

;		return 1

#include <system.h>

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		lda #1
		rts

		.byte $02		; End Of Code - marker !

end_of_code:
