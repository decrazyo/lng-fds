#ifndef _CSTYLE_CA65_H
#define _CSTYLE_CA65_H

;// lupo macros for ca65

;// special macros (C-Stylish) for the current version
;// of LUnix next generation

;// must include system.h or exit won't work
#include <system.h>
#include <stdio.h>

;// exit(exitcode) macro

#begindef exit(code)
  lda  #code
  jmp  lkf_suicide
#enddef

#begindef set_zeropage_size(value)
  lda  #value
  jsr  lkf_set_zpsize
#enddef

;// print_string("Hello World\n") macro
;// doesn't confuse +/- shortcuts of luna

#begindef print_string(string)
   ldx  #stdout
   bit  __pr%%next,pcur,push%%
   jsr  lkf_strout
   jmp  __pr%%next,pcur%%
 __pr%%ptop%%: 
   .asciiz "string"
 __pr%%pcur,pop%%:
#enddef

;// load effective address

#begindef lea_xa(address)
    lda #>address
    ldx #<address
#enddef

#begindef lea_ay(address)
    ldy #>address
    lda #<address
#enddef

#endif


