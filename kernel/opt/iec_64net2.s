
		;; 64net/2 bus routines
		;; (parallel link, only filesystem stuff here)
		;; lowlevel stuff should be exported to allow use
		;; other 64net/2 extensions (sockets, ram expansion)
		;; by Maciej 'YTM/Elysium' Witkowiak, helped by
		;; 64net/2 by Paul Gardner-Stephen
		;; fs_iec.s code by Daniel Dallmann

		;; 4,8-9.06.2000

;**************************************************************************
;		low level I/O subroutines
;**************************************************************************

; define this if you want to have sane IEC stuff
#define SANE_IEC

#ifdef SANE_IEC
setpa2low:	lda CIA2_PRA
		and #%11111011
		bne +			; will never be =0
setpa2high:	lda CIA2_PRA
		ora #%00000100
	+	sta CIA2_PRA
		rts
#endif

sendbyte_64net:	php
		pha
		sei
		lda #$ff
		sta CIA2_DDRB
		pla
		sta CIA2_PRB
		lda CIA2_ICR
#ifdef SANE_IEC
		jsr setpa2low
#else
		lda #$93
		sta CIA2_PRA
#endif
		lda #%00010000
	-	bit CIA2_ICR
		beq -
#ifdef SANE_IEC
		jsr setpa2high
#else
		lda #$97
		sta CIA2_PRA
#endif
		lda #0
		sta CIA2_DDRB
		lda #%00010000
	-	bit CIA2_ICR
		beq -
		plp
		rts

getbyte_64net:	php
		sei
		lda CIA2_ICR
#ifdef SANE_IEC
		jsr setpa2low
#else
		lda #$93
		sta CIA2_PRA
#endif
		lda #0
		sta CIA2_DDRB		; could be omitted

		lda #%00010000
	-	bit CIA2_ICR
		beq -
		lda CIA2_PRB
		pha
#ifdef SANE_IEC
		jsr setpa2high
#else
		lda #$97
		sta CIA2_PRA
#endif
		lda #%00010000
	-	bit CIA2_ICR
		beq -
		pla
		plp
		rts

;**************************************************************************
;		indirect I/O related subroutines
;**************************************************************************

send_talk_64net2:
		tay					;talk
		lda #$80
		sta ch_state
		lda #"R"
	-	jsr sendbyte_64net
		;; might be needed later
		lda #0
		sta status
		tya
		jmp sendbyte_64net

send_listen_64net2:	
		tay					;listen
		lda #$40
		sta ch_state
		lda #"W"
		bne -

get_byte_64net2:	
		lda #"H"				;acptr
		jsr sendbyte_64net
		jsr getbyte_64net
		sta status
		jsr getbyte_64net
		sta byte
		rts
		
send_byte_64net2:
		pha					;ciout
		lda #"G"
		jsr sendbyte_64net
		pla
		jmp sendbyte_64net

send_untalk_64net2:	
		lda #"J"				;untalk
		.byte $2c
send_unlisten_64net2:	
		lda #"I"				;unlisten
		jsr sendbyte_64net
		lda #0
		sta ch_state
		jsr getbyte_64net
		;sta status				; ignore status
		rts

sec_adr_after_talk_64net2:				;tksa
		tay
		lda #"D"
	-	jsr sendbyte_64net
		tya
		jmp sendbyte_64net

sec_adr_after_listen_64net2:				;second
		tay
		lda #"A"
		bne -

open_iec_file_64net2:
		lda #0
		sta status
		lda ch_device
		jsr send_listen_64net2
		lda ch_secadr
		ora #$f0
		jsr sec_adr_after_listen_64net2
		lda status
		bne ++					; will never happen
		tay
		sty byte_count
	-	cpy filename_length
		beq +
		lda filename,y
		jsr send_byte_64net2
		iny
		bne -

	+	jmp send_unlisten_64net2

close_iec_file_64net2:
		lda ch_device
		jsr send_listen_64net2
		lda ch_secadr
		and #$ef
		ora #$e0
		jsr sec_adr_after_listen_64net2
		jsr send_unlisten_64net2
		clc
	+	rts
