	;; for emacs: -*- MODE: asm; tab-width: 4; -*-
	;; for jed: -*- TAB: 4 -*-
	;; for vi:  ex: set shiftwidth=4:
	;; uname
	;; derived from Stefan Haubenthal "uname" for LUnix v0.1

#include <system.h>
#include <stdio.h>
#include <ipv4.h>

#define OPT_S %00000001			; Print the operating system name
#define OPT_N %00000010			; Print the machine's network node hostname
#define OPT_R %00000100			; Print the operating system release
#define OPT_V %00001000			; Print the operating system version
#define OPT_M %00010000			; Print the machine (hardware) type
#define OPT_P %00100000			; Print the processor (hardware) type

argc	equ	userzp
argv	equ	userzp				; .word
number	equ	userzp

		start_of_code equ $1000

		.org start_of_code

		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION,	<LNG_VERSION
		.byte >(end_of_code-start_of_code+255)
		.byte >start_of_code

		lda  argc
		cmp  #2
		bcs  +

		lda  #OPT_S
		sta  opt_map
		bne  main

	+	ldy  #0
		sty  argv

		;; skip command name
	-	iny
		lda  (argv),y
		bne  -
		iny

opt_loop:
		jsr  get_option
		bcs  main

		ldx  #0					; (no match)
		cmp  #$61				; "a"
		bne  +
		ldx  #OPT_S|OPT_N|OPT_R|OPT_V|OPT_M|OPT_P

	+	cmp  #$73				; "s"
		bne  +
		ldx  #OPT_S

	+	cmp  #$6e				; "n"
		bne  +
		ldx  #OPT_N

	+	cmp  #$72				; "r"
		bne  +
		ldx  #OPT_R

	+	cmp  #$76				; "v"
		bne  +
		ldx  #OPT_V

	+	cmp  #$6d				; "m"
		bne  +
		ldx  #OPT_M

	+	cmp  #$70				; "p"
		bne  +
		ldx  #OPT_P

	+	txa
		beq  HowTo

		ora  opt_map
		sta  opt_map
		jmp  opt_loop

main:	lsr  opt_map
		bcc  +
		;; print operating system name
		ldx  #stdout
		bit  txt_osname
		jsr  lkf_strout
		nop

	+	lsr  opt_map
		bcc  +
		jsr  print_hostname

	+	lsr  opt_map
		bcc  +
		;; print operating system release
		ldx  #stdout
		bit  txt_osrelease
		jsr  lkf_strout
		nop

	+	lsr  opt_map
		bcc  +
		;; print operating system version
		ldx  #stdout
		bit  txt_osversion
		jsr  lkf_strout
		nop

	+	lsr  opt_map
		bcc  +
		;; print machine (hardware) type
		jsr  print_hwtype

	+	lsr  opt_map
		bcc  +
		;; print processor (hardware) type
		jsr  print_cputype

	+	lda  #$0a
		jsr  putc
		lda  #0
		rts

HowTo:	ldx  #stdout
		bit  howto_txt
		jsr  lkf_strout
		nop
		lda  #1
		jmp  lkf_suicide

		;; read one option after the other (single chars)
get_option:
		lda  (argv),y
		beq  opt_end
		bit  opt_flag
		bmi  in_option
		cmp  #"-"
		bne  opt_error
		iny
		lda  opt_flag
		ora  #%10000000
		sta  opt_flag
		lda  (argv),y
in_option:
		iny
		pha
		lda  (argv),y
		bne  +
		iny
		lda  opt_flag
		and  #<~%10000000
		sta  opt_flag
	+	pla
		clc
		rts
opt_end:
		sec
		rts

opt_error:
		jmp  HowTo

; print decimal to stdout

print_decimal:
		ldx  #1
		ldy  #0

	-	cmp  dec_tab,x
		bcc  +
		sbc  dec_tab,x
		iny
		bne  -

	+	sta  number
		tya
		beq  +
		ora  #"0"
		jsr  putc
		ldy  #"0"
	+	lda  number
		dex
		bpl  -

		ora  #"0"
putc:	stx  [+]+1				; save .X register
		sec
		ldx  #stdout
		jsr  fputc
		nop
	+	ldx  #0					; restore .X
		rts

		;; print machine's network node hostname
		;; (try to print IP address)
		bit  ipv4_struct
print_hostname:
		;; search for packet interface
		lda  #0
		ldx  #<ipv4_struct
		ldy  print_hostname-1	; #>ipv4_struct
		jsr  lkf_get_moduleif
		bcs  name_unknown
		;; get info
		bit  tcpinfo_struct
		jsr  IPv4_tcpinfo
		lda  tcpinfo_struct
		jsr  print_decimal
		lda  #"."
		jsr  putc
		lda  tcpinfo_struct+1
		jsr  print_decimal
		lda  #"."
		jsr  putc
		lda  tcpinfo_struct+2
		jsr  print_decimal
		lda  #"."
		jsr  putc
		lda  tcpinfo_struct+3
		jsr  print_decimal
		lda  #" "
		jsr  putc
		jmp  IPv4_unlock

name_unknown:
		ldx  #stdout
		bit  txt_unknown
		jsr  lkf_strout
		nop
		rts

print_hwtype:
		ldx  #stdout
		lda  lk_archtype
		and  #larchf_type
		cmp  #larch_c64
		beq  hwc64
		cmp  #larch_c128
		bne  name_unknown

		;; hwc128
		bit  txt_machtype128
		jsr  lkf_strout
		nop
		jmp  +

hwc64:	bit  txt_machtype64
		jsr  lkf_strout
		nop
	+	lda  lk_archtype
		and  #larchf_pal
		bne  hwpal
		bit  txt_machtypentsc
		jsr  lkf_strout
		nop
		rts

hwpal:	bit  txt_machtypepal
		jsr  lkf_strout
		nop
		rts

print_cputype:
		lda  lk_archtype
		and  #larchf_scpu
		beq  +
		lda  #"s"
		jsr  putc
	+	ldx  #stdout
		lda  lk_archtype
		and  #larchf_8500
		bne  +
		bit  txt_cputype6510	; (c64)
		jsr  lkf_strout
		nop
		jmp  ++
	+	bit  txt_cputype8500	; (c128)
		jsr  lkf_strout
		nop
	+	lda  lk_archtype
		and  #larchf_reu
		beq  +
		lda  #"+"
		jsr  putc
		lda  #"r"
		jmp  putc

	+	rts

		RELO_END ; no more code to relocate

howto_txt:
		.text "usage:",$0a
		.text " uname [-snrvmpa]",$0a
		.text " print system information",$0a,0

txt_osname:
		.text "LNG ",0			; Little Unix, Next Generation
txt_unknown:
		.text "unknown ",0
txt_osrelease:
		.text "$"
		.digit (LNG_VERSION>4)&15
		.digit LNG_VERSION&15
		.text " ",0

txt_osversion:
		.text "$"
		.digit LNG_VERSION>12
		.digit (LNG_VERSION>8)&15
		.text " ",0

txt_machtype64:
		.text "C64",0
txt_machtype128:
		.text "C128",0
txt_machtypepal:
		.text "pal ",0
txt_machtypentsc:
		.text "ntsc ",0

txt_cputype6510:
		.text "6510",0
txt_cputype8500:
		.text "8500",0
opt_flag:
		.byte %00000000
opt_map:
		.byte %00000000

dec_tab:
		.byte 10,100

ipv4_struct:
		IPv4_struct9			; defined in ipv4.h

tcpinfo_struct:
		.buf IPV4_TCPINFOSIZE

end_of_code:

