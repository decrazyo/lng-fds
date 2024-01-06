
#ifndef _CIA_H
#define _CIA_H

#define CIA1 $dc00
#define CIA2 $dd00

;// CIA1 and CIA2 register map
#define CIA1_PRA     CIA1+0       ; port register A (i/o)
#define CIA1_PRB     CIA1+1       ; port register B (i/o)
#define CIA1_DDRA    CIA1+2       ; data direction register A  (0=input,
#define CIA1_DDRB    CIA1+3       ; data direction register B   1=output)
#define CIA1_TALO    CIA1+4       ; timer A bits 0-7 (lo byte)
#define CIA1_TAHI    CIA1+5       ; timer A bits 8-15 (hi byte)
#define CIA1_TBLO    CIA1+6       ; timer B bits 0-7 (lo byte)
#define CIA1_TBHI    CIA1+7       ; timer B bits 8-15 (hi byte)
#define CIA1_TOD10   CIA1+8       ; time of day - 1/10 seconds
#define CIA1_TODSEC  CIA1+9       ; time of day - seconds (in BCD)
#define CIA1_TODMIN  CIA1+10      ; time of day - minutes (in BCD)
#define CIA1_TODHR   CIA1+11      ; time of day - hour + am/pm
#define CIA1_SDR     CIA1+12      ; serial data register (i/o)
#define CIA1_ICR     CIA1+13      ; iterrupt control register
#define CIA1_CRA     CIA1+14      ; control register A
#define CIA1_CRB     CIA1+15      ; control register B

#define CIA2_PRA     CIA2+0       ; port register A (i/o)
#define CIA2_PRB     CIA2+1       ; port register B (i/o)
#define CIA2_DDRA    CIA2+2       ; data direction register A  (0=input,
#define CIA2_DDRB    CIA2+3       ; data direction register B   1=output)
#define CIA2_TALO    CIA2+4       ; timer A bits 0-7 (lo byte)
#define CIA2_TAHI    CIA2+5       ; timer A bits 8-15 (hi byte)
#define CIA2_TBLO    CIA2+6       ; timer B bits 0-7 (lo byte)
#define CIA2_TBHI    CIA2+7       ; timer B bits 8-15 (hi byte)
#define CIA2_TOD10   CIA2+8       ; time of day - 1/10 seconds
#define CIA2_TODSEC  CIA2+9       ; time of day - seconds (in BCD)
#define CIA2_TODMIN  CIA2+10      ; time of day - minutes (in BCD)
#define CIA2_TODHR   CIA2+11      ; time of day - hour + am/pm
#define CIA2_SDR     CIA2+12      ; serial data register (i/o)
#define CIA2_ICR     CIA2+13      ; iterrupt control register
#define CIA2_CRA     CIA2+14      ; control register A
#define CIA2_CRB     CIA2+15      ; control register B

#endif

