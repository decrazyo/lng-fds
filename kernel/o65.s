
; .o65 loader for LUnix, based on original code by Andre Fachat
;
; Maciej Witkowiak <ytm@elysium.pl>
; 24,28,30.11.2001, 18.11.2002
; 2003-09-10, Greg King <gngking@erols.com>

; CHANGES:
; - fixed: loado65 handles errors (frees RAM, closes file, and returns code) correctly (GK).
; - fixed: loado65 never allocates an excess RAM-page (GK).
; - added: programs can use loado65 to load, relocate, and link modules without running them (GK).

; TODO
; - some things seem to be calculated twice
; - get address of 'main' (entry point) from exported variables (later or never)
;   (execute.s and addtask.s will need changes then too (addtask allows only for page-hi addr))
; - note that load_block == fread()

#include <config.h>

#ifdef HAVE_O65

#include <system.h>
#include <kerrors.h>
#include <zp.h>
#include <ikernel.h>

#define	A_ADR		$80
#define	A_HIGH		$40	 ; or'd with the low byte
#define	A_LOW		$20

#define	A_MASK		$e0	 ; reloc type mask
#define	A_FMASK		$0f	 ; segment type mask

#define	SEG_UNDEF	0
#define	SEG_ABS		1
#define	SEG_TEXT	2
#define	SEG_DATA	3
#define	SEG_BSS		4
#define	SEG_ZERO	5

#define	FM_ADDR		%00001000
#define	FM_TYPE		%00010000
#define	FM_SIZE		%00100000
#define	FM_RELOC	%01000000
#define	FM_CPU		%10000000

#define O65_OPTION_OS	1

#define O65_OS_LUNIX	2

		.global loado65

err_memory:	lda #lerr_outofmem
		SKIP_WORD
err_hdr:	lda #lerr_illcode
error1:		pha
		ldx p3
		jsr fclose
		ldx #lsem_o65		; unlock semaphore
		jsr unlock
		pla
		sec
		rts

		;; function: loado65
		;; Loads and relocates an o65-format file.
		;; Links function-calls to the kernel.
		;; < X = fd, first two bytes (magic number) already read
		;; > C=0: A/Y = execute-address ($00/first-page)
		;; > C=1: A = error-code
		;; calls: lock,unlock,fgetc,fclose,mpalloc,pfree

loado65:	txa
		pha
		sec			; (wait until other relocation finishes)
		ldx #lsem_o65		; raise semaphore for o65 relocation
		jsr lock
		pla
		tax
		stx p3			; save fd

		;; verify "o65" signature
		jsr fgetc
		cmp #$6f		; "o"
		bne err_hdr
		jsr fgetc
		cmp #"6"
		bne err_hdr
		jsr fgetc
		cmp #"5"
		bne err_hdr
		jsr fgetc		; version (ignored)

		;; get low-byte of mode
		jsr fgetc
		bcs error1
		and #%00000011
		sta amode		; store align mode

		;; check high-byte of mode
		jsr fgetc
		bcs error1
		and #FM_CPU | FM_SIZE | FM_TYPE
		bne err_hdr

		;; load rest of header data
		ldy #0
	-	jsr fgetc
		bcs error1
		sta o65_header, y
		iny
		cpy #18
		bne -

;;inc $d020
		;; load and ignore most header options
	-	jsr fgetc
		bcs error1
		beq _cont		; no more options
		tay
		dey			; number of bytes that follow
		cpy #3			; 3-byte-long option -- might be OS
		beq +

		;; skip option
	-	jsr fgetc
		bcs error1
		dey
		bne -
		beq --			; read next option

	+	jsr fgetc
		dey
		cmp #O65_OPTION_OS
		bne -
		jsr fgetc
		dey
		cmp #O65_OS_LUNIX
		bne err_hdr		; not LUnix -- illegal code
		beq -			; ignore version byte

_cont:
		;; zero segment check - zbase, zlen are ignored, zerod is not set
		;; system.h header is used to reference zero page locations, so
		;; no relocation is needed

