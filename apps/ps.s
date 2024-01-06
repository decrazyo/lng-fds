		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; ps
		;; list processes
		
		
#include <system.h>
#include <stdio.h>

		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION, <LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		lda  #6					; allocate 6 bytes of zeropage
		jsr  lkf_set_zpsize

		;; get a free page

		lda  #2
		jsr  lkf_palloc
		nop						; (die on error)
		stx  userzp+3			; remember address
		txa
		pha						; remember

		;; make snapshot of process table
		ldy  #0
		sty  userzp+2
		sty	 userzp
		jsr  lkf_locktsw		; lock taskswitching (IRQ stays enabled!)

		ldx  #31				; task limit

		;; 16 bytes per task
		;;   0     - Status, Priority and Flags
		;;   1/2   - PID
		;;   3/7   - Time
		;;   8/9   - Waitstate
		;;   10/11 - PPID
		;;   12    - used pages

loop:
		;; Status, Priority, Flags
		lda  lk_tstatus,x
		sta  buffer
		beq  buffer_filled
		;; PID
		lda  lk_ttsp,x
		sta  userzp+1
		ldy  #tsp_pid
		lda  (userzp),y
		sta  buffer+1
		iny
		lda  (userzp),y
		sta  buffer+2
		;; Time
		ldy  #tsp_time
	-	lda  (userzp),y
		sta  buffer+3-tsp_time,y
		iny
		cpy  #tsp_time+5
		bne  -
		;; waitstate
		ldy  #tsp_wait0
		lda  (userzp),y
		sta  buffer+8
		iny
		lda  (userzp),y
		sta  buffer+9
		;; PPID
		ldy  #tsp_ippid
		lda  (userzp),y
		bpl  +
		iny
		lda  #0					; no parent there
		sta  buffer+10
		beq  ++
	+	tay
		lda  lk_ttsp,y
		sta  userzp+1
		ldy  #tsp_pid
		lda  (userzp),y
		sta  buffer+10
		iny
		lda  (userzp),y
	+	sta  buffer+11
		;; used pages
		lda  #0
		sta  userzp+4			; page counter
		ldy  #2
		txa
	-	cmp  lk_memown,y
		bne  +
		inc  userzp+4
	+	iny
		bne  -
		lda  userzp+4
		sta  buffer+12

buffer_filled:			
		ldy  #12
	-	lda  buffer,y
		sta  (userzp+2),y
		dey
		bpl  -
		clc
		lda  userzp+2
		adc  #16
		sta  userzp+2
		bcc  +
		inc  userzp+3
	+	dex
		bmi  +
		jmp  loop
		
	+	jsr  lkf_unlocktsw		; allow taskswitching

		;; print headline
		
		ldy  #0
	-	lda  titleline,y
		beq  +
		jsr  out
		iny
		bne  -
		
		;; print_table

	+	lda  #0
		sta  userzp				; counter (0..31)
		pla
		pha
		sta  userzp+3

print_loop:
		ldy  #0
		lda  (userzp+2),y
		beq  print_skip
		;; print PID
		iny
		lda  (userzp+2),y
		sta  userzp+4
		iny
		lda  (userzp+2),y
		sta  userzp+5
		jsr  print_pid
		jsr  space
		;; print status
		jsr  print_status
		jsr  space
		;; print time
		ldy  #7
	-	lda  (userzp+2),y
		jsr  hexout
		dey
		cpy  #2
		bne  -
		jsr  space
		;; print PPID
		ldy  #10
		lda  (userzp+2),y
		sta  userzp+4
		iny
		lda  (userzp+2),y
		sta  userzp+5
		jsr  print_pid
		jsr  space
		;; print ID
		lda  userzp
		jsr  hexout
		jsr  space
		;; print FL (priority+flags)
		ldy  #0
		lda  (userzp+2),y
		jsr  hexout
		jsr  space
		;; print MEM (used internal memory pages)
		ldy  #12
		lda  (userzp+2),y
		jsr  hexout
		lda  #$0a
		jsr  out

