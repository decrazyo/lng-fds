
#include <config.h>
#include <system.h>
#include MACHINE_H
#include <zp.h>
#include <console.h>

		.global cons_home
		.global cons_clear
		.global cons_csr_show

#define ESC $1b


; TODO: add support for 2 consoles

; TODO: if we're only using 1 console then use all if VRAM and horizontal mirroring.
;       that would allow us to scroll the screen back by 30 line.


;; function: cons_clear
;; clear the screen
;; returns with PPU_ADDR pointing at the attribute table.
;; changes: A, X
cons_clear:
		; set VRAM address
		lda #$20
		sta PPU_ADDR
		lda #0
		sta PPU_ADDR

		; zero out VRAM.
		ldx #240
	-	sta PPU_DATA
		sta PPU_DATA
		sta PPU_DATA
		sta PPU_DATA
		dex
		bne -

		rts


;; function: cons_home
;; move cursor to the upper left corner of the screen.
;; changes: A, X, Y
;; > C = 0 : ok
;;       1 : error
cons_home:
		ldx #0
		jsr scroll_y_to_csr
		tay
;; function: cons_setpos
;; move cursor to an arbitrary position.
;; the caller must account for the current scrolling.
;; < X = cursor x position
;; < Y = cursor y position
;; > C = 0 : ok
;;       1 : error
;; changes: A
;; changes: tmpzp
cons_setpos:
		cpx #size_x
		bcs + ; branch if new cursor position is off the screen.
		stx csrx
		cpy #size_y
		bcs + ; branch if new cursor position is off the screen.
		sty csry
	+	rts


;; function: cons_csr_up
;; move cursor up 1 character.
;; > C = 0 : ok
;;       1 : error
;; changes: A, X
cons_csr_up:
		ldx csry
		beq + ; branch if cursor would be outside of VRAM.
		jsr scroll_y_to_csr
		cmp csry
		beq + ; branch if cursor would wrap around the screen.
		dex
		stx csry
		clc
		SKIP_BYTE
	+	sec
		rts


;; function: cons_csr_down
;; move cursor down 1 character.
;; > C = 0 : ok
;;       1 : error
;; changes: A, X
;; changes: tmpzp
cons_csr_down:
		ldx csry
		inx
		cpx #size_y
		beq + ; branch if cursor would be outside of VRAM.
		jsr scroll_y_to_csr
		sta tmpzp
		cpx tmpzp
		beq + ; branch if cursor would wrap around the screen.
		stx csry
		clc
		SKIP_BYTE
	+	sec
		rts


;; function: cons_csr_left
;; move cursor left 1 character.
;; > C = 0 : ok
;;       1 : error
;; changes: X
cons_csr_left:
		ldx csrx
		beq + ; branch if cursor would wrap around the screen.
		dex
		stx csrx
		clc
		SKIP_BYTE
	+	sec
		rts


;; function: cons_csr_right
;; move cursor right 1 character.
;; > C = 0 : ok
;;       1 : error
;; changes: X
cons_csr_right:
		ldx csrx
		inx
		cpx #size_x
		beq + ; branch if cursor would wrap around the screen.
		stx csrx
		clc
		SKIP_BYTE
	+	sec
		rts


; TODO: use a color-inverted version of the character on screen to represent the cursor.
;       that would require adding an inverted ASCII table to CRAM.
;       we should have plenty of space for that in CRAM.

;; function: cons_csr_show
;; replace the character on screen with the cursor.
;; changes: A, X
cons_csr_show:
		lda cflag
		bne + ; branch if cursor is already displayed.
		inc cflag
		; save the character at the cursor position.
		jsr csr_to_vram
		lda PPU_DATA
		sta buc
		; write the cursor character to screen.
		jsr csr_to_vram
		lda #"_"
		sta PPU_DATA
	+	rts


;; function: cons_csr_hide
;; replace the cursor with the character that was preciously on screen.
;; changes: A, X
cons_csr_hide:
		lda cflag
		beq + ; branch if cursor is already hidden.
		dec cflag
		; restore the character that was previously at the cursor position.
		jsr csr_to_vram
		lda buc
		sta PPU_DATA
	+	rts


;; function: cons_erase
;; erase the rest of the line, starting at (and including) the cursor.
;; > C = 0 ; always succeeds.
;; changes: A, X
cons_erase:
		jsr csr_to_vram
		ldx csrx
		lda #0
	-	sta PPU_DATA
		inx
		cpx #size_x
		bne -
		clc
		rts


;; function: cons_cr
;; return cursor to the beginning of the current line.
;; > C = 0 ; always succeeds.
;; changes: X
cons_cr:
		ldx #0
		stx csrx
		clc
		rts


