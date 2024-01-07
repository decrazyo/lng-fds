
		; enable the APU frame counter interrupt.
		; this should generates IRQs every 1/60 second.
		; not quite the 1/64 second that the common kernel code expects
		; but hopefully it's good enough.
		; we might be able to achieve better results by abusing the APU DMC.
		; we could also use the timer in the RAM adapter
		; but it might be easier to leave that dedicated to disk access operations.
		lda #0
		sta APU_FRAME

; TODO: make sure all interrupts are configured here.
