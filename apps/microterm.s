		;; micro terminal for LNG
		;; using generic (built in) serial driver
		;; (test application)
		
#include <system.h>
#include <jumptab.h>
#include <rs232.h>
#include <kerrors.h>
#include <stdio.h>

#begindef print_string(pointer)
   ldy  #0
 - lda  pointer,y
   beq  +
   jsr  out
   iny
   bne  -
 +
#enddef
		  				
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
		jsr  rs232_ctrl			; set selected baudrate
		bcs  pr_error			; skip with error

		print_string(term_ok_txt)

term_loop:		
		jsr  rs232_getc
		bcs  +
		jsr  out
		jmp  term_loop
	+	clc
		ldx  #stdin
		jsr  fgetc
		bcs  +
		cmp  #$03				; RUN/STOP ?
		beq  endall
		jsr  rs232_putc
		jmp  term_loop

	+	cmp  #lerr_tryagain
		beq  term_loop
		jmp  lkf_suicerrout

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

endall:	jsr  rs232_unlock
		lda  #0
		rts
		
		RELO_END ; no more code to relocate

moddesc:
	RS232_sstruct4	; MACRO defined in rs232.h (rs232_{unlock,ctrl,getc,putc})

welc_txt:
		.text "Micro terminal V0.2 for LNG"
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
		
end_of_code:
