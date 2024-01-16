
;; Famicom disk system (FDS) routines.

#include <config.h>

#include MACHINE_H
#include <system.h>
#include <kerrors.h>
#include <fs.h>
#include <zp.h>

		.global fs_fds_fopen
		.global fs_fds_fopendir
		.global fs_fds_fclose
		.global fs_fds_fgetc
		.global fs_fds_fputc
		.global fs_fds_fcmd
		.global fs_fds_freaddir

		.global enter_atomic
		.global leave_atomic
		.global unix2cbm
		.global cbm2unix

#define buffer_size 32 - fdssmb_buffer

infile_ptr      equ  syszp
infile_ptr_lo   equ  syszp
infile_ptr_hi   equ  syszp+1

smb_ptr         equ  syszp
smb_ptr_lo      equ  syszp
smb_ptr_hi      equ  syszp+1

smb_id          equ  syszp+2

file_handle     equ  syszp+3

blocking_flag   equ  syszp+4

dir_struct_ptr  equ  syszp+5
dir_strcut_lo   equ  syszp+5
dir_strcut_hi   equ  syszp+6


;; function: fs_fds_open
;; syszp=file, syszp+2=fmode 
;; X=minor (device number)
fs_fds_fopen:
		; TODO: check that the file isn't being opened for writing.
		;       we're only supporting reading on partition 0.

		tsx
		stx tmp_stack

		jsr get_file_count

		lda #$0
		sta tmp_current_index
		ldx #lerr_nosuchfile
		cmp tmp_file_count
		jsr xfer_fail_on_cs ; error if there are no files somehow.

_check_next_file:
		; TODO: preemptively allocate an SMB.
		;       write file names there to save on RAM usage.
		jsr get_file_info
		jsr rstrip_filename

_strcmp_filenames:
		lda filename, y
		cmp (infile_ptr), y
		bne _file_mismatch
		dey
		bpl _strcmp_filenames

		; file names match
		jsr xfer_done
		jsr raw_open ; overwrites infile_ptr with smb_ptr

		; Y = fdssmb_index
		lda tmp_current_index
		sta (smb_ptr), y ; file index.

		iny
		lda #0
		sta (smb_ptr), y ; data offset lo.
		iny
		sta (smb_ptr), y ; data offset hi.

		iny
		sta (smb_ptr), y ; buffer length.

		iny
		sta (smb_ptr), y ; buffer index.

		clc
		ldx tmp_file_handle
		rts
_file_mismatch:
		; return error if we have run out of files to check.
		inc tmp_current_index
		ldx #lerr_nosuchfile
		lda tmp_current_index
		cmp tmp_file_count
		jsr xfer_fail_on_cs ; error if index is out of range
		jsr skip_file_data
		jmp _check_next_file



;; function: raw_open
;; TODO: document this
raw_open:
		sec ; non blocking
		jsr smb_alloc
		jsr alloc_pfd
		; TODO: handle allocation errors
		stx tmp_file_handle ; remember fd.

		ldy #0
		lda #MAJOR_FDS
		sta (smb_ptr), y ; major.

		iny
		; TODO: get the minor value from our caller.
		;       until we implement a second partition, we can just hard-code this.
		lda #0 
		sta (smb_ptr), y ; minor (partition number).

		; this was copied from "fd_iec.s".
		; it works but it's overkill since we only support reading on partition 0.
		lda  syszp+2
		cmp  #fmode_ro
		beq  _read_only
		lda  #0					; rdcnt=0 / wrcnt=1
		ldx  #fflags_write		; flags= write only
		bne  _write_only
_read_only:
		lda  #1					; rdcnt=1 / wrcnt=0
		ldx  #fflags_read		; flags= read only
_write_only:
		iny
		sta  (smb_ptr), y			; ->rdcnt
		eor  #1
		iny
		sta  (smb_ptr), y			; ->wrcnt
		iny
		txa
		sta  (smb_ptr), y			; ->flags

		iny
		lda #0
		sta (smb_ptr), y ; file index.

		rts


;; function: fs_fds_fopendir
;; TODO: document this
fs_fds_fopendir:
		; TODO: check that the directory isn't being opened for writing.
		;       we're only supporting reading on partition 0.
		; TODO: check that we aren't trying to open a sub-directory.
		;       the native FDS partition doesn't support directories.
		; TODO: check that a disk in inserted.

		jsr raw_open
		clc
		lda tmp_file_handle
		rts


;; function: fs_fds_fclose
;; TODO: document this
fs_fds_fclose:
		; fclose will handle freeing the SMB.
		; i don't think there is any work for us to do here.
		clc
		rts


;; function: fs_fds_freaddir
;; read a single directory entry.
;;
;; < smb_ptr        (syszp)
;; < smb_id         (syszp+2)
;; < file_handle    (syszp+3)
;; < blocking_flag  (syszp+4) ; ignored
;; < dir_struct_ptr (syszp+5)
;; > c=0 : A = byte?
;;   c=1 : A = errno
fs_fds_freaddir:
		tsx
		stx tmp_stack

		ldy #fdssmb_index
		lda (smb_ptr), y
		sta tmp_file_index
		jsr seek_to_file

		jsr xfer_done ; we've got everything we need. end transfer.

		ldy #0
		lda #%00000011 ; flags (have mode and size)
		sta (dir_struct_ptr), y

		iny
		lda #%00000101 ; mode (read and execute)
		sta (dir_struct_ptr), y

		; file size
		iny
		lda tmp_size_lo
		sta (dir_struct_ptr), y
		iny
		lda tmp_size_hi
		sta (dir_struct_ptr), y
		iny
		lda #0
		sta (dir_struct_ptr), y
		iny
		lda #0
		sta (dir_struct_ptr), y

		; file name
		jsr rstrip_filename
		ldy #11 ; directory struct file name offset - 1.
_copy_file_name_freaddir:
		iny
		lda filename-12, y
		sta (dir_struct_ptr), y
		bne _copy_file_name_freaddir

		; increment file index for the next call.
		inc tmp_file_index
		lda tmp_file_index
		ldy #fdssmb_index
		sta (smb_ptr), y

		clc ; success
		rts


;; function: fs_fds_fgetc
;; read a single byte from stream.
;; returns through "io_return".
;;
;; < smb_ptr        (syszp)
;; < smb_id         (syszp+2)
;; < file_handle    (syszp+3)
;; < blocking_flag  (syszp+4) ; ignored
;; > c=0 : A = byte
;;   c=1 : A = errno
;; errors: lerr_ioerror, lerr_deverror, lerr_eof
fs_fds_fgetc:
		; the low-level disk routines manipulate the stack to return errors.
		; this allows us to catch errors and return them with io_return_error.
		jsr _fs_fds_fgetc_impl
_io_return_error:
		jmp io_return_error
_fs_fds_fgetc_impl:
		; check if we have data buffered in the SMB.
		ldy #fdssmb_bufidx
		lda (smb_ptr), y
		dey ; #fdssmb_bufend
		cmp (smb_ptr), y
		beq _buffer_data ; branch if there is no data in the buffer.

		; grab a byte from the buffer and store it in X.
		tay
		lda (smb_ptr), y ; get data from the buffer
		tax

		; increment the buffer index
		iny
		tya
		ldy #fdssmb_bufidx
		sta (smb_ptr), y

		; remove our error handler from the stack.
		pla
		pla
		; return the read byte.
		txa
		jmp  io_return ; must return with io_return.

