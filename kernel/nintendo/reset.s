
; this is based on init code from nesdev.org
; 
; 
; reset:
		; interrupts and decimal mode have already been disabled.
;		sei        ; ignore IRQs
;		cld        ; disable decimal mode
		ldx #$40
		stx APU_FRAME  ; disable APU frame IRQ
		; the stack has already been set up
;		ldx #$ff
;		txs        ; Set up stack
;		inx        ; now X = 0
		ldx #0
		stx PPU_CTRL  ; disable NMI
		stx PPU_MASK  ; disable rendering
		stx APU_DMC_1  ; disable DMC IRQs

		; Optional (omitted):
		; Set up mapper and jmp to further init code here.

		; The vblank flag is in an unknown state after reset,
		; so it is cleared here to make sure that vblankwait1
		; does not exit immediately.
		bit PPU_STATUS

		; First of two waits for vertical blank to make sure that the
		; PPU has stabilized
vblankwait1:
		bit PPU_STATUS
		bpl vblankwait1

		; memory initialization will be handled by "kernel/bootstrap.s".

		; We now have about 30,000 cycles to burn before the PPU stabilizes.
		; One thing we can do with this time is put RAM in a known state.
		; Here we fill it with $00, which matches what (say) a C compiler
		; expects for BSS.  Conveniently, X is still 0.
;		txa
;clrmem:
;		sta $000,x
;		sta $100,x
;		sta $200,x
;		sta $300,x
;		sta $400,x
;		sta $500,x
;		sta $600,x
;		sta $700,x
;		inx
;		bne clrmem

		; Other things you can do between vblank waits are set up audio
		; or set up other mapper registers.
   
vblankwait2:
		bit PPU_STATUS
		bpl vblankwait2