		;; scheduler

#include <system.h>

.global p_remove
.global p_insert

		;; macro
		;;  A := A * 2^(lk_cyclefactor)
		;; (changes REG, REG is X or Y)
		
#begindef SCALE_A(REG)
%%next,push,next,push,next%%	; macro needs 3 local labels
		ldREG  lk_cyclefactor	; (plast, ptop, pcur)
		beq  %%pcur%%
		bmi  %%ptop%%
%%plast%%:		
		asl  a
		deREG
		bne  %%plast%%
		beq  %%pcur%%
%%ptop%%:		
		lsr  a
		adc  #0					; result must never be 0 !
		inREG
		bne  %%ptop%%

%%pcur,pop,pop%%:
#enddef
		
		;; function: p_remove
		
		;; remove process from the switching queue
		;; < x=IPID  (assume IRQ|taskwsitching is disabled)
		
p_remove:
		lda  lk_tstatus,x
		ora  #tstatus_susp
		sta  lk_tstatus,x

		txa						; check if there is another running task
		cmp  lk_tnextt,x
		bne  +
				
		;; no other task
		lda  #$ff
		sta  lk_tnextt,x
		lda  #0					; (no cycletime)
		sta  lk_cycletime
		sta  lk_cyclefactor
		rts

		;; there are other tasks
	+	tay
	-	dey
		bpl  +
		ldy  #31
	+	cmp  lk_tnextt,y		; prev to current task ?
		bne  -					; (yes)
		
		lda  lk_tnextt,x
		sta  lk_tnextt,y

		lda  lk_tstatus,x
		and  #tstatus_pri
		SCALE_A(y)				; scale A (y changed)
		sec
		eor  #$ff
		adc  lk_cycletime
		sta  lk_cycletime

		;; function: check_cycletime
		;; after the run-queue has changed, the round trip time
		;; of the scheduler might have become to low/high and
		;; need some further recomputation
		;; changes: A,Y

check_cycletime:		
		cmp  #17				; check, if the cycletime is getting to short
		bcs  check2

		cmp  #0					; should not happen, but does !
		bne  +					; (must be a bug somewhere)
		lda  #1
	+
			
		;; have to increase the cycletime
		;; and recalculate all tslices
		
	-	inc  lk_cyclefactor
		asl  a
		cmp  #17
		bcc  -
		
		txa						; must preserve X
		pha
		ldy  #31
		lda  #0
		sta  lk_cycletime
		
	-	lda  lk_tstatus,y
		beq  +
		and  #tstatus_susp
		bne  +					; skip all tasks that are not running
		lda  lk_tstatus,y
		and  #tstatus_pri
		SCALE_A(x)				; scale A (X changed)
		sta  lk_tslice,y
		adc  lk_cycletime
		sta  lk_cycletime
	+	dey
		bpl  -
		pla
		tax
		rts

check2:
		;; check if cycle time went too long
		cmp  #32
		bcs  +					; cycletime went to long
		rts

	+ 	dec  lk_cyclefactor
		lda  #0
		sta  lk_cycletime
		ldy  #31
		
	-	lda  lk_tstatus,y		; divide all tslice values by 2
		beq  +
		and  #tstatus_susp
		bne  +					; skip all tasks that are not running
		lda  lk_tslice,y
		lsr  a
		adc  #0
		sta  lk_tslice,y
		adc  lk_cycletime
		sta  lk_cycletime
	+	dey
		bpl  -

		lda  lk_cycletime
		jmp  check2

		;; function: p_insert
		;; insert task in run-queue
		;; < X=ipid
		;; changes: A,Y
		;; calls: check_cycletime
		
p_insert:
		lda  lk_tstatus,x
		and  #$ff-tstatus_susp
		sta  lk_tstatus,x
		txa						; (will be overwritten if there is
		sta  lk_tnextt,x		; another running task)
		
		;; search for the prev runnnig task
		tay
	-	dey
		bpl  +
		ldy  #31
	+	lda  lk_tstatus,y
		beq  -					; skip
		and  #tstatus_susp
		bne  -					; skip
		lda  lk_tnextt,y
		sta  lk_tnextt,x
		txa
		sta  lk_tnextt,y
		lda  lk_ipid
		bpl  +
		txa						; if the system is idle
		ora  #$80				; make it switch to this task
		sta  lk_ipid			; upon the next IRQ
		lda  #3
		sta  lk_cyclefactor		; (initial cyclefactor)
		lda  #0
		sta  lk_cycletime
		
	+	lda  lk_tstatus,x
		and  #tstatus_pri
		SCALE_A(y)				; scale A (y changed)
		sta  lk_tslice,x		; add to cycle time
		adc  lk_cycletime
		sta  lk_cycletime
		bne  +					; may overrun and become zero
		lda  #$ff

	+	jmp  check_cycletime

