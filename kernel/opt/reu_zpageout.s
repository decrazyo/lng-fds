
# include <reu.h>
		
# ifndef ALWAYS_SZU
#  msg REU based taskswitcher assumes ALWAYS_SZU set
# endif

		;; swapping in zpage from REU
		;; (are all registers initialized if reustackout wasn't used?)

		ldy  #tsp_zpsize
		lda  (lk_tsp),y			; size of used zeropage
		clc
		adc  #8
		sta  REU_translen		; (translen+1 is still 0)
#ifdef C128
		;; on C128 REU is still uninitialized (no reustackout used)
		ldx  #0
		stx  REU_translen+1
		stx  REU_reubase
		stx  REU_reubase+1
		stx  REU_reubase+2
		stx  REU_control
#endif
		lda  #userzp-8			; (equal to #syszp)
		sta  REU_intbase
		lda  #0
		sta  REU_intbase+1
		lda  #REUcmd_int2reu|REUcmd_load|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; copy zeropage to REU

		lda  #tsp_swap-8
		sta  REU_intbase
		lda  lk_tsp+1
		sta  REU_intbase+1
		lda  #REUcmd_reu2int|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; copy zeropage from REU into tsp
				
		ldy  lk_ipid