_buffer_data:
		tsx
		stx tmp_stack

		ldy #fdssmb_index
		lda (smb_ptr), y
		sta tmp_file_index
		; this could error out with "lerr_eof", which doesn't really make sense in this context.
		; that should only happen if the user swapped disks.
		; that feels like an unlikely failure mode so i don't care.
		jsr seek_to_file

		; compute the number of bytes left to be read.
		; file size -= file offset
		; this will also determine if this will be our last read.
		; if so, verify the block 4 CRC.
		sec
		ldy #fdssmb_offset_lo
		lda tmp_size_lo
		sbc (smb_ptr), y
		sta tmp_size_lo
		iny ; #fdssmb_offset_hi
		lda tmp_size_hi
		sbc (smb_ptr), y
		sta tmp_size_hi

		bne _read_max ; branch if high byte isn't 0. plenty of data to read.
		ldx #lerr_eof
		lda tmp_size_lo
		jsr xfer_fail_on_eq
		cmp #buffer_size
		beq _read_max ; branch if this is our last read and it will fill the buffer exactly.
		bcs _set_not_done_flag ; branch if remaining data will fill the buffer and then some.

		; compute where the end of the buffer will be in the SMB.
		clc
		adc #fdssmb_buffer
		; ; compute where the end of the buffer will be in the SMB.
		; sec
		; lda #32 ; end of SMB.
		; sbc tmp_size_lo
		bpl _read_some ; branch always

_set_not_done_flag:
		inc tmp_size_hi ; make this non-zero so we know it isn't our last read.
_read_max:
		lda #32 ; end of SMB.
_read_some:
		sta tmp_size_lo ; SMB index where the buffer ends.

		; seek to the start of block 4 (file data)
		lda #4
		jsr check_block_type

		; seek to the correct byte in the file.
		ldy #fdssmb_offset_hi
		lda (smb_ptr), y
		tax
		dey ; #fdssmb_offset_lo
		lda (smb_ptr), y
		tay
		jsr seek_x_y_bytes

		; buffer disk data in the SMB.
		; this drastically cuts down on seek time for subsequent calls.
		ldy #fdssmb_buffer ; SMB index for start of the buffer
_read_into_buffer:
		jsr xfer_byte ; changes A and X
		sta (smb_ptr), y
		iny
		cpy tmp_size_lo ; SMB index for end of the buffer.
		bne _read_into_buffer

		; if we are at the end of the file then check the CRC.
		lda tmp_size_hi
		bne _skip_crc_check
		jsr end_block_read ; changes A and X
_skip_crc_check:

		jsr xfer_done ; change A and X

		; compute the buffer length from the SMB index.
		tya
		sec
		sbc #fdssmb_buffer
		; add the buffer length to the data offset.
		ldy #fdssmb_offset
		clc
		adc (smb_ptr), y ; fdssmb_offset_lo
		sta (smb_ptr), y
		iny
		lda #0
		adc (smb_ptr), y ; fdssmb_offset_hi
		sta (smb_ptr), y

		; set SMB index of the buffer end.
		lda tmp_size_lo
		ldy #fdssmb_bufend
		sta (smb_ptr), y

		; set SMB index for the start of the buffer.
		iny
		lda #fdssmb_buffer
		sta (smb_ptr), y

		; now that we've buffered the data, just grab a byte out of the buffer.
		jmp _fs_fds_fgetc_impl


;; function: fs_fds_fputc
;; TODO: document this
fs_fds_fputc:
		lda #lerr_notimp
		sec ; error
		rts


;; function: fs_fds_fcmd
;; TODO: document this
fs_fds_fcmd:
		lda #lerr_notimp
		sec ; error
		rts


;**************************************************************************
; disk routines
;**************************************************************************

;; function: seek_to_file
;; reset the drive to the start of the disk.
;; read the file count.
;; seek to the nth file on disk.
;; this does not use the file id nor file number stored in block 3.
;;
;; < tmp_file_index = desired file index (0 indexed)
;; > drive head in gap between block 3 and block 4.
;; > filename
;; > tmp_size_lo
;; > tmp_size_hi
;; changes: A, X, Y
;; changes: tmp_current_index
;; errors: lerr_ioerror, lerr_deverror, lerr_eof
seek_to_file:
		jsr get_file_count

		; throw error if file index is out of range.
		ldx #lerr_eof
		lda tmp_file_index
		cmp tmp_file_count
		jsr xfer_fail_on_cs

		lda #0
		sta tmp_current_index
