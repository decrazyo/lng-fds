;// main configuration file

#ifndef _CONFIG_H
#define _CONFIG_H

# define C64
# define MACHINE_H <c64.h>
# define MACHINE(file) "c64/file"

;// Keyboard/console settings
;// -------------------------
;//   Enable this if you want to have German keyboard layout

;#define DIN


;// Kernel error messages
;// ---------------------
;//   The functions "lkf_printerror" and "lkf_suicerrout" print a short
;//   message via printk. Normally just the error code is reported.
;//   If you want to have textual error messages add the following to
;//   the compile-flags (costs 444 bytes)

#define VERBOSE_ERROR


;// Commodore IEC serial bus messages
;// ---------------------------------
;//
;//   After opening files and after other disc operations the IEC error 
;//   channel (secundary address 15) is read out. If "PRINT_IECMSG" is defined
;//   all messages other than ("00 OK ...") will be reported via printk.
;//   (costs 37 bytes)

;#define PRINT_IECMSG


;// REU support
;// -----------
;// if you have a REU installed at $df00 you may define the following
;// the use of REU's DMA feature will speed up several things, but may also
;// lead to problems with applications that require short NMI/IRQ latencies.
;// The REU kernel is around 102 bytes smaller than the normal one,
;// because HAVE_REU also implies ALWAYS_SZU.

;#define HAVE_REU


;// VDC console
;// -----------
;// if you run LUnix on a C128 in C64 mode, you might want to use
;// the 80 column capabillities of the VDC instead of the standard
;// VIC-text console.
;// (this replaces the VIC console and implies multiple consoles plus
;// use of the 2MHz mode of the C128)
;// saves 2048-131=1917 bytes compared with (VIC/Multiple Consoles)

;#define VDC_CONSOLE


;// Multiple consoles
;// -----------------
;// startup with more than just one console, system needs at least 1k for
;// each additional console! (should better allocate memory on demand)
;// currently the functions keys are used to select and shift+commodore to
;// switch between consoles (this time just 2 consoles are available F1/F2 with
;// VIC or 6 consoles - F1/3/5/7/2/4 with VDC)

#define MULTIPLE_CONSOLES


;// VIC 80 column console
;// ---------------------
;// startup with one 80x25 console, you can switch 0-39 and 40-79 screens with
;// the same keys as to switch between consoles
;// multiple consoles code will be disabled with this option

;#define VIC_CONSOLE80


;// PC AT-compatible keyboard support
;// ---------------------------------
;// this allows you to use PC-compatible keyboard as the only input device
;// read docs for info about interface (it's very easy to build)
;// WARNING: currently the driver isn't 100% reliable on VIC console, so try 
;// to not use this option if you're about to type much, you'll avoid 
;// stress ;)

;#define PCAT_KEYB


;// SuperCPU support
;// ----------------
;// if you have a CMD SuperCPU you might want to uncomment the following
;// (the system will still run without a SCPU) there is just some code
;// added in order to run well with a SCPU. (otherwise disc accesses
;// will only work, when the SCPU is manually switch to 1MHz).
;// Warning: HAVE_SCPU might conflict with MULTIPLE_CONSOLES
;// (second console $0800-$0fff is not updated by SCPU! - to be confirmed)
;// (costs 39 (+ 512) bytes)

#define HAVE_SCPU


;// 64net/2 support
;// ---------------
;// if you have a PC capable of running 64net/2 and your C64/128 is hooked
;// to it, you can enable 64net/2 support for IEC bus. This will currently
;// allow you to do disk operations on partition 0
;// for more information about 64net/2 go to
;// http://sourceforge.net/projects/c64net/

;#define HAVE_64NET2


;// IDE64 support
;// -------------
;// IDE64 is a cartridge that allows for connecting two IDE devices to C64
;// You can enable support for it. This will currently allow you to do
;// disk operation on current directory of master disk.
;// for more information about IDE64 go to
;// http://ide64.come.to/ or http://www.volny.cz/dundera/

;#define HAVE_IDE64


;// Silversurfer support
;// --------------------
;// Silversurfer is an UART based serial interface connected to the
;// Retroreplay.
;// defining this will patch the fifo64 and sfifo64 driver
;// to enable the Silversurfer
#define HAVE_SILVERSURFER

;// UART Configuration (fifo64/sfifo64 drivers)
;// UART base adress
;#define UART_BASE $de00	;// IDE64
#define UART_BASE $de08		;// Silversurfer

;// UART Oscillator Frequency in khz (rounded)
;#define UART_OSC_1843  ;// IDE64
#define UART_OSC_7373	;// Silversurfer


;// .o65 file format support
;// ------------------------
;// .o65 is a relocatable file format different than LNG native one.
;// Soon cc65 (a free C compiler for 6502) will have support for building
;// LNG applications and the output format had to be .o65. Hence enable this
;// if you want to execute applications built using cc65. (costs ~900 bytes)

#define HAVE_O65


;// Init shell script support
;// -------------------------
;// this forces kernel to load sh and execute lunixrc script upon boot
;// instead of executing built-in microshell

#define HAVE_INITSCRIPT


;// Misc stuff
;// ----------
;// always_szu may save some memory (around 265 bytes), but usually
;// slows taskswitching down (up to 160us per taskswitch)

;#define ALWAYS_SZU



;//---------------------------------------------------------------------------
;// end of configurable section

#ifdef HAVE_SCPU
# include <scpu.h>
# define SPEED_MAX    sta SCPU_20MHZ
# define SPEED_1MHZ   sta SCPU_1MHZ
#endif

#ifdef HAVE_REU
# define ALWAYS_SZU
#endif

#ifdef VDC_CONSOLE
# include <vic.h>
# undef MULTIPLE_CONSOLES
# define MULTIPLE_CONSOLES
# define HAVE_VDC
# ifndef HAVE_SCPU
#  define SPEED_MAX    lda #1:sta VIC_CLOCK
#  define SPEED_1MHZ   lda #0:sta VIC_CLOCK
# else
#  undef SPEED_MAX
#  undef SPEED_1MHZ	
;// C128 with SCPU (don't know, if this really works)
#  define SPEED_MAX    lda #1:sta VIC_CLOCK:sta SCPU_20MHZ
#  define SPEED_1MHZ   lda #0:sta VIC_CLOCK:sta SCPU_1MHZ
# endif
#endif

;// fall back to VIC console (40)
#ifndef VDC_CONSOLE
# ifndef VIC_CONSOLE80
#  define VIC_CONSOLE
# endif
#endif

#ifdef VIC_CONSOLE80
# undef MULTIPLE_CONSOLES
#endif

#ifndef SPEED_1MHZ	
# define SPEED_MAX
# define SPEED_1MHZ
#endif

#endif
