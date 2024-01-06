		;; error and termination

#include <config.h>
#include <system.h>
#include <kerrors.h>

.global catcherr
.global suicerrout
.global print_error
.global suicide
.global hexout
		
		;; function: catcherr
		;; return from kernel or module function bach to user application
		;; with error, if next instruction in user context is "nop" catcherr
		;; will jump to suicerrout
		;; < A=error code, that should be returned to main program
		;; calls: suicide
		;; changes:	tmpzp(0,1,2,3,4)
catcherr:
		sei
		sta  tmpzp+2
		stx  tmpzp+3
		sty  tmpzp+4
#ifndef ALWAYS_SZU
		ldx  lk_ipid
		lda  lk_tstatus,x
		and  #$ff-tstatus_szu
		sta  lk_tstatus,x
#endif
		tsx
		inx
		lda  $100,x
		sta  tmpzp
		inx
		lda  $100,x
		sta  tmpzp+1
		ldy  #1
		lda  (tmpzp),y
		cmp  #234
		beq  +					; next opcode in userspace is NOP
		lda  tmpzp+2
		ldx  tmpzp+3
		ldy  tmpzp+4
		cli
		sec
		rts

	+	lda  tmpzp+2
		
		;; function: suicerrout
		;; kill current task, but print a error message first
		;; < A=error code
		;; calls: suicide
		;; calls: print_error
suicerrout:
		jsr  print_error

		;; function: suicide
		;; kill current task
		;; < A=exit code
		;; changes: task
suicide:
		;; unlock used ressources
		pha
		sei
		ldx  lk_ipid
		lda  lk_tstatus,x
		ora  #tstatus_szu|tstatus_nosig
		sta  lk_tstatus,x		; used system zeropage (syszp)
		cli
		lda  #0
		sta  lk_locktsw			; be sure IRQ+taskswitches are enabled

		lda  #2
		jsr  set_zpsize
		
		pla
		sta  userzp				; userzp=exitcode

		;; close all opened files
		ldx  #0
		
	-	stx  userzp+1
		jsr  fclose
		ldx  userzp+1
		inx
		cpx  #MAX_FILES
		bne  -
		
		;; unlock used ressources
		lda  #4
		sta  syszp+3
		lda  #32
		sta  syszp+2

	-	clc
		lda  syszp+3
		adc  #tsp_semmap
		tay
		lda  (lk_tsp),y
		beq  ++					; skip 8 semaphores
		ldx  syszp+2
	-	lsr  a
		bcc  +
		;; need unlock
		jsr  unlock
		jmp  --
	+	inx
		bne  -
	+	dec  syszp+3
		sec
		lda  syszp+2
		sbc  #8
		sta  syszp+2
		bpl  --

		;; enable nmi, if it had been disabled
		ldx  lk_ipid
		lda  lk_tstatus,x
		and  #tstatus_nonmi
		beq  +
		jsr  enable_nmi

		;; free all used internal memory (exept tsp)
	+	lda  lk_ipid
		ldx  #2					; first possible page
	-	cpx  lk_tsp+1
		beq  +
		cmp  lk_memown,x
		bne  +
		txa
		pha
		jsr  pfree
		pla
		tax
		lda  lk_ipid
	+	inx
		bne  -

		;; look for children, that try to serve their exitcode to this
		;; task

		lda  #waitc_zombie
		ldx  lk_ipid
		sei
		jsr  mun_block			; unblock all affected tasks
		;; and change children's ippid to $ff (they have no parent any more)
		lda  #0
		sta  tmpzp
		ldy  #tsp_ippid
		ldx  #$1f
	-	lda  lk_tstatus,x
		beq  +
		lda  lk_ttsp,x
		sta  tmpzp+1
		lda  (tmpzp),y
		cmp  lk_ipid
		bne  +
		lda  #$ff
		sta  (tmpzp),y
	+	dex
		bpl  -		
		cli
		
		;; serve exitcode
		sei
		ldy  #tsp_ippid
		lda  (lk_tsp),y			; get IPID of parent process
		bmi  exdone					; skip if there is no parent

		tax						; check if, parent is already waiting
		lda  lk_tstatus,x
		and  #tstatus_susp|tstatus_nosig ; is parent suspended or killed ?
		beq  +					; not, then ok
		and  #tstatus_susp
		beq  exdone				; skip if parent is already dieing
		lda  lk_ttsp,x
		sta  syszp+3
		lda  #0
		sta  syszp+2
		ldy  #tsp_wait0
		lda  (syszp+2),y
		cmp  #waitc_wait		; suspended because of 'wait'
		bne  +					; not, then ok

		;; parent is already waiting for my exitcode
		jsr  p_insert			; wakeup parent
		jmp  ++
		
		;; parent does something else, try to send signal sig_chld
	+	lda  #sig_chld
		sta  tmpzp+4
		jsr  _raw_sendsignal
		
	+	lda  userzp
		ldy  lk_ipid
		sta  lk_tslice,y		; current_task->tslice=exitcode
		lda  #waitc_zombie		; so he can fetch my exitcode (X=PPID)
		jsr  block				; suspend current task
		;; (continues, if parent read the exitcode)
