#ifndef _IDENT_H
#define _IDENT_H

#ifndef USING_CA65

;// macros for luna

; RCS and Amiga compatible identification tag
#begindef ident(string,number)
   .text "$VER: "
   .text "string "
   .text "number "
   .text _DATE_
   .text "$",0
#enddef

#else

;// macros for ca65

#begindef ident(string,number)
   .byte "$VER: "
   .byte "string "
   .byte "number "
   .byte _DATE_
   .byte "$",0
#enddef

#endif

#endif
