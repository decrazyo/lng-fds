		;; switch to LUnix' memory configuration
		lda  #%00101111
		sta  0
		lda  #%00000101			; should be just RAM except I/O
		sta  1

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

#ifdef VDC_CONSOLE
		lda  VIC_YSCL			; switch off VIC screen
		and  #%11101111			; (makes compuer run slightly faster)
		sta  VIC_YSCL
#endif

		;; CIA initialization
		lda  #%11111111
		sta  CIA1_DDRA
		lda  #%00111111
		sta  CIA2_DDRA
		lda  #%00000000
		sta  CIA1_DDRB
		sta  CIA2_DDRB

		;; set archtype (first solution of PAL/NTSC detection)
		;; ---------------------------------------------------------------
		
		; lda  #larch_c64
		; ldx  $02a6				; PAL(1)/NTSC(0) ? (is this reliable?)
		; beq  +
		; ora  #larchf_pal
	; +	sta  lk_archtype

		
		;; need VIC to detect PAL/NTSC version
		;; (second solution)
		;; ---------------------------------------------------------------

		;lda  VIC_YSCL
		;ora  #$80
		;sta  VIC_YSCL
		;lda  #$37
		;sta  VIC_RC				; set raster interrupt to line $137
		;lda  #$0f
		;sta  VIC_IRQ			; delete interrupts
		;lda  #1
	;-	cmp  VIC_RC
		;bne  -
	;-	lda  VIC_RC
		;bne  -					; wait for rasterline 0
		;lda  VIC_IRQ
		;and  #1					; line $137 reached ??
		;beq  +
		;lda  #larchf_pal		; if so, then it is a PAL-VIC
	;+	ora  #larch_c64
		;sta  lk_archtype
		
		;; alternate (shorter) solution from comp.sys.cbm
		;; ---------------------------------------------------------------

		ldx  #larch_c64
	-	bit  VIC_RC
		bpl  -					; wait for rasterline  127<x<256
		lda  #24				; (rasterline now >=256!)
	-	cmp  VIC_RC				; wait for rasterline = 24 (or 280 on PAL)
		bne  -
		lda  VIC_YSCL			; 24 or 280 ?
		bpl  +
		ldx  #larch_c64|larchf_pal
	+	stx  lk_archtype
	