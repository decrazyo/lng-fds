
		;; reload environment using REU

		;; reload zpage

		sta  REU_intbase+1		; (A is [lk_tsp+1])
		lda  #tsp_swap-8
		sta  REU_intbase
		ldy  #tsp_zpsize		; size of zeropage
		lda  (lk_tsp),y
		clc
		adc  #8
		sta  REU_translen
		ldx  #0
		stx  REU_translen+1
		stx  REU_reubase
		stx  REU_reubase+1
		stx  REU_reubase+2
		stx  REU_control
		lda  #REUcmd_int2reu|REUcmd_load|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; copy TSP-zeropage into REU
		
		lda  #userzp-8			; (equal to #syszp)
		sta  REU_intbase
		stx  REU_intbase+1
		lda  #REUcmd_reu2int|REUcmd_load|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; copy TSP-zp (from REU) into real zeropage
