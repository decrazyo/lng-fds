		;; virtual filesystem (pipes)
		;;

#include <config.h>
#include <system.h>
#include <kerrors.h>
#include <fs.h>

		.global popen
		.global fs_pipe_fopen
		.global fs_pipe_fclose
		.global fs_pipe_fputc
		.global fs_pipe_fgetc
		
_omem1:	ldx syszp+4
		jsr  smb_free
	-	lda  #lerr_illarg
		SKIP_WORD
_outofmem:
		lda  #lerr_outofmem
		jmp  catcherr

		;; function: popen
		;; open bidirectional pipe
		;; > X/Y fd for reading/writing
		;; calls: smb_alloc 
		
fs_pipe_fopen:
		lda  syszp+2
		cmp  #fmode_rw
		bne  -
popen:
		sei
#ifndef ALWAYS_SZU
		ldx  lk_ipid
		lda  #tstatus_szu
		ora  lk_tstatus,x
		sta  lk_tstatus,x
#endif
		ldy  #tsp_ftab			; check if there are 2 unused ftab-slots
		ldx  #2
	-	lda  (lk_tsp),y
		bne  +
		dex
		beq  ++					; ok
	+	iny
		cpy  #tsp_ftab+MAX_FILES
		bne  -
		lda  #lerr_toomanyfiles
		jmp  catcherr
		
	+	cli
		sec						; non blocking
		jsr  smb_alloc
		bcs  _outofmem
		;; X=SMB-ID1, syszp=address1
		stx  syszp+4
		lda  syszp
		sta  syszp+5
		lda  syszp+1
		sta  syszp+6
		sec
		jsr  smb_alloc
		bcs  _omem1
		;; X=SMB-ID2, syszp=address2
		stx  syszp+3
		ldy  #0
		lda  #MAJOR_PIPE
		sta  (syszp),y			; set major
		sta  (syszp+5),y		; set major
		lda  #0
		iny
		sta  (syszp+5),y		; set minor (SMB1)
		sta  (syszp),y			; set minor (SMB2)
		iny
		sta  (syszp),y			; set rd-counter (SMB2)
		lda  #1
		sta  (syszp+5),y		; set rd-counter (SMB1)
		iny
		sta  (syszp),y			; set wr-counter (SMB2)
		lda  #0
		sta  (syszp+5),y		; set wr-counter (SMB1)
		lda  #fflags_read
		iny
		sta  (syszp+5),y		; set flags (read-only) (SMB1)
		lda  #fflags_write
		sta  (syszp),y			; set flags (write-only) (SMB2)
		iny
		lda  syszp+4
		sta  (syszp),y			; set SMB1-ID (in SMB2)
		lda  syszp+3
		sta  (syszp+5),y		; set SMB2-ID (in SMB1)
		lda  #pflags_empty
		iny
		sta  (syszp+5),y		; set pipe-flags (empty)
		lda  #15
		iny
		sta  (syszp+5),y		; set pipe-readptr
		iny
		sta  (syszp+5),y		; set pipe-writeptr
		ldx  syszp+4			; ("convert SMB-ID into fs")
		jsr  alloc_pfd			; (will be successfull)
		stx  syszp+4
		ldx  syszp+3
		jsr  alloc_pfd			; (will be successfull)
		stx  syszp+3
#ifndef ALWAYS_SZU
		sei
		ldx  lk_ipid
		lda  #$ff-tstatus_szu
		and  lk_tstatus,x
		sta  lk_tstatus,x
		ldx  syszp+4			; fs for reading
		ldy  syszp+3			; fs for writing
		cli
#else
		ldx  syszp+4
		ldy  syszp+3
#endif
		clc
		rts

fs_pipe_fclose:
		ldy  #fsmb_flags
		lda  (syszp),y
		and  #fflags_read
		bne  close_read_end
		
