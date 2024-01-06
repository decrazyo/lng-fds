		;; IEC bus routines
		;; (serial kind of IEC, only using the signals
		;;  DATA, CLOCK and ATN)

#include <config.h>

#include MACHINE_H
#include <system.h>
#include <kerrors.h>
#include <fs.h>
#include <zp.h>

#include MACHINE(iec.s)

		.global fs_iec_fopen
		.global fs_iec_fopendir
		.global fs_iec_fclose
		.global fs_iec_fgetc
		.global fs_iec_fputc
		.global fs_iec_fcmd
		.global fs_iec_freaddir

		.global enter_atomic
		.global leave_atomic
		.global unix2cbm
		.global cbm2unix
		.global filename
		.global CBMerr_tab
		.global CBMerr2lng

bit_count		equ tmpzp
byte_count		equ syszp+5
byte			equ syszp+6
status			equ syszp+7

		;; include lowlevel stuff
#include "opt/iec_1541.s"

#ifdef HAVE_64NET2
#include "opt/iec_64net2.s"
		;; decide here which path to go:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; like:
;		bit iec_dev_flag
;		bmi +
;		jmp send_byte_64net2
;	+	jmp send_byte_iec

send_byte:
		bit iec_dev_flag
		bmi +
		jmp send_byte_64net2
	+	jmp send_byte_iec

get_byte:
		bit iec_dev_flag
		bmi +
		jmp get_byte_64net2
	+	jmp get_byte_iec

send_listen:
		bit iec_dev_flag
		bmi +
		jmp send_listen_64net2
	+	jmp send_listen_iec

sec_adr_after_listen:
		bit iec_dev_flag
		bmi +
		jmp sec_adr_after_listen_64net2
	+	jmp sec_adr_after_listen_iec

send_unlisten:
		bit iec_dev_flag
		bmi +
		jmp send_unlisten_64net2
	+	jmp send_unlisten_iec

send_talk:
		bit iec_dev_flag
		bmi +
		jmp send_talk_64net2
	+	jmp send_talk_iec

sec_adr_after_talk:
		bit iec_dev_flag
		bmi +
		jmp sec_adr_after_talk_64net2
	+	jmp sec_adr_after_talk_iec

send_untalk:
		bit iec_dev_flag
		bmi +
		jmp send_untalk_64net2
	+	jmp send_untalk_iec

open_iec_file:
		bit iec_dev_flag
		bmi +
		jmp open_iec_file_64net2
	+	jmp open_iec_file_iec

close_iec_file:
		bit iec_dev_flag
		bmi +
		jmp close_iec_file_64net2
	+	jmp close_iec_file_iec
#else
; without 64net/2 support
	send_byte		equ send_byte_iec
	get_byte		equ get_byte_iec
	send_listen		equ send_listen_iec
	sec_adr_after_listen	equ sec_adr_after_listen_iec
	send_unlisten		equ send_unlisten_iec
	send_talk		equ send_talk_iec
	sec_adr_after_talk	equ sec_adr_after_talk_iec
	send_untalk		equ send_untalk_iec
	open_iec_file		equ open_iec_file_iec
	close_iec_file		equ close_iec_file_iec
#endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#ifdef HAVE_64NET2
		;; set apropriate flag if current device is 64net2
check_64net2_flag:
		pha
		php
		lda ch_device
		cmp #15
		bne +
		lda #0
		SKIP_WORD
	+	lda #128
		sta iec_dev_flag
		plp
		pla
		rts

		;; check if current device is not a 64net/2 and sleep
sleep_if_1541:
		bit iec_dev_flag
		bpl +
		ldx  #<150
		ldy  #>150
		jsr  sleep				; sleep for (at least) 2.5 seconds
	+	rts					; time for the drive to locate the file
#else
sleep_if_1541:
		ldx  #<150
		ldy  #>150
		jsr  sleep				; sleep for (at least) 2.5 seconds
							; time for the drive to locate the file
check_64net2_flag:
		rts					; dummy...
#endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; everything below is common

		;; needs ch_device set (changes ch_secadr to 15)
		;; returns A=CBM-error number
		;;  c=1 : i/o error

