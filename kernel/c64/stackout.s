		;; taskswitching without REU
		;; swapping stack out (not needed on C128)

		
		lda  lk_tsp+1
# ifndef MMU_STACK
		sta  _stsl+2			; self modifying code for extra performance
# endif
# ifndef HAVE_REU
		sta  _zpsl+2			; not needed if REU does zpage swap
# endif
		
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
# ifndef MMU_STACK
		inx
		
	-	pla						; stackpointer must be initialized with 0 (!)
_stsl:	sta  .0,x
		inx
		bne  -
# endif

