
#ifndef _SYSTEM_H
#define _SYSTEM_H

;// LNG-magic and version
#define LNG_MAGIC   $fffe
#define LNG_VERSION $0015   ;// in decimal => 0, 21

;// O65 file format version
#define O65_MAGIC    $0001

;// jumptab-addresses are adapted at runtime (by the code relocator)
;// (i want binary compatible apps on all supported machines)
#define lk_jumptab   $0200  ;// (virtual) start address of kernel jumptable

;// system zeropage

#define lk_ipid        $02  ;// IPID of current task
#define lk_timer       $03  ;// time left for current task (in 1/64s)
#define lk_tsp         $04  ;// pointer to task-superpage (16 bit)
#define lk_sleepcnt    $06  ;// time till next wakeup (16 bit)
#define lk_locktsw     $08  ;// >0 -> taskswitching disabled
#define lk_systic      $09  ;// systic counter (1/64s)  (24 bit)
#define lk_sleepipid   $0c  ;// IPID of task to wakeup next
#define lk_cycletime   $0d  ;// sum of tslice of all running tasks
#define lk_cyclefactor $0e  ;// defines how tslice is calculated from priority

;// additional zp allocations start at $15 and
;// are defined in zp.h !

;// nmizp - only used by NMI-handler 

;// irqzp - may be used by IRQ-handler or between sei/.../cli (=1)
;// tmpzp - may be used between jsr locktsw/.../jsr unlocktsw (=2) or (1)
;// syszp - may be used, when tstatus_szu set or (1) or (2)

;// userzp - use as many bytes as enabled with jsr set_zpsize in a task

;// NMI or IRQ handler have dedicated zeropage areas, they must not modify
;// any other bytes of the zeropage (not even indirect by calling other
;// routines)

#define nmizp          $60    ;// 8 bytes for NMI handler
#define irqzp          $68    ;// 8 bytes for IRQ handler(s)
#define tmpzp          $70    ;// 8 bytes for atomic routines
#define syszp          $78    ;// 8 bytes for reentrant system/library routines
#define userzp         $80    ;// up to 64 bytes for the user

;// ---------------------------------------------------------------------------
;// per task data structures (offset to task-superpage)

;//   parts that are initialized with zero
#define tsp_time    $00       ;// (5 bytes) counts system tics (1/64s)
#define tsp_wait0   $05       ;// wait state code
#  define waitc_sleeping  $01 ;// waiting for wakeup
#  define waitc_wait      $02 ;// waiting for exitcode of child
#  define waitc_zombie    $03 ;// waiting for parent reading exitcode (zombie)
#  define waitc_smb       $04 ;// waiting for free SMB
#  define waitc_imem      $05 ;// waiting for internal memory page
#  define waitc_stream    $06 ;// waiting for stream-data
#  define waitc_semaphore $07 ;// waiting for system semaphore
#  define waitc_brkpoint  $08 ;// waiting for cont. (hit breakpoint)
#  define waitc_conskey   $09 ;// waiting for console key
#define tsp_wait1   $06       ;// wait state sub-code
#define tsp_semmap  $07       ;// 5 bytes (40 semaphores)
#define tsp_signal_vec $0c    ;// 8 16bit signal vectors (16 bytes total)
#  define sig_chld        0   ;// child terminated
#  define sig_term        1   ;// stop-key (CTRL-C, or kill without argument)
#  define sig_kill        9   ;// force process to call suicide routine
#define tsp_zpsize  $1c       ;// must be the last zero initialized item here !
                              ;//  (parts of "addtask.s" depend on this)
#define tsp_ftab    $1d       ;// MAX_FILES bytes file-table (fileno 
                              ;// to SMB-ID mapping)
#  define MAX_FILES       8   ;// max opened files per task
#define tsp_pid     $25       ;// (2 bytes)
#define tsp_ippid   $27       ;// IPID of parent
#define tsp_stsize  $28       ;// size of stored stack
;// inherited stuff  
;// (first inherited item follows! Parts of "addtask.s" depend on this)
#define tsp_pdmajor $29       ;// current device (major)
#define tsp_pdminor $2a       ;// current device (minor)
#define tsp_termwx  $2b       ;// width of attached terminal (X)
#define tsp_termwy  $2c       ;// width of attached terminal (Y)
#define tsp_envpage $2d	      ;// hibyte of environment page
;// end of inherited items! (see "addtask.s")