readout_errchannel:
		ldy  #0
		sty  filename_length
		lda  #$6f
		sta  ch_secadr			; (secadr=15)
		jsr  open_iec_file
		lda  status
		bne  _deep_error1

		lda  ch_device
		jsr  send_talk
		lda  ch_secadr			; channel number 15 (CBM error channel)
		jsr  sec_adr_after_talk
		lda  status
		bne  _deep_error1

		jsr  get_byte
		ldx  status
		bne  _deep_error2
		and  #$0f
		sta  byte_count
		asl  a
		asl  a
		adc  byte_count
		asl  a
		sta  byte_count

		jsr  get_byte
		ldx  status
		bne  _deep_error2
		clc
		and  #$0f
		adc  byte_count
		sta  byte_count			; CBM error number
		beq  ++					; no error, then skip

		;; translate CBM into LNG errorcode
		ldx  #CBMerr2lng-CBMerr_tab
	-	dex
		bmi  +
		cmp  CBMerr_tab,x
		bne  -
		lda  CBMerr2lng,x
		SKIP_WORD
	+	lda  #lerr_ioerror	
		sta  byte_count

		;; print error message
		jsr  get_byte
#ifdef PRINT_IECMSG
		ldy  #7
	-	lda  CBMerr_txt,y
		jsr  printk
		dey
		bpl  -

		lda  ch_device
		ora  #"0"
		jsr  printk
#endif
	-	jsr  get_byte
		bcs  +
#ifdef PRINT_IECMSG
		lda  byte
		jsr  cbm2unix
		jsr  printk
#endif
		lda  status
		beq  -

#ifdef PRINT_IECMSG
		lda  #$0a
		jsr  printk
#endif		
	+	sei
		jsr  send_untalk
		lda  status
		cmp  #1					; if A<>0 then c=1
		lda  byte_count
		cli
		rts

_deep_error2:
		sei
		jsr  send_untalk

_deep_error1:
		cli
		lda  #$ff				; unknown CBM-error
		sec
		rts

;**************************************************************************
;		LNG filesystem interface wrapper
;**************************************************************************

toomanyf:
		jsr  leave_atomic
		lda  #lerr_toomanyfiles
		SKIP_WORD
illdev:
		lda  #lerr_deverror
		SKIP_WORD
	-	lda  #lerr_notimp
		jmp  catcherr

		;; iec_open
		;;  open file on iec-device
		;;
		;;  Note: read/write mode is not supported !
		;;        read only/write only/write append works

		;; syszp=file, syszp+2=fmode
		;; X=minor (device number)

fs_iec_fopen:
		lda  syszp+2
		cmp  #fmode_rw			; read/write is not supported
		beq  -

		cpx  #8
		bcc  illdev
		cpx  #16
		bcs  illdev

		stx  syszp+3
		jsr  enter_atomic

		ldy  #0
		sty  fopen_flags		; clear all fopen-flags

	-	lda  (syszp),y
		jsr  unix2cbm
		cmp  #0
		sta  filename,y
		beq  +
		iny
		cpy  #16
		bne  -

		;; add filename extension
		;;    ,p,r - for fmode_r (read only)
		;;    ,p,w - for fmode_w (write only)
		;;    ,p,a - for fmode_a (append, write only)

	+	lda  #","
		sta  filename,y
		sta  filename+2,y
		lda  #80				; "p"
		sta  filename+1,y
		lda  syszp+2
		cmp  #fmode_ro
		beq  ++
		cmp  #fmode_wo
		beq  +
		lda  #65				; "a"
		SKIP_WORD
	+	lda  #87				; "w"
		SKIP_WORD
	+	lda  #82				; "r"
		sta  filename+3,y
		tya
		clc
		adc  #4