;; function: cons_crlf
;; return cursor to the beginning of the line and move down 1 line.
;; > C = 0 ; always succeeds.
;; changes: A, X
cons_crlf:
		jsr cons_cr
		ldx csry
		inx
		cpx #size_y
		bne +
		ldx #0
	+	stx csry

		jsr scroll_y_to_csr
		sta tmpzp
		cpx tmpzp
		bne ++ ; branch if we don't need to scroll.

		; compute the new scroll position to display the next line.
		lda ppu_scroll_y
		clc
		adc #8 ; tile size in pixels.
		cmp #240 ; screen height in pixels. (30 tiles x 8 pixels per tile)
		bne + ; branch if we don't need to wrap the screen back to the top.
		lda #0
	+	sta ppu_scroll_y
		; erase the line if we had to scroll.
		jsr cons_erase
	+	clc
		rts


;; function: cons_tab
;; print 4 spaces.
;; > C = 0 ; always succeeds.
;; changes: A, X, Y
cons_tab:
		ldy #" "
		jsr cons_out_special
		jsr cons_out_special
		jsr cons_out_special
		jmp cons_out_special


;; function: cons_del
;; erase the character before the cursor.
;; > C = 0 ; always succeeds.
;; changes: A, X
cons_del:
		jsr cons_csr_left
		bcs +
		jsr csr_to_vram
		lda buc
		sta PPU_DATA
	+	clc
		rts


;; function: cons_esc_print
;; print an unsupported or incorrect escape sequence.
;; < Y = most recent character of the sequence.
;; > C = 1 ; always error
cons_esc_print:
		; save current character.
		tya
		pha

		ldx esc_flag
		beq +
		ldy #ESC
		jsr cons_out_special

		dec esc_flag
		beq +
		ldy #"["
		jsr cons_out_special

		dec esc_flag
		beq +
		ldy #esc_arg_1
		jsr cons_out_special

		dec esc_flag

		; restore current character.
		; this will be printed when we return to "cons_out".
	+	pla
		tay
		sec
		rts


