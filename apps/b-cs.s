		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; benchmark
		;; cs - context switch (one2one)
	
#include <system.h>
#include <stdio.h>
#include <kerrors.h>
		
		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION,	<LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code
		
		;; (task is entered here)
		
		ldx  userzp+1			; address of commandline (hi byte)
		jsr  lkf_free			; free used memory

		ldx  #stdout
		bit  on_txt
		jsr  lkf_strout
		
		lda  #8					; use some zeropage
		jsr  lkf_set_zpsize

		ldx  #30				; put something in the stack
	-	pha
		dex
		bne  -
		
		lda  #0					; reset counter
		sta  userzp
		sta  userzp+1
		sta  userzp+2

		lda  lk_systic+1		; (4seconds)
	-	cmp  lk_systic+1
		beq  -
		clc
		lda  lk_systic+1
		adc  #5					; (wait 20 seconds)

	-	jsr  lkf_force_taskswitch
		inc  userzp
		bne  +
		inc  userzp+1
		bne  +
		inc  userzp+2
		
	+	cmp  lk_systic+1
		bne  -

		ldx  #stdout
		bit  off1_txt
		jsr  lkf_strout
		
		jsr  print_result
		
		ldx  #stdout
		bit  off2_txt
		jsr  lkf_strout
		
		lda  #0
		jmp  lkf_suicide

		;; result = (userzp/2)/10
print_result:
		lsr  userzp+2
		ror  userzp+1
		ror  userzp
		
		ldy  #0
		ldx  #0

	-	sec
		lda  userzp
		sbc  dectabl,y
		lda  userzp+1
		sbc  dectabm,y
		lda  userzp+2
		sbc  dectabh,y
		bcc  +
		sta  userzp+2
		lda  userzp
		sbc  dectabl,y
		sta  userzp
		lda  userzp+1
		sbc  dectabm,y
		sta  userzp+1
		inx
		bne  -
	+	txa
		beq  +
		ora  #"0"
		sec
		ldx  #stdout
		jsr  fputc
		ldx  #"0"
	+	iny
		cpy  #7
		bne  -
		lda  #"."
		sec
		ldx  #stdout
		jsr  fputc
		lda  userzp
		ora  #"0"
		sec
		ldx  #stdout
		jmp  fputc		
		
		.byte 2

dectabl:
		.byte <10000000,<1000000,<100000,<10000,<1000,<100,<10
dectabm:
		.byte >10000000&$ff,>1000000&$ff,>100000&$ff,>10000,>1000,>100,>10
dectabh:
		.byte >>10000000,>>1000000,>>100000,>>10000,>>1000,>>100,>>10

on_txt:	.text "running benchmark...",$0a
		.text " (one2one context switch, 16 sec,",$0a
		.text "  30bytes stack + 8 bytes zeropage)",$0a,0
		
off1_txt:
		.text "result: ",0

off2_txt:
		.text " sw/sec",$0a,0

end_of_code:
