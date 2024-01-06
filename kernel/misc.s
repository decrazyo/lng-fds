		;; For emacs: -*- MODE: asm; tab-width: 4; -*-
		;; mics stuff

#include <kerrors.h>
#include <system.h>
#include <config.h>
#include MACHINE_H

		.global get_bitadr
		.global strout
		.global srandom
		.global random
		.global update_random
		.global end_of_kernel

		;; function:	get_bitadr
		;; get parameter passed by a preceeding bit-instruction
		;; the bit-instruction must be right before the jsr instruction
		;; sei is called, you have to call cli somewhen again outside!
		;; < bit instruction following "jsr..."
		;; > X/Y = bitadr (A unchanged)
		;; changes:		tmpzp(0,1)

get_bitadr:
		sei						; get parameter passed by a BIT-instruction
		tsx						; followed by the JSR-instruction.
		inx
		inx
		inx
		pha
		lda  $100,x
		sta  tmpzp
		inx
		lda  $100,x
		sec
		sbc  #1
		sta  tmpzp+1
		ldy  #251
		lda  (tmpzp),y
		cmp  #$2c				; check for BIT-opcode
		bne  +					; if there is no BIT exit with errormessage
		iny
		lda  (tmpzp),y
		tax
		iny
		lda  (tmpzp),y
		tay
		pla
		rts						; parameter is returned in X/Y (A stays
								; unchanged)

	+	lda  #lerr_illcode
		jmp  suicerrout


		;; function:	strout
		;; print string
		;; < X=fd, bit string_start after "jsr strout" command
		;; > c=error or not

strout:
		txa
		jsr  get_bitadr
		sta  tmpzp
		txa
		ldx  tmpzp
		cli
		pha
		tya
		pha
		clc

print_loop:
		sei
		pla
		sta  tmpzp+1
		pla
		sta  tmpzp
		ldy  #0
		lda  (tmpzp),y
		beq  end_of_string
		tay
		lda  tmpzp
		adc  #1
		sta  tmpzp
		pha
		lda  tmpzp+1
		adc  #0
		pha
		cli

		tya
		sec						; forced
		jsr  fputc
		bcc  print_loop

		tsx
		inx
		inx
		txs
		jmp  catcherr			; return received error

end_of_string:
		cli
		clc
		rts


srandom:	;; function:	srandom
		;; Set random number generator seed
		;; < A/Y - seed
		;; > random number (which is so random here :)
		sta lastrnd
		sty lastrnd+1

		;; function:	random
		;; Get a random number
		;; < nothing
		;; > A random number
random:
		jsr update_random
		lda lastrnd
		rts

		;; function:	update_random
		;; Update random number generator
		;; < nothing
		;; > nothing

update_random:
#include MACHINE(random.s)

lastrnd:	.word 0

end:	
end_of_kernel equ end+255
