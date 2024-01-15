
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
		; we'll use it to identify our system.
		ldy #0

vblankwait2:
		inx
		bne noincy
		iny
noincy:
		bit PPU_STATUS
		bpl vblankwait2

		; because of a hardware oversight, we might have missed a vblank flag.
		; so we have to account for 1 or 2 vblanks.

		; system      | cycles per | cycles per | 1 vblank | 2 vblanks
		;             | vblank     | iteration  |  Y    X  |  Y    X
		;-------------+------------+------------+----------+----------
		; NTSC FC/NES | 29780      | 12.005     | $09  $B1 | $13  $62
		; PAL NES     | 33247      | 12.005     | $0A  $D2 | $15  $A4
		; Dendy       | 35464      | 12.005     | $0B  $8A | $17  $14

		; check if we encountered 2 vblanks...
		tya
		cmp #$10
		bcc nodiv2
		lsr a ; if so, divide by 2.
nodiv2:
		sec
		sbc #9
		; system      | A
		;-------------+--
		; NTSC FC/NES | 0
		; PAL NES     | 1
		; Dendy       | 2
		; unknown     | 3+
		beq +
		lda #larchf_pal
	+	ora #larch_nintendo
		ora lk_archtype
		sta lk_archtype
