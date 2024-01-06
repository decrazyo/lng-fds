
#ifndef _C64_H
#define _C64_H

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
;// memconf_rom
;//   value for memory config, where Kernal ROM is available

#define GETMEMCONF  lda 1:and #7
#define SETMEMCONF  eor 1:and #$07:eor 1:sta 1 
#define MEMCONF_SYS  5
#define MEMCONF_USER 5
#define MEMCONF_FONT 1
#define MEMCONF_ROM  6

#define HAVE_CIA
#include <cia.h>

#define HAVE_VIC
#include <vic.h>

#define HAVE_SID
#include <sid.h>

#endif

