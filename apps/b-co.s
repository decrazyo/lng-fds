		;; for emacs: -*- MODE: asm; tab-width: 4; -*-
		;; benchmark
		;; co - console output
	
#include <system.h>
#include <stdio.h>
#include <kerrors.h>
		
		start_of_code equ $1000

		.org start_of_code
		
		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION,	<LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code
		
		;; (task is entered here)
		
		ldx  userzp+1			; address of commandline (hi byte)
		jsr  lkf_free			; free used memory

		ldx  #stdout
		bit  on_txt
		jsr  lkf_strout
		
		lda  #6
		jsr  lkf_set_zpsize

		lda  #0					; reset counter
		sta  userzp
		sta  userzp+1
		sta  userzp+2

		lda  lk_systic+1		; (4seconds)
	-	cmp  lk_systic+1
		beq  -
		
		;; some more waiting (to make "b-co!wc" give correct results)
		
		lda  lk_systic+1		; (4seconds)
	-	cmp  lk_systic+1
		beq  -
		
		clc
		lda  lk_systic+1
		adc  #5					; (wait 20 seconds)
		sta  userzp+5

		bit  data1
		bit  data2
loop:
		ldx  loop-1				; #>data2
		ldy  #<data2
		sty  userzp+3
		stx  userzp+4
		ldy  #0
		ldx  #stdout
	-	lda  userzp+5
		cmp  lk_systic+1
		beq  end_loop
		lda  (userzp+3),y
		beq  ++
		sec
		jsr  fputc
		iny
		bne  +
		inc  userzp+4
	+	inc  userzp
		bne  -
		inc  userzp+1
		bne  -
		inc  userzp+2
		bne  -
	+	
		ldx  loop-4				; #>data1
		ldy  #<data1
		sty  userzp+3
		stx  userzp+4
		ldx  #stdout
		ldy  #0
	-	lda  userzp+5
		cmp  lk_systic+1
		beq  end_loop
		lda  (userzp+3),y
		beq  ++
		sec
		jsr  fputc
		iny
		bne  +
		inc  userzp+4
	+	inc  userzp
		bne  -
		inc  userzp+1
		bne  -
		inc  userzp+2
		bne  -
	+	
		ldx  loop-4				; #>data1
		ldy  #<data1
		sty  userzp+3
		stx  userzp+4
		ldy  #0
		ldx  #stdout
	-	lda  userzp+5
		cmp  lk_systic+1
		beq  end_loop
		lda  (userzp+3),y
		beq  ++
		sec
		jsr  fputc
		iny
		bne  +
		inc  userzp+4
	+	inc  userzp
		bne  -
		inc  userzp+1
		bne  -
		inc  userzp+2
		bne  -
	+	jmp  loop
		
end_loop:		
		ldx  #stderr
		bit  off1_txt
		jsr  lkf_strout
		
		jsr  print_result
		
		ldx  #stderr
		bit  off2_txt
		jsr  lkf_strout
		
		lda  #0
		jmp  lkf_suicide

		;; result = (userzp/2)/10
print_result:
		lsr  userzp+2
		ror  userzp+1
		ror  userzp
		
		ldy  #0
		ldx  #0

	-	sec
		lda  userzp
		sbc  dectabl,y
		lda  userzp+1
		sbc  dectabm,y
		lda  userzp+2
		sbc  dectabh,y
		bcc  +
		sta  userzp+2
		lda  userzp
		sbc  dectabl,y
		sta  userzp
		lda  userzp+1
		sbc  dectabm,y
		sta  userzp+1
		inx
		bne  -
	+	txa
		beq  +
		ora  #"0"
		sec
		ldx  #stderr
		jsr  fputc
		ldx  #"0"
	+	iny
		cpy  #7
		bne  -
		lda  #"."
		sec
		ldx  #stderr
		jsr  fputc
		lda  userzp
		ora  #"0"
		sec
		ldx  #stderr
		jmp  fputc		

		.byte 2

dectabl:
		.byte <10000000,<1000000,<100000,<10000,<1000,<100,<10
dectabm:
		.byte >10000000&$ff,>1000000&$ff,>100000&$ff,>10000,>1000,>100,>10
dectabh:
		.byte >>10000000,>>1000000,>>100000,>>10000,>>1000,>>100,>>10

on_txt:	.text "running benchmark...",$0a
		.text " (console output, 16 sec)",$0a,0
		
off1_txt:
		.text $0a,$0a,$0a,"result: ",0

off2_txt:
		.text " bytes/sec",$0a,0

		;; sample text
data1:
		.text "		",$0a
		.text "Xmas 1999 for all Commodore enthusiasts is here... ",$0a
		.text $0a
		.text "                                        _______",$0a
		.text "                                       /__/___/|",$0a
		.text "                                      /__/___/||",$0a
		.text "                                     |   |   |||",$0a
		.text "      L U n i x   N e x t            |   |   |/|",$0a
		.text "      G e n e r a t i o n            |---+---|||",$0a
		.text "                                     |   |   |||",$0a
		.text "           V  0.15                   |___|___|/",$0a
		.text $0a
		.text $0a
		.text $0a
		.text "I'm pleased to announce version 0.15 of ",34,"LUnix Next Gerneration",34," (LNG).",$0a
		.text "This is the first announcement of LNG in the news. The reason for ",$0a
		.text "this announcement is the implementation of PPP. The Point-to-Point",$0a
		.text "protocol is widely used by Internet Service Providers and today",$0a
		.text "(for some small exeptions) the only way to connect a home computer",$0a
		.text "to the Internet. At this point, i want to thank all the people",$0a
		.text "who are contributing to LNG by means of code, testing and ideas - ",$0a
		.text "especially Errol Smith for his work on PPP.",$0a
		.text $0a
		.text $0a
		.text "Some of LNGs key features:",$0a
		.text $0a
		.text "     * Preemptive multitasking (up to 32 tasks, 7 priorities)",$0a
		.text "     * Dynamic memory management (in chunks of 256 or 32 bytes)",$0a
		.text "     * Runtime code relocation",$0a
		.text "     * IPC (inter process communication) through pipes",$0a
		.text "     * IPC through signals",$0a
		.text "     * (minimal) REU support",$0a
		.text "     * SCPU compatible [new]",$0a
		.text "     * 30 standard applications available",$0a
		.text "     * Support for standard RS232 userport interface",$0a
		.text "     * Support for swiftlink RS232 interface",$0a
		.text "     * Virtual consoles",$0a
		.text "     * Hardware accelerated 80 columns console on C128 in C64 mode [new] ",$0a
		.text "     * Native C128 version available [new]",$0a
		.text "     * (simple) command shell (with history function)",$0a
		.text "     * Support for CBM (IEC bus) devices (eg. 1541)",$0a
		.text "     * Open source, comes with all needed (cross-) development tools",$0a
		.text "     * Widely configurable for your needs",$0a
		.text "     * LNG can be terminal and terminal server (RS232)",$0a
		.text "     * Support of SLIP packet encapsulation over serial links",$0a
		.text "     * Support of PPP [new]",$0a
		.text "     * Loop back packet driver for off-line client-server trials",$0a
		.text "     * TCP/IP stack (and clients for telnet and ftp)",$0a
		.text "     * ...",$0a
		.text $0a
		.text $0a
		.text "Visit the LUnix homepage at",$0a
		.text " http://www.heilbronn.netsurf.de/~dallmann/lunix/lng.html",$0a
		.text $0a
		.text "Download the full source code or the system precompiled in binary form.",$0a
		.text "Give feedback, contribute, have a good time ;-)",$0a
		.text $0a
		.text $0a
		.text "Merry Christmas",$0a
		.text "     and a",$0a
		.text "   happy new year !",$0a
		.text $0a
		.text $0a
		.text "...Daniel",$0a
		.text $0a,0

		;; some cursor positioning stuff
