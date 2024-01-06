.global panic
; .extern printk

		;; function: panic
		;; stop system immediateliy, right after printing
		;; a "panik"-message using printk
		;; calls: printk
		;; changes: no_return
		
panic:
		ldx  #0
		
	-	lda  panic_txt,x
		beq  +
		jsr  printk
		inx
		bne  -
		
	+ -	jmp  -					; endless loop

panic_txt:
		.text "Kernel panic"
		.byte $0a,$00
