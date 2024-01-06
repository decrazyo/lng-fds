		;; IEC bus routines
		;; (serial kind of IEC, only using the signals
		;;  DATA, CLOCK and ATN)

		;; burst support on capable devices by Maciej Witkowiak <ytm@friko.onet.pl>
		;; (not as fast as it could be, but C128 Kernel - compatible and safe)
		;; needs CIA1TIMER1...
		;; burst destroys CIA1_TAxx, CIA1_ICR, CIA1_CRA..., burst_leave_fast partially
		;; recovers, but...
		;; twice checked, maybe will work... I hope
		;; defines (macros) should go into kernel/c128/iec.s
		;; 24.01.2000

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

bit_count		equ tmpzp
byte_count		equ syszp+5
byte			equ syszp+6
status			equ syszp+7

#ifdef C128
;;;;
;;; ZEROpage: burst_flag 1
;burst_flag		equ tmpzp+1		; or somewhere else in safe location
;;;;


;**************************************************************************
;		Burst mode related
;**************************************************************************

burst_get_response:
	-	lda CIA1_ICR
		and #8
		beq -
burst_leave_fast:				; or burst_set_in
		lda CIA1_CRA
		and #%10000000			; this is _very_ likely to
		ora #%00000100			; be changed...
		sta CIA1_CRA
		lda MMU_MCR
		and #%11110111
		sta MMU_MCR
		; add SPEED_FAST here???
		rts
		
burst_enter_fast:				; or burst_set_out

		; is SPEED_SLOW here???
		lda MMU_MCR
		ora #%00001000
		sta MMU_MCR
		lda #%01111111
		sta CIA1_ICR
		lda #0
		sta CIA1_TAHI
		lda #4
		sta CIA1_TALO
		lda CIA1_CRA
		and #%10000000
		ora #%01010101
		sta CIA1_CRA
		bit CIA1_ICR
		rts
#endif
;**************************************************************************
;		indirect I/O related subroutines
;**************************************************************************

send_talk:
		ora  #$40
		SKIP_WORD
		
send_listen:
		ora  #$20
		sta  byte
		asl  a
		ora  ch_state			; remember state of bus
		sta  ch_state
#ifdef C128
		sei
		jsr DATA_lo
		lda CIA2_PRA
		and #%00001000			; ATN?
		bne +
		jsr burst_enter_fast
		lda #$ff
		sta CIA1_SDR
		jsr burst_get_response
		txa
		ldx #$14			; delay loop, how long? 111/256us?
	-	dex
		bne -
		tax
	+	jsr ATN_hi
		jsr CLOCK_hi
		jsr DATA_lo
		txa
		ldx #$b8			; another delay, 1ms
	-	dex
		bne -
		tax
#else
		jsr  attention
#endif
		lda  #0
		sta  EOI
		sta  buffer_status

raw_send_byte:
		sei
		jsr  DATA_lo
		jsr  read_port
		bcs  dev_not_present
#ifdef C128
		bit CIA1_ICR
#endif
		jsr  CLOCK_lo
		bit  EOI
		bpl  +					; no EOI, then skip next two commands
		
	-	jsr  read_port
		bcc  -
	-	jsr  read_port
		bcs  -

	+ -	jsr  read_port
#ifdef C128
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		pha
		lda CIA1_ICR
		and #%00001000
		beq +
		lda #$c0
		sta burst_flag				; device is capable of burst transfer
	+	pla
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#endif
		bcc  -
#ifndef C128
		jsr  CLOCK_hi
#else
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		ora #%00010000
		sta CIA2_PRA				; CLOCK_hi
		and #%00001000
		bne send_serial
		bit burst_flag
		bpl send_serial
		jsr burst_enter_fast
		lda byte
		sta CIA1_SDR
		jsr burst_get_response
		jmp raw_send_cleanup
send_serial:						; common way...
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#endif
		lda  #8
		sta  bit_count

	-	jsr  read_port
		bcc  time_out0
		lsr  byte
		bcs  +
		jsr  DATA_hi
		bcc  ++
	+	jsr  DATA_lo
	+	jsr  CLOCK_lo
		DELAY_10us
		jsr  DATA_lo
		jsr  CLOCK_hi
		dec  bit_count
		bne  -

#ifdef C128
raw_send_cleanup:
#endif
		ldy  #to_1ms
		jsr  wait_data_hi_to
		bcc  +
		
time_out0:
		lda  #iecstatus_timeout
		SKIP_WORD
		
dev_not_present:
		lda  #iecstatus_devnotpresent
		ora  status
		sta  status
		jsr  ATN_lo
		jsr  delay_1ms
		jsr  CLOCK_lo
		jsr  DATA_lo
		cli
	+	rts
		
get_byte:
		sei
		jsr  CLOCK_lo
	-	jsr  read_port			; wait for clock lo
		bpl  -
		lda  #0
		sta  bit_count

#ifdef C128
		bit CIA1_ICR
#endif
				
	-	jsr  DATA_lo

		ldy  #to_256us
		jsr  wait_clock_hi_to	; wait with timeout
		bpl  +

		;; timeout (receive EOI)
		lda  bit_count
		bne  time_out0
		
		jsr  DATA_hi
		jsr  CLOCK_lo
		lda  #$ff
		sta  EOI
		sta  bit_count
		bne  -


#ifdef C128
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	+	lda CIA1_ICR
		and #%00001000
		beq +
		lda CIA1_SDR
		sta byte
		lda #$c0			; device is capable of burst transfer
		sta burst_flag
		jmp get_byte_cleanup
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#endif
		
	+	lda  #8
		sta  bit_count

_bitloop:		
		RECEIVE_BIT(byte)			; macro defined in MACHINE/iec.s
		dec  bit_count
		bne  _bitloop

#ifdef C128
get_byte_cleanup:
#endif
		jsr  DATA_hi

		bit  EOI
		bpl  +

		lda  #iecstatus_eof
		ora  status
		sta  status
		jsr  delay_50us
		jsr  CLOCK_lo
		jsr  DATA_lo
		
	+	lda  byte
		cli
		clc
		rts

send_byte:
		bit  buffer_status
		bpl  +
		pha
		lda  buffer
		sta  byte
		jsr  raw_send_byte
		pla
	+	sta  buffer
		lda  #$ff
		sta  buffer_status
		rts

send_untalk:
		sei
		jsr  CLOCK_hi
		jsr  ATN_hi
		lda  #$5f
		SKIP_WORD
		
send_unlisten:
		lda  #0
		sta  ch_state
		lda  #$3f
		pha
		lda  buffer_status
		bpl  +
		sta  EOI
		and  #$7f
		sta  buffer_status
		lda  buffer
		sta  byte
		jsr  raw_send_byte
	+	lsr  EOI
		jsr  attention
		pla
		sta  byte
#ifdef C128
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		lda burst_flag
		and #%01111111
		sta burst_flag
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#endif
		jsr  raw_send_byte
		jsr  ATN_lo
		jsr  delay_50us
		jsr  CLOCK_lo
		jmp  DATA_lo

sec_adr_after_talk:
		sta  byte
		sei
		jsr  CLOCK_hi
		jsr  DATA_lo
		jsr  delay_1ms
		jsr  raw_send_byte

		sei
		jsr  DATA_hi
		jsr  ATN_lo
		jsr  CLOCK_lo
	-	jsr  read_port
		bmi  -
		cli
		rts

sec_adr_after_listen:
		sta  byte
		sei
		jsr  CLOCK_hi
		jsr  DATA_lo
		jsr  delay_1ms
		jsr  raw_send_byte
		jmp  ATN_lo

open_iec_file:
		lda  #0
		sta  status
		lda  ch_device
		jsr  send_listen
		sei
		jsr  CLOCK_hi
		jsr  DATA_lo
		jsr  delay_1ms
		lda  ch_secadr
		ora  #$f0
		sta  byte
		jsr  raw_send_byte
		jsr  ATN_lo
		lda  status
		bne  ++					; error, then return
		lda  #0
		sta  byte_count

	-	ldy  byte_count
		cpy  filename_length
		beq  +
		lda  filename,y
		jsr  send_byte
		inc  byte_count
		bne  -

	+	jmp  send_unlisten

close_iec_file:
		lda  ch_device
		jsr  send_listen
		lda  ch_secadr
		and  #$ef
		ora  #$e0
		sta  byte
		sei
		jsr  CLOCK_hi
		jsr  DATA_lo
		jsr  delay_1ms
		jsr  raw_send_byte
		jsr  ATN_lo
		jsr  send_unlisten
		clc
	+	rts
					
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

	+	ldx  #<150
		ldy  #>150
		jsr  sleep				; sleep for (at least) 2.5 seconds
								; time for the drive to locate the file

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
		bne  -

		;; delete file
		
		stx  syszp+3
		jsr  enter_atomic
		jsr  disable_nmi
		SPEED_1MHZ				; switch to 1MHz mode
		jsr  close_channel

		ldx  syszp+3
		stx  ch_device

		;; open-name is "s:filename"
		
		lda  #83				; "s"
		sta  filename
		lda  #58				; ":"
		sta  filename+1
		ldy  #0
	-	lda  (syszp),y
		sta  filename+2,y
		beq  +
		iny
		cpy  #16
		bne  -
	+	iny
		iny
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
				

;;; ----------------------------- variables -------------------------------

;;; ZEROpage: ch_state 1
;;; ZEROpage: ch_secadr 1
;;; ZEROpage: ch_device 1
;;; ZEROpage: EOI 1
;;; ZEROpage: buffer 1
;;; ZEROpage: buffer_status 1
;;; ZEROpage: filename_length 1
;;; ZEROpage: fopen_flags 1

;ch_state:	.byte 0	; state of channel (idle/listen/talk)
adrmap:		.byte 0,0,0,0, 0,0,0,0	; 8 possible sec-adrs per device (8..15)
		
;ch_secadr:	.buf 1	; secondary address
;ch_device:	.buf 1	; device number
;EOI:		.buf 1	; bmi: end of transmission

;buffer:					.buf 1	; last byte sent
;buffer_status:			.buf 1	; bne: buffer valid

filename:		        .buf 20 ; buffer for name of file (16+",p,w")
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
CBMerr_txt:
		.text ":gsm-MBC"		; "CBM-msg:"
#endif
