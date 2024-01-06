		;; LUnix's spawn function

#include <config.h>
#include <system.h>
#include <kerrors.h>
#include <fs.h>

		.global forkto

_alloc1_error:
		pla
		pla
		pla
		lda  #lerr_outofmem
		jmp  catcherr

_load_error:
		tay
		pla
_o65_error:
		pla

_fopen_error:
		pla
		pla
		tya
		jmp  catcherr

		;; function: forkto
		;; load and start a new process
		;; < A/Y = address of structure:
		;; <	.byte stdin_fd, stdout_fd, stderr_fd
		;; <	.asc  "<filename>\0"
		;; <		optional: .asc "<parameter>\0"
		;; <		...
		;; <	.asc "\0"
		;; > c=1: error (error number in A)
		;; > c=0: X/Y = child's PID
		;; changes: syszp(0,1,2,3,4,5,6,7)
		;; calls: fopen,spalloc,mpalloc,pfree,addtask,catcherr
		;; calls: fgetc,exe_test,reloc_and_exec,loado65

forkto:
		pha				; address of struct (lo)
		clc
		adc  #3
		tax
		tya
		pha				; address of struct (hi)
		bcc  +
		iny
	+	txa
		ldx  #fmode_ro
		jsr  fopen
		tay
		bcs  _fopen_error

#ifndef ALWAYS_SZU
		ldy  lk_ipid
		sei
		lda  lk_tstatus,y
		ora  #tstatus_szu
		sta  lk_tstatus,y
		cli
#endif
		txa
		pha				; fd
		sta  syszp+7
		ldx  lk_ipid
		ldy  #0
		jsr  spalloc
		bcs  _alloc1_error
		txa
		pha				; start address (hi)
		ldy  #0
		sty  syszp
		ldx  syszp+7			; fd

#ifdef HAVE_O65

		jsr  fgetc
		pha                       ; byte 1
		jsr  fgetc
		sei
		stx syszp+7
		tax
		pla                       ; byte 1
		cmp #>LNG_MAGIC           ; $fffe
		bne _o65_load
		cpx #<LNG_MAGIC
		beq _lng_load

_o65_load:
		cmp #<O65_MAGIC           ; $0001
		bne script_run
		cpx #>O65_MAGIC
		bne script_run
		pla             ;start adr hi
		tax
		jsr pfree		; free temporary page (not needed for .o65)
		cli

		ldx syszp+7		; fd
		jsr loado65
		bcc +
		tay
		jmp _o65_error		; (pla 3 times)

		;;
		;;---- start script runner
		;;

TMPCHR  equ syszp
LOOPC	equ syszp+1
SPTR	equ syszp+2  ;+3
SPTR_L	equ SPTR
SPTR_H	equ SPTR+1
DPTR	equ syszp+4  ;+5
DPTR_L	equ DPTR
DPTR_H	equ DPTR+1
TMPFD	equ syszp+7

__fget:
		; get FD into X
		tsx
  		;inx ; return adr.
  		;inx ;   "     "
		;inx ; lcnt
		;inx ; start
		;inx ; fd
		lda	$0105,x
		tax
  		jsr fgetc
		nop
		rts

		; read variables from stack into
		; syszp
__sfget:
		tsx
  		;inx ; return adr.
  		;inx ;   "     "
		;inx ; loopc
		lda	$0103,x
		sta LOOPC
		tay

		;inx ;start
		lda	$0104,x
		sta DPTR_H

		;inx ;fd
		lda	$0105,x
		sta TMPFD

		;inx ;sptr_h
		lda	$0106,x
		sta SPTR_H

		;inx ;sptr_l
		lda	$0107,x
		sta SPTR_L

		rts

script_run:
   		cmp #"#"
		bne _not_script
		cpx #"!"
		bne _not_script

		;; init stackframe

		lda #0       ; loop counter
		pha

		;; read and check 3rd character
		;; aswell (must be space)

		jsr __fget
		cmp #" "
		bne __not_script

		;; copy interpreter name + eventual switches
		;; from scriptfile

ilp1:
		jsr __fget
 		bcs ilp2    ; error

 		cmp #$0a    ; end of line
 		beq ilp2

 		cmp #" "	; replace spaces by zeros
		bne ilp3
		lda #0
