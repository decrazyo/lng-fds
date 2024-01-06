#ifndef _REU_H
#define _REU_H

# define REU_BASE     $df00

# define REU_status   REU_BASE
# define REU_command  REU_BASE+1
#  define REUcmd_int2reu %00000000
#  define REUcmd_reu2int %00000001
#  define REUcmd_swap    %00000010
#  define REUcmd_compare %00000011
#  define REUcmd_noff00  %00010000
#  define REUcmd_load    %00100000
#  define REUcmd_execute %10000000
# define REU_intbase  REU_BASE+2
# define REU_reubase  REU_BASE+4
# define REU_translen REU_BASE+7
# define REU_irqmask  REU_BASE+9
# define REU_control  REU_BASE+10
#  define REUcontr_fixreuadr %01000000
#  define REUcontr_fixintadr %10000000

#endif
