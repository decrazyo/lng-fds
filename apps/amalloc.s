		;; for emacs: -*- MODE: asm; tab-width: 4; -*-

		;; simple testprogramm
		;; for libc_malloc/free/remalloc

#include <cstyle.h>
#include <system.h>

		;; code slightly differs from other source files
		;; since this code will be linked against libstd

		.byte >LNG_MAGIC,   <LNG_MAGIC
		.byte >LNG_VERSION,	<LNG_VERSION

		.word 0	; filled by lld after linking against libstd

		;; you MUST allocate at least 4 zeropage bytes, if
		;; you want to use libc-malloc!

		;; (this code make use of the cstyle.h macros)

		set_zeropage_size(4)
		print_string("Welcome to tmalloc\n")

main_loop:
		jsr  print_prompt

		lea_ay(line_buffer)		; load effective address into A/Y
		sta  userzp
		sty  userzp+1
		
		ldy  #10
		jsr  sreadline			; read line into line_buffer (of 10 chars size)
		bcc  +

		exit(0)					; on error exit with no error (assume EOF)

	+	lea_ay(line_buffer)		; load effective address into A/Y
		sta  userzp
		sty  userzp+1
		
		ldy  #0
		jsr  eat_white_spaces
		beq  main_loop			; (empty line)
		
		cmp  #"m"				; "m #size" -> do a malloc
		beq	 do_malloc

		;; cmp  #"r"
		;; beq  do_remalloc

		cmp  #"f"				; "f #address" -> do a free
		beq  do_free
		print_string("unknown command\n")
		jmp  main_loop

		;; malloc #size

do_malloc:
		iny						; (assume a single space)
		jsr  read_hex16			; read size from line_buffer

		;; call malloc
		lda	 userzp+2
		ldy  userzp+3
		jsr  libc_malloc
		sta  userzp+2
		sty  userzp+3

		;; print returned pointer to stdout
		print_string("malloc: ")
		lda  userzp+3
		jsr  print_hex8
		lda  userzp+2
		jsr  print_hex8

		lda  #10
		jsr  putc
		jmp  main_loop

		;; free #address

do_free:
		iny						; (assume s single space)
		jsr  read_hex16			; read address from line_buffer
		
		;; call free
		lda  userzp+2
		ldy  userzp+3
		jsr  libc_free
		
		print_string("free.\n")
		jmp  main_loop

		;; set pointer to first non space char in line_buffer
		;; (zero flag set, if end of line is reached)
eat_white_spaces:
		lda  (userzp),y
		beq  +
		cmp  #" "
		bne  +
		iny
		bne  eat_white_spaces
	+	rts

		;; get 16 bit hex number from line_buffer
read_hex16:
		ldx  #0
		stx  userzp+2
		stx  userzp+3
		jsr  eat_white_spaces	; (eat trailing spaces, if there are)
		beq  +
		
		;; input loop
	-	jsr  conv_hexdigit
		bcs  +
		inx
		pha
		lda  userzp+3
		asl  userzp+2
		rol  a
		asl  userzp+2
		rol  a
		asl  userzp+2
		rol  a
		asl  userzp+2
		rol  a
		sta  userzp+3
		pla
		ora  userzp+2
		sta  userzp+2
		iny
		beq  +
		lda  userzp+3
		and  #$f0
		bne  +
		lda  (userzp),y
		bne  -
		
	+	rts								

conv_hexdigit:
		sec
		and  #$7f
		sbc  #"0"
		bcc  ++
		cmp  #10
		bcc  +
		sbc  #"a"-"0"-10
		cmp  #10
		bcc  ++
		cmp  #16
		bcs  ++
		
	+	rts
		
	+	sec
		rts

print_prompt:	
		lda  #">"
		jsr  putc
		lda  #" "
		jmp  putc

putc:
		sec
		ldx  #stdout
		jsr  fputc
		nop
		rts

		RELO_JMP(+)
		
line_buffer:	.buf 256

	+							; end
