		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; task control

#include <system.h>
#include <kerrors.h>

.global set_zpsize
.global mun_block
.global wait
.global getipid
		
		;; change size of used zeropage
		;; (default is 0!)
set_zpsize:
		cmp  #$40
		bcs  _err
		ldy  #tsp_zpsize
		sta  (lk_tsp),y
		rts

_err:	lda  #lerr_illarg
		jmp  suicerrout

		;; function: mun_block
		;; un-suspend all tasks with a matching waitcode
		;; < A=wait code 0
		;; < X=wait code 1
		;; changes:		tmpzp(0,1,2,3,4)
		;; calls:		p_insert
mun_block: 
		php
		sei
		sta  tmpzp+3
		stx  tmpzp+4
		lda  #0
		sta  tmpzp
		lda  #31
		sta  tmpzp+2

	-	ldx  tmpzp+2
		lda  lk_tstatus,x
		and  #tstatus_susp
		beq  +
		
		lda  lk_ttsp,x
		sta  tmpzp+1
		ldy  #tsp_wait0
		lda  (tmpzp),y
		cmp  tmpzp+3			; compare wait0
		bne  +
		iny
		lda  (tmpzp),y			; compare wait1
		cmp  tmpzp+4
		bne  +
		jsr  p_insert			; insert this task into the CPU-queue

	+	dec  tmpzp+2
		bpl  -
		plp
		rts

		;; function: wait
		;; wait for a child and get its exitcode
		;; < X/Y=pointer to 7 free bytes (for PID and TIME)
		;; < c=0:		non blocking
		;; < c=1:		blocking (may block for ever, if there is no child)
		;; > c=0:		ok, A=exitcode (struct contains info)
		;; > c=1:		error (try again)
		;; changes: tmpzp(2,3,0,1)
		;; calls: p_insert
		
wait:	bcs  wait_blocking
		php
		sei
		stx  tmpzp+2
		sty  tmpzp+3
		lda  #0
		sta  tmpzp
		ldx  #31
	-	lda  lk_tstatus,x
		and  #tstatus_susp
		beq  +					; skip
		lda  lk_ttsp,x
		sta  tmpzp+1
		ldy  #tsp_wait0
		lda  (tmpzp),y
		cmp  #waitc_zombie
		bne  +					; skip
		iny
		lda  (tmpzp),y
		cmp  lk_ipid
		bne  +					; skip (not my child)
		
		ldy  #tsp_time+4
	-	lda  (tmpzp),y			; copy time
		sta  (tmpzp+2),y
		dey
		bpl  -

		ldy  #tsp_pid
		lda  (tmpzp),y
		ldy  #5
		sta  (tmpzp+2),y		; store PID (lo)
		ldy  #tsp_pid+1
		lda  (tmpzp),y
		ldy  #6
		sta  (tmpzp+2),y		; store PID (hi)
		lda  lk_tslice,x		; slice holds exitcode
		pha
		jsr  p_insert			; add child to CPU-queue
		pla

		plp
		clc
		rts						; ok!
		
	+	dex
		bpl  --
		plp
		sec
		rts						; error!

wait_blocking:
		txa
		pha
		tya
		pha
		sei
		jsr  wait+2				; check and block must be atomic !
		bcc  +
		lda  #waitc_wait
		ldx  #0					; unused
		jsr  block
		cli
		pla
		tay
		pla
		tax
		jmp  wait_blocking
		
	+	tax
		pla
		pla
		txa
		cli
		rts

		;; function: getipid
		;; get internal process number (range 0..31)
		;; from PID
		;;  (IRQ should be disabled for reliable operation !)
		;; < A/Y=PID
		;; > X=IPID, c=error
		;; changes: tmpzp(0,1,2,3)
getipid:
		sta  tmpzp+2
		sty  tmpzp+3
		ldx  #tsp_pid
		stx  tmpzp
		ldx  #31
		
	-	lda  lk_tstatus,x		; check if slot is in use
		beq  +					; skip
		lda  lk_ttsp,x
		sta  tmpzp+1			; get tsp
		ldy  #0
		lda  (tmpzp),y			; compare PIDs
		cmp  tmpzp+2
		bne  +					; skip
		iny
		lda  (tmpzp),y
		cmp  tmpzp+3
		bne  +					; skip
		;; found task
		clc
		rts

	+	dex
		bpl  -
		lda  #lerr_nosuchpid
		sec
		rts
