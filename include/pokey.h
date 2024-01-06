
;// These defines apply only for Atari
;// Maciej Witkowiak <ytm@elysium.pl>
;// 25.12.2000

#ifndef _POKEY_H
#define _POKEY_H

#define POKEY $d200

;// Pokey register map

;// write only registers
#define POKEY_AUDF1	POKEY+0		; audio channel #1 frequency
#define POKEY_AUDC1	POKEY+1		; audio channel #1 control
#define POKEY_AUDF2	POKEY+2		; audio channel #2 frequency
#define POKEY_AUDC2	POKEY+3		; audio channel #2 control
#define POKEY_AUDF3	POKEY+4		; audio channel #3 frequency
#define POKEY_AUDC3	POKEY+5		; audio channel #3 control
#define POKEY_AUDF4	POKEY+6		; audio channel #4 frequency
#define POKEY_AUDC4	POKEY+7		; audio channel #4 control
#define POKEY_AUDCTL	POKEY+8		; audio control
#define POKEY_STIMER	POKEY+9		; start pokey timers
#define POKEY_SKREST	POKEY+10	; reset serial port status reg.
#define POKEY_POTGO	POKEY+11	; start paddle scan sequence
;//#define POKEY_UNUSED	POKEY+12	; unused
#define POKEY_SEROUT	POKEY+13	; serial port data output
#define POKEY_IRQEN	POKEY+14	; interrupt request enable
#define POKEY_SKCTL	POKEY+15	; serial port control

;// read only registers
#define POKEY_POT0	POKEY+0		; paddle 0 value
#define POKEY_POT1	POKEY+1		; paddle 1 value
#define POKEY_POT2	POKEY+2		; paddle 2 value
#define POKEY_POT3	POKEY+3		; paddle 3 value
#define POKEY_POT4	POKEY+4		; paddle 4 value
#define POKEY_POT5	POKEY+5		; paddle 5 value
#define POKEY_POT6	POKEY+6		; paddle 6 value
#define POKEY_POT7	POKEY+7		; paddle 7 value
#define POKEY_ALLPOT	POKEY+8		; eight paddle port status
#define POKEY_KBCODE	POKEY+9		; keyboard code
#define POKEY_RANDOM	POKEY+10	; random number generator
;//#define POKEY_UNUSED	POKEY+11	; unused
;//#define POKEY_UNUSED	POKEY+12	; unused
#define POKEY_SERIN	POKEY+13	; serial port input
#define POKEY_IRQST	POKEY+14	; interrupt request status
#define POKEY_SKSTAT	POKEY+15	; serial port status

#endif