ilp3:
		sta TMPCHR   ; temp: char read

		jsr __sfget
		lda #3
		sta DPTR_L

		lda TMPCHR   ; temp: char read
		sta (DPTR),y

		; restore stack, inc loopc

;;		ldy LOOPC
		iny
		beq ilp2		; for safety
		tya

		; store loopc
		tsx
		;inx ;loopc
		sta	$0101,x

		jmp ilp1

ilp2:
		;; interpreter/switches read ok

		jsr __sfget
		lda #3
		sta DPTR_L

		;; put 0 after interpreter/switches
		lda #0
		sta (DPTR),y
		iny
		sty LOOPC
		sty DPTR_L

		;; copy name of script to argument list
		ldy #3
ilp5:
		lda (SPTR),y
  		sta (DPTR),y
		beq ilp6
		iny
		bne ilp5
ilp6:
  		;; 2 more zeros at end of argument list
		iny
		sta (DPTR),y
  		iny
		sta (DPTR),y

		;; close input file, it will get
		;; re-opened by the interpreter
		ldx TMPFD           ; temp: cmdfile fd
		jsr  fclose
		nop

		;; call interpreter
        ;;

		jsr __sfget
		lda #0	; DPTR_L
		sta DPTR_L

		;; copy new fork struct to old fork struct
		;; we use stdin/stdout/stderr from old struct!
		ldy #3
ilp0:
		lda (DPTR),y
		sta (SPTR),y
		iny
		cpy #32
		bne ilp0

		;; free temp page
		ldx DPTR_H
		jsr  pfree

		;; remove stackframe
		pla ; cnt
		pla ; fd
		pla ; start
		pla ; struchi
		pla ; struclo

		;tsx
		;txa
		;clc
		;adc #5
		;tax
		;txs

		;; fork to interpreter
		lda	SPTR_L
		ldy	SPTR_H
		jmp forkto

__not_script:
		pla
_not_script:
		jmp _exe_error		; (?? pla 4 times)

		;;
		;;---- end script runner
		;;

	+	;; A/Y is address of start, 3 bytes on stack
		;; is (main) is not == (load) this needs to be changed!!!

;;		sta _o65_exe_l+1	; store execution address
;;		sty _o65_exe_h+1
		pla					; fd (not needed after loado65)
		sty  syszp+3		; exe_parameter is base-address (hi)
		pla			; address of struct (hi)
		sta  syszp+5
		pla			; address of struct (lo)
		sta  syszp+4
		ldy  #0
		lda  (syszp+4),y
		sta  syszp		; local stdin fd
		iny
		lda  (syszp+4),y
		sta  syszp+1		; local stdout fd
		iny
		lda  (syszp+4),y
		sta  syszp+2		; local stderr fd
		ldx  #<o65_exec_task
		ldy  #>o65_exec_task
		jmp  to_addtask

_lng_load:
		cli
		ldy #2			; as if 2 magic bytes were already there
		ldx syszp+7
