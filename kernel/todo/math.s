		;; math

public getttime

		;; calculate task's time
		;; < 40bit unsigned, number of CPU ticks
		;;   userzp:	0..4
		;; > minutes, seconds, 1/100seconds
getttime:
		lda  lk_timedivm
		sta  userzp+5
		lda  #0
		sta  userzp+6
		sta  userzp+7
		sta  userzp+8
		sta  userzp+9
		lda  lk_timedive
		clc
		adc  #16
		tax

	-	sec
		lda  userzp+1
		