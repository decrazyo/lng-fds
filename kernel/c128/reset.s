		;; setup LUnix' memory configuration

		lda #%00111110				; only RAM+I/O, bank 0
		sta MMU_CR
		sta MMU_IOCR
		sta MMU_PCRA				; bank0 as preconfig A
		lda #%01111110
		sta MMU_PCRB				; bank1 as preconfig B
#ifdef HAVE_256K
		lda #%10111110
		sta MMU_PCRC				; bank2 as preconfig C
		lda #%11111110
		sta MMU_PCRD				; bank3 as preconfig D (possible problems)
#endif
		;lda #%00001111				; VIC in bank 0, share both 16K (for bootstrap only)
		lda #%00000000				; VIC in bank 0, noshare
		sta MMU_RCR
		ldx #0
		stx MMU_P0H
		stx MMU_P0L				; page 0 at $00000
		inx
		stx MMU_P1H
		stx MMU_P1L				; page 1 at $10100

#ifdef VDC_CONSOLE
		lda  VIC_YSCL			; switch off VIC screen
		and  #%11101111			; (makes computer run slightly faster)
		sta  VIC_YSCL
		;; since SPEED_MAX at start of bootstrap.s
		;; might not be defined we enforce 2MHz here
		;; only if VDC is present and SCPU not
# ifndef HAVE_SCPU
		lda  #1
		sta  VIC_CLOCK
# endif
#endif

		;; stop all timer, and disable all (known) interrupts
		lda  #%00000000
		sta  CIA1_CRA			; stop timer 1 of CIA1
		sta  CIA1_CRB			; stop timer 2 of CIA1
		sta  CIA2_CRA			; stop timer 1 of CIA2
		sta  CIA2_CRB			; stop timer 2 of CIA2
		lda  #%01111111
		sta  CIA1_ICR
		sta  CIA2_ICR
		lda  CIA1_ICR
		lda  CIA1_ICR
		lda  CIA2_ICR
		lda  CIA2_ICR
		lda  #0
		sta  VIC_IRM
		lda  VIC_IRQ
		sta  VIC_IRQ

		;; CIA initialization
		lda  #%11111111
		sta  CIA1_DDRA
		lda  #%00111111
		sta  CIA2_DDRA
		lda  #%00000000
		sta  CIA1_DDRB
		sta  CIA2_DDRB

		;; set type of architecture (first shot)
		;; ---------------------------------------------------------------
		
		;; (Read $0a03 - $ff=PAL, $00=NTSC)
		;lda  #larch_c128
		;ldx  $0a03
		;beq  +					; (ntsc)
		;ora  #larchf_pal		; (pal)
	;+	sta  lk_archtype


		;; alternate (better) solution from comp.sys.cbm
		;; ---------------------------------------------------------------

		ldx  #larch_c128
	-	bit  VIC_RC
		bpl  -					; wait for rasterline  127<x<256
		lda  #24				; (rasterline now >=256!)
	-	cmp  VIC_RC				; wait for rasterline = 24 (or 280 on PAL)
		bne  -
		lda  VIC_YSCL			; 24 or 280 ?
		bpl  +
		ldx  #larch_c128|larchf_pal|larchf_8500
	+	stx  lk_archtype

