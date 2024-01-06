		;; SMB (small memory block)
		;; management

#include <system.h>

		.global smb_alloc
		.global smb_free
		.global get_smbptr

		;; 31 * 8 = 248 SMBs max
		;; (the SMB-IDs 0..7 are illegal)
		
		;; SMB are used anytime the kernel only needs to
		;; allocate 32 bytes (instead of 256 byte of a whole page)
		;; (tstatus_szu must be set !)

		;; function: smb_alloc
		;; allocate SMB (small memory block - 32 bytes)
		;; < c=non blocking
		;; > syszp=address, X=SMB

		;; changes:		A,X,Y
		;; changes:		tmpzp(2)
		;; changes:		syszp(0,1)
		;; calls: locktsw,unlocktsw,spalloc,block
		
smb_alloc:
		php
		jsr  locktsw
		lda  #0
		sta  syszp				; best
		ldx  #31
		
	-	lda  lk_smbmap,x
		beq  +					; skip (page is full)
		eor  #$ff
		beq  +					; skip (page is unused)
		ldy  #0					; count the number of set bits
	-	iny	
	-	asl  a					; (is number of used SMBs in)
		bcc  -
		bne  --
		cpy  syszp
		bcc  +					; skip (already had better page)
		sty  syszp
		stx  syszp+1
	+	dex
		bne  ---

		lda  syszp
		beq  newalloc

		;; it's simple, just use a spare area

		ldx  syszp+1
		lda  lk_smbmap,x
		ldy  #255				; get number of first set bit
	-	iny
		lsr  a
		bcc  -

raw_alloc:		
		sty  syszp
		txa
		asl  a
		asl  a
		asl  a
		ora  syszp
		sta  tmpzp+2			; SBM-ID
		lda  bit_n_set,y		; A=2**Y
		eor  lk_smbmap,x
		sta  lk_smbmap,x
		lda  lk_smbpage,x
		sta  syszp+1
		tya
		lsr  a
		ror  a
		ror  a
		ror  a
		sta  syszp
		ldx  tmpzp+2
		plp
		jsr  unlocktsw			; return with syszp=address, X=SMB-ID
		clc
	-	rts

		;; not that simple, need to allocate a new page

newalloc:		
		ldx  #31
		lda  #$ff

	-	cmp  lk_smbmap,x
		beq  +
		dex
		bne  -

	-	jsr  unlocktsw
		plp
		bcs  ---				; (return with error)
		php
		lda  #waitc_smb			; no SMB-slot left
		ldx  #0
		jsr  block
		jsr  locktsw
		jmp  newalloc
		
	+	stx  tmpzp+2			; SBM-ID
		ldy  #0
		ldx  #memown_smb
		jsr  spalloc			; out of memory, then wait for
		bcs  -					; another available SMB

		txa
		ldx  tmpzp+2
		sta  lk_smbpage,x
		lda  #$ff
		sta  lk_smbmap,x
		ldy  #0
		jmp  raw_alloc


		;; function: smb_free
		;; free SMB allocated with smb_alloc
		;; < X=SMB-ID
		;; calls:		locktsw
		;; calls:		unlocktsw
		;; calls:		pfree
		
smb_free:
		jsr  locktsw
		txa
		lsr  a
		lsr  a
		lsr  a
		tay
		txa
		and  #7
		tax
		lda  bit_n_set,x
		and  lk_smbmap,y
		bne  +					; already freed
		lda  bit_n_set,x
		ora  lk_smbmap,y
		sta  lk_smbmap,y
		cmp  #$ff
		bne  +					; skip if page is not empty
		ldx  lk_smbpage,y
		lda  #0
		sta  lk_smbpage,y
		jsr  pfree
	+	jmp  unlocktsw

		;; function: get_smbptr
		;; get pointer to SMB
		;; < X = SMB-ID
		;; > syszp = ptr, c=error
		;; changes: syszp(0,1)
		
get_smbptr:
		txa
		lsr  a
		ror  a
		ror  a
		tay
		ror  a
		and  #%11100000
		sta  syszp
		tya
		and  #%00011111
		tay
		lda  lk_smbpage,y
		sta  syszp+1
		txa
		and  #7
		tax
		lda  bit_n_set,x		; A=2**x
		and  lk_smbmap,y
		cmp  #1					; carry cleared, when SMB is valid
		rts						; c=1 means illegal SMB-ID


