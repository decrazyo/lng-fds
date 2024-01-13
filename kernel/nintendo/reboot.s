
reboot:
		; run the FDS BIOS reset code.
		lda #FDS_RESET_CTRL_B
		sta FDS_RESET_CTRL

		jmp ($fffc) ; jump through the RESET vector
