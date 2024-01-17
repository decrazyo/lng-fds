
; we can use the APU frame counter to generate IRQs every 1/60 second.
; there may be other ways to abuse the APU as a timer.
; the FDS RAM adapter has a 16-bit timer that we can use too

		lda  lk_ipid
		bmi  _idle ; skip next, if we're idle

; the atari port doesn't seem to think this code matters so we'll ignore it for now.
; TODO: implement this.
;		lda  #0
;		sta  CIA1_CRB ; stop timer2 of CIA1
;		ldy  #tsp_time
;		sec
;		lda  (lk_tsp),y
;		sbc  CIA1_TBLO
;		sta  (lk_tsp),y ; add to time0
;		iny
;		lda  (lk_tsp),y
;		sbc  CIA1_TBHI
;		sta  (lk_tsp),y ; add to time1
;		ldx  #3
;	-	bcc  +
;		iny
;		lda  (lk_tsp),y
;		adc  #0
;		sta  (lk_tsp),y ; increase time2,3,4
;		dex
;		bne  -

	+	dec  lk_timer
		beq  do_taskswitch ; end of time slice, so switch


_checktimer:
#ifdef APU_AS_TIMER
		; we're using the APU frame counter as our timer.
		lda APU_STATUS
		; check if the IRQ was caused by the APU frame counter.
		and #%01000000
#else
		; no longer using the APU frame counter as our timer.
		; switched to using an actual timer for better accuracy.
		lda FDS_DISK_STATUS ; reading the disk status register will acknowledge the IRQ.
		; check if the IRQ was caused by the timer.
		and #FDS_DISK_STATUS_D
#endif
		beq _irq_end ; branch if the IRQ was not from the expected source.

		inc  lk_systic ; system ticks (overflow after 72.8h)
		bne  +
		inc  lk_systic+1 ; (nearly counts seconds/4)
		bne  +
		inc  lk_systic+2
	+	inc  lk_sleepcnt ; time to wakeup a sleeping task ?
		bne  _irq_jobptr ; (not jet)
		inc  lk_sleepcnt+1
		bne  _irq_jobptr ; (not jet)
		jsr  _wakeup ; Yes!

_irq_jobptr:
		bit  $ffff ; placeholder for up to 3 IRQ routines
		bit  $ffff ; all called once every 1/64 second
		bit  $ffff

; return to user task.
_irq_end:
		pla
		SETMEMCONF ; switch to task's memory configuration
		pla
		tay
		pla
		tax
		pla
		rti

; TODO: try to implement a real time clock and time of day alarm.
_irq_alertptr:
		bit  $ffff ; placeholder for 1 alarm handler
		jmp  _irq_end
