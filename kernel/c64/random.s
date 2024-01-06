		;; function:	update_random
		;; Update random number generator
		;; < nothing
		;; > nothing

; This can be accomplished by a function of long period (like in the bottom)
; or by using hardware. lastrnd is 16 bit, but only lower 8 bits are used

		lda lastrnd
		adc VIC_RC
		adc VIC_YSCL
		adc CIA1_TALO
		adc CIA1_TAHI
		;; SID stuff?
		sta lastrnd
		rts

;		inc lastrnd
;		bne +
;		inc lastrnd+1
;    +	 	asl lastrnd
;		rol lastrnd+1
;		bcc ++
;		lda #$0f
;		clc
;		adc lastrnd
;		sta lastrnd
;		bcc +
;		inc lastrnd+1
;    +		rts
;    +		lda lastrnd+1
;		cmp #$ff
;		bcc +
;		lda lastrnd
;		sec
;		sbc #$f1
;		bcc +
;		sta lastrnd
;		lda #0
;		sta lastrnd
;	+	rts