exdone:	cli
		
		;; done...
		sei
		ldx  lk_tsp+1
		jsr  pfree				; free tsp
		
		ldx  lk_ipid			; get ipid of next task
		jsr  p_remove			; remove task from CPU-queue

		lda  #0
		sta  lk_locktsw			; make sure there will be a taskswitch
		sta  lk_tstatus,x		; remove from task list
		ldy  lk_tnextt,x		; IPID of next task
		lda  #$ff
		sta  lk_tnextt,x		; destroy old next pointer
		tya
		bmi  +
		ora  #$80
		sta  lk_ipid			; switch without saving current context

		jsr  force_taskswitch	; switch to next task

		;; nowhere to switch to, then jump to idle_task
	+	sta  lk_ipid			; $ff -> IPID (system is IDLE)
		cli
		jmp  idle_task
		
		;; function: print_error
		;; print a standard error message to stdout or (if not
		;; available) use printk
		;; < A=error code
		;; calls: printk or fputc
		;; calls: hexout

print_error:
		pha
		lda  #"["
		jsr  putcerr
		ldy  #tsp_pid+1
		lda  (lk_tsp),y
		jsr  hexout
		dey
		lda  (lk_tsp),y
		jsr  hexout		
		lda  #"]"
		jsr  putcerr
		ldx  #0
	-	lda  err_txt,x
		beq  +
		jsr  putcerr
		inx
		bne  -
	+	pla
		pha
#ifdef VERBOSE_ERROR
		cmp  #$e6				; <======= adapt to number of errors!
		bcs  textual_errormessage
#endif
		jsr  hexout
		lda  #$0a
		jsr  putcerr
		pla
		rts

#ifdef VERBOSE_ERROR
textual_errormessage:
#ifndef ALWAYS_SZU
		sei
		sta  syszp+2
		ldx  lk_ipid
		lda  lk_tstatus,x
		ora  #tstatus_szu
		sta  lk_tstatus,x		; used system zeropage (syszp)
		cli
#else
		sta  syszp+2
#endif
		lda  #<error_messages
		sta  syszp
		lda  #>error_messages
		sta  syszp+1
		ldy  #0
		
	-	inc  syszp+2
		beq  foundtxt
	-	iny
		bne  +
		inc  syszp+1
	+	lda  (syszp),y
		bne  -
		iny
		bne  --
		inc  syszp+1
		bne  --

foundtxt:
		clc
		tya
		adc  syszp
		pha
		lda  syszp+1
		adc  #0
		pha

#ifndef ALWAYS_SZU
		sei
		ldx  lk_ipid
		lda  lk_tstatus,x
		and  #$ff-tstatus_szu
		sta  lk_tstatus,x
		cli
#endif

cloop:
		sei
		pla
		sta  tmpzp+1
		pla
		sta  tmpzp
		clc
		adc  #1
		pha
		lda  tmpzp+1
		adc  #0
		pha
		ldy  #0
		lda  (tmpzp),y
		cli
		beq  +
		jsr  putcerr
		jmp  cloop
		
	+	pla
		pla
		lda  #$0a
		jsr  putcerr
		pla
		rts

		;; "0123456789012345678901234567890123456789"
		;; "[xxxx] unhandled: ......................"

		;;    >......................<

error_messages:	
		.text "stack overflow", 0
		.text "no hook into system", 0
		.text "illegal argument", 0
		.text "semaphore locked", 0
		.text "device error", 0
		.text "illegal filenumber", 0
		.text "no such file", 0
		.text "unimplemented function", 0
		.text "low on internal memory", 0
		.text "too many files", 0
		.text "end of file", 0
		.text "broken pipe", 0
		.text "try again", 0
		.text "I/O error", 0
		.text "illegal code", 0
		.text "no such module", 0
		.text "illegal module", 0
		.text "too many tasks", 0
		.text "disc full", 0
		.text "readonly filesystem", 0
		.text "file locked", 0
		.text "file exists", 0
		.text "no such pid", 0
		.text "killed" ,0
		.text "no such directory",0
		.text "segmentation fault",0
#endif
		
		;; function: hexout
		;; print 8bit number in hex
		;; (uses printk, so is only usefull for kernel or
		;; module functions!)
		;; calls: printk
hexout:	pha
		lsr  a
		lsr  a
		lsr  a
		lsr  a
		jsr  +
		pla
		and  #15
	+	tax
		lda  hextab,x
putcerr:
		sei
		sta  tmpzp
		txa
		pha
		tya
		pha
		ldy  #tsp_ftab+2		; stderr available ?
		lda  (lk_tsp),y
		beq  +
		lda  tmpzp
		cli
		sec
		ldx  #2
		jsr  fputc
	-	pla
		tay
		pla
		tax
		rts

	+	lda   tmpzp
		cli
		jsr  printk
		jmp  -
		
hextab:	.asc "0123456789abcdef"		

err_txt:
#ifdef VERBOSE_ERROR
		.text " unhandled: "
#else
		.text " unhandled error "
#endif
		.byte $00
