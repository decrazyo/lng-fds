
		ldx #APU_FRAME_D
		stx APU_FRAME ; disable APU frame IRQ

		ldx #0
		stx PPU_CTRL ; disable NMI
		stx PPU_MASK ; disable rendering
		stx APU_DMC_1 ; disable DMC IRQs

		; The vblank flag is in an unknown state after reset,
		; so it is cleared here to make sure that vblankwait1
		; does not exit immediately.
		bit PPU_STATUS

		; First of two waits for vertical blank to make sure that the
		; PPU has stabilized
vblankwait1:
		bit PPU_STATUS
		bpl vblankwait1

		; We now have about 30,000 cycles to burn before the PPU stabilizes.

vblankwait2:
		bit PPU_STATUS
		bpl vblankwait2
