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
		ldx  #>screenL_base		; start page
		ldy  #memown_scr		; usage ID
		sta  tmpzp
		stx  tmpzp+3
		sty  tmpzp+4
		jsr  lkf__raw_alloc		; (does unlocktsw)

		;; try to allocate second console at $0800-$0cff
		jsr  lkf_locktsw
		lda  lk_memmap+1		; check if memory is unused
		and  #$f0
		cmp  #$f0
		bne  -					; (if not, panic)
		lda  #4					; number of pages
		ldx  #>screenR_base		; start page
		ldy  #memown_scr		; usage ID
		sta  tmpzp
		stx  tmpzp+3
		sty  tmpzp+4
		jsr  lkf__raw_alloc		; (does unlocktsw)

		lda #0				; initialize fs_cons stuff
		sta usage_count
;#ifdef MULTIPLE_CONSOLES
;		sta usage_map
;#endif
		lda  #MAX_CONSOLES
		sta  lk_consmax

		;; initialize VIC
		lda  CIA2_PRA
		ora  #3
		sta  CIA2_PRA			; select bank 0
		lda  #0
		sta  VIC_SE			; disable all sprites
		lda  #$9b
		sta  VIC_YSCL			
		lda  #$08
		sta  VIC_XSCL
		lda  #0
		sta  VIC_CLOCK

		lda  #0
		sta  current_output		; output goes to left console
		lda  #1				; default is left screen (at $0400)
		jsr  lkf_console_toggle		; (replaces "jsr  do_cons1")

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
		.text "VIC 80col. console (v1.0) @ $400,$800",$0a,0