;;		stx p3			; save fd

		;; align header lengths (as in original loader)
		lda tlen
		ldy tlen+1
		jsr doalign		; align text segment start
		clc
		adc dlen
		pha
		tya
		adc dlen+1
		tay
		pla
		jsr doalign
		clc
		adc bsslen
		pha
		tya
		adc bsslen+1
		tay
		pla
		;; total length of needed space (with aligned lengths) is in A/Y
		;; mpalloc allocates full pages only, so...
		beq +
		iny			; ... augment (when necessary)
	+	tya			; number of needed pages
		ldx lk_ipid		; owner
		ldy #$80		; mode - no I/O
		jsr mpalloc		; pagewise allocation
		bcc +
		jmp err_memory		; not enough memory

	+	txa
		sta textm+1
		tay
		lda #0
		sta textm

		;; compute textd, datad, bssd, zerod
		sec
		sbc tbase
		sta textd
		tya
		sbc tbase+1
		sta textd+1

		lda tlen
		ldy tlen+1
		jsr doalign
		clc
		adc textm
		pha
		tya
		adc textm+1
		tay
		pla
		sta datam
		sty datam+1
		sec
		sbc dbase
		sta datad
		tya
		sbc dbase+1
		sta datad+1

		lda dlen
		ldy dlen+1
		jsr doalign
		clc
		adc datam
		pha
		tya
		adc datam+1
		tay
		pla

		sec
		sbc bssbase
		sta bssd
		tya
		sbc bssbase+1
		sta bssd+1

		;; if error happens past this point - free allocated memory
		;; ok, memory is owned, now load text and data segments into memory
		ldx p3			; restore fd
		lda textm
		ldy textm+1
		sta p1
		sty p1+1
		lda tlen
		ldy tlen+1
		sta p2
		sty p2+1
		jsr load_block
		bcs error2

		lda datam
		ldy datam+1
		sta p1
		sty p1+1
		lda dlen
		ldy dlen+1
		sta p2
		sty p2+1
		jsr load_block
		bcs error2

		;; check for undefined variables;
		;; if there are many, exit with error
		jsr fgetc
		bcs error2
		cmp #<1			; lowbyte =1, hibyte =0
		bne err_references
		jsr fgetc
		bcs error2
		bne err_references	; more than 1 undefined references!

		;; check if undefined variable is "LUNIXKERNEL"
		ldy #0
	-	jsr fgetc
		bcs error2
		cmp lunix_kernel, y
		bne err_references
		iny
		cmp #$00
		bne -

		;; file pointer is at the start of text segment relocation table - relocate
		ldy textm+1
		ldx textm
		bne +
		dey
	+	dex
		sty p1+1
		stx p1
		jsr o65_relocate	; relocate text segment
		bcs error2

		ldy datam+1
		ldx datam
		bne +
		dey
	+	dex
		sty p1+1
		stx p1
		jsr o65_relocate	; relocate data segment
		bcs error2

		;; ignore exported labels OR get main from there (otherwise start of text is main)

		;; close the file
		ldx p3
		jsr fclose
		lda textm
		pha
		lda textm+1
		pha
		;; ready to fork, A/Y is the execute address
		ldx #lsem_o65		; unlock semaphore
		jsr unlock
		pla
		tay
		pla
		clc
		rts

err_references:	;; too many undefined references
		lda #lerr_illcode
		;; file is corrupt -- free memory, close file
error2:		pha
		ldx textm+1
		jsr pfree
		ldx p3
		jsr fclose
		ldx #lsem_o65		; unlock semaphore
		jsr unlock
		pla
		sec
		rts

		;; load #p2 bytes into (p1) with X==fd
	-	jsr fgetc
		bcs err_load
		ldy #0
		sta (p1),y
		inc p1
		bne +
		inc p1+1
	+	lda p2
		bne +
		dec p2+1
	+	dec p2
load_block:	lda p2
		ora p2+1
		bne -
		clc
err_load:	rts

		;; file-pointer is at start of relocation table
		;; p1 holds start_of_segment-1, p2 is used, p3 is fd