_raw_fopen:
		sta  filename_length

		jsr  disable_nmi
		SPEED_1MHZ				; switch to 1MHz mode
		jsr  close_channel
		SPEED_MAX				; switch to fast mode
		jsr  enable_nmi

		;; the driver manages up to 8 open streams (secadr 2..9) for
		;; each device (8..15)

		ldx  syszp+3
		stx  ch_device
		jsr check_64net2_flag
		jsr  alloc_secadr
		bcs  toomanyf
		tya
		ora  #$60
		sta  ch_secadr

		jsr  alloc_pfd
		sta  byte_count			; (error code to return)
		bcs  _oerr1
		stx  syszp+4			; remember fd
		sec						; non blocking
		jsr  smb_alloc
		sta  byte_count			; (error code to return)
		bcs  _oerr2
		stx  syszp+3			; remember SMB-ID
		lda  syszp+4
		clc
		adc  #tsp_ftab
		tay
		txa
		sta  (lk_tsp),y			; store SMB-ID
		ldy  #0
		lda  #MAJOR_IEC
		sta  (syszp),y			; major
		lda  ch_device
		iny
		sta  (syszp),y			; minor (=device number)

		lda  syszp+2
		cmp  #fmode_ro
		beq  +
		lda  #0					; rdcnt=0 / wrcnt=1
		ldx  #fflags_write		; flags= write only
		bne  ++
	+	lda  #1					; rdcnt=1 / wrcnt=0
		ldx  #fflags_read		; flags= read only
	+	iny
		sta  (syszp),y			; ->rdcnt
		eor  #1
		iny
		sta  (syszp),y			; ->wrcnt
		iny
		txa
		sta  (syszp),y			; ->flags

		ldy  #iecsmb_secadr
		lda  ch_secadr
		sta  (syszp),y			; remember secundary address

		ldy  #iecsmb_dirstate
		lda  fopen_flags
		sta  (syszp),y

		jsr  disable_nmi
		SPEED_1MHZ				; switch to 1MHz
		jsr  open_iec_file
		lda  status
		beq  +
		lda  #lerr_ioerror
		sta  byte_count			; (error code to return)

		;; free SMB, fd, semaphore
_oerr3:
		ldx  syszp+3
		jsr  smb_free

_oerr2:
		clc
		lda  syszp+4
		adc  #tsp_ftab
		tay
		lda  #0
		sta  (lk_tsp),y
_oerr1:
		SPEED_MAX				; switch to fast mode
		jsr  enable_nmi
		lda  ch_secadr
		and  #$0f
		tay
		ldx  ch_device
		jsr  free_secadr		
		jsr  leave_atomic
		lda  byte_count			; (error code)
		jmp  catcherr

		;; there are two ways to check, if fopen has been successfull
		;;  - try a getc (simple, less overhead)
		;;  - read back errorchannel (maybe more reliable)
		;;     problem:	when closing channel 15 all other channels get closed
		;;              also


	+	jsr  sleep_if_1541		; give drive some time to locate file

		jsr  readout_errchannel
		beq  +

		ldy  #iecsmb_secadr
		lda  (syszp),y
		sta  ch_secadr
		jsr  close_iec_file
		jmp  _oerr3

	+	ldy  #iecsmb_status
		lda  #0
		sta  (syszp),y
leave_all:
		jsr  leave_atomic

		;; we're ready for get_byte

	-	
		SPEED_MAX				; switch to fast mode
		jsr  enable_nmi
#ifndef ALWAYS_SZU
		sei
		ldx  lk_ipid
		lda  #$ff-tstatus_szu
		and  lk_tstatus,x
		sta  lk_tstatus,x
		ldx  syszp+4			; load fd
		cli
#else
		ldx  syszp+4
#endif
		clc
		rts

fs_iec_fclose:
		jsr  enter_atomic
		jsr  disable_nmi
		SPEED_1MHZ				; switch to 1MHz
		jsr  close_channel
		ldy  #iecsmb_secadr
		lda  (syszp),y
		sta  ch_secadr
		ldy  #fsmb_minor
		lda  (syszp),y
		sta  ch_device		
		jsr check_64net2_flag
		jsr  close_iec_file
		SPEED_MAX				; switch to fast mode
		jsr  enable_nmi
		lda  ch_secadr
		and  #$0f
		tay
		ldx  ch_device
		jsr  free_secadr
		jsr  leave_atomic
		jmp  -

fs_iec_fgetc:
		jsr  prep_inchannel
		bcs  ++

		jsr  get_byte
		sta  syszp+5
		SPEED_MAX				; switch to fast mode
		jsr  enable_nmi
		lda  status				; (EOI is received together with the last byte)
		beq  +

		cmp  #iecstatus_eof
		bne  get_ioerr
		ldy  #iecsmb_status
		sta  (syszp),y

	+	jsr  leave_atomic
		lda  syszp+5
		jmp  io_return

get_ioerr:
		lda  #lerr_ioerror
	+	pha
		jsr  leave_atomic
		pla
		jmp  io_return_error

		;; prepare to read from specific input channel
