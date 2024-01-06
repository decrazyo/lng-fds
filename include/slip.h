#ifndef _SLIP_H
#define _SLIP_H

#begindef SLIP_struct3
  .asc "pkg"
  .byte 3
  slip_unlock: lda  #0
               rts
  slip_putpacket: jmp lkf_suicide
  slip_getpacket: jmp lkf_suicide
#enddef

#endif
