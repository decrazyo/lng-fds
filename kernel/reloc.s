;; For emacs: -*- MODE: asm; tab-width: 4; -*-
;; for   jed: -*- TAB: 4 -*-

		;; code relocator
		;; 2000Jan5 - Added kernel functions @ virtual addresses.
		;; 2003-7-15, Moved the list of public kernel functions to a separate object-file.

#include <config.h>
#include <system.h>
#include <kerrors.h>
#include <ikernel.h>

		.global exe_test
		.global exe_reloc

		;; - system loads the first 256 bytes of an application.
		;; - then calls exe_test to see if it is in a proper format
		;;   exe_test returns the number of concurrent pages the system
		;;   has to allocate in order to load and run the complete
		;;   application.
		;; - system loads the rest of the applications code into memory.
		;; - then calls exe_reloc to relocate the applications code
		;;   exe_reloc returns the address to jump to in order to
		;;   run the application.

_relobit0:                     ; tables for relocator
        .byte   0,167,  0,255,144,175,  0
        .byte 255,128,175,  0,255,128,175
        .byte   1,255,  0,175,  0,255,  0
        .byte 191,  0,255,  0,175,  1,247
        .byte   0,175,  0,247

_relobit1:
        .byte 223, 87,223, 95,207, 95,223
        .byte  95, 95, 95,223, 95, 95, 95
        .byte 223, 95,255, 95,223, 95,255
        .byte  79,223, 95,255, 95,223, 95
        .byte 255, 95,223, 95

		;; do a quick check of the data format
		;; return with c=1, if the format is okay (and A=code size in pages)

	-	clc						; test's result is "no"
		rts

		;; function: exe_test
		;; syszp points to first 256 bytes of code
		;; check for ($fffe) LNG-magic-bytes
		;; (magic header of LUnix0.1 has been $ffff)
		;; < syszp points to code
		;; > c=1 if code *is* executable

exe_test:
		lda  syszp
		bne  -					; code must be page-aligned

#ifdef HAVE_O65
		;; magic bytes were checked earlier
		ldy  #2
#else
		ldy  #0
		lda  (syszp),y
		cmp  #>LNG_MAGIC
		bne  -
		iny
		lda  (syszp),y
		cmp  #<LNG_MAGIC
		bne  -
		iny
#endif
		;; check version number

		lda  (syszp),y
		cmp  #>LNG_VERSION		; hi byte of version must match exactly
		bne  -					;  wrong version
		iny
		lda  #<LNG_VERSION
		cmp  (syszp),y			; lo byte of system version must be at least
						; equal
		bcc  -				;  wrong version

		iny
		lda  (syszp),y			; number of needed pages

		sec
		rts				; ok it seems to be LUnix (LNG) native code !

		;; function: exe_reloc
		;; code relocator
		;;  syszp points to start of a binary in LNG-format
		;; (exe_reloc runs in the new task's environment!)
		;; < syszp+1 = hi-byte of code to be relocated
		;; < syszp+0 = 0, (syszp) must point to valid exe-header
		;; changes: syszp(0,1,2,3,4,5)

exe_reloc:
		ldy  #5
		lda  (syszp),y			; original base address (hi)
		sta  syszp+3			; (orig-base)
		sec
		lda  syszp+1
		sta  syszp+5
		sbc  (syszp),y			; original base address (hi)
		sta  syszp+2			; (offset)
		ldy  #1
		sta  (syszp),y			; ( [base+1]=hi byte of offset )
		dey
		lda  syszp+1
		sta  (syszp),y			; ( [base]=hi byte of new base )
		tay
		tax
		inx
		lda  #6
		sta  syszp

	-	txa
		cmp  lk_memnxt,y		; search for end of segment
		bne  +
		iny
		inx
		bne  -
	-	jmp  _err_illcode

	+	lda  lk_memnxt,y
		bne  -
		txa
		sec
		sbc  syszp+2			; convert to original origin
		sta  syszp+4			; hi-byte+1 of end

_reloc_:
		;;   syszp    points to code to relocate
		;;   syszp+2  offset
		;;   syszp+3  (>original_start)
		;;   syszp+4  (>original_end)+1

		;; reloc: generates error-messages if there are illegal
		;; opcodes or code isn't terminated with a $02-instruction
		;; i COULD also check for pagefaults or illegal use of zeropage

		ldy  #0					; get size of instruction by looking into
		lda  (syszp),y			; the reloc-table
		tax
		lsr  a
		lsr  a
		lsr  a
		tay
		txa
		and  #7
		tax
		lda  _relobit0,y
		and  btab2r,x
		cmp  #1					; move bit of table into carry
		lda  _relobit1,y
		and  btab2r,x
		beq  +
		lda  #1					; move bit of table into bit0
	+	rol  a					; add bit0 of intruction-size

		beq  _illegal			; size=0, then ill.instr
		cmp  #3
		bne  _addlen			; skip if size is not 3

		;; is a 3 byte instruction

		ldy  #2
		lda  (syszp),y			; hi-byte of destination
		cmp  #>lk_jumptab		; (calling kernel function?)
		bne  +

		dey				; (kernel address remapping)
		lda  (syszp),y
		cmp  #lkfunc_max
		bcs  _err_illcode		; (must be less than twice number of functions)
		tax
		lsr  a
		bcs  _err_illcode		; (must be even)
		lda  kfunc_tab,x		; (lo byte)
		sta  (syszp),y
		iny
		lda  kfunc_tab+1,x		; (hi byte)
		bne  ++

	+	cmp  syszp+3			; destination within code segment ?
		bcc  ++					; (no)
		cmp  syszp+4
		bcs  ++					; (no)
		adc  syszp+2			; byte that has to be converted

	+	sta  (syszp),y			; hi-byte of destination

	+	lda  #3				; length of instruction is 3

_addlen:
		clc				; add length to position
		adc  syszp
		sta  syszp
		bcc  _reloc_
		ldx  syszp+1			; get next codepage
		inx
		lda  lk_memown,x
		cmp  lk_ipid
		bne  _err_illcode		; end of codesegment without $02 instruction!!
		stx  syszp+1
		jmp  _reloc_			; continue relocation

_err_illcode:
		lda  #lerr_illcode
		jmp  suicerrout

		;; illegal instruction
		;; some of them are used in this binary format
		;;   $0c is absjmp for _reloc_, skip a region of pure data
		;;   $02 ends _reloc_

_illegal:
		ldy  #0
		lda  (syszp),y
		cmp  #$02
		beq  _end				; $02 then end
		cmp  #$0c
		bne  _err_illcode		; $0c then reloc-jmp, else error
		iny
		lda  (syszp),y
		tax
		iny
		lda  (syszp),y
		stx  syszp
		clc
		adc  syszp+2
		sta  syszp+1
		tax
		lda  lk_memown,x
		cmp  lk_ipid
		bne  _err_illcode		; end of codesegment without $02 instruction!!
		jmp  _reloc_			; continue relocation

_end:
		ldx  #6					; return with X/Y = base+6
		ldy  syszp+5
		rts
