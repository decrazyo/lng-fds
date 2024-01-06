#ifndef _KERRORS_H
#define _KERRORS_H

;// kernel error numbers

#define lerr_stackoverflow $ff
#define lerr_nohook        $fe
#define lerr_illarg        $fd
#define lerr_nosem         $fc
#define lerr_deverror      $fb
#define lerr_illfileno     $fa
#define lerr_nosuchfile    $f9
#define lerr_notimp        $f8
#define lerr_outofmem      $f7
#define lerr_toomanyfiles  $f6
#define lerr_eof           $f5
#define lerr_brokenpipe    $f4
#define lerr_tryagain      $f3
#define lerr_ioerror       $f2
#define lerr_illcode       $f1
#define lerr_nosuchmodule  $f0
#define lerr_illmodule     $ef
#define lerr_toomanytasks  $ee
#define lerr_discfull      $ed
#define lerr_readonlyfs    $ec
#define lerr_filelocked    $eb
#define lerr_fileexists    $ea
#define lerr_nosuchpid     $e9
#define lerr_killed        $e8
#define lerr_nosuchdir     $e7
#define lerr_segfault      $e6

#endif



