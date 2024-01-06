#include "bootldr1.h"

; boot loader for disk II controller card

; The Apple II starts execution out by running the ROM code of the Disk II.
; This sets up a disk byte translation table and loads track 0, sector 0 of
; the disk medium (this following code) into memory at $0800 and starts
; execution at $0801.

; Our goal is to provide a small (256 byte hopefully) loader that will load
; the bootstrap code.  This code will then load the kernel.  (The ROM allows
; for only a small program to be loaded first; this isn't complex enough to
; span track/sectors.)
.global begin

begin:		.byte $01	; Defines number of sectors to be read in
				; from track 0 during the ROM bootup.

; At this stage of the game, a disk byte translation table is set up and
; the first 256 bytes of this boot loader are in memory.  We need to first
; do our pretty thing and then continue reading pages.

		lda DII_rdptr+1	; Get next page to read in.
		cmp #$09	; Is it page 9 (ie, first page read by bootldr)
		bne skpinit	; If no, we've already initialized-keep reading.

		; I trid clearing the screen here with ROM routines, but
		; it kept overwriting DII_slt16 - this confused me for days!

#ifdef BLOATWARE
printmsg:	ldy #$00	; Initialize counter
printloop:	lda _printmsg,y
		beq printdone	; Exit when done
		jsr $FDF0	; COUT1 - Print char to screen
		iny
		bne printloop	; always branch
printdone:
#endif


skpinit:	dec _load_amt	; Decrement counter of sectors to load
		beq done	; Finish if done..

#ifdef BLOATWARE
		lda #$AE	; a period to print for each sector loaded
		jsr $FDF0	; COUT1 - Print char to screen
#endif

		ldx _load_amt	; x = logical sector to read
		lda phys2log,x	; a = physical sector to read
		sta DII_sec	;     .. and store in rom boot variable

		; it should be noted that while we dec _load_adr, and store it
		; at DII_rdptr+1, the ROM rdsec routine does INC DII_rdptr+1...

		dec _load_adr
		lda _load_adr
		sta DII_rdptr+1	; Initialize pointer to boot buffer

		ldx DII_slt16	; x must be initialized before calling next func
		jmp DII_rdsec	; ROM routine to read a sector

		; Note that this routine returns execution to $801,
		; which is the beginning of this code..

done:		dec DII_rdptr+1	; ..because of note above..
		jmp (DII_rdptr)	; last page read in - start of second boot stg

#ifdef BLOATWARE
_printmsg:	.aasc "\n\nLunix Boot 1 Loader\n"
		.aasc "Loading...\0"
#endif

; physical to logical sector table
phys2log:	.byte $00,$0D,$0B,$09,$07,$05,$03,$01
		.byte $0E,$0C,$0A,$08,$06,$04,$02,$0F

; _load_amt is +1 because i want to use it as a sector reference too (and
; only 15 sectors max can be used since t0 s0 is this very bootloader)
; and is decremented before used. (also why _load_adr is not -$01 - dec.)

_load_adr:	.byte load_adr+load_amt
_load_amt:	.byte load_amt+$1
