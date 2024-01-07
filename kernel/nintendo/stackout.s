		;; taskswitching
		;; swapping stack out


		lda  lk_tsp+1
		sta  _stsl+2			; self modifying code for extra performance
		sta  _zpsl+2

		;; swap out stack

		tsx						; remember stackpointer
		txa
		eor  #$ff
		ldy #tsp_stsize
		sta  (lk_tsp),y
		clc						; exact check for stackoverflow
		adc  #tsp_swap
		bcs  _stackoverflow
		ldy  #tsp_zpsize
		adc  (lk_tsp),y
		bcs  _stackoverflow
		inx

	-	pla						; stackpointer must be initialized with 0 (!)
_stsl:		sta  .0,x
		inx
		bne  -
