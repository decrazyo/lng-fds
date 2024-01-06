
        .export         _close
        .export         _write
        .import         __oserror
        .importzp       sp, ptr1, ptr2, ptr3, tmp2
		.import	popax
		.import __errno
		.import _stdout

        .include        "fcntl.inc"
        .include        "cbm.inc"

		.include "../../include/jumptab.ca65.h"

EINVAL=1	; error: invalid handle
MAX_FDS=5   ; max filedescriptors per task

        .include        "filedes.inc"

_close:
		tax
		jsr lkf_fclose
		lda #0
		tax
		rts

;--------------------------------------------------------------------------
; rwcommon: Pop the parameters from stack, preprocess them and place them
; into zero page locations. Return carry set if the handle is invalid,
; return carry clear if it is ok. If the carry is clear, the handle is
; returned in A.

rwcommon:

        eor     #$FF
        sta     ptr1
        txa
        eor     #$FF
        sta     ptr1+1          ; Remember -count-1

        jsr     popax           ; Get buf
        sta     ptr2
        stx     ptr2+1

        lda     #$00
        sta     ptr3
        sta     ptr3+1          ; Clear ptr3

        jsr     popax           ; Get the handle
   ;     cpx     #$01
   ;     bcs     invhandle
   ;     cmp     #MAX_FDS
   ;     bcs     invhandle
   ;     sta     tmp2
        rts                     ; Return with carry clear

;invhandle:
;        lda     #EINVAL
;        sta     __errno
;        lda     #0
;        sta     __errno+1
;        rts                     ; Return with carry set

;; size_t write(int fd,char *buf,size_t count)
_write:
		jsr rwcommon
		tax ; handle into X


		;; do this in constructor
;;        lda     #LFN_WRITE
;;        sta     fdtab+STDOUT_FILENO
;;        sta     fdtab+STDERR_FILENO
;;        lda     #CBMDEV_SCREEN
;;        sta     unittab+STDOUT_FILENO
;;        sta     unittab+STDERR_FILENO

;;  		lda #FILENO_STDOUT
;;		sta __filetab+STDOUT_FILENO


; Output the next character from the buffer

@L0:    ldy     #0
        lda     (ptr2),y
        inc     ptr2
        bne     @L1
        inc     ptr2+1          ; A = *buf++;
@L1:
;; inc 	$d020
;;  	ldx #stdout
		jsr lkf_fputc
        bcs     error           ; Bail out on errors

; Count characters written

        inc     ptr3
        bne     @L2
        inc     ptr3+1

; Decrement count

@L2:    inc     ptr1
        bne     @L0
        inc     ptr1+1
        bne     @L0

; Return the number of chars written

        lda     ptr3
        ldx     ptr3+1
        rts

error:  
;;		sta     __oserror
errout: lda     #$FF
        tax                     ; Return -1
        rts
