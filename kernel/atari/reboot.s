
reboot:
		sei
		lda #%10000011			; enable OS & BASIC or only OS?
		sta PIA_PORTB
		sta $033d			; make sure it's a cold boot
		jmp ($fffc)			; jump through RESET vector
