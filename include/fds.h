
;// definitions for the Famicom disk system (FDS) RAM adapter.

#ifndef _FDS_H
#define _FDS_H

;// TODO: come up with better definition names.

#define FDS_REG             $4000
#define FDS_RAM             $6000
#define FDS_BIOS            $e000
#define FDS_VECTOR          $dff6
#define FDS_VECTOR_CTRL     $0100

#define FDS_CTRL            FDS_REG+$25

#define FDS_CTRL_I          %10000000
#define FDS_CTRL_S          %01000000
#define FDS_CTRL_1          %00100000
#define FDS_CTRL_B          %00010000
#define FDS_CTRL_M          %00001000
#define FDS_CTRL_R          %00000100
#define FDS_CTRL_T          %00000010
#define FDS_CTRL_D          %00000001


;// FDS pseudo-interrupt vectors
#define FDS_NMI1            FDS_VECTOR+0
#define FDS_NMI2            FDS_VECTOR+2
#define FDS_NMI3            FDS_VECTOR+4
#define FDS_RESET           FDS_VECTOR+6
#define FDS_IRQ             FDS_VECTOR+8

#define FDS_NMI_CTRL        FDS_VECTOR_CTRL+0
#define FDS_IRQ_CTRL        FDS_VECTOR_CTRL+1
#define FDS_RESET_CTRL      FDS_VECTOR_CTRL+2

;// TODO: define registers

;// TODO: define BIOS functions

#endif