; TODO: add support for this sequence.
;       <ESC>[#y;#xH   - cursor positioning (#y, #x default to 0)

;; function: cons_esc
;; handle escape sequences.
;; we are only handling the following subset of the ANSI escape sequences.
;;   <ESC>D         - cursor down one line
;;   <ESC>[2J       - clear screen
;;   <ESC>[K        - erase rest of line
;;   <ESC>[A        - cursor up one line
;;   <ESC>[B        - cursor down one line
;;   <ESC>[C        - cursor forward one char
;;   <ESC>[D        - cursor backward one char
;; < Y = character to handle.
cons_esc:
		lda esc_flag
		beq _cons_esc_state_0
		cmp #1
		beq _cons_esc_state_1
		cmp #2
		beq _cons_esc_state_2
_cons_esc_state_3:
		cpy #"J" ; <ESC>[#J
		bne + ; branch if sequence is unsupported.
		lda #"2"
		cmp esc_arg_1 ; <ESC>[2J
		bne + ; branch if sequence is unsupported.
		jsr cons_clear
		jmp _cons_esc_done ; sequence done
	+	jmp cons_esc_print
_cons_esc_state_2:
		cpy #"K" ; <ESC>[K
		bne +
		jsr cons_erase
		bcc _cons_esc_done ; sequence done
	+	cpy #"A" ; <ESC>[A
		bne +
		jsr cons_csr_up
		jmp _cons_esc_done ; sequence done
	+	cpy #"B" ; <ESC>[B
		bne +
		jsr cons_csr_down
		jmp _cons_esc_done ; sequence done
	+	cpy #"C" ; <ESC>[C
		bne +
		jsr cons_csr_right
		jmp _cons_esc_done ; sequence done
	+	cpy #"D" ; <ESC>[D
		bne +
		jsr cons_csr_left
		jmp _cons_esc_done ; sequence done
		; <ESC>[#
		cpy #"0"
		bcc + ; branch if char is less than ASCII 0.
		cpy #"9" + 1
		bcs + ; branch if char is greater than ASCII 9.
		sty esc_arg_1
		bcc _cons_esc_ok ; branch if sequence continues in state 3
	+	jmp cons_esc_print
_cons_esc_state_1:
		cpy #"D" ; <ESC>D
		bne +
		jsr cons_csr_down
		jmp _cons_esc_done ; sequence done
	+	cpy #"[" ; <ESC>[
		beq _cons_esc_ok ; branch if sequence continues in state 2
		jmp cons_esc_print
_cons_esc_state_0:
		cpy #ESC
		bne _cons_esc_err
		; sequence continues in state 1
_cons_esc_ok:
		inc esc_flag
		clc
		bcc _cons_esc_end
_cons_esc_err:
		sec
_cons_esc_done:
		lda #0
		sta esc_flag
_cons_esc_end:
		rts


;; function: cons_control
;; handle control characters [$00,$1f].
;; < Y = character to handle.
;; > C = 0 : ok
;;       1 : error
;; changes: A, X, (and sometimes Y)
cons_control:
		cpy #$1b
		beq cons_esc ; branch if this is an escape sequence.
		cpy #"\n" ; LF. move down one line. treated as a CR LF.
		beq cons_crlf
		cpy #"\r" ; CR. move to beginning of line.
		beq cons_cr
		cpy #"\t" ; TAB. advance cursor by 4 spaces.
		beq cons_tab
		cpy #$08 ; DEL. erase character before the cursor. (backspace)
		beq cons_del
		sec
		rts


;; function: cons_out
;; write a printable character to the screen.
;; handles non-printable control characters.
;; < A = character to print.
;; > C = 0 ; always succeeds.
;; changes: A, X, Y
cons_out:
		tay ; save the character for later.

		; disable rendering
		lda ppu_mask
		and #~PPU_MASK_b
		sta ppu_mask
		sta PPU_MASK

		jsr cons_csr_hide
		jsr cons_out_impl
		jsr cons_csr_show

		; PPU_SCROLL and PPU_CTRL needs to be reset after accessing PPU_DATA.
		lda ppu_scroll_x
		sta PPU_SCROLL
		lda ppu_scroll_y
		sta PPU_SCROLL
		lda ppu_ctrl
		sta PPU_CTRL

		; the FDS BIOS changes various registers to their default values during RESET.
		; we're changing this here to make kernel panics due to RESET print correctly.
		lda fds_ctrl
		and #~FDS_CTRL_M
		sta FDS_CTRL

		; enable rendering
		lda ppu_mask
		ora #PPU_MASK_b
		sta ppu_mask
		sta PPU_MASK
		rts


;; function: cons_out_impl
;; < Y = character to print.
;; > C = 0 ; always succeeds.
;; changes: A, X, (and sometimes Y)
cons_out_impl:
		lda esc_flag
		beq +
		jsr cons_esc
		bcc _cons_out_done

	+	cpy #$20
		bcs cons_out_special ; branch if we're handling a normal character
		jsr cons_control
		bcc _cons_out_done ; branch if the control character was successfully handled
		; print unhandled control characters
;; function: cons_out_special
;; < Y = character to print.
;; > C = 0 ; always succeeds.
cons_out_special:
		; write char to VRAM at cursor position.
		jsr csr_to_vram
		sty PPU_DATA

		; advance the cursor.
		jsr cons_csr_right
		bcc _cons_out_done ; branch if the cursor was moved successfully.
		jsr cons_crlf
_cons_out_done:
		rts


console_toggle:
		rts


;; function: scroll_y_to_csr
;; determine the highest cursor y position from the y scroll position.
;; > A = highest cursor y position
scroll_y_to_csr:
		; divide y scroll position by 8 pixel tile size to find the top of the screen.
		lda ppu_scroll_y
		lsr a
		lsr a
		lsr a
		rts


;; function: csr_to_vram
;; convert the current cursor position to an address in VRAM.
;; then write the address to the PPU.
;; < csrx
;; < csry
;; > A = address high byte
;; > X = address low byte
;; changes: A, X
;; changes: tmpzp(0,1)
csr_to_vram:
		lda #0
		sta tmpzp ; high byte
		lda csry
		sta tmpzp+1 ; low byte

		; multiply cursor y by 32 tiles per row.
		ldx #5
	-	asl tmpzp+1
		rol tmpzp
		dex
		bne -

		; add x offset
		lda csrx
		ora tmpzp+1
		sta tmpzp+1

		; add VRAM base address
		clc
		lda tmpzp
		adc #$20
		sta tmpzp

		lda tmpzp
		sta PPU_ADDR
		ldx tmpzp+1
		stx PPU_ADDR

		rts


;; variables moved to zeropage

;;; ZEROpage: ppu_mask 1
;;; ZEROpage: ppu_ctrl 1
;;; ZEROpage: ppu_scroll_y 1
;;; ZEROpage: ppu_scroll_x 1
;;; ZEROpage: csrx 1
;;; ZEROpage: csry 1
;;; ZEROpage: buc 1
;;; ZEROpage: cflag 1
;;; ZEROpage: esc_flag 1
;;; ZEROpage: esc_arg_1 1

; ppu_mask			.byte 0
; ppu_ctrl			.byte 0
; ppu_scroll_y		.byte 0
; ppu_scroll_x		.byte 0
; csrx				.byte 0 ; cursor x position
; csry				.byte 0 ; cursor y position
; buc				.byte 0 ; byte under cursor
; cflag				.byte 0 ; cursor visibility flag
; esc_flag			.byte 0 ; escape sequence processing state
; esc_arg_1			.byte 0 ; escape sequence argument 1
