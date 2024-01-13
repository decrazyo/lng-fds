
;// definitions for the NES/Famicom picture processing unit (PPU).

#ifndef _PPU_H
#define _PPU_H

;// #define PPU $2000

;// PPU registers
#define PPU_CTRL        $2000   ;// VPHBSINN
#define PPU_MASK        $2001   ;// BGRsbMmG
#define PPU_STATUS      $2002   ;// VSO-----
#define PPU_OAM_ADDR    $2003   ;// OAM read/write address
#define PPU_OAM_DATA    $2004   ;// OAM data read/write
#define PPU_SCROLL      $2005   ;// fine scroll position (two writes: X scroll, Y scroll)
#define PPU_ADDR        $2006   ;// PPU read/write address (two writes: most significant byte, least significant byte)
#define PPU_DATA        $2007   ;// PPU data read/write
#define PPU_OAM_DMA     $4014   ;// OAM DMA high address 

;// PPU register bit masks
#define PPU_CTRL_V      %10000000 ;// NMI enable
#define PPU_CTRL_P      %01000000 ;// PPU master/slave
#define PPU_CTRL_H      %00100000 ;// sprite height
#define PPU_CTRL_B      %00010000 ;// background tile select
#define PPU_CTRL_S      %00001000 ;// sprite tile select
#define PPU_CTRL_I      %00000100 ;// increment mode
#define PPU_CTRL_N      %00000011 ;// nametable select

#define PPU_MASK_B      %10000000 ;// color emphasis blue
#define PPU_MASK_G      %01000000 ;// color emphasis green
#define PPU_MASK_R      %00100000 ;// color emphasis red
#define PPU_MASK_s      %00010000 ;// sprite enable
#define PPU_MASK_b      %00001000 ;// background enable
#define PPU_MASK_M      %00000100 ;// sprite left column enable
#define PPU_MASK_m      %00000010 ;// background left column enable
#define PPU_MASK_g      %00000001 ;// greyscale

#define PPU_STATUS_V    %10000000 ;// vblank
#define PPU_STATUS_S    %01000000 ;// sprite 0 hit
#define PPU_STATUS_O    %00100000 ;// sprite overflow; read resets write pair for $2005/$2006

;// TODO: define PPU memory map
;//       nametables, attributes, etc...

;// TODO: define colors

#endif
