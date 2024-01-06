		;; swap in stack

		ldx  #$ff
		txs
		ldy  #tsp_stsize
		lda  (lk_tsp),y
		tax
		eor  #$ff
		sta  _stll+1

_stll:		lda  .0,x
		pha
		dex
		bne  _stll
