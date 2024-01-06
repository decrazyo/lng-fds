; For emacs: -*- MODE: asm; tab-width: 4; -*-

		;; $Id: lock.s,v 1.6 2003/03/08 22:19:14 ytm Exp $

		;; semaphore locking

		;; by D.Dallmann, Anton Treuenfels

		;; CHANGE LOG:
		;; $Log: lock.s,v $
		;; Revision 1.6  2003/03/08 22:19:14  ytm
		;; fixed warnings, SKIP_WORD/SKIP_WORDV is used now in whole kernel, IDE64 panics nicer
		;;
		;; Revision 1.5  2001/05/14 20:12:35  dallmann
		;; fixed bug in _check_blocking (AT)
		;;
		;; Revision 1.4  2001/05/07 17:16:26  dallmann
	        ;; bmap renamed to bit_n_set
		;;

#include <system.h>
#include <kerrors.h>
#include <config.h>
#include MACHINE_H

.global lock
.global unlock
.global bit_n_set

		;; number of available semaphores

		SEMID_MAX equ 40		;do not change!

		;; masks for setting and clearing individual bits in bytes
		;; - index 0->7 for lsb->msb of a byte

bit_n_set:   .byte $01,$02,$04,$08,$10,$20,$40,$80

		;; report lock error

	-	lda  #lerr_nosem
		jmp  catcherr

		;; function: _check_blocking
		;; check if blocking desired on unavailable global semaphore
		;; calls: block

_check_blocking:
		ldx  tmpzp+4			;recover semaphore number
		plp				;block on unavailable global?
		bcc  -				;b:no

		txa				;remember semaphore number
		pha
		lda  #waitc_semaphore
		jsr  block			;block with sem/sem#
		pla
		tax
		sec				;keep blocking (fall through)

		;; function: lock
		;; lock system semaphore
		;; < X=No. of semaphore
		;; < C=0 - non blocking

lock:
		php
		jsr  _validate_lock
		bne  +				;b:already locked

		;; global semaphore available?

		lda  lk_semmap-tsp_semmap,y
		and  bit_n_set,x
		bne  _check_blocking		;b:no

		;; lock semaphore globally and in TSP

		lda  lk_semmap-tsp_semmap,y
		ora  bit_n_set,x
		sta  lk_semmap-tsp_semmap,y
		lda  (lk_tsp),y
		ora  bit_n_set,x
		sta  (lk_tsp),y

	+	plp				;blocking calls have C=1...
		clc				;...but not any more
		rts

		;; function: unlock
		;; unlock locked system semaphore
		;; < X=No. of semaphore
		;; calls: mun_block

unlock:
		php
		jsr  _validate_lock
		beq  +				; exit if already unlocked 

		;; unlock semaphore in TSP and globally

		eor  (lk_tsp),y			;(proper bit to manipulate is already set)
		sta  (lk_tsp),y
		lda  bit_n_set,x
		eor  #$ff			;(saves 8 bytes for an extra table)
		and  lk_semmap-tsp_semmap,y
		sta  lk_semmap-tsp_semmap,y

		ldx  tmpzp+4			;recover semaphore number
		jsr  _sem_cleanup		;check if handler semaphore
		lda  #waitc_semaphore
		jsr  mun_block			;unblock all waiting tasks

	+	plp
		clc
		rts

		;; temporary code sequence?
		;; - same sequence in 'hook.s', 'signal.s', & 'taskctrl.s'
		;; - consider introducing 'term_illarg' in 'error.s',
		;;   should load accumulator with err# and fall through
		;;   to 'suicerrout'

	-	lda  #lerr_illarg
		jmp  suicerrout

		;; function: _validate_lock
		;; validate lock number and generate indices
		;; < X=lock number
		;;
		;; if lock number is valid:
		;; > tmpzp+4 = lock number
		;; > Y=index to byte of lock in TSP
		;; > X=index to bit of lock in byte
		;; > A=0 if currently unlocked in TSP, else lock bit is set
		;; > Z=1 if currently unlocked in TSP, 0 if currently locked
		;; > I=1 (IRQs disabled)

		;; changes: tmpzp(4)

_validate_lock:
		cpx  #SEMID_MAX			;valid lock number?
		bcs  -				;b:no -> terminate process with error

		txa
		lsr  a				;calc byte offset
		lsr  a
		lsr  a
		clc
		adc  #tsp_semmap
		tay
		txa
		sei				;disable IRQs (enter critical section)
		sta  tmpzp+4
		and  #$07			;calc bit offset
		tax
		lda  (lk_tsp),y			;check TSP lock status
		and  bit_n_set,x		;Z=1 -> locked
		rts

		;; function: _sem_cleanup
		;; un-register IRQ/Alert or NMI-handler

		;; assumes lsem_nmi is the last semaphore that needs
		;; special cleanup (lsem_* defined in include/system.h)

		;; calls: _nmi_dis

		;; < X=lock number

		;; > X=lock number

_sem_cleanup:
		cpx  #lsem_nmi			;compare to max handler number
		beq  _nmioff			;b:NMI handler
		bcs  +				;b:not a handler

		;; remaining handlers are simply and similarly disabled

		lda  #SKIP_WORDV

		cpx  #lsem_irq1		
		beq  _irq1off

		cpx  #lsem_irq2
		beq  _irq2off

		cpx  #lsem_irq3	
		beq  _irq3off

		;; _alertoff:
		sta  _irq_alertptr		;must be RTC alert

#ifdef HAVE_CIA
		lda  #4
		sta  CIA1_ICR
#endif

	+	rts

_irq1off:					; (remove IRQ-job 1)
		sta  _irq_jobptr
		rts

_irq2off:					; (remove IRQ-job 2)
		sta  _irq_jobptr+3
		rts

_irq3off:					; (remove IRQ-job 3)
		sta  _irq_jobptr+6
		rts

_nmioff:					; (remove NMI-job)
		lda  lk_nmidiscnt		; NMI already disabled ?
		bne  +
		jsr  __nmi_dis			; if not, then disable now
		ldx  #lsem_nmi			; make sure semaphore number is valid
	+	php
		sei
		lda  #SKIP_WORDV		; remove NMI-Job
		sta  _nmi_jobptr
		lda  #<_nmi_donothing		; reset enable and disable call
		sta  _nmi_dis+1
		sta  _nmi_ena+1
		lda  #>_nmi_donothing
		sta  _nmi_dis+2
		sta  _nmi_ena+2
_nmi_donothing:
		plp
		rts

__nmi_dis:
		php
		sei
		jmp  _nmi_dis
