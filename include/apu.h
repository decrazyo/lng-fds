
;// definitions for the NES/Famicom audio processing unit (APU).

#ifndef _APU_H
#define _APU_H

#define APU $4000

;// TODO: come up with better definition names.

;// Pulse 1 channel (write)
#define APU_PUL1_1 APU+$00 ;// DDLC NNNN   Duty, loop envelope/disable length counter, constant volume, envelope period/volume
#define APU_PUL1_2 APU+$01 ;// EPPP NSSS   Sweep unit: enabled, period, negative, shift count
#define APU_PUL1_3 APU+$02 ;// LLLL LLLL   Timer low
#define APU_PUL1_4 APU+$03 ;// LLLL LHHH   Length counter load, timer high (also resets duty and starts envelope)
 
;// Pulse 2 channel (write)
#define APU_PUL2_1 APU+$04 ;// DDLC NNNN   Duty, loop envelope/disable length counter, constant volume, envelope period/volume
#define APU_PUL2_2 APU+$05 ;// EPPP NSSS   Sweep unit: enabled, period, negative, shift count
#define APU_PUL2_3 APU+$06 ;// LLLL LLLL   Timer low
#define APU_PUL2_4 APU+$07 ;// LLLL LHHH   Length counter load, timer high (also resets duty and starts envelope)
 
;// Triangle channel (write)
#define APU_TRI_1 APU+$08  ;// CRRR RRRR   Length counter disable/linear counter control, linear counter reload value
#define APU_TRI_2 APU+$0a ;// LLLL LLLL   Timer low
#define APU_TRI_3 APU+$0b ;// LLLL LHHH   Length counter load, timer high (also reloads linear counter)
 
;// Noise channel (write)
#define APU_NOI_1 APU+$0c ;// --LC NNNN   Loop envelope/disable length counter, constant volume, envelope period/volume
#define APU_NOI_2 APU+$0e ;// L--- PPPP   Loop noise, noise period
#define APU_NOI_3 APU+$0f ;// LLLL L---   Length counter load (also starts envelope)
 
;// DMC channel (write)
#define APU_DMC_1 APU+$10 ;// IL-- FFFF   IRQ enable, loop sample, frequency index
#define APU_DMC_2 APU+$11 ;// -DDD DDDD   Direct load
#define APU_DMC_3 APU+$12 ;// AAAA AAAA   Sample address %11AAAAAA.AA000000
#define APU_DMC_4 APU+$13 ;// LLLL LLLL   Sample length %0000LLLL.LLLL0001
 
;//  ---D NT21   Control: DMC enable, length counter enables: noise, triangle, pulse 2, pulse 1 (write)
;//  IF-D NT21   Status: DMC interrupt, frame interrupt, length counter status: noise, triangle, pulse 2, pulse 1 (read)
#define APU_STATUS  APU+$15

#define APU_FRAME APU+$17 ;// SD-- ----   Frame counter: 5-frame sequence, disable frame interrupt (write) 

;// TODO: define bit masks.

#endif