o65_relocate:	ldx p3			; fd
o65_relocate2:	jsr fgetc
		bcs o65_reloc_err
		cmp #0
		beq o65_reloc_end

		cmp #255
		bne +			;(bcc)
		lda #254-1
		;sec
		adc p1
		sta p1
		bcc o65_relocate2
		inc p1+1
		bne o65_relocate2	; always branch

	+	;clc
		adc p1
		sta p1
		bcc +
		inc p1+1		; (p1) is the relocation address

	+	jsr fgetc
		bcs o65_reloc_err
		tay
		and #A_MASK
		sta amode
		tya
		and #A_FMASK
		cmp #SEG_UNDEF
		bne +
		jsr o65_handle_undefined
		bcc o65_relocate
		bcs o65_reloc_err	; always branch

	+	jsr o65_reldiff
		ldy amode
		cpy #A_ADR
		bne +
		ldy #0
		clc
		adc (p1),y
		sta (p1),y
		iny
		txa
		adc (p1),y
		sta (p1),y
		jmp o65_relocate

	+	cpy #A_LOW
		bne +
		ldy #0
		clc
		adc (p1),y
		sta (p1),y
		jmp o65_relocate

	+	cpy #A_HIGH
		bne o65_relocate
		sta p2
		stx p2+1
		ldx p3			; fd
		jsr fgetc
		bcs o65_reloc_err
		;clc
		adc p2			; get carry for high-byte addition
		ldy #0
		lda p2+1
		adc (p1),y
		sta (p1),y
		jmp o65_relocate

o65_reloc_end:	clc
o65_reloc_err:	rts

o65_reldiff:	; get difference to segment
		cmp #SEG_TEXT
		bne +
		lda textd
		ldx textd+1
		rts

	+	cmp #SEG_DATA
		bne +
		lda datad
		ldx datad+1
		rts

	+	cmp #SEG_BSS
		bne +
		lda bssd
		ldx bssd+1
		rts

	+
;;		cmp #SEG_ZERO
;;		bne o65_reldiff_err
		lda #0			; don't relocate zero page - return $0000 as base
		tax
;;o65_reldiff_err:			; unknown segment type
		rts

o65_handle_undefined:
		;; handle undefined labels, now only LUNIXKERNEL (as base of virtual jumptable)
		;; in the future maybe LIB6502 for shared functions
		;; (changes X)
		lda amode
		cmp #A_ADR		; only 16-bit relocation allowed here
		bne o65_link_err
		jsr fgetc
		sta p2
		jsr fgetc
		ora p2
		bne o65_link_err	; only relocation of label 0 allowed

		ldy #0
		lda (p1), y		; low byte is offset into virtual kernel jumptable
		cmp #lkfunc_max
		bcs o65_link_err	; must be less than twice number-of-functions
		tax
		lsr a			; warning, only 128 kernel calls!
		bcs o65_link_err	; must be even
		lda kfunc_tab, x
		sta (p1), y
		iny
		lda kfunc_tab+1, x
		sta (p1), y
		;clc
		rts

o65_link_err:	lda #lerr_illcode
		sec
		rts

doalign:	ldx amode		; increase given value to align it
		clc
		adc aadd, x
		and aand, x
		pha
		tya
		adc aadd+1, x
		and aand+1, x
		tay
		pla
		rts

; alignment table:	  byte,     word,     long,        page
aadd:		.word        1-1,      2-1,      4-1,      $100-1
aand:		.word $10000-1, $10000-2, $10000-4, $10000-$100

; the only undefined reference is to base of virtual kernel jump table
lunix_kernel:	.text "LUNIXKERNEL",0

;;; ZEROpage: p1 2
; these really don't need to be on zero-page, but it is handy
;;; ZEROpage: p2 2
;;; ZEROpage: p3 1
;;; ZEROpage: amode 1
;;; ZEROpage: textm 2
;;; ZEROpage: datam 2
;p2:		.word 0
;p3:		.byte 0			; file-number
;amode:		.byte 0			; alignment/addressing mode
;textm:		.word 0			; aligned base address of everything
;datam:		.word 0

; o65_header (26 bytes)
o65_header:
tbase:		.word 0			; tbase
tlen:		.word 0			; tlen
dbase:		.word 0			; dbase
dlen:		.word 0			; dlen
bssbase:	.word 0			; bssbase
bsslen:		.word 0			; bsslen
textd:					; (borrow next variable)
zbase:		.word 0			; zbase (once)
datad:					; (borrow next variable)
zlen:		.word 0			; zlen	(once or never)
;zerod:		;.word 0
bssd:					; (borrow next variable)
stack:		.word 0			; stack (never)

#else
loado65:	rts			; (need to put something)
#endif
