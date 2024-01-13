
		; APU interrupts were already disabled in "reset.s".
		; FDS_RESET_CTRL was already configured in "bootstrap.s".

		; instruct the BIOS NMI handler to call the kernel NMI handler.
		lda #FDS_NMI_CTRL_3
		sta FDS_NMI_CTRL

		; enable full background rendering.
		lda #PPU_MASK_b | PPU_MASK_m
		sta PPU_MASK

		; enable NMI.
		lda #PPU_CTRL_V
		sta PPU_CTRL

		; instruct the BIOS IRQ handler to call the kernel IRQ handler.
		lda #FDS_IRQ_CTRL_G
		sta FDS_IRQ_CTRL

		; configure the timer to generate an IRQ every 1/64 second.
		; NES/Famicom (NTSC) CPU @ 1.789773 MHz
		; 1789773 hz / 64 = 27965.203125
		lda #<27965
		sta FDS_TIMER_LO
		lda #>27965
		sta FDS_TIMER_HI

		; enable timer IRQ and reload the timer after every interrupt.
		lda #FDS_TIMER_CTRL_E | FDS_TIMER_CTRL_R
		sta FDS_TIMER_CTRL
