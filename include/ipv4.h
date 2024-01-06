#ifndef _IPV4_H
#define _IPV4_H

#begindef IPv4_struct8
  .asc "ip4"
  .byte 5
  IPv4_unlock:   lda #0
                 rts
  IPv4_connect:  jmp lkf_suicide
  IPv4_listen:   jmp lkf_suicide
  IPv4_accept:   jmp lkf_suicide
  IPv4_sockinfo: jmp lkf_suicide
#enddef

#begindef IPv4_struct9
  .asc "ip4"
  .byte 6
  IPv4_unlock:   lda #0
                 rts
  IPv4_connect:  jmp lkf_suicide
  IPv4_listen:   jmp lkf_suicide
  IPv4_accept:   jmp lkf_suicide
  IPv4_sockinfo: jmp lkf_suicide
  IPv4_tcpinfo:  jmp lkf_suicide
#enddef

#define IPV4_TCP     $01
#define IPV4_UDP     $02
#define IPV4_ICMP    $03

#define E_CONTIMEOUT $80
#define E_CONREFUSED $81
#define E_NOPERM     $82
#define E_NOPORT     $83
#define E_NOROUTE    $84
#define E_NOSOCK     $85
#define E_NOTIMP     $86
#define E_PROT       $87
#define E_PORTINUSE  $88

#define IPV4_TCPINFOSIZE 10

#endif
