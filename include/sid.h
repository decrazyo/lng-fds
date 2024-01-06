
;Maciej 'YTM/Elysium' Witkowiak <ytm@friko.onet.pl>
;15.09.2000

#ifndef _SID_H
#define _SID_H

#define	SID	$d400
;// channel  #1
#define SID_FRELO1	SID+0		; channel #1 frequency low byte
#define SID_FREHI1	SID+1		; channel #1 frequency high byte
#define SID_PWLO1	SID+2		; channel #1 pulse width low byte
#define SID_PWHI1	SID+3		; channel #1 pulse width high byte
#define SID_VCREG1	SID+4		; channel #1 voice control register
#define SID_ATDCY1	SID+5		; channel #1 attack+decay time register
#define SID_SUREL1	SID+6		; channel #1 sutain+release time register
;// channel #2
#define SID_FRELO2	SID+7		; channel #2 frequency low byte
#define SID_FREHI2	SID+8		; channel #2 frequency high byte
#define SID_PWLO2	SID+9		; channel #2 pulse width low byte
#define SID_PWHI2	SID+10		; channel #2 pulse width high byte
#define SID_VCREG2	SID+11		; channel #2 voice control register
#define SID_ATDCY2	SID+12		; channel #2 attack+decay time register
#define SID_SUREL2	SID+13		; channel #2 sutain+release time register
;// channel #3
#define SID_FRELO3	SID+14		; channel #3 frequency low byte
#define SID_FREHI3	SID+15		; channel #3 frequency high byte
#define SID_PWLO3	SID+16		; channel #3 pulse width low byte
#define SID_PWHI3	SID+17		; channel #3 pulse width high byte
#define SID_VCREG3	SID+18		; channel #3 voice control register
#define SID_ATDCY3	SID+19		; channel #3 attack+decay time register
#define SID_SUREL3	SID+20		; channel #3 sutain+release time register
;// SID control
#define SID_CUTLO	SID+21		; filter frequency cutoff low byte
#define SID_CUTHI	SID+22		; filter frequency cutoff high byte
#define SID_RESON	SID+23		; filter control register
#define SID_VOL		SID+24		; volume and filter control register
#define SID_POTX	SID+25		; potx register (1st or 3rd - depending on CIA1_PRA value)
#define SID_POTY	SID+26		; poty register (2nd or 4th - depending on CIA1_PRA value)
#define SID_RANDOM	SID+27		; channel #3 output, random values if noise wave is selected
#define SID_ENV3	SID+28		; oscillator #3 output, similar to previous one

#endif
