		;; For emacs: -*- MODE: asm; tab-width: 4; -*-

		;; taskswitcher

		;; timer 1 of CIA $cc00 generates IRQs every 1/64 second
		;; timer 2 of CIA $cc00 measures the exact time spend in the task
		;;                      since the last IRQ
		
		;; every process can force a taskswitch, if there is nothing
		;; more to do. (the unused CPU time can't be collected for later
		;; use!)

		;; C128 code by Maciej 'YTM/Alliance' Witkowiak <ytm@friko.onet.pl>
		;; 10,11,12.01.2000 - required changes, still doesn't work
		;; 18.01 - finally works - swapper_idle was overwritting last stack, now it
		;;	   has own one at $00100 (remember to always set MMU_P1H!)
		;; 19.01 - expanded C128 have problems with that $00100, changed it
		;;	   to $1d000
		;; 31.01 - REU/C64/C128 swapping code moved to machine-depended files
		;; 09.02 - introduced MMU_STACK option
		;; 10.02 - removed HAVE_256K - all C128s need it

#include <config.h>
		
#include MACHINE_H				
#include <system.h>
#include <kerrors.h>

.global force_taskswitch
.global irq_handler
.global _irq_jobptr
.global _irq_alertptr
.global idle_task
.global locktsw
.global unlocktsw

;;; externals:	 _wakeup suicerrout brk_handler

		;; function: force_taskswitch
		;; force a task (context) switch
		;; changes: tmpzp(0,1,2,3,4,5,6,7)
		
force_taskswitch:
		;; emulate IRQ
		php						; push status
		sei						; no IRQ here please
		pha						; push akku
		txa
		pha						; push X
		tya
		pha						; push Y
		;; adapt return address
		cld						; must do this, to make adc work properly
		clc
		tsx
		txa
		adc  #5
		tax
		inc  $100,x				; correct return address
		bne  +					; because rti will be used instead of rts !
		inx
		inc  $100,x
		;; jump to end of time slice
	+	lda  #1
		sta  lk_timer
		jmp  irq_handler_2

to_brk:	jmp  brk_handler

irq_handler:
		pha
		txa
		pha
		tya
		pha
		tsx
		lda  $104,x
		and  #$10
		bne  to_brk
 
irq_handler_2:
		;; push memory configuration
		GETMEMCONF				; get current memory configuration
		pha						; (remember)
		lda  #MEMCONF_SYS		; change value for IRQ/NMI memory conf.
		SETMEMCONF				; -> C64-KERNAL-ROM + I/O
		cld						; (might need arithmetic)

		;; system dependend taskswitching core
		;;  includes:	 _checktimer
		;;               _irq_jobptr
		;;               _irq_alertptr
		
#		include MACHINE(tasksw.s)
				
		;; taskswitching...
_idle:
		ldy  lk_locktsw			; don't to anything, 
		bne  do_taskswitch		; if taskswitching is locked
								; if CPU has been idle...
		and  #$7f				; is there a task to switch to from idle state
		cmp  #$20
		tay
		bcc  _activate_this		; yes, then go ahead
		
	-	lda  #1					; no, then wait 1/64s and look again
		sta  lk_timer
		jmp  _checktimer

		;; a stack overflow is a serious thing (and hard to track)
_stackoverflow:	
		ldx  #255
		txs						; be sure there now is enough stack available
		lda  #lerr_stackoverflow
		jmp  suicerrout			; this is a dirty hack and might cause
		                        ; problems, because interrupts may get lost!
		                        ; but its a rare situation and i want to save
		                        ; memory
		
	-	ora  #$80				; set flag
		sta  lk_locktsw
		bne  --					; (always jump)
		
do_taskswitch:
		lda  lk_locktsw			; a way to disable taskswitches without sei/cli
		bne  -

		;; save environment of current task (zeropage and stack)

		;; task superpage:
		;;  offset				contents
		;;  -----------------------------------------
		;;  tsp_swap,...		copy of used zeropage
		;;  ...,$ff				copy of used stack


