;; utilities for bcd 

#include <system.h>

.global bcdtohex

		;; bcdtohex
		;; convert bcd value to hexadecimal
		;; < A bcd value
		;; > A hex value
		;; X,Y,flags are preserved
		;; tmpzp+0,+1 are changed
		
bcdtohex:
		php
		cld
		sei
		pha
		and  #$0f
		sta  tmpzp
		pla
		and  #$f0
		lsr  a
		sta  tmpzp+1
		lsr  a
		lsr  a       ; carry is cleared, because bit 0 is 0
		adc  tmpzp
		adc  tmpzp+1
		plp
		rts

