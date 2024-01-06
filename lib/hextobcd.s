;; utilities for bcd 

#include <system.h>

.global hextobcd

		;; hextobcd
		;; convert hexadecimal value to bcd
		;; < A hex value
		;; > A bcd value
		;; X,Y,flags are preserved
		;; tmpzp+0 is changed

hextobcd:
		php
		txa
		pha
		ldx	#0
	-	sta	tmpzp
		sec
		sbc	#10
		bmi	+
		inx
		bne	-
	+	txa
		asl	a
		asl	a
		asl	a
		asl	a
		ora	tmpzp
		sta	tmpzp
		pla
		tax
		lda	tmpzp
		plp
		rts