_seek_to_file:
		; seek to and read block 3 (file header)
		jsr get_file_info

		; return if we have reached the desired file.
		lda tmp_current_index ; current file index
		cmp tmp_file_index ; desired file index
		beq _done_seeking

		jsr skip_file_data

		inc tmp_current_index
		bne _seek_to_file ; branch always.
_done_seeking:
		rts



skip_file_data:
		; seek to the start of block 4 (file data)
		lda #4
		jsr check_block_type

		; seek to the end of block 4
		ldx tmp_size_hi
		ldy tmp_size_lo
		jsr seek_x_y_bytes

		; verify checksum
		jmp end_block_read
		; jsr rts -> jmp


;; function: get_file_info
;; get the name and size from the next file header (block 3).
;;
;; < drive head in gap before block 3.
;; > drive head in gap between block 3 and block 4.
;; > filename
;; > tmp_size_lo
;; > tmp_size_hi
;; changes: A, X, Y
;; errors: lerr_ioerror, lerr_deverror
get_file_info:
		lda #3
		jsr check_block_type

		; seek to file name.
		ldy #2
		jsr seek_y_bytes

		ldy #0
_copy_file_name:
		jsr xfer_byte
		sta filename, y
		iny
		cpy #8 ; max file name length.
		bne _copy_file_name

		; seek to file size.
		ldy #2
		jsr seek_y_bytes

		jsr xfer_byte
		sta tmp_size_lo
		jsr xfer_byte
		sta tmp_size_hi

		; TODO: consider using this determine executable permissions.
		jsr xfer_byte ; skip file type.
		jmp end_block_read
		; jsr rts -> jmp


;; function: get_file_count
;; reset the drive to the start of the disk.
;; read the file count.
;; seek to the end of block 2.
;; verify disk integrity along the way.
;;
;; > drive head in gap between block 2 and block 3.
;; > tmp_file_count
;; changes: A, X, Y
;; errors: lerr_ioerror, lerr_deverror
get_file_count:
		jsr start_xfer

		; skip all of block 1 (disk info)
		ldy #55
		jsr seek_y_bytes

		jsr end_block_read

		; seek to block 2 (file amount)
		lda #2
		jsr check_block_type

		jsr xfer_byte
		sta tmp_file_count

		jmp end_block_read
		; jsr rts -> jmp


;; function: end_block_read
;; verify a block's integrity be checking the CRC bytes at the end of the block.
;;
;; > drive head in gap after block.
;; calls: check_disk_set
;; errors: lerr_ioerror, lerr_deverror
;; changes: A, X 
end_block_read:
		jsr xfer_byte ; first CRC byte.

		; throw error if premature end of file.
		ldx #lerr_ioerror
		lda FDS_DISK_STATUS
		and #FDS_DISK_STATUS_E
		jsr xfer_fail_on_ne

		; set CRC control.
		lda tmp_fds_ctrl
		ora #FDS_CTRL_B
		sta tmp_fds_ctrl
		sta FDS_CTRL

		jsr xfer_byte ; second CRC byte.

		; throw error if CRC fails.
		ldx #lerr_ioerror
		lda FDS_DISK_STATUS
		and #FDS_DISK_STATUS_B
		jsr xfer_fail_on_ne
;; function: check_disk_set
;; disable disk interrupts, transfer behavior, and CRC control.
;; enable transfer mode (read).
;; check that a disk is inserted.
;;
;; errors: lerr_deverror
check_disk_set:
		lda tmp_fds_ctrl
		; disable interrupts, transfer behavior, and CRC control.
		and #~(FDS_CTRL_I | FDS_CTRL_S | FDS_CTRL_B) & $ff
		ora #FDS_CTRL_R
		sta tmp_fds_ctrl
		sta FDS_CTRL

		; return error if disk is not inserted.
		ldx #lerr_deverror
		lda FDS_DRIVE_STATUS
		lsr a
		jmp xfer_fail_on_cs
		; jsr rts -> jmp


;; function: seek_x_y_bytes
;; uses X and Y as a 16-bit number of bytes to skip on the disk.
;;
;; < X = 256*X number of bytes to skip.
;; < Y = number of bytes to skip.
;; > A = last byte read.
;; changes: X, Y
seek_x_y_bytes:
		stx tmp_seek_hi
		cpy #0
		beq _seek_y_done
		jsr seek_y_bytes
_seek_y_done:
		ldx tmp_seek_hi
		beq _seek_x_done
_seek_x_bytes:
		jsr seek_y_bytes ; seek 256 bytes
		dec tmp_seek_hi
		bne _seek_x_bytes
_seek_x_done:
		rts
;; function: seek_y_bytes
;; skip the next Y bytes of the disk.
;; 
;; < Y = number of bytes to skip. 0 skips 256 bytes.
;; > A = last byte read.
;; changes: X, Y
seek_y_bytes:
		jsr xfer_byte
		dey
		bne seek_y_bytes
		rts


;; function: start_xfer
;; reset the disk drive and wait for the head to seek to the start of the disk.
;; seek forward to the start of a block 1 and verify the block type.
;;
;; > drive head after first byte of block 1.
;; > A = block type
;; changes: A, X, Y
;; errors: lerr_ioerror, lerr_deverror
start_xfer:
		; disable NMI interrupts.
		lda ppu_ctrl
		and #~PPU_CTRL_V
		sta PPU_CTRL
		; disable timer interrupts.
		ldx #FDS_TIMER_CTRL_R
		stx FDS_TIMER_CTRL

		jsr wait_for_ready

		; TODO: figure out why this is needed.
		ldy #197
		jsr fds_delay_ms
		ldy #70
		jsr fds_delay_ms

		lda #1 ; expected block type
		jmp check_block_type
		; jsr rts -> jmp


;; function: check_block_type
;; seek forward to the start of a block
;; read the first byte of the block and check that it matches an expected value.
;;
;; > drive head after first byte of a block.
;; > A = block type
;; changes: A, Y, X
;; errors: lerr_ioerror
check_block_type:
		ldy #5
		jsr fds_delay_ms

		sta tmp_block_type ; expected block type.

		lda tmp_fds_ctrl
		ora #FDS_CTRL_S ; set transfer behavior.
		sta tmp_fds_ctrl
		sta FDS_CTRL

		; throw error if block type is incorrect.
		jsr xfer_first_byte
		ldx #lerr_ioerror
		cmp tmp_block_type
		jmp xfer_fail_on_ne
		; jsr rts -> jmp


;; function: xfer_first_byte
;; enable disk transfer interrupts.
;; wait for the disk to read a byte and return it.
;;
;; > drive head after first byte of block 1.
;; > A = first byte read from disk.
;; changes: X
xfer_first_byte:
		; enable disk transfer IRQ handler.
		ldx #FDS_IRQ_CTRL_X
		stx FDS_IRQ_CTRL
		; enable disk transfer IRQ.
		rol tmp_fds_ctrl
		sec
		ror tmp_fds_ctrl
		ldx tmp_fds_ctrl
		stx FDS_CTRL
;; function: xfer_byte
;; wait for the disk to read a byte and return it.
;;
;; > A = byte read from disk.
;; changes: X
xfer_byte:
		cli
wait_irq:
		jmp wait_irq


;; function: wait_for_ready
;; reset the disk drive and wait for the head to seek to the start of the disk.
;;
;; > drive head at start of disk.
;; changes: A, X, Y
;; errors: lerr_deverror
wait_for_ready:
		jsr stop_motor

		ldy #0 ; 256 ms
		jsr fds_delay_ms
		jsr fds_delay_ms

		jsr start_motor

		ldy #150
		jsr fds_delay_ms

		; check battery status.
		lda tmp_fds_write_ext
		ora #FDS_READ_EXT_B
		sta tmp_fds_write_ext
		sta FDS_WRITE_EXT

		; throw error if batteries are low.
		ldx #lerr_deverror
		eor FDS_READ_EXT
		rol a
		jsr xfer_fail_on_cs

		jsr stop_motor
		jsr start_motor
		; wait for drive to be ready.
