;; utilities for bcd 

#include <kerrors.h>
#include <jumptab.h>

.global checkbcd

		;; checkbcd
		;; check if value is in bcd format
		;; < A=value
		;; > C=0 bcd, A=value
		;; > C=1 not bcd, A=errorcode
		;; X,Y are preserved

checkbcd: 
		pha
		and  #$0f
		cmp  #$0a    
		pla
		bcs  illbcd 
		cmp  #$a0  
		bcs  illbcd   
		rts
illbcd:         lda  #lerr_illarg
		jmp  lkf_catcherr


