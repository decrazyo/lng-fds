		;; sleep

        #include <system.h>
	#include <kerrors.h>


.global _wakeup					; called from taskswitcher
.global sleep					; called by user

		;; _wakeup is a kind of IRQ-handler
		
		tspent equ irqzp
		min    equ irqzp+2
		ntsp   equ irqzp+4
		best   equ irqzp+6
		    		
	-	lda  #0					; reset counter (to highest value)
		sta  lk_sleepcnt
		sta  lk_sleepcnt+1
		rts						; and return to IRQ-routine

_wakeup:
		ldx  lk_sleepipid		; someone sleeping ?
		bmi  -					; (no)

		lda  lk_tslice,x
		sta  tspent				; time spent (lo)

		;; unsleep process
		jsr  p_insert
		
		;; search next process to wakeup
		lda  #0
		sta  ntsp
		lda  lk_ttsp,x
		sta  ntsp+1
		ldy  #tsp_wait1
		lda  (ntsp),y
		sta  tspent+1			; time spent (hi)
		lda  #$ff
		sta  min
		sta  min+1				; reset minimum
		sta  best
		ldx  #31
		
	-	lda  lk_tstatus,x
		and  #tstatus_susp
		beq  _nxt				; not suspended, then skip (can't be sleeping)
		lda  lk_ttsp,x
		sta  ntsp+1
		ldy  #tsp_wait0		
		lda  (ntsp),y
		cmp  #waitc_sleeping
		bne  _nxt				; (not sleeping)
		
		sec						; rest_time -= time_spent;
		lda  lk_tslice,x
		sbc  tspent
		sta  lk_tslice,x
		ldy  #tsp_wait1
		lda  (ntsp),y
		sbc  tspent+1
		sta  (ntsp),y
		ora  lk_tslice,x
		bne  +
		;; zero, have to wakeup this process too !!
		jsr  p_insert
		jmp  _nxt
		
	+	lda  (ntsp),y
		cmp  min+1				; if (rest_time < min)
		bne  +
		lda  lk_tslice,x
		cmp  min
	+	bcs  _nxt
		lda  lk_tslice,x		;   min=rest_time; best=current_task;
		sta  min
		lda  (ntsp),y
		sta  min+1
		stx  best
		
_nxt:	dex
		bpl  -

		lda  best				; is #$ff if none found
		sta  lk_sleepipid
		lda  min
		eor  #$ff
		sta  lk_sleepcnt
		lda  min+1
		eor  #$ff
		sta  lk_sleepcnt+1
		rts

		;; function: sleep
		;; suspend current task for a specified time
		;; < X/Y=sleeptime in jiffies (1/64s)
		;; changes:	tmpzp(0,1,2,3,4,5)
		
sleep:							; (must be reentrant code!)
		sei
		stx  tmpzp
		sty  tmpzp+1
		ldx  lk_sleepipid
		bmi  _alone				; will be the only sleeping task

		clc						; how long has the current
		lda  lk_sleepcnt		; sleeper slept already
		adc  lk_tslice,x
		sta  tmpzp+2
		lda  #0
		sta  tmpzp+4
		lda  lk_ttsp,x
		sta  tmpzp+5
		ldy  #tsp_wait1
		lda  lk_sleepcnt+1
		adc  (tmpzp+4),y
		sta  tmpzp+3

		clc						; who will wakeup first ?
		lda  tmpzp				; is it him or me?
		adc  lk_sleepcnt
		lda  tmpzp+1
		adc  lk_sleepcnt+1
		bcc  +					; i'll wakeup first!

		ldx  lk_ipid
		clc
		lda  tmpzp
		adc  tmpzp+2
		sta  lk_tslice,x
		lda  tmpzp+1
		adc  tmpzp+3
		tax
		lda  #waitc_sleeping
		jmp  suspend			; (will enable IRQ)

		;; have to replace the task
	+	ldx  #31

	-	lda  lk_tstatus,x
		and  #tstatus_susp
		beq  +
		lda  lk_ttsp,x
		sta  tmpzp+5
		ldy  #tsp_wait0
		lda  (tmpzp+4),y
		cmp  #waitc_sleeping
		bne  +
		sec
		lda  lk_tslice,x
		sbc  tmpzp+2			; time to wait - time spent
		sta  lk_tslice,x
		ldy  #tsp_wait1
		lda  (tmpzp+4),y
		sbc  tmpzp+3
		sta  (tmpzp+4),y
	+	dex
		bpl  -

_alone:	ldx  lk_ipid
		stx  lk_sleepipid
		lda  tmpzp
		sta  lk_tslice,x
		eor  #$ff
		sta  lk_sleepcnt
		lda  tmpzp+1
		tax
		eor  #$ff
		sta  lk_sleepcnt+1
		lda  #waitc_sleeping
		jmp  suspend
