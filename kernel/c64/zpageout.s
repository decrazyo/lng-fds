		;; swap out zeropage
		
# ifndef ALWAYS_SZU
		ldy  #tsp_zpsize
		lda  (lk_tsp),y			; size of used zeropage
		beq  +
		tax
		dex

	-	lda  userzp,x			; if zpsize is zero 1 byte will be copied
_zpsl:	sta  .tsp_swap,x		; (doesn't matter, i think)
		dex
		bpl  -

	+	ldy  lk_ipid
		lda  lk_tstatus,y		; task status
		and  #tstatus_szu		; check if system zeropage is used
		beq  +					; not used, then skip

		lda  lk_tsp+1			; extra 8 zeropage bytes for
		sta  _szsl+2			; kernel or (shared-) library routines
		ldx  #7
	-	lda  syszp,x
_szsl:	sta  .tsp_syszp,x
		dex
		bpl  -
	+
# else
		;; always add 8 bytes szu to zeropage (syszp = userzp-8)
		ldy  #tsp_zpsize
		lda  (lk_tsp),y			; size of used zeropage
		clc
		adc  #7
		tax
	-	lda  userzp-8,x			; if zpsize is zero 1 byte will be copied
_zpsl:	sta  .tsp_swap-8,x		; (doesn't matter, i think)
		dex
		bpl  -
		ldy  lk_ipid
# endif
