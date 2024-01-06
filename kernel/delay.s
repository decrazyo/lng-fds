		;; delay for (at least) 50us
		;; (no matter what CPU-speed!)

		;;  must be calibrated at startup
		
.global delay_50us
.global delay_calib_lo
.global delay_calib_hi		
		
		;; function: delay_50us
		;; delay for 50us, is affected by
		;; calib
delay_50us:
		clc
		ldx  #255
		lda  #255
	-	inx
		bne  -
		adc  #1	
		bcc  -
		rts
		
delay_calib_lo equ delay_50us+2
delay_calib_hi equ delay_50us+4

