
;// These defines apply only for Atari
;// Maciej Witkowiak <ytm@elysium.pl>
;// 25.12.2000

#ifndef _GTIA_H
#define _GTIA_H

#define GTIA $d000

;// write only registers
#define GTIA_HOSP0	GTIA+0		; horizontal position player 0
#define GTIA_HOSP1	GTIA+1		; horizontal position player 1
#define GTIA_HOSP2	GTIA+2		; horizontal position player 2
#define GTIA_HOSP3	GTIA+3		; horizontal position player 3
#define GTIA_HOSM0	GTIA+4		; horizontal position missile 0
#define GTIA_HOSM1	GTIA+5		; horizontal position missile 1
#define GTIA_HOSM2	GTIA+6		; horizontal position missile 2
#define GTIA_HOSM3	GTIA+7		; horizontal position missile 3
#define GTIA_SIZEP0	GTIA+8		; size of player 0
#define GTIA_SIZEP1	GTIA+9		; size of player 1
#define GTIA_SIZEP2	GTIA+10		; size of player 2
#define GTIA_SIZEP3	GTIA+11		; size of player 3
#define GTIA_SIZEM	GTIA+12		; size of missiles
#define GTIA_GRAFP0	GTIA+13		; graphics shape of player 0
#define GTIA_GRAFP1	GTIA+14		; graphics shape of player 1
#define GTIA_GRAFP2	GTIA+15		; graphics shape of player 2
#define GTIA_GRAFP3	GTIA+16		; graphics shape of player 3
#define GTIA_GRAFM	GTIA+17		; graphics shape of missiles
#define GTIA_COLPM0	GTIA+18		; color player and missile 0
#define GTIA_COLPM1	GTIA+19		; color player and missile 1
#define GTIA_COLPM2	GTIA+20		; color player and missile 2
#define GTIA_COLPM3	GTIA+21		; color player and missile 3
#define GTIA_COLPF0	GTIA+22		; color playfield 0
#define GTIA_COLPF1	GTIA+23		; color playfield 1
#define GTIA_COLPF2	GTIA+24		; color playfield 2
#define GTIA_COLPF3	GTIA+25		; color playfield 3
#define GTIA_COLBK	GTIA+26		; color background
#define GTIA_PRIOR	GTIA+27		; priority selection
#define GTIA_VDELAY	GTIA+28		; vertical delay
#define GTIA_GRACTL	GTIA+29		; stick/paddle latch, p/m control
#define GTIA_HITCTL	GTIA+30		; clear p/m collision
#define GTIA_CONSOL	GTIA+31		; console buttons (r/w)

;// read only registers
#define GTIA_M0PF	GTIA+0		; missile 0 to playfield collision
#define GTIA_M1PF	GTIA+1		; missile 1 to playfield collision
#define GTIA_M2PF	GTIA+2		; missile 2 to playfield collision
#define GTIA_M3PF	GTIA+3		; missile 3 to playfield collision
#define GTIA_P0PF	GTIA+4		; player 0 to playfield collision
#define GTIA_P1PF	GTIA+5		; player 1 to playfield collision
#define GTIA_P2PF	GTIA+6		; player 2 to playfield collision
#define GTIA_P3PF	GTIA+7		; player 3 to playfield collision
#define GTIA_M0PL	GTIA+8		; missile 0 to player collision
#define GTIA_M1PL	GTIA+9		; missile 1 to player collision
#define GTIA_M2PL	GTIA+10		; missile 2 to player collision
#define GTIA_M3PL	GTIA+11		; missile 3 to player collision
#define GTIA_P0PL	GTIA+12		; player 0 to player collision
#define GTIA_P1PL	GTIA+13		; player 1 to player collision
#define GTIA_P2PL	GTIA+14		; player 2 to player collision
#define GTIA_P3PL	GTIA+15		; player 3 to player collision
#define GTIA_TRIG0	GTIA+16		; joystick trigger 0
#define GTIA_TRIG1	GTIA+17		; joystick trigger 1
#define GTIA_TRIG2	GTIA+18		; joystick trigger 2
#define GTIA_TRIG3	GTIA+19		; joystick trigger 3
#define GTIA_PAL	GTIA+20		; pal/ntsc flag

#endif