data2:		
		.byte $20, $1b, $5b, $32, $4a, $1b, $5b, $37
		.byte $6d, $1b, $5b, $31, $39, $3b, $31, $48
		.byte $20, $20, $20, $20, $20, $20, $20, $20
		.byte $20, $3d, $3d, $3d, $3e, $20, $57, $65
		.byte $6c, $63, $6f, $6d, $65, $20, $74, $6f
		.byte $20, $4c, $4e, $47, $20, $3d, $3d, $20
		.byte $20, $20, $20, $20, $20, $20, $20, $20
		.byte $1b, $5b, $30, $6d, $1b, $5b, $31, $3b
		.byte $39, $48, $4c, $1b, $5b, $31, $3b, $39
		.byte $48, $4c, $1b, $5b, $31, $3b, $31, $30
		.byte $48, $4c, $1b, $5b, $31, $3b, $39, $48
		.byte $4c, $1b, $5b, $31, $3b, $31, $30, $48
		.byte $4c, $1b, $5b, $31, $3b, $31, $31, $48
		.byte $4c, $1b, $5b, $31, $3b, $39, $48, $4c
		.byte $1b, $5b, $31, $3b, $31, $30, $48, $4c
		.byte $1b, $5b, $31, $3b, $31, $31, $48, $4c
		.byte $1b, $5b, $31, $3b, $31, $32, $48, $4c
		.byte $1b, $5b, $31, $3b, $39, $48, $4c, $1b
		.byte $5b, $31, $3b, $31, $30, $48, $4c, $1b
		.byte $5b, $31, $3b, $31, $31, $48, $4c, $1b
		.byte $5b, $31, $3b, $31, $32, $48, $4c, $1b
		.byte $5b, $31, $3b, $39, $48, $4c, $1b, $5b
		.byte $31, $3b, $31, $30, $48, $4c, $1b, $5b
		.byte $31, $3b, $31, $31, $48, $4c, $1b, $5b
		.byte $31, $3b, $31, $32, $48, $4c, $1b, $5b
		.byte $31, $3b, $39, $48, $4c, $1b, $5b, $31
		.byte $3b, $31, $30, $48, $4c, $1b, $5b, $31
		.byte $3b, $31, $31, $48, $4c, $1b, $5b, $31
		.byte $3b, $31, $32, $48, $4c, $1b, $5b, $32
		.byte $3b, $39, $48, $4c, $1b, $5b, $31, $3b
		.byte $31, $30, $48, $4c, $1b, $5b, $31, $3b
		.byte $31, $31, $48, $4c, $1b, $5b, $31, $3b
		.byte $31, $32, $48, $4c, $1b, $5b, $32, $3b
		.byte $39, $48, $4c, $1b, $5b, $32, $3b, $31
		.byte $30, $48, $4c, $1b, $5b, $31, $3b, $31
		.byte $31, $48, $4c, $1b, $5b, $31, $3b, $31
		.byte $32, $48, $4c, $1b, $5b, $32, $3b, $39
		.byte $48, $4c, $1b, $5b, $32, $3b, $31, $30
		.byte $48, $4c, $1b, $5b, $32, $3b, $31, $31
		.byte $48, $4c, $1b, $5b, $31, $3b, $31, $32
		.byte $48, $4c, $1b, $5b, $32, $3b, $39, $48
		.byte $4c, $1b, $5b, $32, $3b, $31, $30, $48
		.byte $4c, $1b, $5b, $32, $3b, $31, $31, $48
		.byte $4c, $1b, $5b, $32, $3b, $31, $32, $48
		.byte $4c, $1b, $5b, $33, $3b, $39, $48, $4c
		.byte $1b, $5b, $32, $3b, $31, $30, $48, $4c
		.byte $1b, $5b, $32, $3b, $31, $31, $48, $4c
		.byte $1b, $5b, $32, $3b, $31, $32, $48, $4c
		.byte $1b, $5b, $33, $3b, $39, $48, $4c, $1b
		.byte $5b, $33, $3b, $31, $30, $48, $4c, $1b
		.byte $5b, $32, $3b, $31, $31, $48, $4c, $1b
		.byte $5b, $32, $3b, $31, $32, $48, $4c, $1b
		.byte $5b, $33, $3b, $39, $48, $4c, $1b, $5b
		.byte $33, $3b, $31, $30, $48, $4c, $1b, $5b
		.byte $33, $3b, $31, $31, $48, $4c, $1b, $5b
		.byte $32, $3b, $31, $32, $48, $4c, $1b, $5b
		.byte $34, $3b, $38, $48, $4c, $1b, $5b, $33
		.byte $3b, $39, $48, $4c, $1b, $5b, $33, $3b
		.byte $31, $30, $48, $4c, $1b, $5b, $33, $3b
		.byte $31, $31, $48, $4c, $1b, $5b, $33, $3b
		.byte $31, $32, $48, $4c, $1b, $5b, $34, $3b
		.byte $38, $48, $4c, $1b, $5b, $34, $3b, $39
		.byte $48, $4c, $1b, $5b, $33, $3b, $31, $30
		.byte $48, $4c, $1b, $5b, $33, $3b, $31, $31
		.byte $48, $4c, $1b, $5b, $33, $3b, $31, $32
		.byte $48, $4c, $1b, $5b, $34, $3b, $38, $48
		.byte $4c, $1b, $5b, $34, $3b, $39, $48, $4c
		.byte $1b, $5b, $34, $3b, $31, $30, $48, $4c
		.byte $1b, $5b, $33, $3b, $31, $31, $48, $4c
		.byte $1b, $5b, $33, $3b, $31, $32, $48, $4c
		.byte $1b, $5b, $34, $3b, $38, $48, $4c, $1b
		.byte $5b, $34, $3b, $39, $48, $4c, $1b, $5b
		.byte $34, $3b, $31, $30, $48, $4c, $1b, $5b
		.byte $34, $3b, $31, $31, $48, $4c, $1b, $5b
		.byte $33, $3b, $31, $32, $48, $4c, $1b, $5b
		.byte $35, $3b, $38, $48, $4c, $1b, $5b, $34
		.byte $3b, $39, $48, $4c, $1b, $5b, $34, $3b
		.byte $31, $30, $48, $4c, $1b, $5b, $34, $3b
		.byte $31, $31, $48, $4c, $1b, $5b, $35, $3b
		.byte $38, $48, $4c, $1b, $5b, $35, $3b, $39
		.byte $48, $4c, $1b, $5b, $34, $3b, $31, $30
		.byte $48, $4c, $1b, $5b, $34, $3b, $31, $31
		.byte $48, $4c, $1b, $5b, $35, $3b, $38, $48
		.byte $4c, $1b, $5b, $35, $3b, $39, $48, $4c
		.byte $1b, $5b, $35, $3b, $31, $30, $48, $4c
		.byte $1b, $5b, $34, $3b, $31, $31, $48, $4c
		.byte $1b, $5b, $35, $3b, $38, $48, $4c, $1b
		.byte $5b, $35, $3b, $39, $48, $4c, $1b, $5b
		.byte $35, $3b, $31, $30, $48, $4c, $1b, $5b
		.byte $35, $3b, $31, $31, $48, $4c, $1b, $5b
		.byte $36, $3b, $38, $48, $4c, $1b, $5b, $35
		.byte $3b, $39, $48, $4c, $1b, $5b, $35, $3b
		.byte $31, $30, $48, $4c, $1b, $5b, $35, $3b
		.byte $31, $31, $48, $4c, $1b, $5b, $36, $3b
		.byte $38, $48, $4c, $1b, $5b, $36, $3b, $39
		.byte $48, $4c, $1b, $5b, $35, $3b, $31, $30
		.byte $48, $4c, $1b, $5b, $35, $3b, $31, $31
		.byte $48, $4c, $1b, $5b, $36, $3b, $38, $48
		.byte $4c, $1b, $5b, $36, $3b, $39, $48, $4c
		.byte $1b, $5b, $36, $3b, $31, $30, $48, $4c
		.byte $1b, $5b, $35, $3b, $31, $31, $48, $4c
		.byte $1b, $5b, $37, $3b, $37, $48, $4c, $1b
		.byte $5b, $36, $3b, $38, $48, $4c, $1b, $5b
		.byte $36, $3b, $39, $48, $4c, $1b, $5b, $36
		.byte $3b, $31, $30, $48, $4c, $1b, $5b, $36
		.byte $3b, $31, $31, $48, $4c, $1b, $5b, $37
		.byte $3b, $37, $48, $4c, $1b, $5b, $37, $3b
		.byte $38, $48, $4c, $1b, $5b, $36, $3b, $39
		.byte $48, $4c, $1b, $5b, $36, $3b, $31, $30
		.byte $48, $4c, $1b, $5b, $36, $3b, $31, $31
		.byte $48, $4c, $1b, $5b, $37, $3b, $37, $48
		.byte $4c, $1b, $5b, $37, $3b, $38, $48, $4c
		.byte $1b, $5b, $37, $3b, $39, $48, $4c, $1b
		.byte $5b, $36, $3b, $31, $30, $48, $4c, $1b
		.byte $5b, $36, $3b, $31, $31, $48, $4c, $1b
		.byte $5b, $37, $3b, $37, $48, $4c, $1b, $5b
		.byte $37, $3b, $38, $48, $4c, $1b, $5b, $37
		.byte $3b, $39, $48, $4c, $1b, $5b, $37, $3b
		.byte $31, $30, $48, $4c, $1b, $5b, $36, $3b
		.byte $31, $31, $48, $4c, $1b, $5b, $38, $3b
		.byte $37, $48, $4c, $1b, $5b, $37, $3b, $38
		.byte $48, $4c, $1b, $5b, $37, $3b, $39, $48
		.byte $4c, $1b, $5b, $37, $3b, $31, $30, $48
		.byte $4c, $1b, $5b, $38, $3b, $37, $48, $4c
		.byte $1b, $5b, $38, $3b, $38, $48, $4c, $1b
		.byte $5b, $37, $3b, $39, $48, $4c, $1b, $5b
		.byte $37, $3b, $31, $30, $48, $4c, $1b, $5b
		.byte $38, $3b, $37, $48, $4c, $1b, $5b, $38
		.byte $3b, $38, $48, $4c, $1b, $5b, $38, $3b
		.byte $39, $48, $4c, $1b, $5b, $37, $3b, $31
		.byte $30, $48, $4c, $1b, $5b, $38, $3b, $37
		.byte $48, $4c, $1b, $5b, $38, $3b, $38, $48
		.byte $4c, $1b, $5b, $38, $3b, $39, $48, $4c
		.byte $1b, $5b, $38, $3b, $31, $30, $48, $4c
		.byte $1b, $5b, $39, $3b, $37, $48, $4c, $1b
		.byte $5b, $38, $3b, $38, $48, $4c, $1b, $5b
		.byte $38, $3b, $39, $48, $4c, $1b, $5b, $38
		.byte $3b, $31, $30, $48, $4c, $1b, $5b, $39
		.byte $3b, $37, $48, $4c, $1b, $5b, $39, $3b
		.byte $38, $48, $4c, $1b, $5b, $38, $3b, $39
		.byte $48, $4c, $1b, $5b, $38, $3b, $31, $30
		.byte $48, $4c, $1b, $5b, $39, $3b, $37, $48
		.byte $4c, $1b, $5b, $39, $3b, $38, $48, $4c
		.byte $1b, $5b, $39, $3b, $39, $48, $4c, $1b
		.byte $5b, $38, $3b, $31, $30, $48, $4c, $1b
		.byte $5b, $31, $30, $3b, $36, $48, $4c, $1b
		.byte $5b, $39, $3b, $37, $48, $4c, $1b, $5b
		.byte $39, $3b, $38, $48, $4c, $1b, $5b, $39
		.byte $3b, $39, $48, $4c, $1b, $5b, $39, $3b
		.byte $31, $30, $48, $4c, $1b, $5b, $36, $3b
		.byte $32, $32, $48, $4c, $1b, $5b, $31, $30
		.byte $3b, $36, $48, $4c, $1b, $5b, $31, $30
		.byte $3b, $37, $48, $4c, $1b, $5b, $39, $3b
		.byte $38, $48, $4c, $1b, $5b, $39, $3b, $39
		.byte $48, $4c, $1b, $5b, $39, $3b, $31, $30
		.byte $48, $4c, $1b, $5b, $36, $3b, $32, $32
		.byte $48, $4c, $1b, $5b, $36, $3b, $32, $33
		.byte $48, $55, $1b, $5b, $31, $30, $3b, $36
		.byte $48, $4c, $1b, $5b, $31, $30, $3b, $37
		.byte $48, $4c, $1b, $5b, $31, $30, $3b, $38
		.byte $48, $4c, $1b, $5b, $39, $3b, $39, $48
		.byte $4c, $1b, $5b, $39, $3b, $31, $30, $48
		.byte $4c, $1b, $5b, $36, $3b, $32, $32, $48
		.byte $4c, $1b, $5b, $36, $3b, $32, $33, $48
		.byte $55, $1b, $5b, $36, $3b, $32, $34, $48
		.byte $6e, $1b, $5b, $31, $30, $3b, $36, $48
		.byte $4c, $1b, $5b, $31, $30, $3b, $37, $48
		.byte $4c, $1b, $5b, $31, $30, $3b, $38, $48
		.byte $4c, $1b, $5b, $31, $30, $3b, $39, $48
		.byte $4c, $1b, $5b, $39, $3b, $31, $30, $48
		.byte $4c, $1b, $5b, $36, $3b, $32, $32, $48
		.byte $4c, $1b, $5b, $36, $3b, $32, $33, $48
		.byte $55, $1b, $5b, $36, $3b, $32, $34, $48
		.byte $6e, $1b, $5b, $36, $3b, $32, $35, $48
		.byte $69, $1b, $5b, $31, $31, $3b, $36, $48
		.byte $4c, $1b, $5b, $31, $30, $3b, $37, $48
		.byte $4c, $1b, $5b, $31, $30, $3b, $38, $48
		.byte $4c, $1b, $5b, $31, $30, $3b, $39, $48
		.byte $4c, $1b, $5b, $36, $3b, $32, $33, $48
		.byte $55, $1b, $5b, $36, $3b, $32, $34, $48
		.byte $6e, $1b, $5b, $36, $3b, $32, $35, $48
		.byte $69, $1b, $5b, $36, $3b, $32, $36, $48
		.byte $78, $1b, $5b, $31, $31, $3b, $36, $48
		.byte $4c, $1b, $5b, $31, $31, $3b, $37, $48
		.byte $4c, $1b, $5b, $31, $30, $3b, $38, $48
		.byte $4c, $1b, $5b, $31, $30, $3b, $39, $48
		.byte $4c, $1b, $5b, $36, $3b, $32, $34, $48
		.byte $6e, $1b, $5b, $36, $3b, $32, $35, $48
		.byte $69, $1b, $5b, $36, $3b, $32, $36, $48
		.byte $78, $1b, $5b, $31, $31, $3b, $36, $48
		.byte $4c, $1b, $5b, $31, $31, $3b, $37, $48
		.byte $4c, $1b, $5b, $31, $31, $3b, $38, $48
		.byte $4c, $1b, $5b, $31, $30, $3b, $39, $48
		.byte $4c, $1b, $5b, $36, $3b, $32, $35, $48
		.byte $69, $1b, $5b, $36, $3b, $32, $36, $48
		.byte $78, $1b, $5b, $36, $3b, $32, $38, $48
		.byte $43, $1b, $5b, $31, $31, $3b, $36, $48
		.byte $4c, $1b, $5b, $31, $31, $3b, $37, $48
		.byte $4c, $1b, $5b, $31, $31, $3b, $38, $48
		.byte $4c, $1b, $5b, $31, $31, $3b, $39, $48
		.byte $4c, $1b, $5b, $37, $3b, $32, $35, $48
		.byte $42, $1b, $5b, $36, $3b, $32, $36, $48
		.byte $78, $1b, $5b, $36, $3b, $32, $38, $48
		.byte $43, $1b, $5b, $36, $3b, $32, $39, $48
		.byte $6f, $1b, $5b, $31, $32, $3b, $36, $48
		.byte $4c, $1b, $5b, $31, $31, $3b, $37, $48
		.byte $4c, $1b, $5b, $31, $31, $3b, $38, $48
		.byte $4c, $1b, $5b, $31, $31, $3b, $39, $48
		.byte $4c, $1b, $5b, $37, $3b, $32, $35, $48
		.byte $42, $1b, $5b, $37, $3b, $32, $36, $48
		.byte $65, $1b, $5b, $36, $3b, $32, $38, $48
		.byte $43, $1b, $5b, $36, $3b, $32, $39, $48
		.byte $6f, $1b, $5b, $36, $3b, $33, $30, $48
		.byte $6e, $1b, $5b, $31, $32, $3b, $36, $48
		.byte $4c, $1b, $5b, $31, $32, $3b, $37, $48
		.byte $4c, $1b, $5b, $31, $31, $3b, $38, $48
		.byte $4c, $1b, $5b, $31, $31, $3b, $39, $48
		.byte $4c, $1b, $5b, $37, $3b, $32, $35, $48
		.byte $42, $1b, $5b, $37, $3b, $32, $36, $48
		.byte $65, $1b, $5b, $37, $3b, $32, $37, $48
		.byte $6e, $1b, $5b, $36, $3b, $32, $38, $48
		.byte $43, $1b, $5b, $36, $3b, $32, $39, $48
		.byte $6f, $1b, $5b, $36, $3b, $33, $30, $48
		.byte $6e, $1b, $5b, $36, $3b, $33, $31, $48
		.byte $73, $1b, $5b, $31, $32, $3b, $36, $48
		.byte $4c, $1b, $5b, $31, $32, $3b, $37, $48
		.byte $4c, $1b, $5b, $31, $32, $3b, $38, $48
		.byte $4c, $1b, $5b, $31, $31, $3b, $39, $48
		.byte $4c, $1b, $5b, $37, $3b, $32, $35, $48
		.byte $42, $1b, $5b, $37, $3b, $32, $36, $48
		.byte $65, $1b, $5b, $37, $3b, $32, $37, $48
		.byte $6e, $1b, $5b, $37, $3b, $32, $38, $48
		.byte $63, $1b, $5b, $36, $3b, $32, $39, $48
		.byte $6f, $1b, $5b, $36, $3b, $33, $30, $48
		.byte $6e, $1b, $5b, $36, $3b, $33, $31, $48
		.byte $73, $1b, $5b, $36, $3b, $33, $32, $48
		.byte $6f, $1b, $5b, $31, $33, $3b, $35, $48
		.byte $4c, $1b, $5b, $31, $32, $3b, $36, $48
		.byte $4c, $1b, $5b, $31, $32, $3b, $37, $48
		.byte $4c, $1b, $5b, $31, $32, $3b, $38, $48
		.byte $4c, $1b, $5b, $31, $32, $3b, $39, $48
		.byte $4c, $1b, $5b, $37, $3b, $32, $36, $48
		.byte $65, $1b, $5b, $37, $3b, $32, $37, $48
		.byte $6e, $1b, $5b, $37, $3b, $32, $38, $48
		.byte $63, $1b, $5b, $37, $3b, $32, $39, $48
		.byte $68, $1b, $5b, $36, $3b, $33, $30, $48
		.byte $6e, $1b, $5b, $36, $3b, $33, $31, $48
		.byte $73, $1b, $5b, $36, $3b, $33, $32, $48
		.byte $6f, $1b, $5b, $36, $3b, $33, $33, $48
		.byte $6c, $1b, $5b, $31, $33, $3b, $35, $48
		.byte $4c, $1b, $5b, $31, $33, $3b, $36, $48
		.byte $4c, $1b, $5b, $31, $32, $3b, $37, $48
		.byte $4c, $1b, $5b, $31, $32, $3b, $38, $48
		.byte $4c, $1b, $5b, $31, $32, $3b, $39, $48
		.byte $4c, $1b, $5b, $37, $3b, $32, $37, $48
		.byte $6e, $1b, $5b, $37, $3b, $32, $38, $48
		.byte $63, $1b, $5b, $37, $3b, $32, $39, $48
		.byte $68, $1b, $5b, $37, $3b, $33, $30, $48
		.byte $6d, $1b, $5b, $36, $3b, $33, $31, $48
		.byte $73, $1b, $5b, $36, $3b, $33, $32, $48
		.byte $6f, $1b, $5b, $36, $3b, $33, $33, $48
		.byte $6c, $1b, $5b, $36, $3b, $33, $34, $48
		.byte $65, $1b, $5b, $31, $33, $3b, $35, $48
		.byte $4c, $1b, $5b, $31, $33, $3b, $36, $48
		.byte $4c, $1b, $5b, $31, $33, $3b, $37, $48
		.byte $4c, $1b, $5b, $31, $32, $3b, $38, $48
		.byte $4c, $1b, $5b, $31, $32, $3b, $39, $48
		.byte $4c, $1b, $5b, $37, $3b, $32, $38, $48
		.byte $63, $1b, $5b, $37, $3b, $32, $39, $48
		.byte $68, $1b, $5b, $37, $3b, $33, $30, $48
		.byte $6d, $1b, $5b, $37, $3b, $33, $31, $48
		.byte $61, $1b, $5b, $36, $3b, $33, $32, $48
		.byte $6f, $1b, $5b, $36, $3b, $33, $33, $48
		.byte $6c, $1b, $5b, $36, $3b, $33, $34, $48
		.byte $65, $1b, $5b, $31, $33, $3b, $35, $48
		.byte $4c, $1b, $5b, $31, $33, $3b, $36, $48
		.byte $4c, $1b, $5b, $31, $33, $3b, $37, $48
		.byte $4c, $1b, $5b, $31, $33, $3b, $38, $48
		.byte $4c, $1b, $5b, $31, $32, $3b, $39, $48
		.byte $4c, $1b, $5b, $37, $3b, $32, $39, $48
		.byte $68, $1b, $5b, $37, $3b, $33, $30, $48
		.byte $6d, $1b, $5b, $37, $3b, $33, $31, $48
		.byte $61, $1b, $5b, $37, $3b, $33, $32, $48
		.byte $72, $1b, $5b, $36, $3b, $33, $33, $48
		.byte $6c, $1b, $5b, $36, $3b, $33, $34, $48
		.byte $65, $1b, $5b, $31, $34, $3b, $35, $48
		.byte $4c, $1b, $5b, $31, $33, $3b, $36, $48
		.byte $4c, $1b, $5b, $31, $33, $3b, $37, $48
		.byte $4c, $1b, $5b, $31, $33, $3b, $38, $48
		.byte $4c, $1b, $5b, $31, $33, $3b, $39, $48
		.byte $4c, $1b, $5b, $38, $3b, $32, $39, $48
		.byte $56, $1b, $5b, $37, $3b, $33, $30, $48
		.byte $6d, $1b, $5b, $37, $3b, $33, $31, $48
		.byte $61, $1b, $5b, $37, $3b, $33, $32, $48
		.byte $72, $1b, $5b, $37, $3b, $33, $33, $48
		.byte $6b, $1b, $5b, $36, $3b, $33, $34, $48
		.byte $65, $1b, $5b, $31, $34, $3b, $35, $48
		.byte $4c, $1b, $5b, $31, $34, $3b, $36, $48
		.byte $4c, $1b, $5b, $31, $33, $3b, $37, $48
		.byte $4c, $1b, $5b, $31, $33, $3b, $38, $48
		.byte $4c, $1b, $5b, $31, $33, $3b, $39, $48
		.byte $4c, $1b, $5b, $31, $33, $3b, $31, $30
		.byte $48, $4c, $1b, $5b, $38, $3b, $32, $39
		.byte $48, $56, $1b, $5b, $38, $3b, $33, $30
		.byte $48, $31, $1b, $5b, $37, $3b, $33, $31
		.byte $48, $61, $1b, $5b, $37, $3b, $33, $32
		.byte $48, $72, $1b, $5b, $37, $3b, $33, $33
		.byte $48, $6b, $1b, $5b, $31, $34, $3b, $35
		.byte $48, $4c, $1b, $5b, $31, $34, $3b, $36
		.byte $48, $4c, $1b, $5b, $31, $34, $3b, $37
		.byte $48, $4c, $1b, $5b, $31, $33, $3b, $38
		.byte $48, $4c, $1b, $5b, $31, $33, $3b, $39
		.byte $48, $4c, $1b, $5b, $31, $33, $3b, $31
		.byte $30, $48, $4c, $1b, $5b, $31, $33, $3b
		.byte $31, $31, $48, $4c, $1b, $5b, $38, $3b
		.byte $32, $39, $48, $56, $1b, $5b, $38, $3b
		.byte $33, $30, $48, $31, $1b, $5b, $38, $3b
		.byte $33, $31, $48, $2e, $1b, $5b, $37, $3b
		.byte $33, $32, $48, $72, $1b, $5b, $37, $3b
		.byte $33, $33, $48, $6b, $1b, $5b, $31, $34
		.byte $3b, $35, $48, $4c, $1b, $5b, $31, $34
		.byte $3b, $36, $48, $4c, $1b, $5b, $31, $34
		.byte $3b, $37, $48, $4c, $1b, $5b, $31, $34
		.byte $3b, $38, $48, $4c, $1b, $5b, $31, $33
		.byte $3b, $39, $48, $4c, $1b, $5b, $31, $33
		.byte $3b, $31, $30, $48, $4c, $1b, $5b, $31
		.byte $33, $3b, $31, $31, $48, $4c, $1b, $5b
		.byte $31, $33, $3b, $31, $32, $48, $4c, $1b
		.byte $5b, $38, $3b, $32, $39, $48, $56, $1b
		.byte $5b, $38, $3b, $33, $30, $48, $31, $1b
		.byte $5b, $38, $3b, $33, $31, $48, $2e, $1b
		.byte $5b, $38, $3b, $33, $32, $48, $30, $1b
		.byte $5b, $37, $3b, $33, $33, $48, $6b, $1b
		.byte $5b, $31, $35, $3b, $35, $48, $4c, $1b
		.byte $5b, $31, $34, $3b, $36, $48, $4c, $1b
		.byte $5b, $31, $34, $3b, $37, $48, $4c, $1b
		.byte $5b, $31, $34, $3b, $38, $48, $4c, $1b
		.byte $5b, $31, $34, $3b, $39, $48, $4c, $1b
		.byte $5b, $31, $33, $3b, $31, $30, $48, $4c
		.byte $1b, $5b, $31, $33, $3b, $31, $31, $48
		.byte $4c, $1b, $5b, $31, $33, $3b, $31, $32
		.byte $48, $4c, $1b, $5b, $31, $33, $3b, $31
		.byte $33, $48, $4c, $1b, $5b, $38, $3b, $33
		.byte $30, $48, $31, $1b, $5b, $38, $3b, $33
		.byte $31, $48, $2e, $1b, $5b, $38, $3b, $33
		.byte $32, $48, $30, $1b, $5b, $31, $35, $3b
		.byte $35, $48, $4c, $1b, $5b, $31, $35, $3b
		.byte $36, $48, $4c, $1b, $5b, $31, $34, $3b
		.byte $37, $48, $4c, $1b, $5b, $31, $34, $3b
		.byte $38, $48, $4c, $1b, $5b, $31, $34, $3b
		.byte $39, $48, $4c, $1b, $5b, $31, $34, $3b
		.byte $31, $30, $48, $4c, $1b, $5b, $31, $33
		.byte $3b, $31, $31, $48, $4c, $1b, $5b, $31
		.byte $33, $3b, $31, $32, $48, $4c, $1b, $5b
		.byte $31, $33, $3b, $31, $33, $48, $4c, $1b
		.byte $5b, $31, $33, $3b, $31, $34, $48, $4c
		.byte $1b, $5b, $38, $3b, $33, $31, $48, $2e
		.byte $1b, $5b, $38, $3b, $33, $32, $48, $30
		.byte $1b, $5b, $31, $35, $3b, $35, $48, $4c
		.byte $1b, $5b, $31, $35, $3b, $36, $48, $4c
		.byte $1b, $5b, $31, $35, $3b, $37, $48, $4c
		.byte $1b, $5b, $31, $34, $3b, $38, $48, $4c
		.byte $1b, $5b, $31, $34, $3b, $39, $48, $4c
		.byte $1b, $5b, $31, $34, $3b, $31, $30, $48
		.byte $4c, $1b, $5b, $31, $34, $3b, $31, $31
		.byte $48, $4c, $1b, $5b, $31, $33, $3b, $31
		.byte $32, $48, $4c, $1b, $5b, $31, $33, $3b
		.byte $31, $33, $48, $4c, $1b, $5b, $31, $33
		.byte $3b, $31, $34, $48, $4c, $1b, $5b, $31
		.byte $33, $3b, $31, $35, $48, $4c, $1b, $5b
		.byte $38, $3b, $33, $32, $48, $30, $1b, $5b
		.byte $31, $35, $3b, $35, $48, $4c, $1b, $5b
		.byte $31, $35, $3b, $36, $48, $4c, $1b, $5b
		.byte $31, $35, $3b, $37, $48, $4c, $1b, $5b
		.byte $31, $35, $3b, $38, $48, $4c, $1b, $5b
		.byte $31, $34, $3b, $39, $48, $4c, $1b, $5b
		.byte $31, $34, $3b, $31, $30, $48, $4c, $1b
		.byte $5b, $31, $34, $3b, $31, $31, $48, $4c
		.byte $1b, $5b, $31, $34, $3b, $31, $32, $48
		.byte $4c, $1b, $5b, $31, $33, $3b, $31, $33
		.byte $48, $4c, $1b, $5b, $31, $33, $3b, $31
		.byte $34, $48, $4c, $1b, $5b, $31, $33, $3b
		.byte $31, $35, $48, $4c, $1b, $5b, $31, $33
		.byte $3b, $31, $36, $48, $4c, $1b, $5b, $31
		.byte $35, $3b, $36, $48, $4c, $1b, $5b, $31
		.byte $35, $3b, $37, $48, $4c, $1b, $5b, $31
		.byte $35, $3b, $38, $48, $4c, $1b, $5b, $31
		.byte $35, $3b, $39, $48, $4c, $1b, $5b, $31
		.byte $34, $3b, $31, $30, $48, $4c, $1b, $5b
		.byte $31, $34, $3b, $31, $31, $48, $4c, $1b
		.byte $5b, $31, $34, $3b, $31, $32, $48, $4c
		.byte $1b, $5b, $31, $34, $3b, $31, $33, $48
		.byte $4c, $1b, $5b, $31, $33, $3b, $31, $34
		.byte $48, $4c, $1b, $5b, $31, $33, $3b, $31
		.byte $35, $48, $4c, $1b, $5b, $31, $33, $3b
		.byte $31, $36, $48, $4c, $1b, $5b, $31, $33
		.byte $3b, $31, $37, $48, $4c, $1b, $5b, $31
		.byte $35, $3b, $37, $48, $4c, $1b, $5b, $31
		.byte $35, $3b, $38, $48, $4c, $1b, $5b, $31
		.byte $35, $3b, $39, $48, $4c, $1b, $5b, $31
		.byte $35, $3b, $31, $30, $48, $4c, $1b, $5b
		.byte $31, $34, $3b, $31, $31, $48, $4c, $1b
		.byte $5b, $31, $34, $3b, $31, $32, $48, $4c
		.byte $1b, $5b, $31, $34, $3b, $31, $33, $48
		.byte $4c, $1b, $5b, $31, $34, $3b, $31, $34
		.byte $48, $4c, $1b, $5b, $31, $33, $3b, $31
		.byte $35, $48, $4c, $1b, $5b, $31, $33, $3b
		.byte $31, $36, $48, $4c, $1b, $5b, $31, $33
		.byte $3b, $31, $37, $48, $4c, $1b, $5b, $31
		.byte $33, $3b, $31, $38, $48, $4c, $1b, $5b
		.byte $31, $35, $3b, $38, $48, $4c, $1b, $5b
		.byte $31, $35, $3b, $39, $48, $4c, $1b, $5b
		.byte $31, $35, $3b, $31, $30, $48, $4c, $1b
		.byte $5b, $31, $35, $3b, $31, $31, $48, $4c
		.byte $1b, $5b, $31, $34, $3b, $31, $32, $48
		.byte $4c, $1b, $5b, $31, $34, $3b, $31, $33
		.byte $48, $4c, $1b, $5b, $31, $34, $3b, $31
		.byte $34, $48, $4c, $1b, $5b, $31, $34, $3b
		.byte $31, $35, $48, $4c, $1b, $5b, $31, $33
		.byte $3b, $31, $36, $48, $4c, $1b, $5b, $31
		.byte $33, $3b, $31, $37, $48, $4c, $1b, $5b
		.byte $31, $33, $3b, $31, $38, $48, $4c, $1b
		.byte $5b, $31, $33, $3b, $31, $39, $48, $4c
		.byte $1b, $5b, $31, $35, $3b, $39, $48, $4c
		.byte $1b, $5b, $31, $35, $3b, $31, $30, $48
		.byte $4c, $1b, $5b, $31, $35, $3b, $31, $31
		.byte $48, $4c, $1b, $5b, $31, $35, $3b, $31
		.byte $32, $48, $4c, $1b, $5b, $31, $34, $3b
		.byte $31, $33, $48, $4c, $1b, $5b, $31, $34
		.byte $3b, $31, $34, $48, $4c, $1b, $5b, $31
		.byte $34, $3b, $31, $35, $48, $4c, $1b, $5b
		.byte $31, $34, $3b, $31, $36, $48, $4c, $1b
		.byte $5b, $31, $33, $3b, $31, $37, $48, $4c
		.byte $1b, $5b, $31, $33, $3b, $31, $38, $48
		.byte $4c, $1b, $5b, $31, $33, $3b, $31, $39
		.byte $48, $4c, $1b, $5b, $31, $35, $3b, $31
		.byte $30, $48, $4c, $1b, $5b, $31, $35, $3b
		.byte $31, $31, $48, $4c, $1b, $5b, $31, $35
		.byte $3b, $31, $32, $48, $4c, $1b, $5b, $31
		.byte $35, $3b, $31, $33, $48, $4c, $1b, $5b
		.byte $31, $34, $3b, $31, $34, $48, $4c, $1b
		.byte $5b, $31, $34, $3b, $31, $35, $48, $4c
		.byte $1b, $5b, $31, $34, $3b, $31, $36, $48
		.byte $4c, $1b, $5b, $31, $34, $3b, $31, $37
		.byte $48, $4c, $1b, $5b, $31, $33, $3b, $31
		.byte $38, $48, $4c, $1b, $5b, $31, $33, $3b
		.byte $31, $39, $48, $4c, $1b, $5b, $31, $35
		.byte $3b, $31, $31, $48, $4c, $1b, $5b, $31
		.byte $35, $3b, $31, $32, $48, $4c, $1b, $5b
		.byte $31, $35, $3b, $31, $33, $48, $4c, $1b
		.byte $5b, $31, $35, $3b, $31, $34, $48, $4c
		.byte $1b, $5b, $31, $34, $3b, $31, $35, $48
		.byte $4c, $1b, $5b, $31, $34, $3b, $31, $36
		.byte $48, $4c, $1b, $5b, $31, $34, $3b, $31
		.byte $37, $48, $4c, $1b, $5b, $31, $34, $3b
		.byte $31, $38, $48, $4c, $1b, $5b, $31, $33
		.byte $3b, $31, $39, $48, $4c, $1b, $5b, $31
		.byte $35, $3b, $31, $32, $48, $4c, $1b, $5b
		.byte $31, $35, $3b, $31, $33, $48, $4c, $1b
		.byte $5b, $31, $35, $3b, $31, $34, $48, $4c
		.byte $1b, $5b, $31, $35, $3b, $31, $35, $48
		.byte $4c, $1b, $5b, $31, $34, $3b, $31, $36
		.byte $48, $4c, $1b, $5b, $31, $34, $3b, $31
		.byte $37, $48, $4c, $1b, $5b, $31, $34, $3b
		.byte $31, $38, $48, $4c, $1b, $5b, $31, $34
		.byte $3b, $31, $39, $48, $4c, $1b, $5b, $31
		.byte $35, $3b, $31, $33, $48, $4c, $1b, $5b
		.byte $31, $35, $3b, $31, $34, $48, $4c, $1b
		.byte $5b, $31, $35, $3b, $31, $35, $48, $4c
		.byte $1b, $5b, $31, $35, $3b, $31, $36, $48
		.byte $4c, $1b, $5b, $31, $34, $3b, $31, $37
		.byte $48, $4c, $1b, $5b, $31, $34, $3b, $31
		.byte $38, $48, $4c, $1b, $5b, $31, $34, $3b
		.byte $31, $39, $48, $4c, $1b, $5b, $31, $35
		.byte $3b, $31, $34, $48, $4c, $1b, $5b, $31
		.byte $35, $3b, $31, $35, $48, $4c, $1b, $5b
		.byte $31, $35, $3b, $31, $36, $48, $4c, $1b
		.byte $5b, $31, $35, $3b, $31, $37, $48, $4c
		.byte $1b, $5b, $31, $34, $3b, $31, $38, $48
		.byte $4c, $1b, $5b, $31, $34, $3b, $31, $39
		.byte $48, $4c, $1b, $5b, $31, $35, $3b, $31
		.byte $35, $48, $4c, $1b, $5b, $31, $35, $3b
		.byte $31, $36, $48, $4c, $1b, $5b, $31, $35
		.byte $3b, $31, $37, $48, $4c, $1b, $5b, $31
		.byte $35, $3b, $31, $38, $48, $4c, $1b, $5b
		.byte $31, $34, $3b, $31, $39, $48, $4c, $1b
		.byte $5b, $31, $37, $3b, $31, $31, $48, $28
		.byte $1b, $5b, $31, $35, $3b, $31, $36, $48
		.byte $4c, $1b, $5b, $31, $35, $3b, $31, $37
		.byte $48, $4c, $1b, $5b, $31, $35, $3b, $31
		.byte $38, $48, $4c, $1b, $5b, $31, $35, $3b
		.byte $31, $39, $48, $4c, $1b, $5b, $31, $37
		.byte $3b, $31, $31, $48, $28, $1b, $5b, $31
		.byte $37, $3b, $31, $32, $48, $43, $1b, $5b
		.byte $31, $35, $3b, $31, $37, $48, $4c, $1b
		.byte $5b, $31, $35, $3b, $31, $38, $48, $4c
		.byte $1b, $5b, $31, $35, $3b, $31, $39, $48
		.byte $4c, $1b, $5b, $31, $37, $3b, $31, $31
		.byte $48, $28, $1b, $5b, $31, $37, $3b, $31
		.byte $32, $48, $43, $1b, $5b, $31, $37, $3b
		.byte $31, $33, $48, $29, $1b, $5b, $31, $35
		.byte $3b, $31, $38, $48, $4c, $1b, $5b, $31
		.byte $35, $3b, $31, $39, $48, $4c, $1b, $5b
		.byte $31, $37, $3b, $31, $31, $48, $28, $1b
		.byte $5b, $31, $37, $3b, $31, $32, $48, $43
		.byte $1b, $5b, $31, $37, $3b, $31, $33, $48
		.byte $29, $1b, $5b, $31, $35, $3b, $31, $39
		.byte $48, $4c, $1b, $5b, $31, $37, $3b, $31
		.byte $32, $48, $43, $1b, $5b, $31, $37, $3b
		.byte $31, $33, $48, $29, $1b, $5b, $31, $37
		.byte $3b, $31, $35, $48, $32, $1b, $5b, $31
		.byte $37, $3b, $31, $33, $48, $29, $1b, $5b
		.byte $31, $37, $3b, $31, $35, $48, $32, $1b
		.byte $5b, $31, $37, $3b, $31, $36, $48, $30
		.byte $1b, $5b, $31, $37, $3b, $31, $35, $48
		.byte $32, $1b, $5b, $31, $37, $3b, $31, $36
		.byte $48, $30, $1b, $5b, $31, $37, $3b, $31
		.byte $37, $48, $30, $1b, $5b, $31, $37, $3b
		.byte $31, $35, $48, $32, $1b, $5b, $31, $37
		.byte $3b, $31, $36, $48, $30, $1b, $5b, $31
		.byte $37, $3b, $31, $37, $48, $30, $1b, $5b
		.byte $31, $37, $3b, $31, $38, $48, $30, $1b
		.byte $5b, $31, $37, $3b, $31, $36, $48, $30
		.byte $1b, $5b, $31, $37, $3b, $31, $37, $48
		.byte $30, $1b, $5b, $31, $37, $3b, $31, $38
		.byte $48, $30, $1b, $5b, $31, $37, $3b, $31
		.byte $37, $48, $30, $1b, $5b, $31, $37, $3b
		.byte $31, $38, $48, $30, $1b, $5b, $31, $37
		.byte $3b, $32, $30, $48, $62, $1b, $5b, $31
		.byte $37, $3b, $31, $38, $48, $30, $1b, $5b
		.byte $31, $37, $3b, $32, $30, $48, $62, $1b
		.byte $5b, $31, $37, $3b, $32, $31, $48, $79
		.byte $1b, $5b, $31, $37, $3b, $32, $30, $48
		.byte $62, $1b, $5b, $31, $37, $3b, $32, $31
		.byte $48, $79, $1b, $5b, $31, $37, $3b, $32
		.byte $30, $48, $62, $1b, $5b, $31, $37, $3b
		.byte $32, $31, $48, $79, $1b, $5b, $31, $37
		.byte $3b, $32, $33, $48, $50, $1b, $5b, $31
		.byte $37, $3b, $32, $31, $48, $79, $1b, $5b
		.byte $31, $37, $3b, $32, $33, $48, $50, $1b
		.byte $5b, $31, $37, $3b, $32, $34, $48, $6f
		.byte $1b, $5b, $31, $37, $3b, $32, $33, $48
		.byte $50, $1b, $5b, $31, $37, $3b, $32, $34
		.byte $48, $6f, $1b, $5b, $31, $37, $3b, $32
		.byte $35, $48, $6c, $1b, $5b, $31, $37, $3b
		.byte $32, $33, $48, $50, $1b, $5b, $31, $37
		.byte $3b, $32, $34, $48, $6f, $1b, $5b, $31
		.byte $37, $3b, $32, $35, $48, $6c, $1b, $5b
		.byte $31, $37, $3b, $32, $36, $48, $64, $1b
		.byte $5b, $31, $37, $3b, $32, $34, $48, $6f
		.byte $1b, $5b, $31, $37, $3b, $32, $35, $48
		.byte $6c, $1b, $5b, $31, $37, $3b, $32, $36
		.byte $48, $64, $1b, $5b, $31, $37, $3b, $32
		.byte $37, $48, $69, $1b, $5b, $31, $37, $3b
		.byte $32, $35, $48, $6c, $1b, $5b, $31, $37
		.byte $3b, $32, $36, $48, $64, $1b, $5b, $31
		.byte $37, $3b, $32, $37, $48, $69, $1b, $5b
		.byte $31, $37, $3b, $32, $36, $48, $64, $1b
		.byte $5b, $31, $37, $3b, $32, $37, $48, $69
		.byte $1b, $5b, $31, $37, $3b, $32, $37, $48
		.byte $69, $1b, $5b, $32, $31, $3b, $31, $48
		.byte 0

end_of_code:
