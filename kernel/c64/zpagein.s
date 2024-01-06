		;; reload without REU
		
		sta  _zpll+2
# ifndef MMU_STACK
		sta  _stll+2			; not needed for C128 MMU stack swap-in
# endif

		;; swap in zeropage
		
# ifndef ALWAYS_SZU
		lda  lk_tstatus,y		; task status
		and  #tstatus_szu		; check if system zeropage is used
		beq  +					; not used, then skip

		lda  lk_tsp+1			; extra 8 zeropage bytes for
		sta  _szll+2			; kernel or (shared-) library routines
		ldx  #7
_szll:	lda  .tsp_syszp,x
		sta  syszp,x
		dex
		bpl  _szll
		
	+	ldy  #tsp_zpsize		; size of zeropage
		lda  (lk_tsp),y
		beq  +
		tax
		dex
		
_zpll:  lda  .tsp_swap,x
		sta  userzp,x
		dex
		bpl  _zpll
	+
# else
		ldy  #tsp_zpsize		; size of zeropage
		lda  (lk_tsp),y
		clc
		adc  #7
		tax
_zpll:  lda  .tsp_swap-8,x		; (alwasy_szu makes this loop 96us longer)
		sta  userzp-8,x
		dex
		bpl  _zpll		
# endif
