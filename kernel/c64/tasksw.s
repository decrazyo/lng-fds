		;; For emacs: -*- MODE: asm; tab-width: 4; -*-

		;; add CPU time spent to task's time
		;;  5 bytes -> overflow after 12 days, 22 hours, 4 minutes, ...

		lda  lk_ipid
		bmi  _idle				; skip next, if we're idle

		lda  #0
		sta  CIA1_CRB           ; stop timer2 of CIA1
		ldy  #tsp_time
		sec
		lda  (lk_tsp),y
		sbc  CIA1_TBLO
		sta  (lk_tsp),y         ; add to time0
		iny
		lda  (lk_tsp),y
		sbc  CIA1_TBHI
		sta  (lk_tsp),y         ; add to time1
		ldx  #3
	-	bcc  +
		iny
		lda  (lk_tsp),y
		adc  #0
		sta  (lk_tsp),y         ; increase time2,3,4
		dex
		bne  -

	+	dec  lk_timer
		beq  do_taskswitch		; end of time slice, so switch

_checktimer:
		;; check the timer
		lda  CIA1_ICR
		bpl  ++					; no timer IRQ, then return to user task
		and  #4
		bne  _irq_alertptr		; is TOD-alarm !

		inc  lk_systic			; system ticks (overflow after 72.8h)
		bne  +
		inc  lk_systic+1		; (nearly counts seconds/4)
		bne  +
		inc  lk_systic+2
	+	inc  lk_sleepcnt		; time to wakeup a sleeping task ?
		bne  _irq_jobptr		; (not jet)
		inc  lk_sleepcnt+1
		bne  _irq_jobptr		; (not jet)
		jsr  _wakeup			; Yes!

_irq_jobptr:
		bit  $ffff				; placeholder for up to 3 IRQ routines
		bit  $ffff				; all called once every 1/64 second
		bit  $ffff

	- +	lda  #$11
		sta  CIA1_CRB			; restart timer2 of CIA1
		pla
		SETMEMCONF				; switch to task's memory configuration
		pla
		tay
		pla
		tax
		pla
		rti

_irq_alertptr:
		bit  $ffff				; placeholder for 1 alarm handler
		lda  #4
		sta  CIA1_ICR			; disable TOD interrupt
		jmp  -

;_idle is here