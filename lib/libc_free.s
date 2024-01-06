		;; for emacs: -*- MODE: asm; tab-width: 4; -*-

; experimental libc-memory management
; for LUnix
;		libc_malloc  ( A/Y=size ), returns A/Y=pointer
;		libc_free	 ( A/Y=pointer ), returns nothing
;		libc_remalloc( A/Y=pointer, (X)=new_size ), returns A/Y=pointer

#include <system.h>
#include <cstyle.h>
#include <jumptab.h>
#include <kerrors.h>

; can't be used for shared libraries !

#ifdef debug
#  begindef db(text)
	php
	pha
	txa
	pha
	tya
	pha
	print_string(text)
	pla
	tay
	pla
	tax
	pla
	plp
#  enddef
#else
  #define db(text)
#endif

	-	cli
		rts

		;; free pages [tmpzp]..[tmpzp+1]-1

.global _frag_free
_frag_free:
		;; adapt memnxt pointers
		ldx  tmpzp
		cpx  tmpzp+1
		bcs  -					; ->internal error?

		dex						; (assumption)
		lda  lk_memnxt,x
		cmp  tmpzp
		bne  +
		lda  #0					; end previous fragment
		sta  lk_memnxt,x
	+	ldx  tmpzp+1
		dex						; (assumption)
		lda  #0
		lda  lk_memnxt,x
		
		ldx  tmpzp
		cli
		jmp  lkf_free

.global libc_free
libc_free:						; A/Y=desc
		tax
		bne  +
		cpy  #0
		beq  -					; nothing to do, if desc=NULL

	 +	sec						; tmpzp/tmpzp+1=desc-4 (points to begin of mem-struct)
		db("free!!\n")

		sei
		sbc  #4					; tmpzp = desc - 4
		sta  tmpzp
		tya
		sbc  #0
		sta  tmpzp+1

		tay						; check permission
		lda  lk_memown,y
		cmp  lk_ipid
		bne  _segfault

		;; search for mem-struct in linked list

		lda  #0
		sta  userzp+3			; plast=NULL
		lda  __libcmalloc_start	; pcurrent=start
		sta  userzp
		lda  __libcmalloc_start+1

	-	sta  userzp+1
		tay
		beq  _segfault			; not found, then segfault

		lda  lk_memown,y		; check permission
		cmp  lk_ipid
		bne  _segfault			; (is a sanity check)

		ldx  tmpzp				; compare malloc-pointer
		ldy  tmpzp+1
		cli						; (enable IRQ tmpzp/tmpzp+1 is stored in X/Y)
		cpx  userzp
		bne  +
		cpy  userzp+1
		beq  ++					; found!

	+	sei						; try next element
		stx  tmpzp				; (disable IRQ X/Y -> tmpzp/tmpzp+1)
		sty  tmpzp+1
		
		lda  userzp				; plast=pcurrent
		sta  userzp+2
		lda  userzp+1
		sta  userzp+3

		ldy  #1					; pcurrent=pcurrent->next
		lda  (userzp),y
		tax
		dey
		lda  (userzp),y		; (hi)
		stx  userzp			; (lo)

		jmp  -

_segfault:
		db("free segfault\n")
		lda  #lerr_segfault
		jmp  lkf_suicerrout

		;; found

	+	ldy  #0					; found mem-struct (it is pcurrent)
		lda  (userzp),y			; (verify struct)
		beq  +
		tax						; pcurrent->next!=NULL
		lda  lk_memown,x		; check permission
		cmp  lk_ipid			; (is a sanity check)
		bne  _segfault

	+	sei
		lda  userzp+3			; plast=NULL ?
		bne  +					; ->no

		db("replace start\n")

		lda  userzp+1			; so plast==NULL
		sta  tmpzp				; tmpzp=mem-block

		lda  (userzp),y			; start=pcurrent->next
		sta  __libcmalloc_start+1
		iny
		lda  (userzp),y
		sta  __libcmalloc_start

		jmp  _free_endif_last	; free pages from tmpzp to end of mem-block

		;; plast!=NULL

	+	ldx  userzp+3			; check if plast is bound to pcurrent
		lda  userzp+1
		jsr  _mem_boundcheck
		lda  userzp+1
		bcc  +

		;; in the same block

		ldy  #3					; calculate first page to free
		lda  (userzp+2),y		; (from plast->end)
		cmp  #1
		dey
		lda  (userzp+2),y
		adc  #0

		;; not in one block

	+							; if last, next are in different mem-blocks
		sta  tmpzp

		ldy  #0					; plast->next=pcurrent->next
		lda  (userzp),y
		sta  (userzp+2),y
		iny
		lda  (userzp),y
		sta  (userzp+2),y

_free_endif_last:
		ldy  #0					; check if pcurrent and pcurrent->next
		lda  (userzp),y			; are part of the same memory block
		beq  +					; (->next==NULL!)
		ldx  userzp+1
		jsr  _mem_boundcheck
		bcs  ++					; -> are part of the same block

	+	ldy  #3					; not the same block
		lda  (userzp),y
		cmp  #1
		dey
		lda  (userzp),y
		adc  #0					; calculate last page to free

		jmp  ++

	+	ldy  #2					; in the same block
		lda  (userzp),y

	+	sta  tmpzp+1
		jsr  _frag_free

		db("free done\n")

	 	rts