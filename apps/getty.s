		;; For emacs: -*- MODE: asm; tab-width: 4; -*-
		;; simple getty for LNG

#include <system.h>
#include <stdio.h>
#include <rs232.h>
#include <kerrors.h>

#define	CMD_LEN 32				; max length of command

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

		start_of_code equ $1000

		.org start_of_code

		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		;; start point

	hibyte_moddesc equ *+2
		bit  moddesc

		;; set terminal width to vt100 standard 25x80
		ldy  #tsp_termwx
		lda  #80
		sta  (lk_tsp),y
		ldy  #tsp_termwy
		lda  #25
		sta  (lk_tsp),y
		
		;; get desired link speed from commandline

		lda  #3
		jsr  lkf_set_zpsize
		lda  userzp
		cmp  #2
		bne  HowTo
		ldy  #0
		sty  userzp
	-	iny
		lda  (userzp),y
		bne  -
		iny
		sty  userzp
		lda  #0
		sta  userzp+2

		ldx  #0
	-	lda  speed_tab,x
		beq  HowTo				; end_of_table
		ldy  #0

	-	lda  speed_tab,x
		beq  end_of_entry
		cmp  (userzp),y
		bne  +
		iny
		inx
		bne  -
	+ -	inx
		lda  speed_tab,x
		bne  -
	-	inc  userzp+2
		inx
		bne  ----

end_of_entry:
		cmp  (userzp),y
		bne  -
		ldx  userzp+1
		jsr  lkf_free			; free argument page

		lda  #0					; choose first available module
		ldx  #<moddesc
		ldy  hibyte_moddesc
		jsr  lkf_get_moduleif
		bcs  pr_error

		ldx  userzp+2			; baud code
		jsr  rs232_ctrl			; set selected baudrate
		bcs  pr_error2			; skip with error

		print_string(ok_txt)

		ldx  #stdin
		jsr  fclose
		ldx  #stdout
		jsr  fclose

		jmp  getty

HowTo:
		print_string(HowTo_txt)
		lda  #$01				; return 1 (error)
		rts

pr_error2:
		jsr  rs232_unlock
pr_error:
		print_string(error_txt)
		lda  #$01				; return 1 (error)
		rts

putc:	sec
		ldx  #stdout
		jsr  fputc
		nop
		rts

		;; start of main getty code
getty:
		ldx  #0
		stx  userzp
	-	ldx  userzp
		lda  Prompt_txt,x
		beq  +
		jsr  rs232_putc
		inc  userzp
		bne  -
	+	lda  #0
		sta  userzp				; counts chars

iloop:	ldx  #<60
		ldy  #>60
		jsr  lkf_sleep			; wait for 1s
iloop2:
		jsr  rs232_getc			; get char from serial interface
		bcs  iloop
		cmp  #$0a
		beq  iloop_end
		cmp  #$20
		bcc  iloop2				; ignore special code
		ldx  userzp
		sta  appstruct+3,x
		cpx  #CMD_LEN-3
		beq  iloop2
		inx
		stx  userzp
		jsr  rs232_putc			; echo to terminal
		jmp  iloop2

iloop_end:
		lda  #$0d
		jsr  rs232_putc
		lda  #$0a
		jsr  rs232_putc

		ldy  userzp
		beq  getty				; ignore empty lines
		lda  #0
		sta  appstruct+3,y		; terminate command name with $00
		jmp  spawn_command

report_error_2:
		pha
		ldx  userzp+1			; (channel from child)
		jsr  fclose
		ldx  appstruct+1		; childs stdout
		jsr  fclose
		pla

report_error_1:
		pha
		ldx  appstruct+0		; childs stdin
		jsr  fclose
		ldx  userzp				; (channel to child)
		jsr  fclose
		pla
report_error:
		;; print error
		ldx  #0
		stx  userzp
	-	ldx  userzp
		lda  exe_error_txt,x
		beq  +
		jsr  rs232_putc
		inc  userzp
		bne  -
	+	jmp  getty

spawn_command:
		;; create new process (code loaded from disk)

		sta  appstruct+4,y		; no args
		sta  appstruct+5,y

		;; create pipe to write to child process
		jsr  lkf_popen				; x=read-fd, y=write-fd
		bcs  report_error
_appstruct_ptr:
		stx  appstruct+0		; childs stdin
		sty  userzp				; (channel to child)

		;; create pipe to read from child process
		jsr  lkf_popen				; x=read-fd, y=write-fd
		bcs  report_error_1
		stx  userzp+1			; (channel from child)
		sty  appstruct+1		; childs stdout
		sty  appstruct+2		; childs stderr

		;; fork_to child process
		lda  #<appstruct
		ldy  _appstruct_ptr+2		; #>appstruct
		jsr  lkf_forkto
		bcs  report_error_2

		;; close unused pipe-ends
		ldx  appstruct+0
		jsr  fclose
		ldx  appstruct+1
		jsr  fclose

		;; read child's stdout channel
		;; while passing keystrokes to childs stdin channel
		lda  #0
		sta  userzp+2			; clear wait flag

	-	ldx  userzp+1
		clc						; nonblocking
		jsr  fgetc
		bcs  +
		cmp  #$0a				; LF -> CR/LF conversion
		bne  noconv
		lda  #$0d
		jsr  rs232_putc
		lda  #$0a
noconv:
		jsr  rs232_putc
		lda  #0
		sta  userzp+2
		jmp  -

	+	cmp  #lerr_tryagain
		bne  ++

	-	jsr  rs232_getc
		bcc  +

		bit  userzp+2
		bpl  short_wait
		ldx  #<16				; 16 jiffies = 1/4 s second
		ldy  #>16
		jsr  lkf_sleep
		jmp  --
short_wait:
		lda  #$80
		sta  userzp+2
		jsr  lkf_force_taskswitch
		jmp  --

	+	sec						; blocking (might get deadlocked here!)
		ldx  userzp
		jsr  fputc
		lda  #0
		sta  userzp+2
		bcc  -

	+
		;; close pipes to and from child
		ldx  userzp
		jsr  fclose
		ldx  userzp+1
		jsr  fclose

		;; check for finished child processes

		sec						; blocking
		ldx  #<wait_struct
		ldy  #>wait_struct
		jsr  lkf_wait			; look for terminated child
		bcs  +
		jmp  getty

	+	jmp  report_error

		RELO_END ; no more code to relocate

moddesc:
	RS232_sstruct4 ; MACRO defined in rs232.h (rs232_{unlock,ctrl,getc,putc})

Prompt_txt:
		.text "Welcome to LNG"
		.byte $0d,$0a
		.text "load ?"
		.byte $00

HowTo_txt:
		.text "Usage: getty speed"
		.byte $0a,$00

ok_txt:
		.text "getty version 1.0 running"
		.byte $0a,$00

error_txt:
		.text "Error initializing serial interface"
		.byte $0a,$00

exe_error_txt:
		.text "Error loading/executing application"
		.byte $0d,$0a,$00

speed_tab:
		.text "300"
		.byte 0
		.text "600"
		.byte 0
		.text "1200"
		.byte 0
		.text "2400"
		.byte 0
		.text "4800"
		.byte 0
		.text "9600"
		.byte 0
		.text "19200"
		.byte 0
		.text "38400"
		.byte 0
		.text "57600"
		.byte 0
		.byte 0

appstruct:
		.byte 0,0,0
		.buf  CMD_LEN

wait_struct:	.buf 7			; 7 bytes

end_of_code:
