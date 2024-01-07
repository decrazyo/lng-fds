
#ifndef _NINTENDO_H
#define _NINTENDO_H

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

;// we don't have multiple memory configurations to manage.
#define GETMEMCONF  nop
#define SETMEMCONF  nop
#define MEMCONF_SYS  0
#define MEMCONF_USER 0
#define MEMCONF_FONT 0
#define MEMCONF_ROM  0

#define HAVE_PPU
#include <ppu.h>

#define HAVE_APU
#include <apu.h>

#define HAVE_FDS
#include <fds.h>

#define JOYPAD1 $4016
#define JOYPAD2 $4017

#endif
