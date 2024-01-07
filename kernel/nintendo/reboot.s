
reboot:
		sei
		; TODO: figure out what else needs to be done here.
		;       maybe disable NMI?
		jmp ($fffc) ; jump through the RESET vector
