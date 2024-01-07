
;// definitions for the NES/Famicom picture processing unit (PPU).

#ifndef _PPU_H
#define _PPU_H

#define PPU $2000

;// PPU registers
#define PPU_CTRL        PPU+0   ;// VPHB SINN   NMI enable (V), PPU master/slave (P), sprite height (H), background tile select (B), sprite tile select (S), increment mode (I), nametable select (NN)
#define PPU_MASK        PPU+1   ;// BGRs bMmG   color emphasis (BGR), sprite enable (s), background enable (b), sprite left column enable (M), background left column enable (m), greyscale (G)
#define PPU_STATUS      PPU+2   ;// VSO- ----   vblank (V), sprite 0 hit (S), sprite overflow (O); read resets write pair for $2005/$2006
#define PPU_OAM_ADDR    PPU+3   ;// aaaa aaaa   OAM read/write address
#define PPU_OAM_DATA    PPU+4   ;// dddd dddd   OAM data read/write
#define PPU_SCROLL      PPU+5   ;// xxxx xxxx   fine scroll position (two writes: X scroll, Y scroll)
#define PPU_ADDR        PPU+6   ;// aaaa aaaa   PPU read/write address (two writes: most significant byte, least significant byte)
#define PPU_DATA        PPU+7   ;// dddd dddd   PPU data read/write
#define PPU_OAM_DMA     $4014   ;// aaaa aaaa   OAM DMA high address 

;// PPU register bit masks
#define PPU_CTRL_V      %10000000
#define PPU_CTRL_P      %01000000
#define PPU_CTRL_H      %00100000
#define PPU_CTRL_B      %00010000
#define PPU_CTRL_S      %00001000
#define PPU_CTRL_I      %00000100
#define PPU_CTRL_N      %00000011

#define PPU_MASK_B      %10000000
#define PPU_MASK_G      %01000000
#define PPU_MASK_R      %00100000
#define PPU_MASK_s      %00010000
#define PPU_MASK_b      %00001000
#define PPU_MASK_M      %00000100
#define PPU_MASK_m      %00000010
#define PPU_MASK_g      %00000001

#define PPU_STATUS_V    %10000000
#define PPU_STATUS_S    %01000000
#define PPU_STATUS_O    %00100000

;// TODO: define PPU memory map
;//       nametables, attributes, etc...

;// TODO: define colors

#endif
