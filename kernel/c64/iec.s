		;; C64 related IEC-routines

		;; need this short delaytime
		
#begindef DELAY_10us
		nop
		nop
		nop
		nop
		nop
#enddef

delay_50us:
		clc
		ldx  #256-5
		lda  #255
	-	inx
		bne  -
		adc  #1	
		bcc  -
		rts

;**************************************************************************
;		direct I/O related subroutines (very C64 specific)
;**************************************************************************

		io_port   equ CIA2_PRA
		ATN_out   equ %00001000
		CLOCK_out equ %00010000
		DATA_out  equ %00100000
		;; CLOCK_in  equ %01000000
		;; DATA_in   equ %10000000

DATA_lo:
		lda  #$ff-DATA_out
		and  io_port
		sta  io_port
		rts

DATA_hi:
		lda  #DATA_out
		ora  io_port
		sta  io_port
		rts

CLOCK_lo:
		lda  #$ff-CLOCK_out
		and  io_port
		sta  io_port
		rts

CLOCK_hi:
		lda  #CLOCK_out
		ora  io_port
		sta  io_port
		rts
		
ATN_lo:
		lda  #$ff-ATN_out
		and  io_port
		sta  io_port
		rts

ATN_hi:
		lda  #ATN_out
		ora  io_port
		sta  io_port
		rts

read_port:
		lda  io_port
		cmp  io_port
		bne  read_port
		asl  a
		rts						; returns with c=!DATA_in and n=!CLOCK_in !!

attention:
		sei
		jsr  DATA_lo
		jsr  ATN_hi
		jsr  CLOCK_hi

#define to_1ms     60			; 60*17 = 1020 CPU-ticks
#define to_256us   15           ; 15*17 = 255 CPU-ticks

delay_1ms:
		ldy  #to_1ms
		
	-	bit  delay_1ms
		bit  delay_1ms
		bit  delay_1ms
		dey
		bne  -
		rts

		;;  Y=timeout
		;;  returns with c=1 on timeout
		
wait_data_hi_to:
	-	lda  io_port
		ora  io_port
		asl  a
		bcc  +
		dey
		bne  -
	+	rts
		
		;;  Y=timeout
		;;  returns with c=0 on timeout
		
wait_clock_hi_to:
	-	lda  io_port
		ora  io_port
		asl  a
		bpl  +
		dey
		bne  -
		dey						; set negative-flag
	+	rts

#begindef RECEIVE_BIT(destination)
 %%next,pcur%%:	lda  io_port
		cmp  io_port
		bne  %%pcur%%
		asl  a
		bpl  %%pcur%%
		ror  destination
 %%next,pcur%%:	lda  io_port
		cmp  io_port
		bne  %%pcur%%
		asl  a
		bmi  %%pcur%%
#enddef