#define tsp_syszp   $78       ;// room for 8 syszp zeropage registers
#define tsp_swap    $80       ;// room for up to 128 bytes stack
;// ---------------------------------------------------------------------------

;// system memory data - separate for each 64K of memory
;// (memory bank dependent)
#define lk_memnxt    $c000    ;// 256 bytes - 1 byte for each internal page
#define lk_memown    $c100    ;// 256 bytes - 1 byte for each internal page
#  define memown_smb      $20 ;// page used for SMB structures
#  define memown_cache    $21 ;// page used for exec-code cache (unused)
#  define memown_sys      $22 ;// page used for system code/data
#  define memown_modul    $23 ;// page used by module code/data
#  define memown_scr      $24 ;// memory mapped video RAM
#  define memown_netbuf   $25 ;// page used for network buffers
#  define memown_none     $ff ;// unused page
#define lk_memmap    $ff85    ;// 32 bytes - 1 bit for each internal page

;// per task system data (not in tsp for faster access)
;// each arrays of 32 (index is internal task ID)
#define lk_tstatus   $ff05    ;// status of task
#  define tstatus_szu     $80 ;// if task uses the syszp zeropage
#  define tstatus_susp    $40 ;// if task is not getting CPU
#  define tstatus_nonmi   $20 ;// if task has disabled NMI
#  define tstatus_nosig   $10 ;// no signals / no kill (birth/death)
#  define tstatus_pri     $07 ;// priority (value is 1..7, not 0!)
#define lk_tnextt    $ff25    ;// number of next task to switch to
#define lk_tslice    $ff45    ;// length of time slice
#define lk_ttsp      $ff65    ;// hi-byte of tasks TSP

;// SMB related
#define lk_smbmap    $ffa5    ;// 32 bytes, bitmap of unused SMB-IDs
#define lk_smbpage   $ffc5    ;// 32 bytes, base address of SMB-pages (hi byte)
                              ;// (byte 0 not used)
;// semaphores
#define lk_semmap    $ffe5    ;// 5 bytes (enough for 40 semaphores)
#  define lsem_irq1       0   ;// byte 0, bit 0
#  define lsem_irq2       1   ;// byte 0, bit 1
#  define lsem_irq3       2   ;// byte 0, bit 2
#  define lsem_alert      3   ;// byte 0, bit 3
#  define lsem_nmi        4   ;// byte 0, bit 4
;// lsem_nmi marks end of "special" semaphores("kernel/lock.s" depends on this)
#  define lsem_iec        5   ;// byte 0, bit 5  (access to IEC serial bus)
#  define lsem_o65        6   ;// byte 0, bit 6  (o65 relocator and its special variables)

;// other stuff
#define lk_nmidiscnt $ffea    ;// counts number of "nonmi" tasks
#define lk_taskcnt   $ffeb    ;// counts number of tasks (16 bit)
#define lk_modroot   $ffed    ;// root of linked list of modules (16bit)
#define lk_consmax   $ffef    ;// absolute number of consoles
#define lk_archtype  $fff0    ;// machine architecture
#  define larchf_type     %00000011 ;// type of machine
#   define larch_c64       0
#   define larch_c128      1
#   define larch_atari     2
#  define larchf_8500     %00010000 ;// flag for 85xx (not 65xx) CPU
#  define larchf_pal      %00100000 ;// flag for PAL (not NTSC) video hardware
#  define larchf_reu      %01000000 ;// flag for available REU hardware
#  define larchf_scpu     %10000000 ;// flag for available SCPU hardware

;// this is not implemented, hence nonused
#define lk_timedive  $c2c0    ;// exponent of time dic
#define lk_timedivm  $c2e0    ;// mantisse of timediv

;// ---------------------------------------------------------------------------
;// general assembler macros (could move into a seperate file)

;// CPU ignores the following 1 or 2 bytes
#define SKIP_BYTE      .byte $24           ;// 8bit BIT instruction
#define SKIP_WORD      .byte $2c           ;// 16bit BIT instruction
#define SKIP_BYTEV     $24                 ;// 8bit BIT instruction
#define SKIP_WORDV     $2c                 ;// 16bit BIT instruction

#ifndef USING_CA65
;// code relocator continues at "adr" (ignores a region full of data)
#define RELO_JMP(adr)  .byte $0c:.word adr ;// pseudo opcode (16bit argument)
;// code relocator has nothing more to do
#define RELO_END       .byte $02           ;// pseudo opcode (no argument)
#else
;// empty macros for ca65
#define RELO_JMP(adr)
#define RELO_END
#endif

#endif
