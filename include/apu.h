
;// definitions for the NES/Famicom audio processing unit (APU).

#ifndef _APU_H
#define _APU_H

;// #define APU $4000

;// APU registers

;// Pulse 1 channel (write)
#define APU_PUL1_1 $4000 ;// DDLC NNNN   Duty, loop envelope/disable length counter, constant volume, envelope period/volume
#define APU_PUL1_2 $4001 ;// EPPP NSSS   Sweep unit: enabled, period, negative, shift count
#define APU_PUL1_3 $4002 ;// LLLL LLLL   Timer low
#define APU_PUL1_4 $4003 ;// LLLL LHHH   Length counter load, timer high (also resets duty and starts envelope)
 
;// Pulse 2 channel (write)
#define APU_PUL2_1 $4004 ;// DDLC NNNN   Duty, loop envelope/disable length counter, constant volume, envelope period/volume
#define APU_PUL2_2 $4005 ;// EPPP NSSS   Sweep unit: enabled, period, negative, shift count
#define APU_PUL2_3 $4006 ;// LLLL LLLL   Timer low
#define APU_PUL2_4 $4007 ;// LLLL LHHH   Length counter load, timer high (also resets duty and starts envelope)
 
;// Triangle channel (write)
#define APU_TRI_1 $4008  ;// CRRR RRRR   Length counter disable/linear counter control, linear counter reload value
#define APU_TRI_2 $400a ;// LLLL LLLL   Timer low
#define APU_TRI_3 $400b ;// LLLL LHHH   Length counter load, timer high (also reloads linear counter)
 
;// Noise channel (write)
#define APU_NOI_1 $400c ;// --LC NNNN   Loop envelope/disable length counter, constant volume, envelope period/volume
#define APU_NOI_2 $400e ;// L--- PPPP   Loop noise, noise period
#define APU_NOI_3 $400f ;// LLLL L---   Length counter load (also starts envelope)
 
;// DMC channel (write)
#define APU_DMC_1 $4010 ;// IL-- FFFF   IRQ enable, loop sample, frequency index
#define APU_DMC_2 $4011 ;// -DDD DDDD   Direct load
#define APU_DMC_3 $4012 ;// AAAA AAAA   Sample address %11AAAAAA.AA000000
#define APU_DMC_4 $4013 ;// LLLL LLLL   Sample length %0000LLLL.LLLL0001
 
;//  ---D NT21   Control: DMC enable, length counter enables: noise, triangle, pulse 2, pulse 1 (write)
;//  IF-D NT21   Status: DMC interrupt, frame interrupt, length counter status: noise, triangle, pulse 2, pulse 1 (read)
#define APU_STATUS $4015

#define APU_FRAME $4017 ;// SD-- ----   Frame counter: 5-frame sequence, disable frame interrupt (write) 

;// APU register bit masks


#define APU_DMC_1_I   %10000000 ;// IRQ enable

#define APU_STATUS_I  %10000000
#define APU_STATUS_F  %01000000
#define APU_STATUS_D  %00010000
#define APU_STATUS_N  %00001000
#define APU_STATUS_T  %00000100
#define APU_STATUS_2  %00000010
#define APU_STATUS_1  %00000001

#define APU_FRAME_S   %10000000 ;// Frame counter: 5-frame sequence
#define APU_FRAME_D   %01000000 ;// disable frame interrupt (write)


#endif
