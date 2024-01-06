
#ifndef _ATARI_H
#define _ATARI_H

;// hardware related

;// loading/changing/activating memory configurations
;// getmemconf
;//   value returned in A represents current memory configuration
;//   this value can be used to restore the configuration at a later time
;// setmemconf
;//   change to a memory configuration (description provded in A)

;// memconf_sys 
;//   value for the memory configuration used during IRQ/NMI
;//   (in the taskswitcher) (I/O area visible)
;// memconf_user
;//   value for the default user task memory configuration

;// memconf_font
;//   value for memory config, where FONT_ROM is available

#define GETMEMCONF  lda $d301
#define SETMEMCONF  sta $d301
#define MEMCONF_SYS  %10000010
#define MEMCONF_USER %10000010
#define MEMCONF_FONT %10000011

#define HAVE_POKEY
#include <pokey.h>

#define HAVE_PIA
#include <pia.h>

#define HAVE_ANTIC
#include <antic.h>

#define HAVE_GTIA
#include <gtia.h>

#endif
