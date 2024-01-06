#ifndef _RS232_H
#define _RS232_H

;// general RS232 defines

#define RS232_baud300   0
#define RS232_baud600   1
#define RS232_baud1200  2
#define RS232_baud2400  3
#define RS232_baud4800  4
#define RS232_baud9600  5
#define RS232_baud19200 6
#define RS232_baud38400 7
#define RS232_baud57600 8

#begindef RS232_sstruct4
  .asc "ser"
  .byte 4
rs232_unlock: lda  #0
              rts
rs232_ctrl:  jmp  lkf_suicide
rs232_getc:  jmp  lkf_suicide
rs232_putc:  jmp  lkf_suicide
#enddef

#begindef RS232_struct2
  .asc "ser"
  .byte 2
rs232_unlock: lda  #0
              rts
rs232_ctrl:  jmp  lkf_suicide
#enddef


#endif
