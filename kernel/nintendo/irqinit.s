
		; APU interrupts were already disabled in "reset.s".
		; FDS_RESET_CTRL was already configured in "bootstrap.s".

		; instruct the BIOS NMI handler to call the kernel NMI handler.
		lda #FDS_NMI_CTRL_3
		sta FDS_NMI_CTRL

		; enable NMI.
		lda #PPU_CTRL_V
		sta PPU_CTRL

		; instruct the BIOS IRQ handler to call the kernel IRQ handler.
		lda #FDS_IRQ_CTRL_G
		sta FDS_IRQ_CTRL

		; configure the timer to generate an IRQ every 1/64 second.
		lda lk_archtype
		and #larchf_pal
		bne +

#ifdef APU_AS_TIMER
		; enable the APU frame counter interrupt.
		; this should generates IRQs every 1/60 second.
		; not quite the 1/64 second that the common kernel code expects.
		lda #0
		sta APU_FRAME
#else
		; NES/Famicom (NTSC) CPU @ 1.789773 MHz
		; 1789773 hz / 64 = 27965.203125
		ldx #<27965
		ldy #>27965
		bne ++

		; NES (PAL) CPU @ 1.662607 MHz
		; 1789773 hz / 64 = 25978.234375
	+	ldx #<25978
		ldy #>25978

	+	stx FDS_TIMER_LO
		sty FDS_TIMER_HI

		; enable timer IRQ and reload the timer after every interrupt.
		lda #FDS_TIMER_CTRL_E | FDS_TIMER_CTRL_R
		sta FDS_TIMER_CTRL
#endif
