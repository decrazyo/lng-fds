		;; user defined filesystem

		;; currently used for TCP/IP streams
		;; connect or accept return two streams

#include <config.h>
#include <fs.h>
#include <system.h>
#include <kerrors.h>

		.global ufd_open
		.global fs_user_fgetc
		.global fs_user_fputc
		.global fs_user_fclose

		;; function: ufd_open
		;; create user defined stream
		;; fgetc/fputc and fclose calls are redirected to a user defined
		;; function

		;; < A=minor, bit$=pointer to function
		;; > X=fd, c=error
		;; calls: smb_alloc

	-	tax
		clc
		lda  syszp+4
		adc  #tsp_ftab
		tay
		lda  #0
		sta  (lk_tsp),y
		txa
	-	jmp  catcherr
		
ufd_open:
#ifndef ALWAYS_SZU
		sei
		sta  syszp+7			; remember minor
		ldx  lk_ipid
		lda  #tstatus_szu
		ora  lk_tstatus,x
		sta  lk_tstatus,x
#else
		sta  syszp+7
#endif
		jsr  alloc_pfd			; (does cli)
		bcs  -
		stx  syszp+4			; remember fd
		sec						; non blocking
		jsr  smb_alloc
		bcs  --
		stx  syszp+3			; remember SMB-ID

		lda  syszp+4
		clc
		adc  #tsp_ftab
		tay
		txa
		sta  (lk_tsp),y			; store SMB-ID
		
		ldy  #0
		lda  #MAJOR_USER
		sta  (syszp),y			; major
		lda  syszp+7
		iny
		sta  (syszp),y			; minor
		lda  #1					; rdcnt=1 / wrcnt=1
		iny
		sta  (syszp),y			; ->rdcnt
		iny
		sta  (syszp),y			; ->wrcnt
		lda  #(fflags_read|fflags_write)
		iny
		sta  (syszp),y			; ->flags
		lda  #<(notimpl-1)
		iny
		sta  (syszp),y			; ->usersmb_ufunc  (default)
		lda  #>(notimpl-1)
		iny		
		sta  (syszp),y			; ->usersmb_ufunc+1

		jsr  get_bitadr
		txa
		bne  +
		dey
	+	dex
		tya
		ldy  #usersmb_ufunc+1
		sta  (syszp),y
		txa
		dey
		sta  (syszp),y
		
#ifndef ALWAYS_SZU
		ldx  lk_ipid
		sei
		lda  #~tstatus_szu
		and  lk_tstatus,x
		sta  lk_tstatus,x
		ldx  syszp+4			; load fd
		cli
#else
		ldx  syszp+4
#endif
		clc
		rts
		

		;; default user-function
notimpl:
		cpx  #fsuser_fclose
		beq  +
		lda  #lerr_notimp
		jmp  io_return_error
	+	rts

fs_user_fclose:
		ldx  #fsuser_fclose
		SKIP_WORD
fs_user_fputc:
		ldx  #fsuser_fputc
		SKIP_WORD
fs_user_fgetc:
		ldx  #fsuser_fgetc
		ldy  #usersmb_ufunc+1
		lda  (syszp),y
		pha
		dey
		lda  (syszp),y
		pha
		rts
		
