		;; For emacs: -*- MODE: asm; tab-width: 4; -*-

		;; 8 signals 0-7
		;; signal 9 is a pseudo signal that terminates a process
		;;  (make process call suicied with exitcode $7f)

		;; C128 modifications by Maciej 'YTM/Alliance' Witkowiak <ytm@friko.onet.pl>
		;; 19.01.2000
		;; I don't think that idle_task can send/receive signals, so I ignore MMU_P1H
		;; here, assuming there's always signal from real task to real task
		;; 09.02.2000
		;; introducing MMU_STACK option instead of C128

#include <system.h>
#include <kerrors.h>
#include <config.h>
#include MACHINE_H
		
.global sendsignal
.global _raw_sendsignal
.global signal
		
	-	lda  #lerr_killed
		jmp  suicide
		
_kill:	cpx  #32				; kill process X=ipid (exitcode $7f)
		bcs  _err_illarg		; valid processes are 0..31
		cpx  lk_ipid
		beq  -					; kill myself is called suicide! 

		lda  lk_tstatus,x
		and  #tstatus_nosig
		bne  +					; kill already in progress ! (just skip it)
		lda  lk_tstatus,x
		ora  #tstatus_nosig
		sta  lk_tstatus,x		; lock signals for this process

		and  #tstatus_susp
		beq  +
		stx  tmpzp
		jsr  p_insert			; add task to CPU queue
		ldx  tmpzp
		
	+	lda  lk_ttsp,x			; set pointer to task's superpage
		sta  tmpzp+1
		lda  #0
		sta  tmpzp
		
		lda  #7
		ldy  #tsp_stsize
		sta  (tmpzp),y			; new stacksize is 7 (mem,y,x,a,sr,pcl,pch)
#ifdef MMU_STACK
		;; this is called from signal below, so I assume that IRQ is already disabled
		;; (we'd be in deep shit if it wouldn't :-)

		ldy MMU_P1L
		stx MMU_P1L			; X=IPID (0..31)
		tsx
		stx tmpzp+2

		ldx #$ff
		txs
		lda #>suicerrout
		pha				; (1) PCh
		lda #<suicerrout
		pha				; (2) PCl
		lda #50
		pha				; (3) SR
		lda #lerr_killed
		pha				; (4) A
		pha				; (5) X
		pha				; (6) Y
		lda #MEMCONF_USER
		pha				; (7) memconf

		ldx tmpzp+2			; restore stack config
		txs
		sty MMU_P1L
#else
		ldy  #256-7
		lda  #MEMCONF_USER		; use default memory configuration
		sta  (tmpzp),y
		iny
		lda  #lerr_killed		; exitcode for 'killed in action'
		sta  (tmpzp),y          ; (Y=exitcode)
		iny
		sta  (tmpzp),y          ; (X=exitcode)
		iny
		sta  (tmpzp),y          ; (A=exitcode)
		lda  #50
		iny
		sta  (tmpzp),y          ; (SR=50)
		lda  #<suicerrout
		iny
		sta  (tmpzp),y          ; (pc=suicide)
		lda  #>suicerrout
		iny
		sta  (tmpzp),y
#endif
		cli

		lda  #0					; return A=0 (signal sent)
		clc
		rts						; done
     
	-	jmp  catcherr

_err_illarg:
		lda  #lerr_illarg
		jmp  suicerrout
		
		;; function:: sendsignal
		;; send signal to current or other task
		;; < A/Y=PID of destination process
		;; < X=number of signal (0..7 or 9 for kill)
		;; changes: tmpzp(0,1,4) ;; also 2 and 3 on C128
		;; calls: getipid
		
sendsignal:  
		sei						; send signal to process A/Y=PID, X=signal
		stx  tmpzp+4
		jsr  getipid
		bcs  -

		lda  tmpzp+4			; check if its a valid signal
		cmp  #9
		beq  _kill				; signal 9 is kill !
		cmp  #8
		bcs  _err_illarg		; only signals 0-7 are valid
          
		; raw-sendsignal-routine (tmpzp+4=signum, X=ipid)

		jsr  _raw_sendsignal
		cli
		bne  -
		clc
		rts
		
