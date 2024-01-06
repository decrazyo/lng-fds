		;; for emacs: -*- MODE: asm; tab-width: 4; -*-

; experimental libc-memory management
; for LUnix
;       libc_malloc  ( A/Y=size ), returns A/Y=pointer
;       libc_free    ( A/Y=pointer ), returns nothing
;       libc_remalloc( A/Y=pointer, (X)=new_size ), returns A/Y=pointer

#include <system.h>
#include <jumptab.h>
#include <kerrors.h>
				
; can't be used for shared libraries !
		
  _remalloc_do_free:
		ldy  $01,x
		lda  $00,x
		jsr  libc_free				; free(desc)
		lda  #0					; return NULL
		tay
		rts

  _remalloc_do_malloc:
		lda  _mem_bytes
		jmp  _malloc_mc			; return malloc(size)

.global libc_remalloc
libc_remalloc:						; A/Y= new_size, (X)=desc, returns A/Y=desc

		sta  _mem_bytes
		sty  _mem_bytes+1
		ora  _mem_bytes+1
		beq  _remalloc_do_free

		lda  $00,x
		sta  userzp
		lda  $01,x
		sta  userzp+1			; [zpbase]=desc
		ora  userzp
		beq  _remalloc_do_malloc ; do malloc, if desc==NULL

		sec						; current=desc-4
		lda  userzp
		sbc  #4
		sta  userzp
		bcs  + 
		dec  userzp+1
	+	clc						; size+=4
		lda  _mem_bytes
		adc  #4
		sta  _mem_bytes
		bcc  +
		inc  _mem_bytes+1

	+	ldx  userzp+1			; check permission (current)
		lda  lk_memown,x
		cmp  lk_ipid
		bne  _segfault3

		ldy  #0					; check permission (current->next)
		lda  (userzp),y
		beq  +
		tax
		lda  lk_memown,x
		cmp  lk_ipid
		beq  +

  _segfault3:
		lda  #lerr_segfault
		jmp  lkf_suicerrout

	+	ldy  #2					; check permission (current->end)
		lda  (userzp),y
		tax
		lda  lk_memown,x
		cmp  lk_ipid
		bne  _segfault3

		clc						; end=current+bytes
		lda  userzp
		adc  _mem_bytes
		sta  _mem_end
		lda  userzp+1
		adc  _mem_bytes+1
		sta  _mem_end+1
 
		cmp  (userzp),y		; compare end with current->end
		bne  +
		lda  _mem_end
		iny
		cmp  (userzp),y
		beq  _remalloc_equal	; same size, nothing to do
	+	bcs  _remalloc_grow		; new size is bigger (difficult)

		;; new size is smaller (simple)

		lda  _mem_end				; calculate first page, that can be
		cmp  #1					; freed
		lda  _mem_end+1
		adc  #0
		sei
		sta  tmpzp

		ldy  #0					; start, start->next bound ?
		lda  (userzp),y
		beq  +
		ldx  userzp+1
		jsr  _mem_boundcheck
		bcs  ++

	+	ldy  #3					; current, current->next are not in one block
		lda  (userzp),y		; calculate last page, that can be
		cmp  #1					; freed
		dey
		lda  (userzp),y
		adc  #0

		jmp  ++

	+	ldy  #2					; current, current->next are in one block
		lda  (userzp),y		; last freeable page is >current->end

	+	sta  tmpzp+1					; store number of last freeable page
		ldy  #2					; current->end=end
		lda  _mem_end+1
		sta  (userzp),y
		iny
		lda  _mem_end
		sta  (userzp),y
          
		jsr  _frag_free			; free pages

_remalloc_equal:

		clc
		lda  userzp
		adc  #4
		ldy  userzp+1
		bcc  +
		iny
	+	rts						; return current+4 in A/Y

_remalloc_grow:

		ldy  #0					; current, current->next bound ?
		lda  (userzp),y 
		beq  +					; (not bound, if next==NULL)
		ldx  userzp+1
		jsr  _mem_boundcheck
		bcs  ++

	+	ldy  #3					; current, current->next not connected
		lda  (userzp),y		; lets see how much room is available here
		cmp  #1
		dey
		lda  (userzp),y
		adc  #0
		cmp  _mem_end+1
		bcc  ++					; no fit
		beq  ++					; no fit
          
		;; fit

	-	ldy  #3					; current->end=end
		lda  _mem_end
		sta  (userzp),y
		dey
		lda  _mem_end+1
		sta  (userzp),y

		jmp  _remalloc_equal	; return current+4 in A/Y

	+	ldy  #0					; current, current->next connected
		lda  _mem_end+1				; (in same memory block)
		cmp  (userzp),y
		bcc  -					; fit in between current and current->next !
		bne  +					; no fit
		iny
		lda  _mem_end
		cmp  (userzp),y
		bcc  -					; fit in between current and current->next !

		;; doesn't fit

	+	lda  userzp+1			; push current on stack
		pha
		lda  userzp
		pha
		jsr  _malloc_mc2		; try to allocate a new memory-struct
		sta  userzp
		sty  userzp+1			; current=malloc(new_size)
		clc
		pla
		adc  #4
		sta  userzp+3
		pla 
		pha
		adc  #0
		sta  userzp+2			; tmp=pop() + 4 (leave hi-byte on stack)
		sec
		ldy  #3
		lda  userzp
		sbc  (userzp),y
		tax
		dey
		lda  userzp+1
		sbc  (userzp),y		; (value of _bytes is not valid after malloc)
		sta  _mem_bytes+1			; X/_bytes+1 = current-current->end = -size
		ldy  #0

	-	lda  (userzp+2),y		; copy old data into new allocated area
		sta  (userzp),y
		iny
		bne  +
		inc  userzp+3
		inc  userzp+1
	+	inx
		bne  -
		inc  _mem_bytes+1
		bne  -

		pla
		pha
		tay
		lda  userzp+2
		pha
		cli
		jsr  libc_free
		pla
		tax
		pla
		tay
		txa
		rts

