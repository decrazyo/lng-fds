;; For emacs: -*- MODE: asm; tab-width: 4; -*-

		;; simple test application2 for the new serial driver API
		
#include <system.h>
#include <jumptab.h>
#include <rs232.h>
#include <kerrors.h>
#include <stdio.h>

#begindef print_string(pointer)
   ldy  #0
 pr%%next,push,ptop%%:	 
   lda  pointer,y
   beq  pr%%next,pcur%%
   jsr  putc
   iny
   bne  pr%%ptop%%
 pr%%pcur,pop%%:
#enddef

#define BUFLEN 16

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		;; start point

	hibyte_moddesc equ *+2
		bit  moddesc
		
		lda  #0
		ldx  #<moddesc
		ldy  hibyte_moddesc
		jsr  lkf_get_moduleif
		bcs  pr_error

		lda  #3
		jsr  lkf_set_zpsize
		
#define buffer_pointer userzp
#define buffer_endptr  userzp+1
#define done_flag      userzp+2
	
		print_string(welc_txt)

		;; ask for baud rate
ask_baud:
		print_string(baudsel_txt)
		sec
		ldx  #stdin
		jsr  fgetc
		nop
		cmp  #"0"
		bcc  wrong_input
		cmp  #"9"
		bcs  wrong_input
		pha
		jsr  out
		pla
		tax
		lda  baudcode-"0",x
		tax
		ldx  #0					; (ctrl - setbaud)
		jsr  rs232_ctrl			; set selected baudrate
		bcs  pr_error			; skip with error

		print_string(term_ok_txt)

		jmp  main


wrong_input:	
		lda  #$0a
		jsr  out
		jmp  ask_baud
		
out:	sec
		ldx  #stdout
		jsr  fputc
		nop
		rts
				
pr_error:
		print_string(term_err_txt)
		lda  #$ff				; return -1
		rts

		;; main part

main:
		ldx  #1					; (ctrl - set receivebyte handler)
		bit  rec_handler
		jsr  rs232_ctrl
		ldx  #2					; (ctrl - set sendbyte handler)
		bit  send_handler
		jsr  rs232_ctrl
		ldx  #4
		jsr  rs232_ctrl			; trigger start of receive

loop:
		ldx  recrptr
		cpx  recwptr
		beq  ++
		lda  recbuf,x
		tay
		inx
		cpx  #BUFLEN
		bcc  +
		ldx  #0
	+	stx  recrptr
		tya
		jsr  putc
		jmp  loop
		
	+	clc
		ldx  #stdin
		jsr  fgetc
		bcs  ++
		ldx  sndwptr
		sta  sndbuf,x
		inx
		cpx  #BUFLEN
		bcc  +
		ldx  #0
	+	stx  sndwptr
		ldx  #3
		jsr  rs232_ctrl			; trigger start of send
		jmp  loop
		
	+	cmp  #lerr_tryagain
		beq  loop

		jsr  rs232_unlock
		lda  #0
		rts

;;; ------------------------------------------------------------------------
		
		;; called within NMI-handler
		;; (NOT in conext of this task!! don't use userzp)
		;; < A=received byte
		;; > c=1 means no more bufferspace left, don't call me again
		;;       until "trigger receive"
rec_handler:
		ldx  recwptr
		sta  recbuf,x
		inx
		cpx  #BUFLEN
		bcc  +
		ldx  #0
	+	stx  recwptr
		clc
		rts
		
		;; called within NMI-handler
		;; (NOT in conext of this task!! don't use userzp)
		;; > A=byte to send
		;; > c=1 means no more bytes to send, don't call me again
		;;       until "trigger send"
send_handler:
		ldx  sndrptr
		cpx  sndwptr
		beq  ++
		lda  sndbuf,x
		tay
		inx
		cpx  #BUFLEN
		bcc  +
		ldx  #0
	+	stx  sndrptr
		tya
		clc
		rts

	+	sec
		rts

;;; ------------------------------------------------------------------------
		
putc:	sec
		ldx  #stdout
		jsr  fputc
		nop
		rts
		
		RELO_END				; no more code to relocate

moddesc:
	RS232_struct2	; MACRO defined in rs232.h (rs232_{unlock,ctrl,getc,putc})

welc_txt:
		.text "232 terminal is active"
		.byte $0a,$00
		
term_err_txt:
		.text "Error initializing RS232-interface"
		.byte $0a,$00

baudsel_txt:
		.text "Select baud rate:"
		.byte $0a
		.text "  0: 300    1: 600    2: 1200"
		.byte $0a
		.text "  3: 2400   4: 4800   5: 9600"
		.byte $0a
		.text "  6: 19200  7: 38400  8: 57600"
		.byte $0a
		.text "  >"
		.byte $00

term_ok_txt:
		.byte $0a
		.text "Running, press RUN/STOP to exit"
		.byte $0a,$00

baudcode:
		.byte RS232_baud300
		.byte RS232_baud600
		.byte RS232_baud1200
		.byte RS232_baud2400
		.byte RS232_baud4800
		.byte RS232_baud9600
		.byte RS232_baud19200
		.byte RS232_baud38400
		.byte RS232_baud57600

recbuf:		.buf BUFLEN
sndbuf:		.buf BUFLEN
		
recwptr:	.byte 0				; write-pointer into receive buffer
recrptr:	.byte 0				; read-pointer into receive buffer
sndwptr:	.byte 0				; write-pointer into send buffer
sndrptr:	.byte 0				; read-pointer into send buffer
		
end_of_code:
