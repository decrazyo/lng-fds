		;; file system cache (experimental)
		;; ok, it really is a command cache (not a file system cache)

		;; known bugs (features??):
		;;   doesn't detect, if the disk or the file has been changed

#include "system.h"
				
.global fs_cache_tryload
.global fs_cache_update

		;; this piece of code maintains a list of cached files 
		;; (referenced by major,minor and filename) and memory 
		;; locations (internal memory) of the cached files.


		;; function:	fs_cache_update
		;; update file system cache
		;; add(remove?) file from cache
		;; < A/Y: filename with path
		;; < X: start address

fs_cache_update:		
		jsr  resolve_dev
		...
		
		;; function:	fs_cache_tryload
		;; fopen file from cache, if possible, else just return
		;; < A/Y: filename with path
		;; < c=1: file not in cache
		;; < c=0: X=start address
		;; changes:		syszp(2,3)
		;; calls:		resolve_dev
		
fs_cache_tryload:		
		jsr  resolve_dev
		bcs  error
		;; Y=major, X=minor, [syszp]=filename
		sty  syszp+2
		stx  syszp+3
		ldx  #0

		jsr  check_cache
		
search_loop:
		lda  cache_dir,x
		beq  search_end
		cmp  syszp+2
		bne  search_nxt
		lda  syszp+3
		cmp  cache_dir+1,x
		bne  search_nxt
		ldy  #0
	-	lda  (syszp),y
		beq  search_f
		cmp  cache_dir+2,x
		bne  search_nxt
		inx
		iny
		bne  -
		
search_nxt:
		lda  cache_dir+2,x
		beq  +
	-	inx
		bne  search_nxt
	+	txa
		clc
		adc  #5
		tax
		jmp  search_loop
		
search_f:
		lda  cache_dir+2,x
		bne  -
		lda  cache_dir+3,x		; startpage
		sta  syszp
		
		;; get size of cached file and lock memory pages

		sta  syszp+1			
		lda  #1
		sta  syszp+2

		lda  syszp+1
	-	lsr  a
		lsr  a
		lsr  a
		tay
		lda  syszp+1
		and  #$07
		tax
		lda  lk_memmap,y
		eor  btab2r,x			; clear bit of memory map (lock this page)
		sta  lk_memmap,y
		ldy  syszp+1
		lda  lk_ipid
		sta  lk_memown,y		; (page now belongs to current task)
		lda  lk_memnxt,y		; get size of cached file
		beq  +
		sta  syszp+1
		inc  syszp+2
		bne  -
		
	+	jsr  unlocktsw			; (had been locked by check_cache)

		lda  syszp+2
		ldx  lk_ipid
		ldy  #$80
		jsr  mpalloc			; allocate memory
		bcs  ???
		
		;; unlock and copy pages

		ldy  #0
		sty  syszp+2
		sty  syszp+4
		sta  syszp+1		
		sta  _cp_dest_hi
		
		lda  syszp
	-	sta  _cp_source_hi
		ldy  #0
		
		_cp_source_hi equ *+2
		_cp_dest_hi equ *+5
		
	-	lda  $ff00,y			; copy page
		sta  $ff00,y
		iny
		bne  -

		inc  _cp_dest_hi
		lda  syszp
		lsr  a
		lsr  a
		lsr  a
		tay
		lda  syszp
		and  #$07
		tax
		sei
		lda  lk_memmap,y
		eor  btab2r,x			; set bit (unlock page)
		sta  lk_memmap,y
		ldy  syszp
		lda  #memown_cache
		sta  lk_memown,y		; (page now belongs to cache again)
		lda  lk_memnxt,y
		cli
		sta  syszp
		bne  --

		...
		lda  syszp+1			; return with A=startpage
		rts


		;; remove chache entries, that have been (partially) overwritten
		;; changes:		syszp(5,6)
		;; calls:		locktsw
		
check_cache:
		jsr  locktsw
		ldy  #0
		sty  syszp+6

ck_loop:		
		sty  syszp+5
		lda  cache_dir,y
		beq  ck_end
		
	-	lda  cache_dir+2,y
		beq  +
		iny
		bne  -
	+	lda  cache_dir+3,y		; start page
	-	tax
		lda  lk_mennxt,x
		beq  valid
		cmp  #1
		bne  -
		;; entry is not valid any more (don't keep it)
ck_next:		
		tya
		adc  #4					; (y=y+5)
		tay
		jmp  ck_loop

valid:
		lda  cache_dir+4,y		; value
		lsr  a
		adc  #0
		lsr  a
		adc  #0
		sec
		eor  #$ff
		adc  cache_dir+4,y
		sta  cache_dir+4,y		; value = value - value/4  (kind of)
		ldx  syszp+6
		cpx  syszp+5
		beq  +					; (nothing removed jet)

		;; copy entry
		ldy  syszp+5
		lda  cache_dir,y
		sta  cache_dir,x
		lda  cache_dir+1,y
		sta  cache_dir+1,x
	-	inx
		iny
		lda  cache_dir+1,y
		sta  cache_dir+1,x
		bne  -
		lda  cache_dir+2,y
		sta  cache_dir+2,x
		lda  cache_dir+3,y
		sta  cache_dir+3,x
		txa
		adc  #4					; +4
		sta  syszp+6			; pointer to next remaining entry
		bcc  ck_next			; (always jump)
		
	+	txa
		adc  #4					; +5
		sta  syszp+6
		sec
		bcs  ck_next

ck_end:	lda  #0
		ldx  syszp+6
		sta  cache_dir,x
		rts
		
cache_dir:	.buf 256