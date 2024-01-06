; For emacs: -*- MODE: asm; tab-width: 4; -*-
		
		;; support for runtime modules
		;; that are added to the system
		
#include <system.h>
#include <kerrors.h>

		;; module strcuture:
		;;  0-2 : module identifier (3 chars)
		;;  3   : module size (number of provided functions)
		;;  4   : ? (version) ?
		;;  5   : module weight (number of virtual devices)
		;;  6/7 : pointer to next structure (0=end)
		
		;;  ( (8),9/10: pointer to lock function of module )
				
		.global add_module
		.global get_moduleif
		.global fix_module
		
		;; 		.global release_module
		;; 		.global search_module

		;; function: add_module
		;; add module to system
		;; < X/Y=pointer to module structure
		;; changes: tmpzp(0,1,2,3)

add_module:
		sei
		stx  tmpzp
		sty  tmpzp+1
		
		ldy  #6
		lda  #0					; clear pointer to next module
		sta  (tmpzp),y			; (this will become the last module)
		iny
		sta  (tmpzp),y
		
		lda  lk_modroot+1		; get startpoint of the linked
		bne  search_end			; list of modules
		
		ldy  tmpzp+1
		stx  lk_modroot			; (this is the very first module)
		sty  lk_modroot+1
		clc
		cli
		rts
		
search_end:
		ldx  lk_modroot			; search the end of the linked list
		
	-	stx  tmpzp+2			; (X/A is address of next module structure)
		sta  tmpzp+3
		ldy  #6
		lda  (tmpzp+2),y
		tax
		iny
		lda  (tmpzp+2),y
		bne  -					; (end not reached, continue searching)
		
		lda  tmpzp+1			; insert module in list
		sta  (tmpzp+2),y
		dey
		lda  tmpzp
		sta  (tmpzp+2),y
		clc
		cli
		rts						; done
		
not_found:
		lda  #lerr_nosuchmodule
		SKIP_WORD
		
wrong_size:
		lda  #lerr_illmodule
		cli
		jmp  catcherr
						
		;; function: get_moduleif
		
		;; serach for module and copy
		;; module interface into local
		;; memory
		
		;; < X/Y=pointer to moddesc
		;;   A=device number
		;; > c=error
		
		;; structure of moddesc:
		;;  .asc "xyz"      ; module type identifier
		;;  .byte ifsize    ; number of provided functions
		;;                  ; will be replaced by module version
		;;  .buf 3*ifsize   ; placeholder for ifsize JMPs

		;; changes: tmpzp(0,1,2,3,4,5)
				
get_moduleif:
		sei
		sta  tmpzp+5
		stx  tmpzp
		sty  tmpzp+1
		lda  #1
		sta  tmpzp+4
		
		ldx  lk_modroot
		lda  lk_modroot+1
		
loop:	sta  tmpzp+3			; (X/A = address of next module strcuture)
		beq  not_found
		stx  tmpzp+2
		;; verify module name
		ldy  #2
	-	lda  (tmpzp),y
		cmp  (tmpzp+2),y
		bne  nomatch
		dey
		bpl  -
		;; verify device number
		clc
		lda  tmpzp+4
		ldy  #5
		adc  (tmpzp+2),y		; add module weight
		sta  tmpzp+4
		sbc  #0
		cmp  tmpzp+5
		bcc  nomatch
		;; verify module size
		ldy  #3
		lda  (tmpzp+2),y
		cmp  (tmpzp),y
		bcc  wrong_size
		;; copy module interface
		lda  (tmpzp),y
		bne  +
		
nomatch:
		ldy  #6
		lda  (tmpzp+2),y
		tax
		iny
		lda  (tmpzp+2),y
		jmp  loop
		
		; found match
		
	+	asl  a					; *3
		adc  (tmpzp),y
		tax
		
		ldy  #10
		lda  (tmpzp+2),y
		pha
		dey
		lda  (tmpzp+2),y
		pha
		lda  tmpzp+2
		adc  #7					; +7
		sta  tmpzp+2
		bcc  +
		inc  tmpzp+3
	+	ldy  #4
	-	lda  (tmpzp+2),y
		sta  (tmpzp),y
		iny
		dex
		bne  -
		lda  tmpzp+5			; device number
		cli
		php
		rti						; call lock function of selected module
								; with A=device number

		;; function: fix_module
		
		;; make module (associated with current task) a passive
		;; part of the system.
		;; this means, all memory occupied by the current task
		;; is converted into "memory used by a module" and the task
		;; is removed from the scheduler.
		;; => there is no return from this function!
		
		;; < X=address of first unneccessary code page. (or $00 if none)
		;;   (all hardware initialisation and detection code of a module
		;;   should be at the end of the code, so the used memory can be
		;;   deallocated afterwards) 

fix_module:
		txa
		beq  +
		lda  lk_memown-1,x
		cmp  lk_ipid			; segfault?
		bne  ill_param
		lda  #0
		sta  lk_memnxt-1,x
		jsr  free
	+	jsr  locktsw
		ldx  #2
		lda  lk_ipid
	-	cmp  lk_memown,x
		bne  +
		lda  #memown_modul
		sta  lk_memown,x
		lda  lk_ipid
	+	inx
		bne  -
		jsr  unlocktsw
		lda  #0
		jmp  suicide
		
ill_param:
		lda  #lerr_segfault
		jmp  suicerrout