print_skip:
		clc
		lda  userzp+2
		adc  #16
		sta  userzp+2
		bcc  +
		inc  userzp+3
	+	ldx  userzp
		inx
		stx  userzp
		cpx  #32
		beq  +
		jmp  print_loop

	+	pla
		tax
		jsr  lkf_free
		lda  #0
		rts

		;; print 16 bit unsigned number (aligned)
print_pid:		
		;; < [4]/[5]=value
		
		ldx		#3
		ldy		#0

	-	sec 
		lda		userzp+4
		sbc		dec_tablo,x
		lda		userzp+5
		sbc		dec_tabhi,x
		bcc		+
		
		sta		userzp+5
		lda		userzp+4
		sbc		dec_tablo,x
		sta		userzp+4
		iny 
		bne		-

	+	tya
		beq		repl
		ora		#"0"
		jsr		out
		ldy		#"0"
	-	dex
		bpl		--

		lda		userzp+4
		ora		#"0"
		jmp		out

repl:	lda		#" "
		;; beq		-
		jsr		out
		jmp		-
		
		;; print hexadecimal
hexout:
		pha
		lsr  a
		lsr  a
		lsr  a
		lsr  a
		tax
		lda  hextab,x
		jsr  out
		pla
		and  #$0f
		tax
		lda  hextab,x
		
		SKIP_WORD
space:	
		lda  #" "
		;; print single character
out:
		sec						; blocking
		stx  outbackx
		ldx  #stdout
		jsr  fputc
		nop
outbackx equ *+1
		ldx  #0
		rts

print_status:
		ldy  #0
		lda  (userzp+2),y
		and  #tstatus_susp
		beq  st_running
		;; task is not running
		ldy  #8
		lda  (userzp+2),y		; waitstate lo
		cmp  #waitc_sleeping
		beq  st_sleeping
		cmp  #waitc_wait
		beq  st_wait
		cmp  #waitc_zombie
		beq  st_zombie
		cmp  #waitc_imem
		beq  st_memory
		cmp  #waitc_stream
		beq  st_stream
		cmp  #waitc_semaphore
		beq  st_sema
		cmp  #waitc_conskey
		beq  st_cons
		;; unknown
		lda  #"?"
		jsr  out
		lda  (userzp+2),y
		jsr  hexout
		iny
		lda  (userzp+2),y
		jmp  hexout
st_running:
		ldy  #str_running - str_base
		SKIP_WORD
st_sleeping:
		ldy  #str_sleeping - str_base
		SKIP_WORD
st_wait:
		ldy  #str_wait - str_base
		SKIP_WORD
st_zombie:
		ldy  #str_zombie - str_base
		SKIP_WORD
st_memory:
		ldy  #str_memory - str_base
		SKIP_WORD
st_cons:
		ldy  #str_cons - str_base
		ldx  #5
	-	lda  str_base,y
		jsr  out
		iny
		dex
		bne  -
		rts
st_stream:
		lda  #"i"
		jsr  out
		lda  #"o"
		jsr  out
		lda  #" "
		jsr  out
	-	ldy  #9
		lda  (userzp+2),y
		jmp  hexout
st_sema:
		lda  #" "
		jsr  out
		lda  #"s"
		jsr  out
		lda  #" "
		jsr  out
		jmp  -		
						
		RELO_END ; no more code to relocate

dec_tablo:		.byte <10, <100, <1000, <10000
dec_tabhi:		.byte >10, >100, >1000, >10000

titleline:
		.text " PID    ST     Time     PPID ID FP MEM"
		;;     ##### ##### ########## ##### ## ##  ##
		;;     0123456789012345678901234567890123456789
		.byte $0a, $00
hextab:
		.text "0123456789ABCDEF"

str_base:
str_running:
		.text " cpu "
str_sleeping:	
		.text "sleep"
str_zombie:
		.text " zomb"
str_wait:
		.text " wait"
str_memory:
		.text " mem "
str_cons:
		.text "wcons"
		
buffer:	.buf 16					; buffer for a single task-item
				
end_of_code:
