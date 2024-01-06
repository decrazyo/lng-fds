		;; For emacs: -*- MODE: asm; tab-width: 4; -*-

		;; adding tasks to the system

		;; C128 native by Maciej 'YTM/Elysium' Witkowiak <ytm@friko.onet.pl>
		;; 12,13.1.2000; 09.2.2000 (MMU_STACK)

#include <config.h>
#include <system.h>
#include <kerrors.h>
#include MACHINE_H

.global addtask

		;; function: int_fddup
		;; < A=fn
		;; increase reader/writer counter of stream
		;; according to flags (readable/writeable)
		;; calls: get_smbptr
		;; calls: ref_increment

int_fddup:
		cmp  #MAX_FILES
		bcs  illfs+1
		adc  #tsp_ftab
		tay
		lda  (lk_tsp),y
		beq  +
		pha
		tax
		jsr  get_smbptr
		bcs  illfs
		jsr  ref_increment
		pla
	+	rts

illfs:		pla
		lda  #0
		rts

		;; function: addtask
		;; < X/Y = address of code to execute
		;; < A = priority (1-7)
		;; add task to scheduler
		;; syszp:	0=stdin, 1=stdout, 2=stderr (will be dupped),
		;; syszp+3=codebase_hi (-> syszp+7 in new context),
		;; syszp+4/5=parameter-structure ([5]=0 if none)

		;; changes:		tmpzp(0,1,2,3,4,5,6,7)
		;; changes:		syszp(4,5)
		;; calls: spalloc
		;; calls: int_fddup
		;; calls: p_insert

addtask:
		;; find+allocate slot in taskqueue
		php
		sei						; no IRQ in here
		stx  tmpzp+3
		sty  tmpzp+4			; remember code address
		sta  tmpzp
		ldx  #31
	-	lda  lk_tstatus,x
		beq  +					; found a unused slot
		dex
		bpl  -
		ldy  #lerr_toomanytasks
		bmi  skipadd			; (always jump)

		;; allocate slot

	+	lda  lk_ipid
		bmi  +
		tay
		lda  lk_tstatus,y
	+	and  #tstatus_pri		; get priority of current task
		cmp  tmpzp
		bcc  +
		lda  tmpzp			; only use wanted priority, if it is
		                    		; smaller, than that of the current task
		bne  +
		lda  #1				; priority must be at least 1!

	+	ora  #tstatus_susp|tstatus_nosig|tstatus_szu
		sta  lk_tstatus,x		; flags:  susp, nosig, szu

		stx  tmpzp+2			; remember IPID of new task

		;; do as less as possible for the new task (he should do as much as
		;; possible on itself!)

		;; set up TSP (task-super-page), arguments page and environment page

		ldy  #$80			; no I/O (since it is accessed from the kernel,
		jsr  spalloc			; which runs with I/O enabled)
		bcc  +				; got a page, so continue
		jmp  _nomem_err
	+	txa
		sta  tmpzp+7			; remember environment page
		ldx  tmpzp+2
		ldy  #$80
		jsr  spalloc
		bcc  +
		;; free 1 and return error
		jmp  _free1
	+	txa
		sta  tmpzp+6			; remember TSP page
		ldx  tmpzp+2
		ldy  #$80
		jsr  spalloc			; allocate args page
		bcc  +
		;; free 2 and return error
		ldx  tmpzp+6
		jsr  pfree
_free1:		ldx  tmpzp+7
		jsr  pfree

_nomem_err:	ldy  #lerr_outofmem
		SKIP_WORD
_illarg_err:	ldy  #lerr_illarg
		ldx  tmpzp+2
		lda  #0				; release task slot
		sta  lk_tstatus,x
skipadd:
		plp
		tya
		sec				; error (you may try again later)
		rts

free3nskip:	;; free 3 and return illarg error
		ldx  tmpzp+1
		jsr  pfree
		ldx  tmpzp+6
		jsr  pfree
		ldx  tmpzp+7
		jsr  pfree
		jmp  _illarg_err

		;; ok have 3 pages allocated
		;; copy commandline arguments into new task's context

	+	stx  tmpzp+1			; address of allocated page (IRQ is still disabled!)
		ldy  #0
		sty  tmpzp
		ldx  #0				; count number of arguments

		clc				; skip stdin/out/err channels in exec-structure
		lda  syszp+4
		adc  #3
		sta  syszp+4
		lda  syszp+5
		beq  nostruc			; skip if hi byte is zero
		adc  #0
		sta  syszp+5

	-	lda  (syszp+4),y		; exec-structure
		sta  (tmpzp),y
		beq  +				; of of filename
		iny
		bne  -

		;; illegal argument structure
		;; free 3 pages and return illarg
	-	jmp  free3nskip

	+	inx
		iny
		beq  -
		lda  (syszp+4),y
		bne  --
		sta  (tmpzp),y

nostruc:
		ldy  tmpzp+1
		lda  tmpzp+6			; get address of second allocated page
		sta  tmpzp+1			; address of allocated page (IRQ is still disabled!)
		tya
		ldy  #tsp_swap+1
		sta  (tmpzp),y			; store address of arguments page in userzp+1
		txa
		dey
		sta  (tmpzp),y			; store number of arguments in userzp+0


