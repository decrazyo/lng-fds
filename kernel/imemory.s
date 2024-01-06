		;; allocation / deallocation of internal memory

		;; the allocation is pagewise (a page has 256bytes)
		;; there are 2 ways to allocate memory
		;;  slow - n concurrent pages (best fit)
		;;  fast - a single page

		;; depending on a flag some shared pages can be disabled
		;; (if a process does direct access to hardware, it might not
		;; want to get RAM that is hidden under the I/O area)

#include <config.h>
#include <system.h>
#include <kerrors.h>

		;; all routines are atomic !
		;; and use locktsw to lock taskswitches without disabling IRQ
		;; (because searching+allocating memory might take longer than 1/64s)
		
.global mpalloc
.global spalloc
.global _raw_alloc
.global free
.global pfree
.global io_map
.global btab2r
.global palloc
		
		;; function: palloc
		;; pagewise allocation (forward search)
		;; wrapper for mpalloc with simpler interface for applications
		;; < A=number of pages to allocate
		;; > c=0: X=start page
		;; > c=1: out of memory

		;; calls:		mpalloc
		
palloc:	
		ldx  lk_ipid
		ldy  #0
		jsr  mpalloc
		bcs  +
		rts
	+	ldx  #lerr_outofmem
		jmp  catcherr

		
		;; function: mpalloc
		;; multi page allocation (forward search)
		;; < A=number of pages to allocate
		;; < X=page usage code / flags
		;; < Y=mode (bit7 = no I/O area)
		;; > c=0: X=start page
		;; > c=1: out of memory

		;; changes:		tmpzp(0,1,2,3,4,5)
		
mpalloc:
		php
		sei						; sorry, no IRQ in here!
		sta  tmpzp				; A=number of pages
		stx  tmpzp+4			; X was usage code
		sty  tmpzp+5			; Y was mode
		jsr  locktsw
		plp
		lda  #$ff				; prepare for search
		sta  tmpzp+2			; size of smallest chunk = 255
		ldx  #0					; current page
		stx  tmpzp+3			; (initialize best location)
		ldy  #0					; current map offset
		clc						; search for next free page
		
	-	lda  lk_memmap,y
		bit  tmpzp+5
		bpl  +
		and  io_map,y			; remove I/O pages, if neccessary
	+	cmp  #0
		bne  mpa3				; there is a page, go find it!
		txa						; jump to next map-byte
		adc  #$07				; (carry=1 !)
		tax
mpa1:	iny
		cpy  #32
		bne  -					; scan next 8pages

		jmp  _raw_alloc			; nothing more found, we're ready!
          
mpa2:   iny						; free area crossed 8 pages boudary
		lda  lk_memmap,y		; continue searching the end the fast way
		bit  tmpzp+5
		bpl  +
		and  io_map,y			; remove I/O pages, if neccessary
	+	cmp  #$ff				
		bne  +					; here is the end, go find it
		txa						; (carry is set!)
		adc  #7
		tax
		bcc  mpa2
		;; loop never left this way, since page $ff should be 
		;; allocated by the system!

		;; search end of gap
	+	sec						; go on finding the end (append 1 to map-byte)
		rol  a					; by scanning each bit
		jmp  +

		;; current map-byte has at least 1 bit set
		
mpa3:	sec						; prepare for bit-scan
		;; append "1" to the map-byte, so beq after rol/asl means
		;; we have scanned the whole map-byte

	-	rol  a					; find first '1'-bit (=free page)
		bcs  mpa4				; found!
		inx
		bne  -					; (loop will never end this way!)

		;; pointing to a set map-bit (a free page)
		
mpa4:   stx  tmpzp+1			; remember first free page
		
		;; now search for the end of the current gap
		
	-	inx						; (no overrun possible!, since page $ff is
		asl  a					;  always used by the kernel)
		beq  mpa2				; go to next map-byte
	+	bcs  -					; found an other free page...

		;; found end of gap
		
		pha						; store pattern
		sec
		txa
		sbc  tmpzp+1			; calculate size of gap
		cmp  tmpzp				; check if there are enough free pages
		beq  ++					; yeah, there are, and its a 100% fit!!
		bcc  +					; not enough, then skip
		cmp  tmpzp+2			; better match than before ?
		bcs  +					; no then don't store it
		sta  tmpzp+2			; yes, then update smallest size
		lda  tmpzp+1			; and remember this location
		sta  tmpzp+3
	+	pla						; restore pattern

		;; search for beginning of next gap
		
	-	inx						; search for next free block
		beq  _raw_alloc			; stop if the bottom is reached
		asl  a
		beq  mpa1				; nothing here at all, go and scan the fast way
		bcc  -					; continue scanning until there is a free page

		bcs  mpa4				; alway jump!

	+	pla						; found 100% fit
		lda  tmpzp+1
		bne  +					; (always jump)

		;; finished searching

		;; function: _raw_alloc
		
		;; raw memory allocation
		;; (call lock_tsw before!)
		;; < tmpzp = number of pages
		;; < tmpzp+3 = start page
		;; < tmpzp+4 = usage flags
		;; > c=0: X=start page

		;; calls:		unlocktsw
		
		