prep_inchannel:	
		ldy  #iecsmb_status
		lda  (syszp),y
		cmp  #iecstatus_eof
		beq  ++					; return with lerr_eof
		jsr  enter_atomic
		jsr  disable_nmi
		SPEED_1MHZ				; switch to 1MHz
		lda  #0
		sta  status		
		bit  ch_state
		bpl  +
		lda  ch_device
		ldy  #fsmb_minor
		cmp  (syszp),y
		bne  +
		lda  ch_secadr
		ldy  #iecsmb_secadr
		cmp  (syszp),y
		bne  +
	-	clc
		rts
		;; need_sendtalk
	+	jsr  close_channel
		ldy  #iecsmb_secadr
		lda  (syszp),y
		sta  ch_secadr
		ldy  #fsmb_minor
		lda  (syszp),y
		sta  ch_device
		jsr check_64net2_flag
		jsr  send_talk
		lda  ch_secadr
		jsr  sec_adr_after_talk
		ldy  #iecsmb_status
		lda  status
		sta  (syszp),y
		beq  -
		lda  #lerr_ioerror
		SKIP_WORD
	+	lda  #lerr_eof	
		sec
		rts

fs_iec_fputc:
		jsr  enter_atomic
		jsr  disable_nmi
		SPEED_1MHZ				; switch to 1MHz
		lda  #0
		sta  status
		bit  ch_state
		bvc  need_sendlisten
		lda  ch_device
		ldy  #fsmb_minor
		cmp  (syszp),y
		bne  need_sendlisten
		lda  ch_secadr
		ldy  #iecsmb_secadr
		cmp  (syszp),y
		beq  +

need_sendlisten:
		jsr  close_channel
		ldy  #iecsmb_secadr
		lda  (syszp),y
		sta  ch_secadr
		ldy  #fsmb_minor
		lda  (syszp),y
		sta  ch_device
		jsr check_64net2_flag
		jsr  send_listen
		lda  ch_secadr
		jsr  sec_adr_after_listen
		ldy  #iecsmb_status
		lda  status
		sta  (syszp),y
		bne  _toioerr

	+	lda  syszp+5
		jsr  send_byte
		SPEED_MAX				; switch to fast mode
		jsr  enable_nmi
		lda  status
		beq  +

		ldy  #iecsmb_status
		sta  (syszp),y
_toioerr:		
		jmp  get_ioerr

	+	jsr  leave_atomic
		jmp  io_return

		;; bring channel into idle state
close_channel:
		sei
		bit  ch_state
		bmi  +
		bvc  ++
		jmp  send_unlisten
	+	jmp  send_untalk	
	+	cli
		rts

		;; X=ch_device (range 8..15)
alloc_secadr:
		lda  adrmap-8,x
		ldy  #7
	-	lsr  a
		bcc  +
		dey
		bpl  -
		rts						; return with carry set

	+	lda  btab2r,y
		ora  adrmap-8,x
		sta  adrmap-8,x
		iny
		iny
		rts						; return with carry clear, y=secadr (2..9)

		;; X=ch_device (range 8..15), Y=secadr (range 2..9)
free_secadr:
		lda  btab2r-2,y
		eor  #$ff
		and  adrmap-8,x
		sta  adrmap-8,x
		rts

		;; pass local semaphore
enter_atomic:
		sec						; blocking
		ldx  #lsem_iec
		jmp  lock

		;; release local semaphore
leave_atomic:
		ldx  #lsem_iec
		jmp  unlock


	-	lda  #lerr_deverror
		SKIP_WORD	
	-	lda  #lerr_notimp
		jmp  catcherr

		;; iec_fcmd
		;;  perform file operations

		;; syszp=file, syszp+2=command id
		;; X=minor (device number)

fs_iec_fcmd:
		cpx  #8
		bcc  --
		cpx  #16
		bcs  --
		lda  syszp+2
		cmp  #fcmd_del
		beq  +
		cmp  #fcmd_chdir
		bne  -

	+	pha
		stx  syszp+3
		jsr  enter_atomic
		jsr  disable_nmi
		SPEED_1MHZ				; switch to 1MHz mode
		jsr  close_channel

		ldx  syszp+3
		stx  ch_device
		jsr check_64net2_flag

		;; open-name is command

		pla
		cmp  #fcmd_chdir
		beq  _chdir

_del:		lda  #83				; "s"
		sta  filename
		ldx  #1
		bne  +
