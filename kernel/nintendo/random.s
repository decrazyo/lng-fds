		;; function:	update_random
		;; Update random number generator
		;; < nothing
		;; > nothing

; using the FDS BIOS random implementation here is more trouble than it's worth.
; it don't take advantage of any special hardware anyway.
; the Famicom/NES don't have any random hardware.

		inc lastrnd
		bne +
		inc lastrnd+1
	+	asl lastrnd
		rol lastrnd+1
		bcc ++
		lda #$0f
		clc
		adc lastrnd
		sta lastrnd
		bcc +
		inc lastrnd+1
	+	rts
	+	lda lastrnd+1
		cmp #$ff
		bcc +
		lda lastrnd
		sec
		sbc #$f1
		bcc +
		sta lastrnd
		lda #0
		sta lastrnd
	+	rts

