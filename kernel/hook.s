; For emacs: -*- MODE: asm; tab-width: 4; -*-

		;; hook into the system by a IRQ or NMI or alert handler

		;; the system must register in some way, that the task
		;; has installed a handler. I think this can be done by
		;; passing a semaphore. (->lock)
		;; by unlocking the semaphore the handler is de-installed.
		
		
		;; hook in by IRQ

#include <system.h>
#include <kerrors.h>
		
.global hook_irq
.global hook_alert
.global hook_nmi
.global disable_nmi
.global enable_nmi
.global _nmi_ena
.global _nmi_dis
		
		;; function: hook_irq
		;; Note: you must disable IRQ before using tmpzp (!)
		;; and keep it disabled as long as tmpzp must not be modified
		;; by another task
		
		;; bit pattern for
		;;   lsem_irq1 = $0000000001 (No. 0)
		;;   lsem_irq2 = $0000000002 (No. 1)
		;;   lsem_irq3 = $0000000004 (No. 2)
		
		;; < X/Y=address of handler
		;; changes: tmpzp(0,1,2)
		
hook_irq:
		clc
		php
		sei
		stx  tmpzp
		sty  tmpzp+1
		
		lda  lk_semmap+0		; lowest byte of semaphore map
		and  #%00000111
		cmp  #%00000111
		beq  _err_hook			; all slots allocated, then return with error
		ldx  #0
		lsr  a
		bcc  +					; X=0, if lsem_irq1 is unused
		
		inx
		lsr  a
		bcc  +					; X=1, if lsem_irq2 is unused
		
		inx						; X=2, if lsem_irq3 is nuused
		clc						; perform lock of sem. (non blocking)
		
	+	stx  tmpzp+2
		jsr  lock
		ldx  tmpzp
		ldy  tmpzp+1			; (address of handler)
		lda  tmpzp+2
		beq  _alloc_irq1
		lsr  a
		lda  #$20
		bcs  _alloc_irq2

		sty  _irq_jobptr+8		; (allocate slot 3)
		stx  _irq_jobptr+7
		sta  _irq_jobptr+6
		lda  #lsem_irq3
		plp						; enable IRQ and clear carry
		rts

_alloc_irq1:	
		stx  _irq_jobptr+1		; (allocate slot 1)
		sty  _irq_jobptr+2
		lda  #$20
		sta  _irq_jobptr
		lda  #lsem_irq1
		plp
		rts

_alloc_irq2:	
		stx  _irq_jobptr+4		; (allocate slot 2)
		sty  _irq_jobptr+5
		sta  _irq_jobptr+3
		lda  #lsem_irq2
		plp
		rts

		;; function: hook_alert
		;; install a alarm handler (triggered by TOD of CIA1)
          
		;; < X/Y=address of handler
		
hook_alert:						; hook into alert
		clc
		php
		sei
		stx  tmpzp
		sty  tmpzp+1
		ldx  #lsem_alert		; try to lock semaphore
		jsr  lock				; (non blocking)
		bcs  _err_hook			; already locked, then no slot error
		ldx  tmpzp
		ldy  tmpzp+1
		lda  #$20
		sta  _irq_alertptr		; allocate slot
		stx  _irq_alertptr+1
		sty  _irq_alertptr+2
		plp
		rts
          
_err_hook:
		plp
		lda  #lerr_nohook
		jmp  catcherr

; pointer passed to nmihook points to a structure containing :
;
;   jmp  nmi_handler   - must return with rts
;   jmp  nmi_disable   - must return with plp:rts
;   jmp  nmi_enable    - must return with plp:rts
;
; nmi_disable disables NMI (eg. called before using the IEC serial bus)
; nmi_enable  enables NMI (eg. called after using the IEC serial bus)
;  (enable is also called by the kernel, if nmihook was successfull)

		;; function: hook_nmi
		;; < X/Y=address of handler
		;; calls: lock
hook_nmi:
		clc
		php
		sei
		stx  tmpzp
		sty  tmpzp+1
		ldx  #lsem_nmi			; hook into NMI
		jsr  lock				; (non blocking)
		bcs  _err_hook			; error if not available
		lda  #$4c
		ldy  #0					; first check for $4c $xx $xx $4c $xx $xx $4c
		cmp  (tmpzp),y
		bne  +
		ldy  #3
		cmp  (tmpzp),y
		bne  +
		ldy  #6
		cmp  (tmpzp),y
		bne  +

		ldy  #1
		sta  _nmi_jobptr		; insert NMI-Job
		lda  (tmpzp),y
		sta  _nmi_jobptr+1
		iny
		lda  (tmpzp),y
		sta  _nmi_jobptr+2
          
		ldy  #4					; init disable-call
		lda  (tmpzp),y
		sta  _nmi_dis+1
		iny
		lda  (tmpzp),y
		sta  _nmi_dis+2

		ldy  #7					; init enable-call
		lda  (tmpzp),y
		sta  _nmi_ena+1
		iny
		lda  (tmpzp),y
		sta  _nmi_ena+2

		lda  lk_nmidiscnt		; can i enable the NMI now ?
		bne  _nmi_donothing		; sorry, maybe next time :)
		jmp  _nmi_ena

_nmi_donothing:
		plp
		rts
          
	+	plp
		lda  #lerr_illarg
		jmp  suicerrout
          
		;; function: disable_nmi
		;; disable NMI temporary
		  
disable_nmi:
		php
		sei
		ldx  lk_ipid
		lda  lk_tstatus,x
		and  #tstatus_nonmi
		bne  _nmi_donothing		; already disbled, do nothing
		lda  lk_tstatus,x
		ora  #tstatus_nonmi
		sta  lk_tstatus,x		; set NMI-bit
		inc  lk_nmidiscnt		; increment number of processes that have
		lda  lk_nmidiscnt		; disabled NMI
		cmp  #1
		bne  _nmi_donothing		; NMI already disabled, then just return
_nmi_dis:
		jmp  _nmi_donothing

		;; function: enable_nmi
		;; enable temporary disabled NMI
		
enable_nmi:
		php
		sei
		ldx  lk_ipid
		lda  lk_tstatus,x
		and  #tstatus_nonmi
		beq  _nmi_donothing		; already enabled, do nothing
		eor  lk_tstatus,x
		sta  lk_tstatus,x		; clear NMI-bit
		dec  lk_nmidiscnt		; decrement nmuber of processes...
		bne  _nmi_donothing		; still staying disabled ? then just return
_nmi_ena:
		jmp  _nmi_donothing
