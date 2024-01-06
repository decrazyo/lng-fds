
		;; reload stack using REU

		ldy  #tsp_stsize
		lda  (lk_tsp),y
		sta  REU_translen
		eor  #$ff
		tax
		txs
		inx
		stx  REU_intbase
		lda  lk_tsp+1
		sta  REU_intbase+1
		lda  #REUcmd_int2reu|REUcmd_load|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; copy TSP-stack into REU

		lda  #1
		sta  REU_intbase+1
		lda  #REUcmd_reu2int|REUcmd_load|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; copy TSP-stack (from REU) into real stack
