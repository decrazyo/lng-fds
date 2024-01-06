		;; calibrate delay loop (only for startup)

		;; should be the shortest possible delay available on all
		;; 6502-machines (i assume they all run at least at 1MHz)
		;; so the shortest delay would be JSR+RTS = 12탎
		;; the smallest (worst case) step we can do is INX+BNE = 5탎
		;; do get a accuracy of 90% in every case the time should be
		;; at least 10*5탎 = 50탎

		;; lets implement "delay_50us"

#include <system.h>
#include <ksym.h>
#include <config.h>
#include MACHINE_H
.global calibrate_delay

; .extern delay_50us
; .extern delay_calib_lo
; .extern delay_calib_hi
; .extern printk

#undef sprintk
#begindef sprintk(ptr)
		ldx  #0
	-	lda  ptr,x
		beq  +
		jsr  lkf_printk
		inx
		bne  -
		+
#enddef

		;; no calib for other systems yet
		;;   delay = value*5+26 cycles = 50탎

		;; function: calibrate_delay
		;; used to calibrate delay loops 
		;; well, seems not to work well this way
		;; hardcoding might be better
		;; changes: unknown

;simple version (without calibration) could look like that		
;calibrate_delay:
;		ldx  #<($10000 - 5)		; default values for 1MHz systems
;		ldy  #>($10000 - 5)		; ( 1MHz -> 5 )
;		stx  delay_calib_lo
;		sty  delay_calib_hi
;		rts

calibrate_delay:
		;; include machine dependent calibration code
#  include MACHINE(calib.s)

		;; delay_calib_lo/hi should be set now
		;; code below is common

		;; calculate number of CPU-cycles for 0.01s
		;; ( = 5ms_loops * 2 * 5.0156)
		;; ( = 5ms_loops * 10)

		lda  lkf_delay_calib_lo
		asl  a
		sta  tmpzp+2
		tax
		lda  lkf_delay_calib_hi
		rol  a
		sta  tmpzp+3
		sta  tmpzp
		lda  #0
		rol  a
		sta  tmpzp+4			; divisor = loops * 2
		sta  tmpzp+1
		txa
		asl  a
		rol  tmpzp
		rol  tmpzp+1
		asl  a
		rol  tmpzp
		rol  tmpzp+1
		adc  tmpzp+2
		sta  tmpzp+2
		lda  tmpzp
		adc  tmpzp+3
		sta  tmpzp+3
		ldx  #0
		lda  tmpzp+1
		adc  tmpzp+4			; divisor += divisor*4

		bmi  +
	-	inx
		asl  tmpzp+2
		rol  tmpzp+3
		rol  a
		bpl  -
	+	stx  lk_timedive		; exponent of time divisor
		sta  lk_timedivm		; mantisse of time divisor

		jsr  print_bogomips

		;; then calculate delay_calib for 50us
		;;  result = value/100-5

		lda  lkf_delay_calib_lo		; tmp = calib/128
		asl  a
		sta  tmpzp+6
		lda  lkf_delay_calib_hi
		rol  a
		sta  tmpzp+7
		lda  #0
		rol  a
		sta  tmpzp+2

		lda  lkf_delay_calib_hi		; tmp += calib/512
		lsr  a
		sta  tmpzp+3
		lda  lkf_delay_calib_lo
		ror  a
		sta  tmpzp+4
		clc
		adc  tmpzp+6
		sta  tmpzp+6
		lda  tmpzp+3
		adc  tmpzp+7
		sta  tmpzp+7
		bcc  +
		inc  tmpzp+2

	+	lda  tmpzp+4			; tmp += calib/4096
		lsr  tmpzp+3
		ror  a
		lsr  tmpzp+3
		ror  a
		lsr  tmpzp+4
		ror  a
		adc  tmpzp+6
		sta  tmpzp+6
		lda  tmpzp+3
		adc  tmpzp+7
		sta  tmpzp+7
		bcc  +
		inc  tmpzp+2

	+	sec						; tmp -=5
		lda  tmpzp+7			; delay_calib = 65536-tmp
		sbc  #5
		eor  #$ff
		sta  lkf_delay_calib_lo
		lda  tmpzp+2
		sbc  #0
		eor  #$ff
		sta  lkf_delay_calib_hi
		sprintk(end_txt)
		rts

print_bogomips:
		;; the correct formula is bogo_ips=1680+400*measured_delay_calib
		lda  lkf_delay_calib_lo
		sta  tmpzp+6
		lda  lkf_delay_calib_hi
		sta  tmpzp+7
		ldy  #3
		jsr  count
		beq  +
		ora  #"0"
		jsr  lkf_printk
	+	dey
		jsr  count
		ora  #"0"
		jsr  lkf_printk 
		lda  #"."
		jsr  lkf_printk
		dey
		jsr  count
		ora  #"0"
		jsr  lkf_printk
		dey
		jsr  count
		ora  #"0"
                jmp  lkf_printk

count:
		ldx  #0
	-	sec
		lda  tmpzp+6
		sbc  bogoconst_lo,y
		lda  tmpzp+7
		sbc  bogoconst_hi,y
		bcc  +
		sta  tmpzp+7
		lda  tmpzp+6
		sbc  bogoconst_lo,y
		sta  tmpzp+6
		inx
		bne  -
	+	txa
		rts

bogoconst_lo:
		.byte <25,<250,<2500,<25000
bogoconst_hi:
		.byte >25,>250,>2500,>25000

begin_txt:
		.asc "cALIBRATING DELAY LOOP.. \0"
end_txt:
		.asc " bOGOmips"
		.byte $0a,$00