_raw_alloc:		
				
		lda  tmpzp+3			; get location of best fit
		beq  _search_ered		; sorry, not enough memory available !
		sta  tmpzp+1			; store beginning of best location		
	+	ldy  tmpzp				; y=number of pages to alloc
		tax						; x=start page

		;; set usage + links of allocated pages
		
	-	lda  tmpzp+4			; set usage/flags
		sta  lk_memown,x
		inx
		txa
		sta  lk_memnxt-1,x		; set pointer to next page
		dey
		bne  -

		lda  #0					; last page points to NULL
		sta  lk_memnxt-1,x
		
		lda  tmpzp+1			; get pointer into membitmap
		and  #7
		tay
		lda  tmpzp+1
		lsr  a
		lsr  a
		lsr  a
		tax						; x is (byte) offset to bitmap
		lda  btab2r,y				; a=bit pattern, y=pointer into bitmap
		ldy  tmpzp				; y=number of pages to alloc

	-	pha
		eor  lk_memmap,x		; clear bit in bitmap
		sta  lk_memmap,x
		pla						; restore bit pattern
		dey						; switch to next bit
		beq  +					; all done, then end
		lsr  a
		bne  -					; crossed 8 page boundary ?

	-	inx						; yes, then continue with fast allocation
		lda  #128
		cpy  #8					; more than 7 pages left to alloc ?
		bcc  --					; no, then finish the slow way
		
		lda  #0					; yes, allocate 8 pages at once
		sta  lk_memmap,x
		tya
		sbc  #8
		beq  +					; all done, then end
		tay
		bne  -					; (always jump) continue the fast way. 

	+	ldx  tmpzp+1			; ok, all done so return
		jsr  unlocktsw
		clc						; carry cleared with X=startpage (=MID)
		rts


		;; function: spalloc
		;; allocate a single page (much faster, backward search)
		;; < X=page usage code / flags
		;; < Y=mode (bit7 = no I/O area)
		;; > c=0: X=start page
		;; > c=1: out of memory

		;; changes:		tmpzp(0,1)
		;; calls:		locktsw
		;; calls:		unlocktsw
		
spalloc:  
		jsr  locktsw
		stx  tmpzp				; X was usage/flags
		ldx  #31				; 32 map-bytes to scan
		tya
		bmi  spa_noio

	-	lda  lk_memmap,x
		bne  +					; hey, there is a page...
		dex
		bpl  -

_search_ered:
		;; no fit found, return with error
		jsr  unlocktsw
		sec
		rts						; return with carry set

spa_noio:
	-	lda  lk_memmap,x
		and  io_map,x
		bne  +					; hey, there is a page...
		dex
		bpl  -

		bmi  _search_ered		; (always jump)

		;; search for the set bit
		
	+	pha
		txa						; initialize pagenumber
		asl  a
		asl  a
		asl  a
		ora  #7
		tay						; get bit-pattern of page
		lda  lk_memmap,x
		pla
		
	-	lsr  a					; scann for the free page
		bcs  +					; found the free page!
		dey
		bne  -					; continue search
								; (loop never left this way)
		
	+	sty  tmpzp+1			; store found page
		lda  tmpzp				; and allocate it
		sta  lk_memown,y
		lda  #0					; no next page so pointer is NULL
		sta  lk_memnxt,y
		tya
		and  #7
		tay
		lda  lk_memmap,x  
		eor  btab2r,y			; clear bit in bitmap
		sta  lk_memmap,x
		ldx  tmpzp+1			; load highbyte of page in X (=MID)
		jsr  unlocktsw
		clc						; return with carry clear
		rts

		;; function: free
		;; free pages allocated with palloc, mpalloc or spalloc
		;; wrapper for pfree with security checks
		;; < X=start page
		;; calls:		pfree
free:
		lda  lk_ipid
		cmp  lk_memown,x		; (is a sanity check)
		bne  ill_free
		cpx  lk_tsp+1			; (another sanity check)
		bne  pfree
ill_free:		
		lda  #lerr_segfault
		jmp  suicerrout			; no way to catch this.
		
		       
		;; function: pfree
		;; free memory allocated with mpalloc or spalloc
		;; (new: you can also free parts of allocated memory now !)
		;; < X=startpage of memory
		
		;; (no error check!)
		;; (could do many sanity checks in here)
		;; calls:		locktsw
		;; calls:		unlocktsw
		

pfree:	jsr  locktsw
	-	lda  lk_memnxt,x		; is area already free (or fixed) ?
		pha						; remember next page
		lda  #1					; set mid and owner to default values (free)
		sta  lk_memnxt,x
		lda  #memown_none
		sta  lk_memown,x
		txa
		and  #7
		tay						; bit no.
		txa
		lsr  a
		lsr  a
		lsr  a
		tax						; (byte-) offset to bitmap
		lda  lk_memmap,x		; calculate bitpattern and set bit in
		ora  btab2r,y			; bitmap
		sta  lk_memmap,x
		pla
		cmp  #2
		bcc  pf_end
		tax
		bne  -					; not last page, then continue
pf_end:	
		jmp  unlocktsw

#include MACHINE(io_map.s)	

btab2r:	.byte $80,$40,$20,$10,$08,$04,$02,$01

		