_chdir:		lda  #67				; "c"
		sta  filename
		lda  #68				; "d"
		sta  filename+1
		ldx  #2
	+	lda  #58				; ":"
		sta  filename,x
		inx
		ldy  #0
	-	lda  (syszp),y
		jsr  unix2cbm
		cmp  #0
		sta  filename,x
		beq  +
		iny
		inx
		cpy  #16
		bne  -
	+	txa
		tay
		jsr  readout_errchannel+2
		pha
		jsr  leave_atomic
		SPEED_MAX				; switch to fast mode
		jsr  enable_nmi
		pla
		bne  +
		clc
		rts

	+	lda  byte_count
		SKIP_WORD
	-	lda  #lerr_deverror
		SKIP_WORD
	-	lda  #lerr_nosuchdir
_jtocatcherr:
		jmp  catcherr

		;; iec_opendir
		;;  open directory on iec-device

		;; syszp=dirname
		;; X=minor (device number)
fs_iec_fopendir:
		cpx  #8
		bcc  --
		cpx  #16
		bcs  --

		ldy  #0
		lda  (syszp),y
		bne  -					; iec (1541) only has one directory

		stx  syszp+3
		jsr  enter_atomic

		lda  #$80
		sta  fopen_flags

		lda  #"$"
		sta  filename
		lda  #1
		jmp  _raw_fopen

		;; dir-structure for LNG (= lib6502 standard):
		;;   .buf 1    - valid bits (0:perm, 1:len, 2:date)
		;;   .buf 1    - permissions (d----rwx)
		;;   .buf 4    - file length in bytes (approx)
		;;   .buf 6    - date (year-1990, month, day, hr, min, sec)
		;;   .buf 17   - filename,0
		;; -----------
		;;        29 bytes

		;; CBM directory structure:
		;;   .buf 1    - type ($80=valid, $40=write protect,
		;;                     0=del, 1=seq, 2=prg, 3=usr, 4=rel)
		;;   .buf 1    - track of first block
		;;   .buf 1    - sector of first block
		;;   .buf 16   - filename padded with $a0
		;;   .buf 3    - (used for rel-files)
		;;   .buf 4    - unused
		;;   .buf 2    - track/sector of new file, when overwriting (@:...)
		;;   .buf 2    - number of used blocks (each up to 254 bytes)
		;;   (.buf 2   - unused, not always present)

	-	jmp  readdir_eof
to_dir_error:	
		jmp  dir_error

fs_iec_freaddir:
		ldy  #iecsmb_dirstate
		lda  (syszp),y
		bpl  -					; (can not readdir from normal file)
		ldx  syszp+5
		ldy  syszp+6
		stx  syszp+2
		sty  syszp+3			; pointer to dir-structure
		jsr  prep_inchannel
		bcs  _jtocatcherr

		ldy  #iecsmb_dirstate
		lda  (syszp),y
		and  #$40
		bne  next_entry
		;; read trailing 254 bytes
		lda  #254
		sta  byte_count

	-	jsr  get_byte
		ldx  status
		bne  to_dir_error
		dec  byte_count
		bne  -
		;; read next directory entry
next_entry:
		jsr  get_byte
		ldx  status
		bne  to_dir_error
		and  #7
		beq  skip_entry
		cmp  #2
		bne  +
		ldx  #%00000111			; -rwx
		SKIP_WORD
	+	ldx  #%00000000			; ---- if not PRG file
		txa
		bit  byte
		bmi  +
		and  #%00000010			; currently written (can't read)
	+	bit  byte
		bvc  +
		and  #%00000101			; write protected
	+	SKIP_WORD
skip_entry:
		lda  #%10000000
		ldy  #1
		sta  (syszp+2),y
		dey
		lda  #%00000011			; length and permissions are valid
		sta  (syszp+2),y
		jsr  get_byte			; skip two unused bytes (track/sector)
		jsr  get_byte
		lda  #12				; read filename
		sta  byte_count
	-	jsr  get_byte
		cmp  #$a0				; replace $a0 with $00
		bne  +
		lda  #0
	+	ldy  byte_count
		jsr  cbm2unix
		sta  (syszp+2),y
		iny
		sty  byte_count
		cpy  #12+16
		bne  -
		lda  #0					; terminate with $00
		sta  (syszp+2),y
		lda  #10				; skip 9 unused bytes
		sta  byte_count
	-	jsr  get_byte
		dec  byte_count
		bne  -
		ldy  #3					; 10th was length lo-byte
		sta  (syszp+2),y
		jsr  get_byte			; length hi-byte
		ldy  #4
		sta  (syszp+2),y
		lda  #0					; fill rest of 32bit length field
		iny
		sta  (syszp+2),y
		ldy  #2
		sta  (syszp+2),y

		;; might need to read 2 more bytes
		ldy  #iecsmb_dirstate
		lda  (syszp),y
		and  #7
		cmp  #7
		beq  +
		pha
		jsr  get_byte		
		jsr  get_byte
		ldy  #iecsmb_dirstate
		pla
	+	clc
		adc  #1
		and  #7
		ora  #$c0
		sta  (syszp),y

		ldy  #1
		lda  (syszp+2),y		; check, if this entry is valid
		bpl  +
		ldx  status
		bne  dir_error
		jmp  next_entry

	+	lda  status				; (EOI is received together with the last byte)
		beq  +

		cmp  #iecstatus_eof
		bne  readdir_ioerr
		ldy  #iecsmb_status
		sta  (syszp),y

	+	jmp  leave_all