#ifndef MMU_STACK

		;; set up simple stack
		ldy  #255
		lda  #>task_init		; address hi-byte (init)
		sta  (tmpzp),y			; (1)
		dey
		lda  #<task_init		; address lo-byte (init)
		sta  (tmpzp),y			; (2)
		dey
		lda  #0				; SR=0
		sta  (tmpzp),y			; (3)
		dey
		sta  (tmpzp),y			; A=0 (4)
		dey
		sta  (tmpzp),y			; X=0 (5)
		dey
		sta  (tmpzp),y			; Y=0 (6)
		dey
		lda  #MEMCONF_USER		; use default memory configuration
		sta  (tmpzp),y			; memconfig=standard  (= total 7 bytes)

#else
		;; we're acting differently on a C128 with MMU stackswapping
		ldy MMU_P1L			;; get current stack ptr (we're still in current task)
		tsx
		stx tmpzp+5			;; store it (seems unused here)
		lda tmpzp+2			;; new IPID is here
		sta MMU_P1L			;; this is new task's stack
		ldx #$ff			;; now let's setup stack
		txs
		lda #>task_init
		pha				;; (1)
		lda #<task_init
		pha				;; (2)
		lda #0
		pha				;; (3) SR=0
		pha				;; (4) A
		pha				;; (5) X
		pha				;; (6) Y
		GETMEMCONF			; use current memory configuration (caller knows better)
		pha				;; (7) memconfig

						;; restore kernel-stack (in fact parent process stack)
		ldx tmpzp+5
		txs
		sty MMU_P1L

#endif

		lda  #7				; stacksize=7
		ldy  #tsp_stsize
		sta  (tmpzp),y
		lda  #2
		ldy  #tsp_zpsize
		sta  (tmpzp),y			; value for initial zeropage size (2= argv/*argc)

		lda  lk_taskcnt			; increase task counter and set PID of task
		adc  #1
		sta  lk_taskcnt
		ldy  #tsp_pid
		sta  (tmpzp),y
		lda  lk_taskcnt+1
		adc  #0
		sta  lk_taskcnt+1
		iny
		sta  (tmpzp),y

		lda  lk_ipid			; set ippid
		ldy  #tsp_ippid			; (internal parent process ID)
		sta  (tmpzp),y

		lda  tmpzp+3			; address lo-byte (task code)
		ldy  #tsp_syszp
		sta  (tmpzp),y			; put it to syszp
		lda  tmpzp+4			; address hi-byte (task code)
		iny
		sta  (tmpzp),y			; to syszp+1

		lda  syszp+3			; codebase_hi
		iny
		sta  (tmpzp),y			; to syszp+2

		lda  syszp+1			; (fd of stdout)
		pha

		lda  syszp			; (fd of stdin)
		jsr  int_fddup			; (changes syszp(0,1) !)
		ldy  #tsp_ftab
		sta  (tmpzp),y			; to ftab entry 0

		pla				; (fd of stdout)
		jsr  int_fddup
		ldy  #tsp_ftab+1
		sta  (tmpzp),y			; to ftab entry 1

		lda  syszp+2			; (fd of stderr)
		jsr  int_fddup
		ldy  #tsp_ftab+2
		sta  (tmpzp),y			; to ftab entry 2

		;; inherited settings...

		ldy  #tsp_pdmajor
	-	lda  (lk_tsp),y
		sta  (tmpzp),y			; copy pdminor, pdmajor, termwx and termwy
		iny
		cpy  #tsp_termwy+1
		bne  -

		;; inherit environment variables

		lda  tmpzp+7			; get allocated env table address
		ldy  #tsp_envpage
		sta  (tmpzp),y			; store new pointer
		lda  (lk_tsp),y			; get old pointer
		sta  tmpzp+5
		ldy  #0
		sty  tmpzp+4
		sty  tmpzp+6

	-	lda  (tmpzp+4),y		; copy parent's environment
		sta  (tmpzp+6),y
		iny
		bne  -

		;; add to scheduler

		ldx  tmpzp+2			; IPID of new task
		lda  tmpzp+1
		sta  lk_ttsp,x			; set pointer to tsp

		jsr  p_insert			; insert into task CPU-queue (X unchanged)

		ldy  #tsp_pid
		lda  (tmpzp),y
		tax
		iny
		lda  (tmpzp),y
		tay
		plp
		clc
		rts				; return without error (X/Y=PID of child)

		;; function: task_init
		;; this is what a new task will execute first

task_init:
		lda  #>(suicide-1)
		pha
		lda  #<(suicide-1)
		pha				; last rts in the task will jump to "suicide"
		lda  syszp+1
		pha				; address (hi) of task's code
		lda  syszp
		pha				; address (lo) of task's code (need rti!!)
		php

		;; set up tsp

		lda  #0
		ldy  #tsp_zpsize-1
	-	sta  (lk_tsp),y			; initialize time,wait,semmap,signal_vec[0-7],
		dey				; pdmajor,pdminor,ftab[0-7],zpsize with $00
		bpl  -
		ldy  #tsp_ftab+3
	-	sta  (lk_tsp),y			; initialize ftab[3..MAX_FILES]
		iny
		cpy  #tsp_ftab+MAX_FILES
		bne  -

		ldy  syszp+2			; exe-parameter -> Y  (codebase_hi for reloc_and_exec)

		ldx  lk_ipid
		lda  lk_tstatus,x
		and  #$ff-(tstatus_szu|tstatus_nosig)
		sta  lk_tstatus,x

		rti				; jump to task's code (normally reloc_and_exec)
