;; for emacs: -*- MODE: asm; tab-width: 4; -*-
	
#include <console.h>

	-	jmp  lkf_panic

		;; initialise console driver
		;; (and set lk_consmax value)

console_init:
		;; allocate memory at $0400-$07ff
		jsr  lkf_locktsw
		lda  lk_memmap+0		; check if memory is unused
		and  #$0f
		cmp  #$0f
		bne  -					; (if not, panic)
		lda  #4					; number of pages
		ldx  #>screenA_base		; start page
		ldy  #memown_scr		; usage ID
		sta  tmpzp
		stx  tmpzp+3
		sty  tmpzp+4
		jsr  lkf__raw_alloc		; (does unlocktsw)

#ifdef MULTIPLE_CONSOLES
		;; try to allocate second console at $0800-$0cff
		jsr  lkf_locktsw
		lda  lk_memmap+1		; check if memory is unused
		and  #$f0
		cmp  #$f0
		bne  -					; (if not, panic)
		lda  #4					; number of pages
		ldx  #>screenB_base		; start page
		ldy  #memown_scr		; usage ID
		sta  tmpzp
		stx  tmpzp+3
		sty  tmpzp+4
		jsr  lkf__raw_alloc		; (does unlocktsw)

		lda #0				; initialize fs_cons stuff
		sta usage_map

		lda  #MAX_CONSOLES			; we have 2 consoles
#else
		lda  #1					; we have just 1 console		
#endif
		sta  lk_consmax

		lda #0				; initialize fs_cons stuff
		sta usage_count

		;; initialize VIC
		lda  CIA2_PRA
		ora  #3
		sta  CIA2_PRA			; select bank 0
		lda  #0
		sta  VIC_SE				; disable all sprites
		lda  #$9b
		sta  VIC_YSCL			
		lda  #$08
		sta  VIC_XSCL
		lda  #0
		sta  VIC_CLOCK

#ifdef MULTIPLE_CONSOLES
		lda  #>screenA_base
		sta  sbase

		lda  #0
		sta  current_output		; output goes to first console
		lda  #1					; default is console 1 (at $0400)
		jsr  lkf_console_toggle		; (replaces "jsr  do_cons1")
#else
		lda  #$16
		sta  VIC_VSCB			; make console visible		
#endif

		;; set 'desktop' color
		lda  #0
		sta  VIC_BC				; border color
		lda  #11
		sta  VIC_GC0			; background color

		lda  #$80
		sta  cflag				; curor enabled (not yet drawn)
		lda  #0
		sta  esc_flag
		sta  rvs_flag
		sta  scrl_y1
		lda  #24
		sta  scrl_y2
		jsr  lkf_cons_home

#ifdef MULTIPLE_CONSOLES
		;; clone screen-status (mapl/(h), csrx/y, cflag, scrl_y1/2)
		ldx  #8
	-	lda  mapl,x
		sta  lkf_cons_regbuf,x
		dex
		bpl  -

		lda  #>screenB_base
		sta  sbase
		sta  maph
		sta  lkf_cons_regbuf+1				; (maph!)
		jsr  lkf_cons_clear		; clear second console

		lda  #>screenA_base
		sta  sbase
		sta  maph
#endif

		jsr  lkf_cons_clear		; clear first console

		;; print startup message
		ldx  #0
	-	lda  start_text,x
		beq  +
		jsr  lkf_printk
		inx
		bne  -

	+	rts

start_text:
#ifdef MULTIPLE_CONSOLES
		.text "VIC consoles (v1.1) @ $400,$800",$0a,0
#else
		.text "VIC console (v1.1) @ $400",$0a,0
#endif
