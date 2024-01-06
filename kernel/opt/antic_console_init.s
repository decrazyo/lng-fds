;
; ANTIC/GTIA simple console initialization
; Maciej Witkowiak <ytm@elysium.pl>
; 25.12.2000
;

#include <console.h>

console_init:
		;; allocate memory for display_list and screen
		jsr  lkf_locktsw
		lda  #4				; number of pages
		ldx  #>DISPLAY_LIST		; start page
		ldy  #memown_scr		; usage ID
		sta  tmpzp
		stx  tmpzp+3
		sty  tmpzp+4
		jsr  lkf__raw_alloc		; (does unlocktsw)
		;; allocate memory for font copy
		jsr  lkf_locktsw
		lda  #4				; number of pages
		ldx  #>ATARI_FONT		; start page
		ldy  #memown_scr		; usage ID
		sta  tmpzp
		stx  tmpzp+3
		sty  tmpzp+4
		jsr  lkf__raw_alloc		; (does unlocktsw)

		;; make a copy of ROM font fixing that braindead scheme...
		;; 00-1f -> $20-$3f	(numbers and punc)
		;; 20-3f -> $40-$5f	(uppercase)
		;; 40-5f -> $80-$9f	(gfx)
		;; 60-7f -> $60-$7f	(lowecase)
		;; then substract $20 from left column:
		;; 00-1f -> 00-1f	$0000-$00ff
		;; 20-3f -> 20-3f	$0100-$01ff
		;; 40-5f -> 60-7f	$0300-$03ff
		;; 60-7f -> 40-5f	$0200-$02ff
		;; so - copy everything but swap upper half (2k)
		;; on output just strip bit 5

		php		
		sei
		GETMEMCONF
		pha
		lda #MEMCONF_FONT
		SETMEMCONF
		lda #<FONT_ROM
		ldx #>FONT_ROM
		sta tmpzp
		stx tmpzp+1
		lda #<ATARI_FONT
		ldx #>ATARI_FONT
		sta tmpzp+2
		stx tmpzp+3
		; copy first 2*32*8 without changes
		ldx #0
		ldy #0
	-	lda (tmpzp),y
		sta (tmpzp+2),y
		iny
		bne -
		inc tmpzp+1
		inc tmpzp+3
		inx
		cpx #2
		bne -
		; copy next 32*8 bytes to 3*32*8 bytes farther (text graphics)
		inc tmpzp+3
	-	lda (tmpzp),y
		sta (tmpzp+2),y
		iny
		bne -
		inc tmpzp+1
		; copy last 32*8 bytes into 2*32*8 (lowercase)
		dec tmpzp+3
	-	lda (tmpzp),y
		sta (tmpzp+2),y
		iny
		bne -
		pla
		SETMEMCONF
		plp

		;; copy displaylist into proper place
		ldx #0
	-	lda sys_displaylist,x
		sta DISPLAY_LIST,x
		inx
		cpx #32
		bne -

		;; init ANTIC
		lda #%00100010			; normal screen
		sta ANTIC_DMACTL
		lda #%00000010			; normal characters
		sta ANTIC_CHACTL

		lda #<DISPLAY_LIST		; address of DList and screen
		ldx #>DISPLAY_LIST
		sta ANTIC_DLISTL
		stx ANTIC_DLISTH
		lda #>ATARI_FONT		; address of copied FONT
		sta ANTIC_CHBASE

		lda #0
		sta ANTIC_HSCROL
		sta ANTIC_VSCROL
		sta ANTIC_PMBASE
		sta ANTIC_NMIEN

		;; init GTIA
		ldx #0
		txa
	-	sta GTIA,x
		inx
		cpx #32
		bne -

		;; set colors - atari default blue
		lda #$9a
		sta GTIA_COLPF1
		lda #$94
		sta GTIA_COLPF2
		lda #0
		sta GTIA_COLBK

                lda #MAX_CONSOLES		; set number of consoles
                sta lk_consmax
                lda #0				; initialize fs_cons stuff
                sta usage_count
#ifdef MULTIPLE_CONSOLES
                sta usage_map
#endif

		lda #>SCREEN_BASE
		sta sbase

                lda  #$80
                sta  cflag			; curor enabled (not yet drawn)
                lda  #0
                sta  esc_flag
                sta  rvs_flag
                sta  scrl_y1
                lda  #23
                sta  scrl_y2
                lda #0				; clone status to all consoles
                sta tmpzp
    		jsr lkf_cons_clear
                jsr lkf_cons_home

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
		.text "ANTIC/GTIA consoles (v0.1) @ $x00,$x00",$0a,0
#else
		.text "ANTIC/GTIA console (v0.1) @ $400",$0a,0
#endif

sys_displaylist:
		.byte $70, $70, $70		; 24 blank lines (3*8)
		.byte $42			; display 1 line of mode 2 & load memory counter...
		.word DISPLAY_LIST+32		; ...screen base
		.byte 2,2,2,2,2,2,2,2		; remaining 23 lines of mode 2
		.byte 2,2,2,2,2,2,2,2
		.byte 2,2,2,2,2,2,2
		.byte $41			; jump to
		.word DISPLAY_LIST		; the begining
		; after copying the screenbase is here
