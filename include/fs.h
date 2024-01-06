#ifndef _FS_H
#define _FS_H

#define MAJOR_PIPE    1
#define MAJOR_CONSOLE 2
#define MAJOR_SYS     3
#define MAJOR_USER    4
#define MAJOR_IEC     5
#define MAJOR_IDE64   6

#define fmode_ro  0
#define fmode_wo  1
#define fmode_rw  2
#define fmode_a   3

#define fcmd_del   0
#define fcmd_chdir 1
#define fcmd_mkdir 2
#define fcmd_rmdir 3
#define fcmd_fsck  4

#define fsmb_major 0
#define fsmb_minor 1
#define fsmb_rdcnt 2
#define fsmb_wrcnt 3
#define fsmb_flags 4
#  define fflags_read  $80  ; stream is readable
#  define fflags_write $40  ; stream is writable

#define psmb_otherid 5 ; SMB-ID of other end of pipe
#define psmb_flags 6
#  define pflags_large $80  ; SMB holds pointer to data-pages
#  define pflags_full  $40  ; pipe-buffer is full
#  define pflags_empty $20  ; pipe-buffer is empty
#  define pflags_wrwait $10 ; writing process is waiting for buffer space
#  define pflags_rdwait $08 ; reading process is waiting for data
#define psmb_rdpos 7
#define psmb_wrpos 8
#define psmb_rdptr 9
#define psmb_wrptr 10

#define iecsmb_status 5
#  define iecstatus_devnotpresent $80
#  define iecstatus_eof           $40
#  define iecstatus_timeout       $20
#define iecsmb_secadr 6
#define iecsmb_dirstate 7

#define usersmb_ufunc 5
#define fsuser_fgetc  1
#define fsuser_fputc  2
#define fsuser_fclose 3
#endif

#define DIRSTRUCT_LEN 29 ; max size of dirstruct (including filename)
#define MAX_FILENAME  17 ; max length of filename (not incl. 0 termination)
