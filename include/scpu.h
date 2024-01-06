#ifndef SCPU_H
#define SCPU_H

#define SCPU_MIRROR_BANK2 $d074  ; ($8000-$bfff)
#define SCPU_MIRROR_BANK1 $d075  ; ($4000-$7fff)
#define SCPU_MIRROR_SCR1  $d076  ; ($0400-$07ff)
#define SCPU_MIRROR_NONE  $d077  ; (-)
#define SCPU_1MHZ         $d07a  ; switch to 1MHZ
#define SCPU_20MHZ        $d07b  ; switch to 20MHZ
#define SCPU_REG_ENABLE   $d07e  ; hardware register enable
#define SCPU_REG_DISABLE  $d07f  ; hardware register disable
#define SCPU_DETECT_REG   $d0bc  ; (used to detect SCPU)
#define SCPU_DETECT_BIT   %10000000

; NOTE: $d200-$d3ff (SCPU-RAM in I/O-area) must not be touched

#endif
