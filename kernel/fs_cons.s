;; for emacs: -*- MODE: asm; tab-width: 4; -*-

		;; virtual filesystem (console)
		;;

#include <config.h>
#include <system.h>
#include <kerrors.h>
#include <fs.h>
#include <zp.h>
#include <console.h>

		.global console_open
		.global console_passkey

		.global fs_cons_fopen
		.global fs_cons_fclose
		.global fs_cons_fputc
		.global fs_cons_fgetc

		#define BUFSIZE 16		; size of keyboard buffer (must be 2**N !!)

_toomany:
		ldx  syszp+3
		jsr  smb_free
		lda  #lerr_toomanyfiles
		.byte $2c
_outofmem:
		lda  #lerr_outofmem
		dec  usage_count
		jmp  catcherr

		;; changed :
		;;  for multiple consoles console_open returns a valid file descriptor
		;;  as long as there are virtual consoles left

console_open:
fs_cons_fopen:
		sei
#ifdef MULTIPLE_CONSOLES
		lda  usage_count
		inc  usage_count
		cmp  lk_consmax
		bcs  _toomany
#else
		lda  usage_count
		bne  _toomany
		inc  usage_count
#endif
#ifndef ALWAYS_SZU
		ldx  lk_ipid
		lda  #tstatus_szu
		ora  lk_tstatus,x
		sta  lk_tstatus,x
#endif
		cli

		sec						; non blocking
		jsr  smb_alloc
		bcs  _outofmem

		;; X=SMB-ID1, syszp=address1
		ldy  #0
		lda  #MAJOR_CONSOLE
		sta  (syszp),y			; set major
#ifdef MULTIPLE_CONSOLES
		;; now find a free console
		;; NOTE: races here?
		ldy #0
		lda usage_map
	-	lsr a
		bcc +
		iny
		cpy lk_consmax
		bne -
		;; we can fall through here because we exit above if there are no free consoles
	+	tya
		ldy  #0
#else
		lda  #0
#endif
		iny
		sta  (syszp),y			; set minor
		iny
		lda  #1
		sta  (syszp),y			; set rd-counter
		iny
		sta  (syszp),y			; set wr-counter
		iny
		lda  #fflags_write|fflags_read
		sta  (syszp),y			; set flags (read/write)
		stx  syszp+3
		jsr  alloc_pfd			; (allocate local fd)
		bcs  _toomany

#if MULTIPLE_CONSOLES | !ALWAYS_SZU
		sei
#endif

#ifdef MULTIPLE_CONSOLES
		;; allocate internally console
		ldy #fsmb_minor
		lda (syszp),y
		tay
		lda usage_map
		ora bit_n_set,y
		sta usage_map
#endif

#ifndef ALWAYS_SZU
		ldy  lk_ipid
		lda  #$ff-tstatus_szu
		and  lk_tstatus,y
		sta  lk_tstatus,y
#endif

#if MULTIPLE_CONSOLES | !ALWAYS_SZU
		cli
#endif

		clc
		rts

#ifndef MULTIPLE_CONSOLES
fs_cons_fclose:
		lda  #0
		sta  usage_count		; must still reset the usage count
		clc						; even if there is only a single console
		rts
#else

fs_cons_fclose:	
		ldy  #fsmb_minor
		lda  (syszp),y
		tay
		lda usage_map
		sei
		eor bit_n_set,y
		sta usage_map
		dec usage_count
		cli
		clc
		rts
#endif

fs_cons_fputc:					; data byte is in syszp+5
		ldy  #fsmb_minor
		lda  (syszp),y
		tax						; (number of console)
		lda  syszp+5
		jsr  cons_out
		jmp  io_return

		;; console_passkey is called by the keyboard interrupt handler !
console_passkey:
		ldx  wr_pointer
		inx
		cpx  #BUFSIZE
		bcc  +
		ldx  #0
	+	cpx  rd_pointer
		beq  +
		ldy  wr_pointer
		sta  keyboard_buffer,y	; ignore char, if buffer is already filled
		stx  wr_pointer
	+	bit  susp_flag
		bmi  +
		rts

	+	lda  #waitc_conskey
		ldx  #0
		stx  susp_flag
		jmp  mun_block

fs_cons_fgetc:
#ifdef MULTIPLE_CONSOLES
		ldy  #fsmb_minor
		lda  (syszp),y
		cmp  cons_visible		; is this console visible ?
		bne  no_key				; no, then skip
#endif
		sei
		ldx  rd_pointer
		cpx  wr_pointer
		beq  no_key
		cli
		lda  keyboard_buffer,x
		inx
		cpx  #BUFSIZE
		bcc  +
		ldx  #0
	+	stx  rd_pointer
		cmp  #$0a				; newline ?
		beq  got_newline
		cmp  #$04				; CTRL+d ?
		beq  got_ctrld
		sta  nlflag				; clear newline-flag
		jmp  io_return

no_key:		lda  syszp+4
		bmi  +					; blocking or nonblocking ?
		cli						; (nonblocking)
		lda  #lerr_tryagain
		jmp  io_return_error

	+	sta  susp_flag			; (blocking)
		lda  #waitc_conskey
		ldx  #0
		jsr  block
		cli
		jmp  fs_cons_fgetc		

got_newline:
		ldx  #0
		stx  nlflag
	-	jmp  io_return

got_ctrld:
		ldx  nlflag
		bne  -		
		;; submit eof, if CTRL+d pressed at beginning of line
		lda  #lerr_eof
		jmp  io_return_error

;; ZEROpage: wr_pointer 1
;; ZEROpage: rd_pointer 1
;; ZEROpage: susp_flag 1
;; ZEROpage: nlflag 1
;; ZEROpage: usage_count 1
#ifdef MULTIPLE_CONSOLES
;; ZEROpage: usage_map 1
#endif

;wr_pointer:	.byte 0			; index to next written char in buffer
;rd_pointer:	.byte 0			; index to next read char in buffer
;susp_flag:		.byte 0			; set if a task is waiting for a key
;nlflag:		.byte 0			; newline flag (0 : last char was newline)
;usage_count:	.byte 0			; number of opened consoles

#ifdef MULTIPLE_CONSOLES
;usage_map:		.byte 0			; bitmap of used consoles
#endif

keyboard_buffer:
		.buf BUFSIZE
