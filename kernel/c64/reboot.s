		;; leave LUnix (?) reboot system

reboot:	
		sei
		lda  #63
		sta  0
		lda  #255
		sta  1
		jmp  64738