
;These defines apply only for C128
;Maciej 'YTM/Alliance' Witkowiak <ytm@friko.onet.pl>
;10.01.2000

#ifndef _MMU_H
#define _MMU_H

;These are available only in I/O mode

#define	MMU_IO	$d500

#define MMU_IOCR	MMU_IO+0		; configuration register
#define MMU_PCRA	MMU_IO+1		; preconfiguration register A
#define MMU_PCRB	MMU_IO+2		; preconfiguration register B
#define MMU_PCRC	MMU_IO+3		; preconfiguration register C
#define MMU_PCRD	MMU_IO+4		; preconfiguration register D
#define MMU_MCR		MMU_IO+5		; mode configuration register
#define MMU_RCR		MMU_IO+6		; RAM configuration register
#define MMU_P0L		MMU_IO+7		; page 0 pointer low
#define MMU_P0H		MMU_IO+8		; page 0 pointer high
#define MMU_P1L		MMU_IO+9		; page 1 pointer low
#define MMU_P1H		MMU_IO+10		; page 1 pointer high
#define MMU_VR		MMU_IO+11		; version register

;These are available always

#define MMU	$ff00

#define MMU_CR		MMU+0			; configuration register (same as MMU_IOCR)
#define MMU_LCRA	MMU+1			; load configuration register A
#define MMU_LCRB	MMU+2			; load configuration register C
#define MMU_LCRC	MMU+3			; load configuration register B
#define MMU_LCRD	MMU+4			; load configuration register D

#endif
