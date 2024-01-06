		;; for emacs: -*- MODE: asm; tab-width: 4; -*-

; experimental libc-memory management
; for LUnix next generation
	
;		libc_malloc  ( A/Y=size ), returns A/Y=pointer
;		libc_free	( A/Y=pointer ), returns nothing
;		libc_remalloc( A/Y=pointer, (X)=new_size ), returns A/Y=pointer

#include <system.h>
#include <cstyle.h>
#include <jumptab.h>
#include <kerrors.h>
#include "lib_conf.h"

; Can't be used for shared libraries !

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

		;; function:	_mem_boundcheck
		;; check if pages X...A are part of the same
		;; memoryblock (c=1 means yes)
		;; < A,X
		;; > c

.global _mem_boundcheck
_mem_boundcheck:
		sei
		sta  tmpzp
		cpx  tmpzp
		beq  ++					; ->yes

	-	lda  lk_memnxt,x
		beq  +					; ->no
		tax
		cpx  tmpzp
		bne  -
		SKIP_BYTE				; ->yes

	+	clc
	+ 	cli
	-	rts

		;; function:	libc_malloc
		;; allocate memory
		;; < A/Y size of area to allocate
		;; > A/Y pointer to allocated area (or NULL if none)

.global libc_malloc
libc_malloc:					; A/Y-size,  returns A/Y=desc
		tax
		bne  _malloc_mc
		cpy  #0
		beq  -					; nothing to do, if size==0

_malloc_mc:
		clc						; add overhead of 4 bytes to size
		adc  #4					; and store result in _bytes
		sta  __mem_bytes
		tya
		adc  #0
		sta  __mem_bytes+1

_malloc_mc2:					; allready used malloc before ?
		lda  __libcmalloc_start+1
		bne  +++

		;; is first time for malloc

_new_malloc:
		db("new malloc\n")

		lda  __mem_bytes		; calculate number of pages to allocate
		cmp  #1
		lda  __mem_bytes+1
		adc  #0

		ldx  lk_ipid			; allocate pages
		ldy  #0					; (may allocate IO area)
		jsr  lkf_mpalloc

		bcs  _malloc_out_of_memory

		stx  userzp+3			; remember baseaddress
		lda  #0
		sta  userzp+2
		ldy  #3
		lda  __mem_bytes		; generate mem-struct
		sta  (userzp+2),y		;  ->end=_bytes+baseaddress
		dey
		lda  __mem_bytes+1
		adc  userzp+3
		sta  (userzp+2),y

		ldx  __libcmalloc_start+1	; start available ?
		bne  +
   
		ldy  #0					; start==NULL
		tya
		sta  (userzp+2),y		; ->next=NULL
		iny
		sta  (userzp+2),y
		  
		jmp  ++

  _malloc_out_of_memory:
		db("malloc out of memory\n")
#ifdef MALLOC_DIE_ON_OUT_OF_MEMORY
		lda  #lerr_outofmem
		jmp  lkf_suicerrout
#else
		lda  #0
		tay
		rts
