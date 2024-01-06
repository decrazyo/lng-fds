		;; calibrate delay loop (only for startup)

		;; should be the shortest possible delay available on all
		;; 6502-machines (i assume they all run at least at 1MHz)
		;; so the shortest delay would be JSR+RTS = 12탎
		;; the smallest (worst case) step we can do is INX+BNE = 5탎
		;; do get a accuracy of 90% in every case the time should be
		;; at least 10*5탎 = 50탎

		;; lets implement "delay_50us"

		;; works for the 50Hzand 60Hz version of the C64/C128
		;; use TOD of CIA1! (frequency range is 260kHz - 65MHz)

		sprintk(begin_txt)
		sei
		lda  #%11111111
		sta  lkf_delay_calib_hi		; smallest delaytime (26 CPU cycles)
		lda  #%00000001
		sta  tmpzp+7
		lda  #%00000000
		sta  lkf_delay_calib_lo
		sta  tmpzp+6

		;; first calibrate delay_calib to 5ms

		lda  CIA1_TOD10
		sta  CIA1_TOD10			; make sure the clock is running

loop1:		cmp  CIA1_TOD10
		beq  loop1			; wait for a change
		lda  CIA1_TOD10
		pha
		ldy  #20
	-	jsr  lkf_delay_50us			; 5ms!
		dey
		bne  -
		pla
		cmp  CIA1_TOD10
		bne  fine_tune
		jsr  toggle
		asl  tmpzp+6
		rol  tmpzp+7
		lda  CIA1_TOD10
		jmp  loop1

; this is included here
toggle:
		lda  lkf_delay_calib_lo
		eor  tmpzp+6
		sta  lkf_delay_calib_lo
		lda  lkf_delay_calib_hi
		eor  tmpzp+7
		sta  lkf_delay_calib_hi
		rts
;
fine_tune:
		lsr  tmpzp+7
		ror  tmpzp+6
		ldy  #8					; accuracy in bits
		sty  tmpzp+2

loop2:		dec  tmpzp+2
		beq  +
		lsr  tmpzp+7
		ror  tmpzp+6
		jsr  toggle
		lda  CIA1_TOD10
	-	cmp  CIA1_TOD10
		beq  -					; wait for a change
		lda  CIA1_TOD10
		pha
		ldy  #20
	-	jsr  lkf_delay_50us			; 5ms!
		dey
		bne  -
		pla
		cmp  CIA1_TOD10
		bne  loop2
		jsr  toggle
		jmp  loop2

		;; calculate number of loops needed for 5ms delay

	+	cli
		lda  lkf_delay_calib_lo
		eor  #$ff
		sta  lkf_delay_calib_lo
		lda  lkf_delay_calib_hi
		eor  #$ff
		sta  lkf_delay_calib_hi