__wait_for_drive_ready:
		; throw error if there is no disk in the drive.
		ldx #lerr_deverror
		lda FDS_DRIVE_STATUS
		lsr a
		jsr xfer_fail_on_cs
		; check if the drive is ready yet.
		lsr a
		bcs __wait_for_drive_ready ; branch if disk not ready yet.
		rts


;; function: stop_motor
;; stop the disk drive motor.
;; should be called before "start_motor".
;;
;; > A = current state of FDS_CTRL
stop_motor:
		lda tmp_fds_ctrl
		; retain mirroring
		and #FDS_CTRL_M
		; set transfer mode read and transfer reset
		ora #FDS_CTRL_1 | FDS_CTRL_R | FDS_CTRL_T
		sta FDS_CTRL
		rts


;; function: start_motor
;; start the disk drive motor.
;; should be called after "stop_motor".
;;
;; < A = current state of FDS_CTRL
;; changes: A
start_motor:
		; start drive motor.
		ora #FDS_CTRL_D
		sta FDS_CTRL
		; unset transfer reset.
		and #~(FDS_CTRL_T) & $ff
		sta tmp_fds_ctrl
		sta FDS_CTRL
		rts


;; function: xfer_fail_on_eq
;; < X = error code
;; < Z = 0 : return
;;   Z = 1 : reset the disk drive and throw an error
xfer_fail_on_eq:
		beq _xfer_fail
_no_xfer_error:
		rts
;; function: xfer_fail_on_ne
;; < X = error code
;; < Z = 0 : reset the disk drive and throw an error
;;   Z = 1 : return
xfer_fail_on_ne:
		beq _no_xfer_error
_xfer_fail:
		sec ; indicate error to caller
;; function: xfer_fail_on_cs
;; < X = error code
;; < C = 0 : return
;;   C = 1 : reset the disk drive and throw an error
xfer_fail_on_cs:
		bcc _no_xfer_error
		; restore the stack so we can throw an error.
		txa
		ldx tmp_stack
		txs
		tax
;; function: xfer_done
;; reset the disk drive
;;
;; changes: A
xfer_done:
		lda tmp_fds_ctrl
		; retain mirroring and drive motor
		and #FDS_CTRL_M | FDS_CTRL_D
		; set transfer mode read and transfer reset
		ora #FDS_CTRL_1 | FDS_CTRL_R | FDS_CTRL_T
		sta tmp_fds_ctrl
		sta FDS_CTRL
		; restore NMI interrupts.
		lda ppu_ctrl
		sta PPU_CTRL
		; use the kernel IRQ handler again.
		lda #FDS_IRQ_CTRL_G
		sta FDS_IRQ_CTRL
		; enable timer IRQs again.
		lda #FDS_TIMER_CTRL_E | FDS_TIMER_CTRL_R
		sta FDS_TIMER_CTRL
		txa
		rts


;; function: rstrip_filename
;; strip trailing spaces from FDS a file name and null terminate the string.
;;
;; < filename
;; > filename
;; > Y = index of null terminator
;; changes: A, Y
rstrip_filename:
		ldy #8
_rstrip_loop:
		lda #0
		sta filename, y
		dey
		bmi _stripped
		lda filename, y
		cmp #$20
		beq _rstrip_loop
_stripped:
		iny ; offset of null terminator
		rts


;**************************************************************************
;		LNG filesystem interface wrapper
;**************************************************************************

; TODO: assess how much of the following is actually needed.
;       it's mostly copied from another driver.

enter_atomic:
		rts
leave_atomic:
		rts

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

;;; ZEROpage: tmp_block_type  1
;;; ZEROpage: tmp_current_index  1
;;; ZEROpage: tmp_fds_ctrl  1
;;; ZEROpage: tmp_fds_write_ext  1
;;; ZEROpage: tmp_file_count  1
;;; ZEROpage: tmp_file_index  1
;;; ZEROpage: tmp_size_lo  1
;;; ZEROpage: tmp_size_hi  1
;;; ZEROpage: tmp_seek_hi  1
;;; ZEROpage: tmp_stack  1
;;; ZEROpage: tmp_file_handle  1

filename: .buf 9 ; 8 character file names + a null terminator.