#endif
 
	+	lda  lk_memown,x		; start!=NULL
		cmp  lk_ipid			; check permission
		bne  _malloc_to_segfault
   
		txa						; ->next=start
		ldy  #0
		sta  (userzp+2),y
		lda  __libcmalloc_start
		iny
		sta  (userzp+2),y

	+	lda  #0					; start=baseaddress
		sta  __libcmalloc_start
		ldy  userzp+3
		sty  __libcmalloc_start+1

		lda  #4
		rts						; return baseaddress+4 (=desc)


		;; start has been != NULL
		;; so search for a place for new memory area

	+	lda  #0					; last=NULL
		sta  _last+1
		lda  __libcmalloc_start	; current=start
		sta  userzp
		ldx  __libcmalloc_start+1
		stx  userzp+1

		lda  lk_memown,x		; check permission
		cmp  lk_ipid
   _malloc_to_segfault:
		bne  _segfault2

		;; start of malloc-search-loop

	-	lda  userzp+1			; while (current!=NULL)
		beq  _new_malloc		; (if current==NULL allocate new pages)

		ldx  _last+1			; check if last, current are bound
		beq  +					; (not bound)
		lda  userzp+1
		jsr  _mem_boundcheck
		bcs  +++

		;; not bound, so beginning is start of page

	+	lda  __mem_bytes+1
		bne  ++					; can't fit if size>255
		lda  userzp
		cmp  __mem_bytes
		bcc  ++

		;; _malloc_typ1:
		;; 

		db("malloc typ1\n")
		lda  _last+1
		bne  +

		ldx  userzp+1			; (there is no previous mem-struct)
		stx  userzp+3			; (so userzp is equal to start)
		ldy  #0
		sty  userzp+2			; tmp=start & 0xff00
		sty  __libcmalloc_start	; (new_start=tmp)

		lda  userzp				; tmp->next=start
		sty  userzp				; tmp->end=tmp+_bytes
		jmp  _malloc_end		; return tmp+4 in A/Y

   +	; (there is a previous mem-struct)
		sta  userzp+3
		lda  _last
		sta  userzp+2			; tmp=last
		lda  userzp+1
		ldy  #0
		sta  (userzp+2),y
		tya
		iny
		sta  (userzp+2),y		; tmp->next=current & 0xff00
		sta  userzp+2			; tmp=current & 0xff00
		ldy  userzp+1
		sty  userzp+3			; tmp->next=current
		lda  userzp				; tmp->end=tmp+_bytes
		jmp  _malloc_end		; return tmp+4 in A/Y

		;; last and current are in one memory block

	+	ldy  #2
		lda  (userzp),y
		sta  __mem_end+1
		tax						; check permission
		iny						; _end=current->end
		lda  (userzp),y
		sta  __mem_end
		bne  +
		dex
	+	lda  lk_memown,x
		cmp  lk_ipid
		bne  _segfault2

		ldy  #1					; _next=current->next
		lda  (userzp),y
		sta  _next
		dey
		lda  (userzp),y
		sta  _next+1
		beq  ++					; (_next is NULL)
		tax						; check permission
		lda  lk_memown,x
		cmp  lk_ipid
		beq  +

_segfault2:
		db("malloc segfault\n")
		exit(38)

	+	ldx  __mem_end+1		; check if end, next are bound
		lda  _next+1
		jsr  _mem_boundcheck
		bcs  ++

	+	lda  __mem_bytes+1		; end and next are not in one memory block
		bne  ++
		sec						; size is less than 256 bytes
		lda  #0
		sbc  __mem_end
		cmp  __mem_bytes
		bcc  ++

		jmp  _malloc_typ2		; fits !

	+	sec						; size is >= 256 bytes
		lda  _next
		sbc  __mem_end
		tax
		lda  _next+1
		sbc  __mem_end+1
		cmp  __mem_bytes+1
		bcc  +					; doesn't fit
		bne  _malloc_typ2		; fits !
		cpx  __mem_bytes
		bcs  _malloc_typ2		; fits !

	+	lda  userzp				; doesn't fit, goto next malloc-struct
		sta  _last				; last=current
		lda  userzp+1
		sta  _last+1
 
		lda  _next				; current=next
		sta  userzp
		lda  _next+1
		sta  userzp+1

		jmp  -

_malloc_typ2:

		db("malloc typ2\n")
		ldy  #0					; fit in between end and next
		lda  __mem_end+1
		sta  userzp+3
		sta  (userzp),y
		iny
		lda  __mem_end
		sta  (userzp),y			; tmp=end
		sta  userzp+2			; tmp->next=next
		lda  _next				; tmp->end=tmp+bytes
		ldx  _next+1			; return tmp+4 in A/Y

_malloc_end:

		db("malloc end\n")
		ldy  #1					; [[userzp+2]+0]=A/X
		sta  (userzp+2),y
		dey
		txa
		sta  (userzp+2),y
		clc						; [[userzp+2]+2]=[userzp+2]+_bytes
		ldy  #3
		lda  userzp+2
		adc  __mem_bytes
		sta  (userzp+2),y
		dey
		lda  userzp+3
		adc  __mem_bytes+1
		sta  (userzp+2),y
		clc						; return [userzp+2]+4 in A/Y
		lda  userzp+2
		adc  #4
		ldy  userzp+3
		bcc  +
		iny
	+	rts

		RELO_JMP(+)

.global _malloc_mc, _malloc_mc2
.global __libcmalloc_start, __mem_bytes, __mem_end

__libcmalloc_start:		.word 0	; shared by free, malloc, remalloc
_last:					.buf 2
_next:					.buf 2
__mem_bytes:			.buf 2	; shared by malloc and remalloc
__mem_end:				.buf 2	; shared by malloc and remalloc
 
 + ; end
