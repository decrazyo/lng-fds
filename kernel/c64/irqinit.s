		;; init system interrupt

		lda  lk_archtype
		and  #larchf_pal
		bne  +
		
		ldx  #<15979			; NTSC (1022727kHz)
		ldy  #>15979
		bne  ++
		
	+	ldx  #<15394			; PAL (985248kHz)  1/64s
		ldy  #>15394
		
	+	stx  CIA1_TALO			; CIA1 timer 1
		sty  CIA1_TAHI
		lda  #$ff
		sta  CIA1_TBLO			; CIA1 timer 2
		sta  CIA1_TBHI
		lda  #%10010001			; 50Hz, forced reloading, run
		sta  CIA1_CRA		
		lda  #%10000001
		sta  CIA1_ICR			; enable interrupts

		;; init internal clock

		lda  CIA2_CRA
		ora  #%10000000			; 50Hz (must be fixed for NTSC version)
		sta  CIA2_CRA
		lda  CIA2_CRB
		and  %011111111			; set time not alarm
		sta  CIA2_CRB
		lda  #$00
		sta  CIA2_TODHR			; reset clock (to 00:00.0am)
		sta  CIA2_TODMIN		; (used by "uptime")
		sta  CIA2_TODSEC
		sta  CIA2_TOD10

		;; try to determine the power frequency (50 or 60 Hz)
		ldx  #<46015
		ldy  #>45015
		stx  CIA2_TALO
		sty  CIA2_TAHI
		lda  CIA2_CRA
		and  #%11000000
		ora  #%00011001			; (forced reloading, run, one-shot)
		tay

		ldx  CIA2_TOD10
	-	cpx  CIA2_TOD10
		beq  -
		ldx  CIA2_TOD10
		
		;; wait for around 1/11s
		lda  #%00000001
		sty  CIA2_CRA			; forced reloading, run, one-shot
		bit  CIA2_ICR
	-	bit  CIA2_ICR
		beq  -
		sty  CIA2_CRA			; forced reloading, run, one-shot
	-	bit  CIA2_ICR
		beq  -
		
		;; if TOD10 changed we are on a 60Hz power net
		cpx  CIA2_TOD10
		beq  +					; (50Hz)
		lda  CIA1_CRA
		and  #%01111111			; 60Hz
		sta  CIA1_CRA
		lda  CIA2_CRA
		and  #%01111111			; 60Hz
		sta  CIA2_CRA

	+