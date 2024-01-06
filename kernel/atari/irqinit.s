; depended on pal/ntsc do:
; - init 1/64s (64Hz) IRQ timers interrupt
; - init internal TOD timer (driven with NMI VBLNK call)
; - init timer 2 (joined 3+4) to count time spent in task, reload on stop (in tasksw.s)
;   (however it fucks up because the value can't be read from there :(

		;; init system interrupt

		lda #%00000011
		sta POKEY_SKCTL			; reset serial, init keyboard scan

		lda #0
		sta POKEY_AUDC1
		sta POKEY_AUDC2

		lda #%00010000			; 64KHz base clock, join timer 1&2
		sta POKEY_AUDCTL
		; timer 2 counts timer 1 shots and timer 1 is on 64KHz clock
		; we have 4*250=1000 and 64000/1000=64Hz
		lda #<2000
		ldx #>2000
		; load half of it???
		;lda #<500
		;ldx #>500
		sta POKEY_AUDF1
		stx POKEY_AUDF2

		lda #%11000010			; enable IRQs from timer 2, kbd & break
		sta POKEY_IRQEN

		sta POKEY_STIMER		; run timers
