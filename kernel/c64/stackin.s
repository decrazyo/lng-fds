		;; swap in stack
		
# ifdef MMU_STACK
		ldy  #tsp_stsize
		lda  (lk_tsp),y
		eor #$ff
		tax
		txs
						;; THIS is real stack-swapping (always 7 cycles)
		lda lk_ipid			;; IPID=(0..31), stacks are in $00-$1f, effective
		sta MMU_P1L			;; address $10000-$11f00
# else
		;; not C128 or C128 with SCPU
		ldx  #$ff
		txs
		ldy  #tsp_stsize
		lda  (lk_tsp),y
		tax
		eor  #$ff
		sta  _stll+1
		
_stll:	lda  .0,x
		pha
		dex
		bne  _stll
# endif
