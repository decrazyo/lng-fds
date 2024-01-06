
;// These defines apply only for Atari
;// Maciej Witkowiak <ytm@elysium.pl>
;// 25.12.2000

#ifndef _ANTIC_H
#define _ANTIC_H

#define ANTIC $d400

#define ANTIC_DMACTL	ANTIC+0		; direct memory access control
#define ANTIC_CHACTL	ANTIC+1		; character mode control
#define ANTIC_DLISTL	ANTIC+2		; display list pointer lo
#define ANTIC_DLISTH	ANTIC+3		; display list pointer hi
#define ANTIC_VSCROL	ANTIC+4		; vertical scroll enable
#define ANTIC_HSCROL	ANTIC+5		; horizontal scroll enable
;//#define ANTIC_UNUSED	ANTIC+6		; unused
#define ANTIC_PMBASE	ANTIC+7		; p/m base address hi
;//#define ANTIC_UNUSED	ANTIC+8		; unused
#define ANTIC_CHBASE	ANTIC+9		; character base address
#define ANTIC_WSYNC	ANTIC+10	; wait for horizontal synchronization
#define ANTIC_VCOUNT	ANTIC+11	; vertical line counter
#define ANTIC_PENH	ANTIC+12	; light pen horizontal position
#define ANTIC_PENL	ANTIC+13	; light pen vertical position
#define ANTIC_NMIEN	ANTIC+14	; non-maskable interrupt enable
#define ANTIC_NMIRES	ANTIC+15	; nmi reset/status

#endif
