#ifndef _VIC_H
#define _VIC_H

;// hardware related

#define VIC  $d000

#define VIC_S0X      VIC+0        ; sprite 0 x (bit 7..0)
#define VIC_S0Y      VIC+1        ; sprite 0 y (bit 7..0)
#define VIC_S1X      VIC+2        ; sprite 1 x (bit 7..0)
#define VIC_S1Y      VIC+3        ; sprite 1 y (bit 7..0)
#define VIC_S2X      VIC+4        ; sprite 2 x (bit 7..0)
#define VIC_S2Y      VIC+5        ; sprite 2 y (bit 7..0)
#define VIC_S3X      VIC+6        ; sprite 3 x (bit 7..0)
#define VIC_S3Y      VIC+7        ; sprite 3 y (bit 7..0)
#define VIC_S4X      VIC+8        ; sprite 4 x (bit 7..0)
#define VIC_S4Y      VIC+9        ; sprite 4 y (bit 7..0)
#define VIC_S5X      VIC+10       ; sprite 5 x (bit 7..0)
#define VIC_S5Y      VIC+11       ; sprite 5 y (bit 7..0)
#define VIC_S6X      VIC+12       ; sprite 6 x (bit 7..0)
#define VIC_S6Y      VIC+13       ; sprite 6 y (bit 7..0)
#define VIC_S7X      VIC+14       ; sprite 7 x (bit 7..0)
#define VIC_S7Y      VIC+15       ; sprite 7 y (bit 7..0)
#define VIC_SX8      VIC+16       ; sprite 7..0 x bit 8
#define VIC_YSCL     VIC+17       ; ..., screen y-offset
#define VIC_RC       VIC+18       ; current raster line
#define VIC_LPX      VIC+19       ; light pen x
#define VIC_LPY      VIC+20       ; light pen y
#define VIC_SE       VIC+21       ; sprite 7..0 enable
#define VIC_XSCL     VIC+22       ; ..., screen x-offset
#define VIC_SEXY     VIC+23       ; sprite 7..0 expand y
#define VIC_VSCB     VIC+24       ; ..., location of charset
#define VIC_IRQ      VIC+25       ; interrupt request
#define VIC_IRM      VIC+26       ; interrupt request mask
#define VIC_BSP      VIC+27       ; sprite 7..0 background priority
#define VIC_SCM      VIC+28       ; sprite 7..0 multicolor mode
#define VIC_SEXX     VIC+29       ; sprite 7..0 expand x
#define VIC_SSC      VIC+30       ; sprite-sprite collision (7..0)
#define VIC_SBC      VIC+31       ; sprite-background collision (7..0)
#define VIC_BC       VIC+32       ; border color
#define VIC_GC0      VIC+33       ; background 0 color
#define VIC_GC1      VIC+34       ; background 1 color
#define VIC_GC2      VIC+35       ; background 2 color
#define VIC_GC3      VIC+36       ; background 3 color
#define VIC_SMC0     VIC+37       ; sprite multicolor color 0     
#define VIC_SMC1     VIC+38       ; sprite multicolor color 1
#define VIC_SC0      VIC+39       ; sprite 0 color
#define VIC_SC1      VIC+40       ; sprite 1 color
#define VIC_SC2      VIC+41       ; sprite 2 color
#define VIC_SC3      VIC+42       ; sprite 3 color
#define VIC_SC4      VIC+43       ; sprite 4 color
#define VIC_SC5      VIC+44       ; sprite 5 color
#define VIC_SC6      VIC+45       ; sprite 6 color
#define VIC_SC7      VIC+46       ; sprite 7 color

;// C128 specific (visbile in C128's C64 mode)
#define VIC_KEYREG   VIC+47	  ; additional key row register
#define VIC_CLOCK    VIC+48	  ; CPU clock (1/2MHz) register

#endif