#ifdef C128
#		include MACHINE(stackout.s)
#else
# ifdef HAVE_REU
#		include "opt/reu_stackout.s"
# else
#		include MACHINE(stackout.s)
# endif
#endif

#ifdef HAVE_REU
#		include "opt/reu_zpageout.s"
#else
#		include MACHINE(zpageout.s)
#endif
		
		; done, y holds IPID of current task
		
		;; switch to the next task

		ldx  lk_tnextt,y		; IPID of next task
		lda  lk_tstatus,y
		and  #tstatus_susp		; switchted away from a suspended
		beq  +					; task ?
		lda  #$ff				; yes, then destroy old next-pointer
		sta  lk_tnextt,y
	+	txa

_activate_this:
		sta  lk_ipid
		bmi  _swapperidle		; no task to switch to, then we're idle
		tay
		lda  lk_tslice,y		; time for the next task
		sta  lk_timer
		lda  lk_ttsp,y			; superpage of the next task
		sta  lk_tsp+1

		;; reload environment of the task (zeropage and stack)

#ifdef HAVE_REU
#		include "opt/reu_zpagein.s"
#else
#		include MACHINE(zpagein.s)
#endif

#ifdef C128
#		include MACHINE(stackin.s)
#else
# ifdef HAVE_REU
#		include "opt/reu_stackin.s"
# else
#		include MACHINE(stackin.s)
# endif
#endif

 		jmp  _checktimer		; look for timer interrupts
		
_swapperidle:
		;; if there is no other task to switch to
		;; we have the problem, that we can't return by rti, because there
		;; is nothing to return to.

#ifdef MMU_STACK
		;; we're using end of stack, so we must provide a new stack
		;; at $1d000  (in 2nd bank, under I/O)
		ldx #$d0
		stx MMU_P1L

		;; this works in VICE X128, so it should work in a stock C128
		;; here I use address $00100 (default), but it can be any page,
		;; where last 10 (at least) bytes are unused
		;; suprisingly MMU bug was discovered and this doesn't work!
		;; (some bytes at stack are lost)
		;ldx #1
		;stx MMU_P1L
		;dex						;X=0
		;stx MMU_P1H
		;dex						;X=255
#endif

		ldx  #255
		txs
		lda  #>idle_task
		pha						; pc lo
		lda  #<idle_task
		pha						; pc hi
		lda  #0
		pha						; sr
		pha						; a
		pha						; x
		pha						; y
		GETMEMCONF				; get current memory configuration
		pha						; (1)
		jmp  _checktimer
		
idle_task:
		;; this is, what the system does, when there is nothing to do
		;; (do what you want here)
		jsr  update_random
		jmp  idle_task

		;; function: locktsw
		;; lock taskswitching without (!) disabling IRQ
		;;  used by:	mpalloc spalloc pfree
locktsw:   
		inc  lk_locktsw
		rts

		;; function: unlocktsw
		;; problem=
		;; task can not be killed while it has disabled taskswitches,
		;; IRQ or NMI handler may not call functions, that disable
		;; taskswitches this way. (may lead to data inconsistency)
		;; (a NMI handler must not call any kernel routine for that reason !)
		;; another problem is killing/sending signals to a suspended task !

		;; might call force_taskswitch
		;; changes: context
		
unlocktsw:
		php
		sei
		dec  lk_locktsw
		lda  lk_locktsw
		asl  a					; check bit 7 and bits 0-6
		bne  +					; (if there are nested "locktsw"s)
		;; taskswitching is enabled again, check if there is a pending
		;; taskswitch
		bcc  +
		sta  lk_locktsw			; clear bit 7
		pla
		and  #$04				; check I-flag
		bne  ++					; I-flag set, so don't do a taskswitch
		cli
		jmp  force_taskswitch

	+	plp
	+	rts