;close_write_end
		ldy  #psmb_otherid
		lda  (syszp),y
		beq  +					; done
		sta  syszp+3
		tax
		jsr  get_smbptr
		ldy  #psmb_otherid
		lda  #0
		sta  (syszp),y			; erase link
		ldy  #psmb_flags
		lda  (syszp),y
		and  #pflags_rdwait
		beq  +
		;; someone is waiting for data! (must unblock)
		lda  #waitc_stream
		ldx  syszp+3			; (reader's SMB-ID)
		jsr  mun_block
	+	rts						; done

close_read_end:
		;; free all used (data) memory
		ldy  #psmb_flags
		lda  (syszp),y
		and  #pflags_large
		beq  ++					; nothing to free
		ldy  #psmb_wrpos
		lda  (syszp),y
		sta  syszp+2
		ldy  #psmb_rdpos
		lda  (syszp),y
		tay
		
	-	sty  syszp+3
		lda  (syszp),y
		jsr  pfree
		ldy  syszp+3
		iny
		cpy  #32
		bne  +
		ldy  #psmb_wrptr+1
	+	cpy  syszp+2
		bne  -

	+	ldy  #psmb_flags
		lda  (syszp),y
		sta  syszp+4
		ldy  #psmb_otherid
		lda  (syszp),y
		beq  rdclose_done
		sta  syszp+3
		tax
		jsr  get_smbptr
		ldy  #psmb_otherid
		lda  #0
		sta  (syszp),y
		lda  syszp+4
		and  #pflags_wrwait
		beq  rdclose_done
		;; someone is waiting for bufferspace! (must unblock)
		lda  #waitc_stream
		ldx  syszp+3			; (writer's SMB-ID)
		jsr  mun_block

rdclose_done:
		rts


		;; buffer is full
	-	bit  syszp+4			; check flags
		bmi  +					; block till byte is available
		lda  #lerr_tryagain
		jmp  io_return_error
		
	+	lda  (syszp),y
		ora  #pflags_wrwait
		sta  (syszp),y
		lda  #waitc_stream
		ldx  syszp+2
		jsr  block
		ldy  #fsmb_rdcnt
		lda  (syszp),y
		beq  _fputc_error
		jmp  +
		
fs_pipe_fputc:					; data byte is in syszp+5
		ldy  #psmb_otherid
		lda  (syszp),y
		beq  _fputc_error		; can't write, because there is no destination
		sta  syszp+6			; remember SMB-ID
		tax
		jsr  get_smbptr
		
	+	ldy  #psmb_flags
		lda  (syszp),y
		tax
		and  #pflags_full
		bne  -
		txa
		and  #$ff-(pflags_empty+pflags_rdwait)
		sta  (syszp),y
		txa
		and  #pflags_rdwait		; check if someone must be woken up
		pha						; store mun_block-flag
		;; <<-- check for large mode (not implemented yet)

		;; put short (without use of extra data pages)
		ldy  #psmb_wrpos
		lda  (syszp),y
		tay
		lda  syszp+5			; data byte
		sta  (syszp),y
		iny
		cpy  #32
		bne  +
		ldy  #psmb_wrpos+1
	+	tya
		ldy  #psmb_wrpos
		sta  (syszp),y
		ldy  #psmb_rdpos
		cmp  (syszp),y
		bne  wrdone1
		;; <<-- try to expand (not implemented yet)
		ldy  #psmb_flags
		lda  #pflags_full
		ora  (syszp),y
		sta  (syszp),y
wrdone1:
		pla
		beq  +
		lda  #waitc_stream
		ldx  syszp+6			; other SMB-ID
		jsr  mun_block			; unblock waiting tasks
	+	jmp  io_return

_fputc_error:
		lda  #lerr_brokenpipe
		SKIP_WORD
		
_fgetc_EOF:
		lda  #lerr_eof
		jmp  io_return_error
		
		;; buffer is empty
	-	ldy  #psmb_otherid
		lda  (syszp),y
		beq  _fgetc_EOF			; no source left, this is EOF

		bit syszp+4				; check flag
		bmi  +					; do block
		lda  #lerr_tryagain
		jmp  io_return_error
		
	+	ldy  #psmb_flags
		lda  (syszp),y
		ora  #pflags_rdwait
		sta  (syszp),y
		lda  #waitc_stream
		ldx  syszp+2
		jsr  block				; block, then try again
		
fs_pipe_fgetc:
		ldy  #psmb_flags
		lda  (syszp),y
		tax
		and  #pflags_empty
		bne  -
		txa
		and  #$ff-(pflags_full+pflags_wrwait)
		sta  (syszp),y
		txa
		and  #pflags_wrwait		; check if someone must be woken up
		pha						; remember munblock-flag
		
		;; <<-- check for large mode (not implemented yet)

		;; short mode
		ldy  #psmb_rdpos
		lda  (syszp),y
		tay
		lda  (syszp),y
		sta  syszp+5			; data byte
		iny
		cpy  #32
		bne  +
		ldy  #psmb_wrpos+1
	+	tya
		ldy  #psmb_rdpos
		sta  (syszp),y
		ldy  #psmb_wrpos
		cmp  (syszp),y
		bne  +
		ldy  #psmb_flags
		lda  #pflags_empty
		ora  (syszp),y
		sta  (syszp),y
	+	pla
		beq  +
		ldy  #psmb_otherid
		lda  (syszp),y
		tax
		lda  #waitc_stream
		jsr  mun_block			; unblock waiting tasks (syszp 0-4 changed)
	+	clc
		lda  syszp+5
		jmp  io_return
