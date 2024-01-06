
;**************************************************************************
;		indirect I/O related subroutines
;**************************************************************************

send_talk_iec:
		ora  #$40
		.byte $2c
		
send_listen_iec:
		ora  #$20
		sta  byte
		asl  a
		ora  ch_state			; remember state of bus
		sta  ch_state
		jsr  attention
		lda  #0
		sta  EOI
		sta  buffer_status

raw_send_byte:
		sei
		jsr  DATA_lo
		jsr  read_port
		bcs  dev_not_present
		jsr  CLOCK_lo
		bit  EOI
		bpl  +					; no EOI, then skip next two commands
		
	-	jsr  read_port
		bcc  -
	-	jsr  read_port
		bcs  -
		
	+ -	jsr  read_port
		bcc  -
		jsr  CLOCK_hi
		lda  #8
		sta  bit_count

	-	jsr  read_port
		bcc  time_out0
		lsr  byte
		bcs  +
		jsr  DATA_hi
		bcc  ++
	+	jsr  DATA_lo
	+	jsr  CLOCK_lo
		DELAY_10us
		jsr  DATA_lo
		jsr  CLOCK_hi
		dec  bit_count
		bne  -

		ldy  #to_1ms
		jsr  wait_data_hi_to
		bcc  +
		
time_out0:
		lda  #iecstatus_timeout
		.byte $2c
		
dev_not_present:
		lda  #iecstatus_devnotpresent
		ora  status
		sta  status
		jsr  ATN_lo
		jsr  delay_1ms
		jsr  CLOCK_lo
		jsr  DATA_lo
		cli
	+	rts
		
get_byte_iec:
		sei
		jsr  CLOCK_lo
	-	jsr  read_port			; wait for clock lo
		bpl  -
		lda  #0
		sta  bit_count
				
	-	jsr  DATA_lo

		ldy  #to_256us
		jsr  wait_clock_hi_to	; wait with timeout
		bpl  +

		;; timeout (receive EOI)
		lda  bit_count
		bne  time_out0
		
		jsr  DATA_hi
		jsr  CLOCK_lo
		lda  #$ff
		sta  EOI
		sta  bit_count
		bne  -
		
	+	lda  #8
		sta  bit_count

_bitloop:		
		RECEIVE_BIT(byte)			; macro defined in MACHINE/iec.s
		dec  bit_count
		bne  _bitloop
		
		jsr  DATA_hi
		bit  EOI
		bpl  +

		lda  #iecstatus_eof
		ora  status
		sta  status
		jsr  delay_50us
		jsr  CLOCK_lo
		jsr  DATA_lo
		
	+	lda  byte
		cli
		clc
		rts

send_byte_iec:
		bit  buffer_status
		bpl  +
		pha
		lda  buffer
		sta  byte
		jsr  raw_send_byte
		pla
	+	sta  buffer
		lda  #$ff
		sta  buffer_status
		rts

send_untalk_iec:
		sei
		jsr  CLOCK_hi
		jsr  ATN_hi
		lda  #$5f
		.byte $2c
		
send_unlisten_iec:
		lda  #0
		sta  ch_state
		lda  #$3f
		pha
		lda  buffer_status
		bpl  +
		sta  EOI
		and  #$7f
		sta  buffer_status
		lda  buffer
		sta  byte
		jsr  raw_send_byte
	+	lsr  EOI
		jsr  attention
		pla
		sta  byte
		jsr  raw_send_byte
		jsr  ATN_lo
		jsr  delay_50us
		jsr  CLOCK_lo
		jmp  DATA_lo

sec_adr_after_talk_iec:
		sta  byte
		sei
		jsr  CLOCK_hi
		jsr  DATA_lo
		jsr  delay_1ms
		jsr  raw_send_byte

		sei
		jsr  DATA_hi
		jsr  ATN_lo
		jsr  CLOCK_lo
	-	jsr  read_port
		bmi  -
		cli
		rts

sec_adr_after_listen_iec:
		sta  byte
		sei
		jsr  CLOCK_hi
		jsr  DATA_lo
		jsr  delay_1ms
		jsr  raw_send_byte
		jmp  ATN_lo

open_iec_file_iec:
		lda  #0
		sta  status
		lda  ch_device
		jsr  send_listen_iec
		sei
		jsr  CLOCK_hi
		jsr  DATA_lo
		jsr  delay_1ms
		lda  ch_secadr
		ora  #$f0
		sta  byte
		jsr  raw_send_byte
		jsr  ATN_lo
		lda  status
		bne  ++					; error, then return
		lda  #0
		sta  byte_count

	-	ldy  byte_count
		cpy  filename_length
		beq  +
		lda  filename,y
		jsr  send_byte_iec
		inc  byte_count
		bne  -

	+	jmp  send_unlisten_iec

close_iec_file_iec:
		lda  ch_device
		jsr  send_listen_iec
		lda  ch_secadr
		and  #$ef
		ora  #$e0
		sta  byte
		sei
		jsr  CLOCK_hi
		jsr  DATA_lo
		jsr  delay_1ms
		jsr  raw_send_byte
		jsr  ATN_lo
		jsr  send_unlisten_iec
		clc
	+	rts
