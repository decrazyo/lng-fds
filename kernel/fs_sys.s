;; root filesystem (virtual)
;; only allows to list its contents
;;
;; Maciej 'YTM/Elysium' Witkowiak <ytm@elysium.pl>
;; 04.01.2002

#include <config.h>
#include MACHINE_H
#include <system.h>
#include <kerrors.h>
#include <fs.h>
#include <zp.h>

		.global fs_sys_fopendir
		.global fs_sys_freaddir
		.global fs_sys_fclose

	-	lda  #lerr_nosuchdir
		jmp  catcherr

fs_sys_fopendir:
		ldy  #0
		lda  (syszp),y
		bne  -				; only current dir '/'

		jsr  enter_atomic

		jsr  alloc_pfd
		bcs  fs_sys_error
		stx  syszp+4			; remember fd
		sec
		jsr  smb_alloc			; non-blocking
		bcs  _oerr1
		stx  syszp+3			; remember smb-id
		lda  syszp+4
		clc
		adc  #tsp_ftab
		tay
		txa
		sta  (lk_tsp),y			; store smb-id
		ldy  #0
		lda  #MAJOR_SYS
		sta  (syszp),y			; major
		tya
		iny
		sta  (syszp),y			; minor

		ldy  #iecsmb_status
		sta  (syszp),y
		ldy  #iecsmb_dirstate
		lda  #4
		sta  (syszp),y			; first entry offset
		jsr  leave_atomic
		ldx  syszp+4
fs_sys_fclose:	clc
		rts

_oerr1:		tax				; remember error
		clc
		lda  syszp+4
		adc  #tsp_ftab
		tay
		lda  #0
		sta  (lk_tsp),y
		txa

fs_sys_error:	pha
		jsr  leave_atomic
		pla
		jmp  catcherr

fs_sys_freaddir:
		;; store next entry in structure (syszp+5)
		jsr  enter_atomic
		ldy  #iecsmb_dirstate
		lda  (syszp),y
		bpl  +				; last entry
		lda  #lerr_eof
		bne  fs_sys_error

	+	and  #%01111111			; get offset
		tax
		ldy  #12			; filename offset
	-	lda  pprefix,x
		jsr  cbm2unix
		cmp  #0
		sta  (syszp+5),y
		beq  +
		inx
		iny
		bne  -
	+	inx
		inx
		inx
		ldy  #iecsmb_dirstate
		lda  pprefix,x			; is there next device?
		bne  +
		lda  #$80			; no - set eof flag
		SKIP_BYTE
	+	txa
		sta  (syszp),y
		lda  #%00000011			; permissions and length valid
		ldy  #0
		sta  (syszp+5),y
		iny
		lda  #%10000111			; d----rwx
		sta  (syszp+5),y
		iny
		lda  #0				; length and date
	-	sta  (syszp+5),y
		iny
		cpy  #12
		bne  -

		jsr  leave_atomic
		clc
		rts
