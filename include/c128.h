
#ifndef _C128_H
#define _C128_H

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

#define GETMEMCONF  lda $ff00
#define SETMEMCONF  sta $ff00 
#define MEMCONF_SYS  %00111110
#define MEMCONF_USER %00111110
#define MEMCONF_FONT %00000001

;would rather want to use preconfig registers to set/restore memory configuration
;(like SCPU - access to preconfig register causes change of config to preloaded one)
;like:	lda $ff01	; (for preconfig A - kernel space)
;	lda $ff02	; (for preconfig B - user space)

#define HAVE_CIA
#include <cia.h>

#define HAVE_VIC
#include <vic.h>

#define HAVE_SID
#include <sid.h>

#include <mmu.h>

#endif