_raw_sendsignal:
		lda  lk_tstatus,x       
		and  #tstatus_nosig
		bne  skip_signal		; no signals ?, then don't send signal
		
		lda  #0					; get pointer to stack
		sta  tmpzp
		lda  lk_ttsp,x
		sta  tmpzp+1

		ldy  #tsp_stsize
		lda  (tmpzp),y			; enough space left in stack ?
		clc
		adc  #16				; need 3 bytes but skip if less than 16 left
		ldy  #tsp_zpsize
		adc  (tmpzp),y
		adc  #tsp_swap
		bcs  skip_signal		; no, then skip

		lda  tmpzp+4			; get pointer to signal vector
		asl  a
		adc  #tsp_signal_vec+1
		tay
		lda  (tmpzp),y			; read hi-byte of vector
		beq  skip_signal		; signal doesn't get caught (ignore it)

		sta  _sig_hi			; remember highbyte
		dey
		lda  (tmpzp),y
		sta  _sig_lo			; remember lowbyte

		cpx  lk_ipid
		beq  self_sig			; send signal to current process

		;; send signal to foreign process
#ifdef MMU_STACK

		stx MMU_P1L			; X=target IPID (0..31)
		tsx
		stx tmpzp+2

		ldy  #tsp_stsize
		lda  (tmpzp),y			; enough space left on stack ?
		clc				; fix new SP (we're adding 3 bytes)
		adc #3
		sta (tmpzp),y
		eor #$ff
		tax
		inx				; pointer to last stack item
		
		ldy #0
-		lda $103,x			; move 3 bytes backwards
		sta $100,x
		inx
		iny
		cpy #4				; last 4 bytes on stack
		bne -
		
		lda #50				; new SR
		sta $100,x
		lda _sig_lo			; new PCl
		sta $101,x
		lda _sig_hi			; new PCh
		sta $102,x

		;; restore stack configuration
		ldx tmpzp+2
		txs
		lda lk_ipid			; current task's IPID
		sta MMU_P1L
		
#else
		ldy  #tsp_stsize
		lda  (tmpzp),y			; enough space left on stack ?
		eor  #$ff
		tay
		iny						; (tmpzp),y points to latest stack element
		lda  (tmpzp),y			; load and emember it (its MEMCONV)
		pha
		iny
		lda  (tmpzp),y          ; load and remember Y
		pha
		lda  #50				; and replace with #50 (new SR, c=0!)
		sta  (tmpzp),y
		iny						; load and remember X
		lda  (tmpzp),y
		pha
		lda  _sig_lo			; and replace with sigaddres-low
		sta  (tmpzp),y
		iny						; load and remember A
		lda  (tmpzp),y
		pha
		lda  _sig_hi			; and replace with sigaddres-high
		sta  (tmpzp),y
		dey
		dey
		dey
		pla						; get A
		sta  (tmpzp),y          ; put A as new stack element
		dey
		pla						; get X
		sta  (tmpzp),y          ; put X as new stack element
		dey
		pla						; get Y
		sta  (tmpzp),y          ; put Y as new stack element
		dey
		pla						; get MEMCONV
		sta  (tmpzp),y          ; put MEMCONV as new stack element
		dey
		tya
		eor  #$ff
		ldy  #tsp_stsize
		sta  (tmpzp),y			; write new stacksize
#endif
		lda  #0					; load returncode 0 ('signal sent')
		SKIP_WORD				; skip next instruction

skip_signal:	
		lda  #lerr_tryagain		; load returncode ('signal not sent')
		rts

self_sig:		
		tsx						; send signal to current process
		inx						; adapt return address (+1)
		inc  $100,x
		bne  +
		inx
		inc  $100,x
	+	lda  #50				; push pseudo SR=50 on stack
		pha						; return with c=0, i=0

		sec						; the signal-handler can check the carry-flag
								; if it is 1, the signal was sent by the
								; process itself !       

		lda  #0					; return with A=0 (signal sent)

		_sig_lo equ *+1
		_sig_hi equ *+2
		
		jmp  $0000				; jump to signaladdess directly

	-	jmp  _err_illarg
		
		;; function: signal
		;; install a signal handler
		;; < X=signal number 0..7, A/Y=address of handler
		;; < (Y=0 de-installs handler)
		;; > c=error

signal:	cpx  #8
		bcs  -					; only signals 0-7 are valid
		pha
		tya
		pha
		txa
		asl  a
		adc  #tsp_signal_vec+1
		tay
		pla						; hi-byte of handler address
		sei
		sta  (lk_tsp),y
		dey
		pla						; lo-byte of handler address
		sta  (lk_tsp),y
		cli
		rts		
