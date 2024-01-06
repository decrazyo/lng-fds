
		;; taskswitching with REU
# include <reu.h>
		
# ifndef ALWAYS_SZU
#  msg REU based taskswitcher assumes ALWAYS_SZU set
# endif


		;; REU stack swapping

		tsx						; remember stackpointer
		txa
		eor  #$ff
		sta  REU_translen
		ldy	 #tsp_stsize
		sta  (lk_tsp),y
		clc						; exact check for stackoverflow
		adc  #tsp_swap
		bcs  _stackoverflow
		ldy  #tsp_zpsize
		adc  (lk_tsp),y
		bcs  _stackoverflow
		
		inx
		stx  REU_intbase
		lda  #1
		sta  REU_intbase+1
		lda  #0
		sta  REU_translen+1
		sta  REU_control
		sta  REU_reubase
		sta  REU_reubase+1
		sta  REU_reubase+2
		lda  #REUcmd_int2reu|REUcmd_load|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; copy stack to REU

		lda  lk_tsp+1
		sta  REU_intbase+1
		lda  #REUcmd_reu2int|REUcmd_load|REUcmd_noff00|REUcmd_execute
		sta  REU_command		; copy stack from REU into tsp
