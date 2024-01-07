
;; Famicom disk system (FDS) routines.

#include <config.h>

#include MACHINE_H
#include <system.h>
#include <kerrors.h>
#include <fs.h>
#include <zp.h>

; these FDS BIOS functions may be useful
; Address 	Name 	Input parameters 	Output parameters 	Description 
; $E484 	GetNumFiles 		$06 = # of files 	Read the number of files from the file amount block. 
; $E4DA 	SkipFiles 	$06 = # of files to skip 		Skip over a specified number of files. 

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
		.global filename
		.global CBMerr_tab
		.global CBMerr2lng


fs_fds_fopen:
		rts
		; this function is very much a work in progress...

		; device 0: read-only native fds partition.
		; device 1: read-write fat or ext or something partition.
		; device 2+: should we allow additional partitions?
		; for now, assume we're dealing with device 0.

		ldy #0

		; copy the file name to "filename"
	-	lda (syszp),y
		sta filename,y
		beq + ; branch if we reached the end of the string
		iny
		cpy #8 ; max file name length for device 0.
		bne - ; branch if we haven't filled the filename buffer

	+	sec ; non blocking
		jsr  smb_alloc
		jsr alloc_pfd
		stx  syszp+4			; remember fd

		ldy  #0
		lda  #MAJOR_FDS
		sta  (syszp),y			; major

		iny
		lda  #0 ; TODO: hard coding device 0 for now. fix this.
		sta  (syszp),y			; minor (=device number)

		; TODO: figure out how this code works. update as needed.
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


; TODO: actually read the disk and open the file.

; TODO: copied from fs_iec. figure out why this is needed.
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

fs_fds_fopendir:
		rts

fs_fds_fclose:
		rts

fs_fds_fgetc:
		rts

fs_fds_fputc:
		rts

fs_fds_fcmd:
		rts

fs_fds_freaddir:
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
