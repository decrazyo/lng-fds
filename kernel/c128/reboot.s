		;; leave LUnix (?) reboot system

reboot:	
		sei
		lda #%000000000
		sta MMU_CR
		jmp $e000
