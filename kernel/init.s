;; for emacs: -*- MODE: asm; tab-width: 4; -*-
	
		;; **************************************************************
		;;  first task in the system  (init)
		;; **************************************************************

#include <fs.h>
#include <system.h>
#include <debug.h>
#include <kerrors.h>
#include MACHINE_H
#include <console.h>

		.global init

out_of_mem:
		lda  #lerr_outofmem
		jmp  suicerrout

init:						; former called microshell
		lda  #3
		jsr  set_zpsize			; use 3 bytes zeropage starting with userzp

		ldy  #tsp_envpage		; clean own environment page,
		lda  (lk_tsp),y			; because it will be inherited
		sta  userzp+1			; by all processes
		lda  #0
		sta  userzp
		tay
	-	sta  (userzp),y
		iny
		bne  -

		ldy  #tsp_pdmajor
		lda  #MAJOR_IEC
		sta  (lk_tsp),y
		iny				; ldy  #tsp_pdminor
		lda  #8
		sta  (lk_tsp),y			; default device (8,0)

.pwd_addr:
		bit  pwd_default
		lda  #<pwd_default
		ldy  pwd_addr+2
		jsr  setenv			; PWD variable

		jsr  console_open
		nop				; (need at least one working console)
		stx  console_fd

		;; get/set size of console

		ldy  #tsp_termwx
		lda  #size_x
		sta  (lk_tsp),y
		lda  #size_y
		iny				; ldy  #tsp_termwy
		sta  (lk_tsp),y

		;; print startup message
		ldx  console_fd
		bit  startup_txt
		jsr  strout

		;; allocate temporary buffers
		ldx  lk_ipid
		ldy  #$00
		jsr  spalloc
		bcs  out_of_mem
		stx  tmp_page			; remember hi byte of page
#ifndef HAVE_INITSCRIPT
		jmp  ploop
#else
tryboot:
		;; try to execute ".lunixrc"
		lda  console_fd
		sta  appstruct2+0		; childs stdin
		sta  appstruct2+1		; childs stdout
		sta  appstruct2+2		; childs stderr

		;; fork_to child process
		lda  #<appstruct2
		ldy  #>appstruct2
		jmp  load_and_execute2
#endif

report_error_2:
report_error:
		jsr  print_error

ploop:
		lda  #"."
		jsr  cout
		jsr  readline
		lda  #$0a
		jsr  cout
		lda  userzp
		beq  ploop			; ignore empty lines

		;; parse commandline

		ldy  #0
		sty  userzp
		lda  (userzp),y
		beq  c_end
		iny
		beq  c_end
		cmp  #"l"
		beq  load_and_execute
		cmp  #"x"
		beq  reboot

		;; unknown command

c_end:
		ldx  console_fd
		bit  error_txt
		jsr  strout

		jmp  ploop

#include MACHINE(reboot.s)

	-	iny
		beq  c_end

load_and_execute:
		;; create new process (code loaded from disk)

		lda  (userzp),y
		beq  c_end
		cmp  #" "
		beq  -

		ldx  #0
	-	sta  appstruct+3,x
		iny
		lda  (userzp),y
		beq  +
		inx
		cpx  #28
		bne  -
		jmp  c_end

	+	sta  appstruct+4,x
		sta  appstruct+5,x
		sta  appstruct+6,x

		lda  console_fd
		sta  appstruct+0		; childs stdin
		sta  appstruct+1		; childs stdout
		sta  appstruct+2		; childs stderr

		;; fork_to child process
		lda  #<appstruct
		ldy  #>appstruct
load_and_execute2:
		jsr  forkto
		bcs  report_error_2

		;; close console stream and try to open new one

		ldx  console_fd
		jsr  fclose

		jsr  console_open
		bcc  +
		ldx  #$ff
	+	stx  console_fd

		;; check for finished child processes

	-	ldx  #<wait_struct		; blocking if there is no console left
		ldy  #>wait_struct
		jsr  wait			; look for terminated child
		bcs  jploop			; carry always means lerr_tryagain (A not set)

	+	lda  console_fd
		bpl  +
		jsr  console_open
		bcs  -
		stx  console_fd

	+	pha
		ldy  #0
	-	lda  child_message_txt,y
		beq  +
		jsr  cout
		iny
		bne  -

	+	pla
		jsr  hex2cons
		lda  #" "
		jsr  cout
		ldy  #0
	-	lda  wait_struct,y
		jsr  hex2cons
		iny
		cpy  #7
		bne  -
		lda  #$0a
		jsr  cout

jploop:	
		jmp  ploop


;;; *******************************************

		;; read line from keyboard (not stdin)

readline:
		lda  #0
		sta  userzp
		lda  tmp_page
		sta  userzp+1

		;; wait for incomming char

	-	ldx  console_fd
		sec
		jsr  fgetc
		bcs  -				; (ignore EOF)

		;; got a valid char

		cmp  #$0a
		beq  read_return
		cmp  #32
		bcc  -				; illegal char (read again)
		ldy  #0
		sta  (userzp),y			; store char and echo to console
		jsr  cout
		inc  userzp
		bne  -
		dec  userzp
		jmp  -				; (beware of buffer overflows)

read_return:
		ldy  #0
		tya
		sta  (userzp),y
		lda  userzp			; return length of string
		rts		

hex2cons:
		pha
		lsr  a
		lsr  a
		lsr  a
		lsr  a
		jsr  +
		pla
		and  #15
	+	tax
		lda  hextab,x
cout:		sec
		ldx  console_fd
		jmp  fputc

hextab:		.text "0123456789abcdef"

child_message_txt:
		.byte $0a
		.text "Child terminated: \0"

console_fd:	.buf 1

wait_struct:	.buf 7				; 7 bytes

appstruct:
		.byte 0,0,0
		.buf  32

#ifdef HAVE_INITSCRIPT
;; boot file (.lunixrc)
;; we shouldnt use a shell _here_,
;; but execute shell script via kernel
appstruct2:
		.byte 0,0,0
		.text "sh"
		.byte 0
   		.text "-s"
   		.byte 0
   		.text "-r"
   		.byte 0
   		.text "-v"
   		.byte 0
   		.text ".lunixrc"
  		.byte 0
		.buf  32-(3+3+8)
#endif

;;; strings

pwd_default:	.text "PWD=/disk8",0
startup_txt:	.text $0a,"Init v0.1",$0a,0
error_txt:	.text "? (l)oad command / e(x)it+reboot",$0a,0
tmp_page:	.buf 1

