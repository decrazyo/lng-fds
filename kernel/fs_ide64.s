
;
; IDE64 filesystem
;
; Maciej Witkowiak <ytm@elysium.pl>
;
; 8,15.12.2001, 2,3.01.2002

; IDEAS
; - common parts of fs_iec and fs_ide64 might be exported as functions
;	 (like preparing filename, printing errorcode)
; - maybe some temporary zeropage bytes can be shared with fs_iec (dunno)
; - if I would only know how to get listing similar to 'll' readdir would be way shorter
; BUGS
; - freaddir gives wrong length of the first file

#include <config.h>

#include MACHINE_H
#include <system.h>
#include <kerrors.h>
#include <fs.h>
#include <zp.h>

#ifdef HAVE_IDE64

; device = 12 (assume 12)
; secadr = channel
; fd = this is by LUnix streams

#define IDE64_DEVICE	12		; assumed
#define IDE64_SECADR	8		; like open x,12,8 always

#define IDE64_ROM_OPEN		$de60
#define IDE64_ROM_CLOSE		$de60
#define IDE64_ROM_CHKIN		$de60
#define IDE64_ROM_CHKOUT	$de60
#define IDE64_ROM_CHRIN		$de60
#define IDE64_ROM_CHROUT	$de60

			.global ide64_swap_bytes
			; need to export these so bootstrap will fill in values
			.global ide64_rom_open
			.global ide64_rom_close
			.global ide64_rom_chkin
			.global ide64_rom_chkout
			.global ide64_rom_chrin
			.global ide64_rom_chrout

			.global fs_ide64_fopen
			.global fs_ide64_fopendir
			.global fs_ide64_fclose
			.global fs_ide64_fgetc
			.global fs_ide64_fputc
			.global fs_ide64_fcmd
			.global fs_ide64_freaddir

;used_locations:
;    $90 - status
;    $98 - # opened files
;    $99 - input device
;    $9a - output device
;    $9d - mode (program/interactive)
;    $a4-$a6
;    $b7 - fname_len
;    $b8 - fd
;    $b9 - secondary address (ignored)
;    $ba - device number
;    $bb/c - fname vector
;    $0259-$0276 - Kernal tables (259-262 - fd, 263-26c - devnum, 26d-276 - secaddr)
;    $0313 - temporary for IDE64

tmp_pr:		.buf 1
tmp_memconf:	.buf 1

buf_tables:	.buf 30
buf_b7:		.buf 6
buf_a4:		.buf 3
buf_98:		.buf 3
buf_90:		.buf 1
buf_9d:		.buf 1
buf_313:	.buf 1

byte_count		equ syszp+5
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ROM hooks
;;;
ide64_rom_open:		jmp IDE64_ROM_OPEN
ide64_rom_close:	jmp IDE64_ROM_CLOSE
ide64_rom_chkin:	jmp IDE64_ROM_CHKIN
ide64_rom_chkout:	jmp IDE64_ROM_CHKOUT
ide64_rom_chrin:	jmp IDE64_ROM_CHRIN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Helper routines
;;;

		;; swap memory locations used by Kernal ROM
ide64_swap_bytes:
		ldx #0
	-	lda $98,x
		tay
		lda buf_98,x
		sta $98,x
		tya
		sta buf_98,x
		lda $a4,x
		tay
		lda buf_a4,x
		sta $a4,x
		tya
		sta buf_a4,x
		inx
		cpx #3
		bne -
		ldx #0
	-	lda $b7,x
		tay
		lda buf_b7,x
		sta $b7,x
		tya
		sta buf_b7,x
		inx
		cpx #6
		bne -
		ldx #0
	-	lda $0259,x
		tay
		lda buf_tables,x
		sta $0259,x
		tya
		sta buf_tables,x
		inx
		cpx #30
		bne -
		ldy $0313
		lda buf_313
		sta $0313
		sty buf_313
		ldy $90
		lda buf_90
		sta $90
		sty buf_90
		ldy $9d
		lda buf_9d
		sta $9d
		sty buf_9d
		rts

enter_ide64_rom:
	; disable IRQ
		php
		sei
		pla
		sta tmp_pr
	; memory locations
		jsr ide64_swap_bytes
		SPEED_1MHZ
	; save memory config
		GETMEMCONF
		sta tmp_memconf
	; enable Kernal+IO
		lda #MEMCONF_ROM
		SETMEMCONF
		rts

leave_ide64_rom:
	; return to LNG memory config
		lda tmp_memconf
		SETMEMCONF
	; restore memory locations
		SPEED_MAX
		jsr ide64_swap_bytes
	; enable IRQ
		lda tmp_pr
		pha
		plp
		rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; API
;;;
	-	lda #lerr_deverror
		SKIP_WORD
	-	lda #lerr_notimp
		jmp catcherr

		;; ide64_open
		;;  open file on IDE64 device
		;;
		;; Note: read/write mode is not supported!
		;;	 read-only/write-only/write-append are working

		;; <syszp=filename, syszp+2=fmode
		;; X=minor (device number)

fs_ide64_fopen:
		txa
		bne --					; only minor==0 supported
		lda syszp+2
		cmp #fmode_rw
		beq -
		jsr enter_atomic			; atomic section

		ldy #0
		sty ide64_fopen_flags			; clear fopen flags

	-	lda (syszp),y
		jsr unix2cbm
		cmp #0
		sta filename,y
		beq +
		iny
		cpy #16
		bne -

		;; add filename extension
	+	lda #","
		sta filename,y
		sta filename+2,y
		lda #80					; "p"
		sta filename+1,y
		lda syszp+2
		cmp #fmode_ro
		beq ++
		cmp #fmode_wo
		beq +
		lda #65					; "a"
		SKIP_WORD
	+	lda #87					; "w"
		SKIP_WORD
	+	lda #82					; "r"
		sta filename+3,y
		tya
		clc
		adc #4
_raw_fopen:	sta ide64_filename_length

	; close current channel -> close_channel
	;	jsr close_channel

	; allocate channel	-> alloc_secadr
		jsr alloc_secadr
		bcc +
		jmp _toomanyf
	+	sty ide64_ch_secadr

	; allocate file descriptor -> alloc_pfd
		jsr alloc_pfd
		sta byte_count				; error code to return
		bcc +
		jmp _oerr1
	+	stx syszp+4				; remember fd
	; allocate smb to store data
		sec					; non-blocking
		jsr smb_alloc
		sta byte_count				; error code to return
		bcc +
		jmp _oerr2
	+	stx syszp+3				; remember SMB-ID
	; put data into smb
		lda syszp+4
		clc
		adc #tsp_ftab
		tay
		txa
		sta (lk_tsp),y				; store SMB_ID
		ldy #0
		lda #MAJOR_IDE64
		sta (syszp),y
		tya					; A=0 - minor
		iny
		sta (syszp),y

		lda syszp+2
		cmp #fmode_ro
		beq +
		lda #0
		ldx #fflags_write
		bne ++
	+	lda #1
		ldx #fflags_read
	+	iny
		sta (syszp),y				; -> rdcnt
		eor #1
		iny
		sta (syszp),y				; -> wrcnt
		iny
		txa
		sta (syszp),y				; -> flags

		ldy #iecsmb_secadr
		lda ide64_ch_secadr
		sta (syszp),y				; remember secaddr

		ldy #iecsmb_dirstate
		lda fopen_flags
		sta (syszp),y

	; call ROM to try opening the file
;;		lda syszp+2
;;		pha
;;		ldx #$80
;;		cmp #fmode_ro
;;		beq +
;;		ldx #$40
;;	+	stx ide64_ch_state
		lda ide64_ch_secadr
		pha
		lda ide64_filename_length
		pha
		jsr enter_ide64_rom
	; ROM setnam
		pla					; filename_length
		ldx #<filename
		ldy #>filename
		sta $b7
		stx $bb
		sty $bc
	; ROM setlfs
		pla					; ch_secadr
		ldx #IDE64_DEVICE
		ldy #IDE64_SECADR
		sta $b8
		stx $ba
		sty $b9
	; ROM open
		jsr ide64_rom_open
;;		ldx $b8
;;		pla
;;		cmp #fmode_ro
;;		bne +
;;		jsr ide64_rom_chkin
;;		jmp ++
;;	+	jsr ide64_rom_chkout
	+	jsr leave_ide64_rom
        	jsr ide64_readout_errchannel
		tax
		; check error status
		beq +
;;;		ldy #iecsmb_secadr		; should be there already
;;;		lda (syszp),y
;;;		sta ide64_ch_secadr
		jsr close_ide64_file

		;; free SMB, fd, semaphore
_oerr3:		ldx syszp+3
		jsr smb_free
_oerr2:		clc
		lda syszp+4
		adc #tsp_ftab
		tay
		lda #0
		sta (lk_tsp),y
_oerr1:		ldy ide64_ch_secadr
;;;		ldx ide64_ch_device
		jsr free_secadr
	-	jsr leave_atomic

		lda byte_count				; errorcode
		jmp catcherr
_toomanyf:	lda #lerr_toomanyfiles
		sta byte_count
		bne -

	+	ldy  #iecsmb_status
		sta  (syszp),y

leave_all:	jsr  leave_atomic
	-	jsr  enable_nmi
#ifndef ALWAYS_SZU
		sei
		ldx  lk_ipid
		lda  #$ff-tstatus_szu
		and  lk_tstatus,x
		sta  lk_tstatus,x
		ldx  syszp+4				; load fd
		cli
#else
		ldx  syszp+4
#endif
		clc
		rts

close_ide64_file:
		lda ide64_ch_secadr
		pha
		jsr enter_ide64_rom
		pla
		jsr ide64_rom_close
		jmp leave_ide64_rom

fs_ide64_fclose:
		jsr  enter_atomic
		jsr  disable_nmi
		ldy  #iecsmb_secadr
		lda  (syszp),y
		sta  ide64_ch_secadr
;;;		ldy  #fsmb_minor
;;;		lda  (syszp),y
;;;		sta  ide64_ch_device
		jsr  close_ide64_file
		jsr  enable_nmi
		ldy  ide64_ch_secadr
;;;		ldx  ide64_ch_device
		jsr  free_secadr
		jsr  leave_atomic
		jmp  -

fs_ide64_fgetc:
	; check EOF flag (return error if set)
		ldy  #iecsmb_status
		lda  (syszp),y
		cmp  #iecstatus_eof
		bne +
		jmp  _getbyte_eof			; return with lerr_eof
	; check if device, channel is already in good mode
	+	jsr  enter_atomic
		jsr  disable_nmi
		lda  #0
		sta  buf_90
;;		lda  ch_device
;;		ldy  #fsmb_minor
;;		cmp  (syszp),y
;;		bne  _switch_inp
		ldy  #iecsmb_secadr
		lda  buf_b7+1				; b8 - current secadr
		and #%00001111
		cmp  (syszp),y				; equal to needed
		bne  _switch_inp
		cmp ide64_ch_secadr
		bne _switch_inp
		bit  ide64_ch_state
		bpl  _switch_inp
;;		lda  ide64_ch_secadr			; current channel
;;		ldy  #iecsmb_secadr
;;		cmp  (syszp),y				; equal to needed
;;		bne  _switch_inp
_getbyte:	jsr  get_byte
		jsr  enable_nmi
		lda  buf_90				; status
		beq +

		cmp  #iecstatus_eof
		bne  get_ioerr
		ldy  #iecsmb_status
		sta  (syszp),y

	+	jsr  leave_atomic
		lda  syszp+5
		jmp  io_return

get_byte:	jsr  enter_ide64_rom
		jsr  ide64_rom_chrin
		pha
		jsr  leave_ide64_rom
		pla
		sta  syszp+5
		rts

		;; need to switch to input
