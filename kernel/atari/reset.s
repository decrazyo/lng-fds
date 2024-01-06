
		;; switch to LUnix' memory configuration
		lda #%00110000			; no interrupts from PIA, PORTB as DDR
		sta PIA_PBCTL
		lda #%11111111			; all PORTB pins as output
		sta PIA_PORTB
		lda #%00110100			; no interrupts from PIA, PORTB as I/O
		sta PIA_PBCTL
		lda #%10000010			; only RAM
		sta PIA_PORTB

		;; stop all timer, and disable all (known) interrupts
		lda #%00110000			; no interrupts from PIA, PORTA as DDR
		sta PIA_PACTL
		lda #%00000000			; all PORTA pins as input
		sta PIA_PORTA
		lda #%00110100			; no interrupts from PIA, PORTA as I/O
		sta PIA_PACTL

		lda #%00000000			; no interrupts from ANTIC
		sta ANTIC_NMIEN

		lda #%00000000			; no interrupts from POKEY
		sta POKEY_IRQEN

		;; set archtype (first solution on PAL/NTSC detection)

		;; recognize Atari subtypes? nah, we don't have enough bits in lk_archtype...
		ldx #larch_atari		; atari/ntsc
		lda GTIA_PAL
		and #%00001110
		bne +
		ldx #larch_atari|larchf_pal
	+	stx lk_archtype