#endif
	-	jsr  fgetc		; (szu won't help, syszp gets lost during fgetc!)
		sei
		sta  syszp+2
		pla			; start address (hi)
		pha			; start address (hi)
		sta  syszp+1
		lda  #0
		sta  syszp
		bcs  _ioerr
		lda  syszp+2
		sta  (syszp),y
		cli
		iny
		bne  -
		beq  +

_ioerr:	lda  syszp+2		; error code
		cmp  #lerr_eof
		beq +
		jmp _load_error
	+
#ifndef ALWAYS_SZU
		ldx  lk_ipid
		lda  lk_tstatus,x
		ora  #tstatus_szu
		sta  lk_tstatus,x
#endif
		cli

		sty  syszp+6
		tya
		beq  +

		lda  #0
	-	sta  (syszp),y			; zero rest of page
		iny
		bne  -

	+	jsr  exe_test			; check binary format
		bcc  _exe_error			; wrong format, then exit with error

		sta  syszp+2			; remember number of needed pages
		cmp  #2				; set carry if >1 page needed
		pla				; start address (hi)
		sta  syszp+1
		bcc  +				; skip reallocating

		;; reallocate memory (task needs more than just a single page)
		ldx  lk_ipid
		ldy  #$80
		lda  syszp+2			; no. of pages to allocate
		jsr  mpalloc
		bcs  _alloc2_error
		lda  syszp+1			; old adr-hi
		sta  syszp+3
		stx  syszp+1			; new adr-hi
		ldy  #0
		sty  syszp
		sty  syszp+2
	-	lda  (syszp+2),y
		sta  (syszp),y
		iny
		bne  -
		ldx  syszp+3
		jsr  pfree

	+	ldy  syszp+6
		bne  _loaded			; already loaded all ?

		;; load rest of tasks code

		ldy  syszp+6
		pla				; fd
		tax
		pha				; fd
		lda  syszp+1			; adr-hi
		pha
		clc
		adc  #1
		pha

	-	jsr  fgetc
		sei
		sta  syszp+2
		pla
		pha
		sta  syszp+1
		lda  #0
		sta  syszp
		bcs  _end2
		lda  syszp+2
		sta  (syszp),y
		cli
		iny
		bne  -
		pla
		adc  #1
		pha
		tay
		lda  lk_memown,y		; ??? not very secure !
		cmp  lk_ipid
		bne  _exe_error			; (segfault)
		ldy  #0
		beq  -

_exe_error:
		lda  #lerr_illcode
		jmp  _load_error		; (4x pla)

_ioerrend:
		pla
		lda  syszp+2
		jmp  _load_error

_alloc2_error:
		ldx  syszp+1
		jsr  pfree
		jmp  _alloc1_error

_end2:
		cli
		lda  syszp+2			; error code from last fgetc
		cmp  #lerr_eof
		bne  _ioerrend
		pla
		pla
		sta  syszp+1			; start address (hi)

_loaded:
		pla				; fd
		tax
		lda  syszp+1			; start address (hi)
		pha				; remember base address
		jsr  fclose
#ifndef ALWAYS_SZU
		ldy  lk_ipid
		sei
		lda  lk_tstatus,y			; fclose released syszp buffer
		ora  #tstatus_szu			; so, reclaim it
		sta  lk_tstatus,y
		cli
#endif
		pla				; start address (hi)
		sta  syszp+3			; exe_paramter is base-address (hi)
		pla				; address of struct (hi)
		sta  syszp+5
		pla				; address of struct (lo)
		sta  syszp+4
		ldy  #0
		lda  (syszp+4),y
		sta  syszp			; local stdin fd
		iny
		lda  (syszp+4),y
		sta  syszp+1			; local stdout fd
		iny
		lda  (syszp+4),y
		sta  syszp+2			; local stderr fd
		ldx  #<reloc_and_exec
		ldy  #>reloc_and_exec
to_addtask:
		lda  #7					; priority
		jsr  addtask
		bcs  to_catcher
		;; X/Y=PID of child
#ifndef ALWAYS_SZU
		sty  syszp
		ldy  lk_ipid
		sei
		lda  lk_tstatus,y
		and  #$ff-tstatus_szu
		sta  lk_tstatus,y
		ldy  syszp
		cli
#endif
		rts

to_catcher:
		jmp  catcherr

		;; function: reloc_and_exec
		;; claim new task's memory, then relocate and launch it
		;; (executed in new task's context
		;;  after initializing the environment)
		;; < Y = exe-parameter (high-byte of base-address)
		;; changes: syszp(0,1)
		;; calls: exe_reloc

reloc_and_exec:
		sei
#ifndef ALWAYS_SZU
		ldx  lk_ipid
		lda  lk_tstatus,x
		ora  #tstatus_szu
		sta  lk_tstatus,x
#endif
		sty  syszp+1
		lda  #0
		sta  syszp

		;; hand over the covered portion of internal memory
	-	lda  lk_ipid
		sta  lk_memown,y
		lda  lk_memnxt,y
		tay
		bne  -
		cli
		jsr  exe_reloc
		tya
		pha
		txa
		pha
		php
		rti						; continue with new task

#ifdef HAVE_O65
		;; function: o65_exec_task
		;; claim new task's memory, then launch it (already relocated)
		;; (executed in new task's context
		;;  after initializing the environment)
		;; < Y = high-byte of first address

o65_exec_task:
		;; 0/Y -- start-address of code to execute
		;; (change!!! if "main" not at start of code)
		tya
		pha
		lda  #<0
		pha
		php

		;; hand over the covered portion of internal memory
		sei
	-	lda  lk_ipid
		sta  lk_memown,y
		lda  lk_memnxt,y
		tay
		bne  -
		rti						; continue with new task
#endif
