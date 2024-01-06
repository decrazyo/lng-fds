
		ldx  #<($10000 - 5)		; default values for 1MHz systems
		ldy  #>($10000 - 5)		; ( 1MHz -> 5 )
		stx  lkf_delay_calib_lo
		sty  lkf_delay_calib_hi
