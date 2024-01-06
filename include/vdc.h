
;These defines apply for C128 in both C64 and C128 modes
;Maciej 'YTM/Alliance' Witkowiak <ytm@friko.onet.pl>
;7.12.1999
;15.12.1999

#ifndef _VDC_H
#define _VDC_H

#define	VDC	$d600

#define	VDC_REG		VDC+0		; VDC status/register no.
#define VDC_DATA_REG	VDC+1		; VDC data register

; now register names & numbers...

#define VDC_HTOTAL	0		; horizontal total
#define VDC_HDISPLAYED	1		; horizontal displayed
#define VDC_HSYNCPOS	2		; horizontal sync position
#define VDC_VHSYNCW	3		; vertical/horizontal sync width
#define VDC_VTOTAL	4		; vertical total
#define VDC_VTOTALFINE	5		; vertical total fine adjustment
#define VDC_VDISPLAYED	6		; vertical displayed
#define VDC_VSYNCPOS	7		; vertical sync position
#define VDC_INTERLACE	8		; interlace mode
#define VDC_CVTOTAL	9		; character vertical total
#define VDC_CSRMODE	10		; cursor mode/start scanline
#define VDC_CSREND	11		; cursor end scanline
#define VDC_DSPHI	12		; display start (hi)
#define VDC_DSPLO	13		; display start (lo)
#define VDC_CSRHI	14		; cursor position (hi)
#define VDC_CSRLO	15		; cursor position (lo)
#define VDC_VLPEN	16		; light pen vertical
#define VDC_HLPEN	17		; light pen horizontal
#define VDC_DATAHI	18		; update address (hi)
#define VDC_DATALO	19		; update address (lo)
#define VDC_ATTHI	20		; attribute map address (hi)
#define VDC_ATTLO	21		; attribute map address (lo)
#define VDC_CHSIZE	22		; character horizontal size control
#define VDC_VCPSPC	23		; vertical character pixel space
#define VDC_VSCROLL	24		; block/rvs/vertical scroll
#define VDC_HSCROLL	25		; diff. mode sw./horizontal scroll
#define VDC_COLORS	26		; fore/background colors
#define VDC_ROWINC	27		; row address increment
#define VDC_CSET	28		; character set A13-15, ram size
#define VDC_ULINE	29		; underline scanline
#define VDC_COUNT	30		; word count (-1)
#define VDC_DATA	31		; data
#define VDC_SRCHI	32		; block copy source (hi)
#define VDC_SRCLO	33		; block copy source (lo)
#define VDC_DEBEGIN	34		; display enable begin
#define VDC_DEEND	35		; display enable end
#define VDC_REFRESH	36		; DRAM refresh rate

#endif
