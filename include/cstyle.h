#ifndef _CSTYLE_H
#define _CSTYLE_H

#ifdef USING_CA65
#include <cstyle.ca65.h>
#else

;// macros for luna

;// macros for if, ifnot, else and endif

#begindef if(cond)
  cond  +   ;// if
  jmp   _if%%next,push,ptop%%
  +
#enddef

#define ifnot(cond) cond  _if%%next,push,ptop%%  ; ifnot

#begindef else
  jmp  %%next,push,ptop%% 
_if%%swap,ptop,pop%%:  ;// else
#enddef

#define endif _if%%ptop,pop%%:  ; endif

;// macros for while, whilenot, wend

#begindef while(cond)
_wh%%next,push,ptop%%:  ;// while
  cond +
  jmp  _wh%%next,push,ptop%%
  +
#enddef

#begindef whilenot(cond)
_wh%%next,push,ptop%%:  ;// whilenot
  cond  _wh%%next,push,ptop%%
#enddef

#begindef wend
  jmp _wh%%plast 1%%  ;// wend
_wh%%ptop,pop,pop%%: 
#enddef
  
;// macros for repeat, until, untilnot=aslongas

#begindef repeat
_ru%%next,push,ptop%%:  ;// repeat
#enddef

#begindef until(cond)
  cond  +  ; until
  jmp  _ru%%ptop,pop%%
  +
#enddef

#define untilnot(cond) cond  _ru%%ptop,pop%%  ; untilnot
#define aslongas(cond) cond  _ru%%ptop,pop%%  ; aslongas

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
   .byte $0c
   .word __pr%%pcur%%
 __pr%%ptop%%: 
   .text "string",0
 __pr%%pcur,pop%%:
#enddef

;// load effective address

#begindef lea_xa(address)
   bit  address
   lda  *-1 ; #>address
   ldx  #<address
#enddef

#begindef lea_ay(address)
   bit  address
   ldy  *-1 ; #>address
   lda  #<address
#enddef

#endif

#endif