_switch_inp:	;;jsr  close_channel
		jsr prep_inchannel
		bcc _getbyte
		bcs _ioerror

prep_inchannel:	
		ldy  #iecsmb_status
		lda  (syszp),y
		cmp  #iecstatus_eof
		beq  +				; return with lerr_eof

;;		ldy  #fsmb_minor
;;		lda  (syszp),y
;;		sta  ch_device
		ldy  #iecsmb_secadr
		lda  (syszp),y
		sta  ide64_ch_secadr
		;; switch needed channel as standard input
		pha
		jsr  enter_ide64_rom
		pla
		tax
		jsr  ide64_rom_chkin
		jsr  leave_ide64_rom

		lda  #$80
		sta  ide64_ch_state

		ldy  #iecsmb_status
		lda  buf_90
		sta  (syszp),y
		beq  ++
		lda  #lerr_ioerror
		SKIP_WORD
	+	lda  #lerr_eof
		sec
    		rts
	+	clc
		rts

get_ioerr:	lda  #lerr_ioerror
		SKIP_WORD
_getbyte_eof:	lda  #lerr_eof
_ioerror:	pha
		jsr  leave_atomic
		pla
		jmp  io_return_error

fs_ide64_fputc:
		jsr  enter_atomic
		jsr  disable_nmi
		lda  #0
		sta  buf_90
		bit  ide64_ch_state
		bvc  _switch_out
;;		lda  ch_device
;;		ldy  #fsmb_minor
;;		cmp  (syszp),y
;;		bne  _switch_out
		ldy  #iecsmb_secadr
		lda  buf_b7+1				; b8 - current secadr
		and #%00001111
		cmp  (syszp),y				; equal to needed
		bne  _switch_out
		lda  ide64_ch_secadr
;;		ldy  #iecsmb_secadr
		cmp  (syszp),y
		bne  _switch_out

_put_byte:	lda  syszp+5
		pha
		jsr  enter_ide64_rom
		pla
ide64_rom_chrout: jsr  IDE64_ROM_CHROUT
		jsr  leave_ide64_rom
		jsr  enable_nmi
		lda  buf_90				; status
		beq  +

		ldy  #iecsmb_status
		sta  (syszp),y
	+	jsr  leave_atomic
		jmp  io_return

_switch_out:	;jsr  close_channel
		ldy  #iecsmb_secadr
		lda  (syszp),y
		sta  ide64_ch_secadr
;;		ldy  #fsmb_minor
;;		lda  (syszp),y
;;		sta  ch_device

		lda  ide64_ch_secadr
		pha
		jsr  enter_ide64_rom
		pla
		tax
		jsr  ide64_rom_chkout
		jsr  leave_ide64_rom

		lda  #$40
		sta  ide64_ch_state

		ldy  #iecsmb_status
		lda  buf_90				; status
		sta  (syszp),y
		beq  _put_byte
		jmp  get_ioerr

ide64_get_errorstatus:
		;; open command channel for input
		jsr  enter_ide64_rom
		lda  #0					; no name
		sta  $b7
		sta  $90
		lda  #15
		sta  $b8
		sta  $b9
		jsr  ide64_rom_open
		ldx  #15
		jsr  ide64_rom_chkin
	-	jsr  ide64_rom_chrin
		ldy  $b7
		cmp  #13
		beq  +
		sta  filename,y
		inc  $b7
		lda  $90
		beq  -
	+	lda  #0
		sta  filename,y
		lda  #15
		jsr  ide64_rom_close
		lda  #0
		sta  $90
		jmp  leave_ide64_rom

ide64_readout_errchannel:
		jsr  ide64_get_errorstatus
		lda  filename
		and  #$0f
		sta  byte_count
		asl  a
		asl  a
		adc  byte_count
		asl  a
		sta  byte_count
		lda  filename+1
		clc
		and  #$0f
		adc  byte_count
		sta  byte_count			; CBM error number
		beq  +++			; no error, then skip

		;; translate CBM into LNG errorcode
;		ldx  #CBMerr2lng-CBMerr_tab
		ldx  #11
	-	dex
		bmi  +
		cmp  CBMerr_tab,x
		bne  -
		lda  CBMerr2lng,x
		SKIP_WORD
	+	lda  #lerr_ioerror	
		sta  byte_count

		;; print error message
#ifdef PRINT_IECMSG
		ldy  #7
	-	lda  CBMerr_txt,y
		jsr  printk
		dey
		bpl  -
#endif
		ldy  #4
	-	lda  filename,y
		beq  +
#ifdef PRINT_IECMSG
		jsr  cbm2unix
		jsr  printk
#endif
		iny
		bne -
	+
#ifdef PRINT_IECMSG
		lda  #$0a
		jsr  printk
#endif

		lda byte_count
	+	rts

fs_ide64_fcmd:
		lda  syszp+2
		cmp  #fcmd_del
		beq  +
		cmp  #fcmd_chdir
		beq  ++
		lda  #lerr_notimp
		bne  _fcmd_err

		;; open-name is "s:filename"

	+	lda  #83				; "s"
		SKIP_WORD
	+	lda  #67				; "c"
		sta  filename
		lda  #58				; ":"
		sta  filename+1
		ldy  #0
	-	lda  (syszp),y
		jsr  unix2cbm
		cmp  #0
		sta  filename+2,y
		beq  +
		iny
		cpy  #40
		bne  -
	+	iny
		iny
		tya
		pha
		jsr  enter_ide64_rom
		pla
		ldx  #<filename
		ldy  #>filename
		sta  $b7
		stx  $bb
		sty  $bc
		lda  #15
		ldx  #IDE64_DEVICE
		ldy  #15
		sta  $b8
		stx  $ba
		sty  $b9
		jsr  ide64_rom_open
		lda  #15
		jsr  ide64_rom_close
		jsr  leave_ide64_rom
		jsr  ide64_readout_errchannel
		bne  +
		rts

_fcmd_err:	lda  #lerr_notimp
		SKIP_WORD
	-	lda  #lerr_nosuchdir
	+	jmp  catcherr

fs_ide64_fopendir:
	; open directory (ignored on 1541, might be usable here)
	; dirname -> do "C:directory"
	; open $
		ldy  #0
		lda  (syszp),y
		bne  -					; only current directory now

		jsr  enter_atomic

		lda  #$80
		sta  fopen_flags

		lda  #"$"
		sta  filename
		lda  #1
		jmp  _raw_fopen


fs_ide64_freaddir:
	; get contents of directory (for more information look at fs_iec.s)
		ldy  #iecsmb_dirstate
		lda  (syszp),y
		bpl  -				; (can not readdir from normal file)

		ldx  syszp+5
		ldy  syszp+6
		stx  syszp+2
		sty  syszp+3			; pointer to dir-structure

		jsr  enter_atomic
		jsr  disable_nmi
		ldy  #iecsmb_secadr
		lda  buf_b7+1				; b8 - current secadr
		and  #%00001111
		cmp  (syszp),y				; equal to needed
		beq  +
;;		bit  ide64_ch_state
;;		bmi  +
		jsr  prep_inchannel
		bcc  +
		jmp  catcherr

	+	ldy  #iecsmb_dirstate
		lda  (syszp),y
		and  #$40
		bne  next_entry

		lda  #$32
		sta  ide64_fopen_flags		; ignore first entry (diskname)

	-	jsr  get_byte			; error won't happen here (this is always present)
		dec  ide64_fopen_flags
		lda  ide64_fopen_flags
		bne  -

		ldy  #iecsmb_dirstate
		lda  #$c0
		sta  (syszp),y

next_entry:
		lda  syszp+3
		pha
		lda  syszp+2
		pha
		jsr  enter_ide64_rom
		pla
		tax
		pla
		tay
		lda  $ff
		pha
		lda  $fe
		pha
		lda  $fd
		pha
		stx  $fe
		sty  $ff

		jsr  ide64_rom_chrin		; skip two bytes
		ldx  $90
		beq  +
		jmp  dir_error
	+	jsr  ide64_rom_chrin

		jsr  ide64_rom_chrin		; get length
		ldy  #3
		sta  ($fe),y
		jsr  ide64_rom_chrin
		ldy  #4
		sta  ($fe),y
		lda  #0
		iny
		sta  ($fe),y
		iny
		sta  ($fe),y

		ldy  #12			; pointer to filename
		sty  $fd			; merely a counter

	-	jsr  ide64_rom_chrin		; skip until filename
		cmp  #$22			; starting quote?
		beq  +
		cmp  #"B"			; last entry?	
		bne  -
		jmp  readdir_eof
	+
	-	jsr  ide64_rom_chrin		; read name
		cmp  #$22			; ending quote?
		beq  +
		jsr  cbm2unix
		ldy  $fd
		sta  ($fe),y
		inc  $fd
		jmp  -

	+	ldy  $fd			; terminate filename
		lda  #0
		sta  ($fe),y

		lda  #0
		sta  $fd			; mode = ----

	-	jsr  ide64_rom_chrin
		cmp  #$20			; ignore next spaces
		beq  -

		cmp  #"*"			; currently written
		bne  +
		lda  #%00000010			; can't read
		sta  $fd
		jsr  ide64_rom_chrin
	+	cmp  #"P"			; prg?
		beq  +
		cmp  #"D"			; dir?
		beq  ++
		ldx  #0				; ---- if nothing
		SKIP_WORD
	+	ldx  #%00000111
		SKIP_WORD
	+	ldx  #%10000111			; drwx
		lda  $fd			; --w- flag is set?
		bne  +
		stx  $fd			; no - put it

		jsr  ide64_rom_chrin		; skip remaining two letters
		jsr  ide64_rom_chrin

		jsr  ide64_rom_chrin		; get write protection
		cmp  #"<"
		bne  +				; not protected
		lda  $fd
		and  #%11111101
		sta  $fd

	+	ldy  #1				; put permissions
		lda  $fd
		sta  ($fe),y
		dey
		lda  #%00000011			; length and permissions are valid
		sta  (syszp+2),y

	-	jsr  ide64_rom_chrin		; skip until end of entry
		tax
		bne  -
		ldx  #0
	-	pla
		sta  $fd
		pla
		sta  $fe
		pla
		sta  $ff
		txa
		pha
		jsr  leave_ide64_rom
		jsr  leave_all			; and return
		pla
		bne  +
		rts
	+	jmp  catcherr

dir_error:
		txa
		and  #iecstatus_eof
		bne  readdir_eof
		ldx  #lerr_ioerror
		SKIP_WORD
readdir_eof:	ldx  #lerr_eof
		bne  -

alloc_secadr:
		;; X=ch_device (range 8..15)
;;		lda  adrmap-8,x
		lda  adrmap
		ldy  #7
	-	lsr  a
		bcc  +
		dey
		bpl  -
		rts					; return with carry set

	+	lda  btab2r,y
;;		ora  adrmap-8,x
;;		sta  adrmap-8,x
		ora  adrmap
		sta  adrmap
		iny
		iny
		rts					; return with carry clear, y=secadr (2..9)

free_secadr:
		;; X=ch_device (range 8..15), Y=secadr (range 2..9)
		lda  btab2r-2,y
		eor  #$ff
;;		and  adrmap-8,x
;;		sta  adrmap-8,x
		and  adrmap
		sta  adrmap
		rts

; data buffers - may use bytes from fs_iec???
;;; ZEROpage: ide64_ch_state 1
;;; ZEROpage: ide64_ch_secadr 1
;;; ZEROpage: ide64_ch_device 1
;;; ZEROpage: ide64_filename_length 1
;;; ZEROpage: ide64_fopen_flags 1

adrmap:		.byte 0					; 8 possible secadrs for each device (one)
#else
		rts					; nothing
#endif
