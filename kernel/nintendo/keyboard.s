
.global keyb_scan

#define KEY_HOLD_DELAY 10

; table for $e? keys
locktab:
		.byte keyb_rshift|keyb_lshift, keyb_ex1, keyb_ex2, keyb_ex3

#define dunno $7f
#define clr_c           dunno
#define home_c          dunno
#define ctr_c           ~keyb_ctrl
#define grph_c          dunno ; TODO: make this alt
#define ins_c           dunno
#define lshift_c        ~keyb_lshift
#define rshift_c        ~keyb_rshift

; TODO: make this a locking key that swaps which pattern table is being used.
#define kana_c          dunno

#define stop_c          $03

; the DEL key function is actually that of backspace.
#define del_c           $08
#define return_c        $0a
#define esc_c           $1b
#define quote_c         $22

; this keyboard has no backslash key.
; historical reasons have given to using the yen key and symbol for the same meaning.
#define yen_c           $5c ; \

#define arrow_up_c      $81
#define arrow_down_c    $82
#define arrow_left_c    $83
#define arrow_right_c   $84

#define f1_c            $f1
#define f2_c            $f2
#define f3_c            $f3
#define f4_c            $f4
#define f5_c            $f5
#define f6_c            $f6
#define f7_c            $f7
#define f8_c            $f8

_keytab_normal:
		.byte  f8_c,return_c,"[","]",kana_c,rshift_c,yen_c,stop_c
		.byte  f7_c,"@",":",";","_","/","-","^"
		.byte  f6_c,"o","l","k",".",",","p","0"
		.byte  f5_c,"i","u","j","m","n","9","8"
		.byte  f4_c,"y","g","h","b","v","7","6"
		.byte  f3_c,"t","r","d","f","c","5","4"
		.byte  f2_c,"w","s","a","x","z","e","3"
		.byte  f1_c,esc_c,"q",ctr_c,lshift_c,grph_c,"1","2"
		.byte  home_c,arrow_up_c,arrow_right_c,arrow_left_c,arrow_down_c," ",del_c,ins_c

_keytab_shift:
		.byte  f8_c,return_c,"[","]",kana_c,rshift_c,yen_c,stop_c
		.byte  f7_c,"@","*","+","_","?","=","^"
		.byte  f6_c,"O","L","K",">","<","P","0"
		.byte  f5_c,"I","U","J","M","N",")","("
		.byte  f4_c,"Y","G","H","B","V","'","&"
		.byte  f3_c,"T","R","D","F","C","%","$"
		.byte  f2_c,"W","S","A","X","Z","E","#"
		.byte  f1_c,esc_c,"Q",ctr_c,lshift_c,grph_c,"!",quote_c
		.byte  clr_c,arrow_up_c,arrow_right_c,arrow_left_c,arrow_down_c," ",del_c,ins_c


key_data:		.byte $00
keytab_offset:	.byte $00
scan_delay:		.byte $00

key_hold:		.byte $00
key_delay:		.byte $00

; TODO: scan the joypads.

; TODO: check if a keyboard is actually connected.

; interrupt routine, that scans for keys
keyb_scan:
		; our current key table offset encodes where we are in the scanning process.
	+	ldx keytab_offset

		; the lowest 2 bits of the offset will tell if we need to read more data from the keyboard.
		txa
		and #%00000011
		beq read_keyboard ; branch if we are at the start of a new column.

		; we have data remaining from a previous iteration that needs to be processed.
		jmp find_key ; TODO: make this an unconditional branch.

; read 4 bits of data from the keyboard
read_keyboard:
		; check if we have finished scanning the whole keyboard matrix.
		cpx #71
		bmi get_nibble ; branch if we haven't finished.

		; reset the keyboard to the 0th row, 0th column.
		lda #$05
		sta JOYPAD1
		; reset keytab_offset to 0
		ldx #0
		stx keytab_offset
		rts

get_nibble:
		; select a column and row of the keyboard to read
	+	txa
		; use bit 2 of keytab_offset as the column select value.
		and #%00000100
		lsr a
		; always set the keyboard enable bit.
		ora #%00000100
		sta JOYPAD1

		; read 4 bits of key data from the keyboard.
		lda JOYPAD2
		; discard open bus junk.
		and #%00011110
		; invert the data so that.
		; 1 == key pressed
		; 0 == key released
		eor #%00011110
		; position key data in the low nibble for further processing.
	+	lsr a
		sta key_data

; increment keytab_offset after each checked bit.
; buffer a key if a bit is set.
find_key:
		lda _keytab_normal, x
		bpl check_key_pressed ; branch if we need to handle a normal key.
		cmp #(~keyb_lshift)-1
		bcc check_key_pressed ; branch if this is a cursor or console key
		; handle lshift, rshift, or ctrl
		lsr key_data
		bcc + ; branch if the key is not pressed.
		eor #$ff
		ora altflags
		SKIP_WORD
	+	and altflags
		sta altflags
		jmp find_next
check_key_pressed:
		lsr key_data
		bcs check_key_held ; branch if we found a pressed key.
		cmp key_hold
		bne find_next
		lda #0
		sta key_hold
find_next:
		inx
		txa
		and #%00000011
		bne find_key ; branch if there is still key data to process
		stx keytab_offset
		jmp read_keyboard ; TODO: make this a unconditional branch.

check_key_held:
		cmp key_hold
		bne buffer_key

		; the key was held down since the last time we scanned the keyboard.
		; introduce a short delay before considering it to actually be pressed.
		dec key_delay
		bne find_next

buffer_key:
		sta key_hold
		lda #KEY_HOLD_DELAY
		sta key_delay

		inx
		stx keytab_offset
		dex

; fall through to "_queue_key" in common kernel code.