dir_error:
		txa
		and  #iecstatus_eof
		bne  readdir_eof		
readdir_ioerr:
		lda  #lerr_ioerror
		SKIP_WORD
readdir_eof:
		lda  #lerr_eof
		pha
		jsr  leave_all
		pla
		jmp  catcherr


		;; character conversions
		;; if you want to share files between LNG and other
		;; programms, you have to translate the chacacter encoding
		;;  UNIX: a=97, A=65
		;;  CBM:  a=65, A=193

unix2cbm:
		cmp  #65
		bcc  ++					; A < 65, then done
		cmp  #92
		bcc	 +					; 65 <= A < 92, then +128
		cmp  #97
		bcc  ++					; 92 <= A < 97, then done
		cmp  #124
		bcs  ++					; A >= 124, then done
		eor  #$20+$80			; 97 <= A < 124, then -32
	+	eor  #$80
	+	rts

cbm2unix:
		cmp  #65
		bcc  ++					; A < 65, then done
		cmp  #92
		bcc	 +					; 65 <= A < 92, then +32
		cmp  #193
		bcc  ++					; 92 <= A < 193, then done
		cmp  #220
		bcs  ++					; A >= 220, then done
		eor  #$80+$20			; 193 <= A < 220, then -128
	+	eor  #$20
	+	rts

;;; ----------------------------- variables -------------------------------

;;; ZEROpage: ch_state 1
;;; ZEROpage: ch_secadr 1
;;; ZEROpage: ch_device 1
;;; ZEROpage: EOI 1
;;; ZEROpage: buffer 1
;;; ZEROpage: buffer_status 1
;;; ZEROpage: filename_length 1
;;; ZEROpage: fopen_flags 1
#ifdef HAVE_64NET2
;;; ZEROpage: iec_dev_flag 1
; iec_dev_flag:	.buf 0	; bit 7 =1 - iec device, bit 7 =0 - 64net/2 device
#endif
;ch_state:	.byte 0	; state of channel (idle/listen/talk)
adrmap:		.byte 0,0,0,0, 0,0,0,0	; 8 possible sec-adrs per device (8..15)

;ch_secadr:	.buf 1	; secondary address
;ch_device:	.buf 1	; device number
;EOI:		.buf 1	; bmi: end of transmission

;buffer:					.buf 1	; last byte sent
;buffer_status:			.buf 1	; bne: buffer valid

#ifdef HAVE_IDE64
filename:		        .buf 40 ; buffer for name of file (16+",p,w")
#else
filename:		        .buf 20 ; buffer for name of file (16+",p,w")
#endif
;filename_length:		.but 1	; length of filename

;fopen_flags:	.buf 1			; mostly used by opendir/readdir

CBMerr_tab:
		.byte 1			; "file deleted" is no error
		.byte 26		; disc with write protection
		.byte 34		; file doesn't exist
		.byte 60		; file already opened for writing
		.byte 62		; file not found
		.byte 63		; file exists
		.byte 65		; no more blocks available 
		.byte 72		; disc or directory full
		.byte 73		; DOS version (no error)
		.byte 70		; no channel available (too many files)
		.byte 67		; illegal track or sector (disc full?)

CBMerr2lng:	
		.byte 0, lerr_readonlyfs, lerr_nosuchfile, lerr_filelocked
		.byte lerr_nosuchfile, lerr_fileexists, lerr_discfull, lerr_discfull
		.byte 0, lerr_toomanyfiles, lerr_discfull

#ifdef PRINT_IECMSG
		.global CBMerr_txt
CBMerr_txt:
		.text ":gsm-MBC"		; "CBM-msg:"
#endif
