; Atari DOS 2.0 File System module
;
; Sectors       Use
; -------       ---
; 0             Invalid sector number (valid sectors 1-720)
; 1             Byte    Use
;               ----    ---
;               0       $00
;               1       # of boot sectors, incl. this one (1-3) default 3
;               2-3     $0700 Boot load address 
;               4-5     $0714 Initialization address 
;               6-8     $4C $0714 JMP instruction to init address
;               9       Maximum number of open files, default 3
;               10      Drive bits (0:D1,1:D2,etc), default 3
;               11-127  Free for additional boot loader code
; 2-3           Free for additional boot loader code
; 4-359         Free sectors
;               Byte    Use
;               ----    ---
;               0-124   File data
;               125     7-2: Directory entry number
;                       1-0: High 2 bits of next sector pointer
;               126     Low 8 bits of next sector pointer
;               127     7: Short Sector? 1: Yes 0:No 
;                       6-0: Number of bytes used in this sector
; 360           VTOC (Volume table of contents)
;               Byte    Use
;               ----    ---
;               0       #$02
;               1-2     Total sectors on disk (707 on formatted disk)
;               3-4     Free sectors on disk (0-707)
;               5-9     Unused
;               10-99   Sector 0-719 bitmaps.  Sector 0 is invalid, so it is
;                       never used, sectors 1-3, 360, 361-368 are reserved.
;                       Sector 720 is not included and so is reserved.
;                       7-0: 1=sector free 0:sector used
;               100-127 Unsed (set to 0)
; 361-368       Directory list, "dirlist" (root directory)
;               16 byte directory entry (8 entries/sector, 64 files/disk)
;               Byte    Use
;               ----    ---
;               0       7:1=deleted (free), 0=either free or entry used
;                       6:1=directory entry in use, 0=free slot
;                       5:1=file locked, 0=unlocked, LUnix: 1=read only
;                       4:Unused, LUnix: 1=not readable, 0=readable
;                       3:Unused, LUnix: 1=directory, 0=file
;                       2:Unused, LUnix: 1=text/data, 0=executable
;                       1:Unused, LUnix: 1=symbolic link, 0=normal file/dir
;                       0:1=open for output, 0=not open, LUnix: always 0 
;               1-2     Sectors in the file, LUnix: if directory use 8
;               3-4     First sector of file, LUnix: or new directory list
;               5-15    File name, LUnix: or directory name
; 369-719       Free sectors
; 720           Reserved for DOS 2.0 bug

; Statistics
; ----------
; 707 useable sectors
; 62 files per directory (after . and ..)
; directory takes 8 sectors and 1 directory entry
; 720 sectors*128 bytes per sector=92160 raw bytes per disk
; 707 free sectors*125 bytes per sector=88375 bytes free
; 92160-88375=3785 bytes (approx 30 sectors), or 4.1% overhead

; Filesystem return codes
; -----------------------
; Carry clear: Success
#define fserr_success 0
; Carry set, A=error number:
; Unsupported function
#define fserr_unsupported_function 1
; 01h Invalid filename
#define fserr_invalid_filename 2
; 02h Disk read failure
#define fserr_disk_read_failure 3
; 03h Disk write failure
#define fserr_disk_write_failure 4
; 04h Directory full
#define fserr_directory_full 5
; 05h Not enough disk space
#define fserr_no_disk_space 6
; 06h File not found
#define fserr_file_not_found 7
; 07h Path not found 
#define fserr_path_not_found 8
; 08h Read only
#define fserr_read_only 9
; 09h Write only
#define fserr_write_only 10
; 0Ah File or directory already exists
#define fserr_file_already_exists 11

; Permissions / Attributes
; ------------------------
#define fs_deleted      %10000000
#define fs_used         %01000000
#define fs_read_only    %00100000
#define fs_write_only   %00010000
#define fs_directory    %00001000
#define fs_executable   %00000100
#define fs_symlink      %00000010

; Internal functions
; ------------------
; requires: disk_read_block, disk_write_block, (disk_blocksize), spalloc
; data:
;       fs_mempage(+1) (zeropage)       ; pointer to filesystem memory page
;       fs_memoffset  (zeropage)        ; offset into memory page 
;       fs_drive                        ; current disk drive
; fs_wait_if_busy:
;       pha             ; save a
;       lda     #0      ; fs_busy: 0=available, 1+=busy
;   -   cmp     fs_busy ; filesystem busy?
;       bne     -       ; if yes, wait
;       sei             ; not busy anymore, put interupts on hold a second
;       inc     fs_busy ; set filesystem as busy again 
;       cli             ; restore interrupts
;       pla             ; restore a
;       rts             ; continue with disk i/o operations
;       fs_busy .byte 0 ; 0=available, 1+=busy
; fs_success_exit:
;       ...
; fs_error_exit:
;       ...
; (fs_conv_truename:)
;   (handle this in step 4)
;   (allows checking if file in use, working with "current" directory, etc)
;   (possibly returns error: Invalid filename)
; fs_get_dirlist:
;   (expects seperate pointers to path and filename)
;   (convert pathname to atari filename)
;   (doesn't do this) call conv_truename, if error: return
;   (set starting directory list sector)
;   calls find_directory
;   if error: returns
;   (find filename in directory (read sectors in current directory list))
;   calls find_filename
;   if error: returns
;   returns fs_curr_dirlist, dirlist sector (128 bytes of fs_mempage),
;           fs_offset (offset to dirlist entry)
; fs_find_path:
; flags: 2:1=don't follow directory symlinks
;   ...
;   possibly returns error: Disk read failure
;   possibly returns error: Path not found
; fs_find_filename:
; flags: 0:0=search for file/dir, 1=search for free dir entry
;        1:1=don't follow file symlinks
;   ...
;   possibly returns error: Disk read failure
;   possibly returns error: Directory full
;   possibly returns error: File not found
; fs_read_vtoc:
;   calls disk_read_block
;   ...
;   returns fs_curr_vtoc, VTOC sector (in 2nd 128 bytes of fs_mempage)
;   possibly returns error: Disk read failure
; fs_write_vtoc: (uses fs_curr_vtoc)
;   calls disk_write_block
;   ...
;   possibly returns error: Disk write failure
; fs_read_dirlist:
;   ...
;   possibly returns error: Disk read failure
; fs_write_dirlist:
;   ...
;   possibly returns error: Disk write failure
; fs_get_perms:                  ; return file permissions
;       ...
;       read permissions into A
;       rts
; fs_set_perms:                  ; set file permissions
;       ...
;       set permissions from A
;       rts
; fs_calc_filesize:
;   if sectors=0 return filesize=0
;   calls fs_get_vtoc
;   if error: return
;   trace file to its last sector:
;     read sector from disk
;     possibly returns error: Disk read failure
;     get next sector number
;     add sector size to file size variable
;     if 7th bit of sector is set (EOF), exit (failsafe)
;   return filesize

; External functions
; ------------------
;*********************************************************************
; format disk and write boot sectors:
;*********************************************************************
                jsr     fs_wait_if_busy
;   ...
;   jumps to fs_success_exit

;*********************************************************************
; get free disk space
;*********************************************************************
fs_get_free_disk_space:
                jsr     fs_wait_if_busy
                jsr     fs_read_vtoc
                bcs     fs_error_exit
;!! count number of free sectors (max 707), multiply by 125
                jmp     fs_success_exit

;*********************************************************************
; get volume label
;*********************************************************************
fs_get_volume_label:
                jsr     fs_wait_if_busy
                jsr     fs_read_vtoc
                bcs     fs_error_exit
;!! read VTOC bytes 5-9 (5 bytes, 2 chars per byte, 10 chars total)
;!! (or use bytes in the boot sectors)
;!! write volume label to given memory buffer
                jmp     fs_success_exit

;*********************************************************************
; set volume label, req: label
;*********************************************************************
fs_set_volume_label:
                jsr     fs_wait_if_busy
                jsr     fs_read_vtoc
                bcs     fs_error_exit
;!! use VTOC bytes 5-9 (5 bytes, 2 chars per byte, 10 chars total)
                jsr     fs_write_vtoc
                bcs     fs_error_exit
                jmp     fs_success_exit

;*********************************************************************
; create directory, (req: x/y->pathname of dir)
;*********************************************************************
fs_create_directory:
                ;jsr     fs_wait_if_busy
                lda     #fserr_unsupported_function
                sec
                jmp     fs_error_exit

;*********************************************************************
; delete directory, (req: x/y->pathname of dir)
;*********************************************************************
fs_delete_directory:
                ;jsr     fs_wait_if_busy
                lda     #fserr_unsupported_function
                sec
                jmp     fs_error_exit

;*********************************************************************
; delete directory, (req: x/y->pathname of dir)
;*********************************************************************
fs_get_file_date:
                lda     #fserr_unsupported_function
                sec
                jmp     fs_error_exit

;*********************************************************************
; create symbolic link, (req: x/y->pathname of symlink & file/dir)
;*********************************************************************
                ;jsr     fs_wait_if_busy
                lda     #fserr_unsupported_function
                sec
                jmp     fs_error_exit

;*********************************************************************
; create file, req: x/y->pathname of file
;*********************************************************************
                jsr     fs_wait_if_busy
                lda     #0              ; flags: 0=search for filename              
                jsr     fs_get_dirlist
                bcs     +
; if there wasn't an error that means the file was found, that's bad
                lda     #fserr_file_already_exists
                sec
                jmp     fs_error_exit
; there was an error, make sure it was "file not found"
        +       cmp     #fs_file_not_found
                bne     fs_error_exit 
                lda     #1      ;flags: 0:1=search for empty dirlist entry
                jsr     get_dirlist
                bcs     fs_error_exit
;!! create file in dir. list entry, set readable, writeable, size:0 sectors 
                jsr     fs_write_dirlist
                jmp     fs_success_exit

;*********************************************************************
; delete file, req: pathname of file
;*********************************************************************
                jsr     fs_wait_if_busy
                lda     #00000010       ; flags: 1:1=search for filename              
                jsr     fs_get_dirlist  ;  but don't follow file symlink
                bcs     fs_error_exit
                jsr     fs_get_perms
; returns error if file is read only
                bit     #fs_read_only   
                bne     +
                lda     #fserr_read_only
                sec
                jmp     fs_error_exit
        +
; set deletion bit for file
                jsr     fs_get_perms
                ora     #fs_deleted
                jsr     fs_set_perms
                jsr     fs_write_dirlist
                bcs     fs_error_exit
;!! remember file starting sector and number of sectors in file
;!! if sectors in file=0 then jump to fs_success_exit
                jsr     fs_read_vtoc
                bcs     fs_error_exit
;!! for each sector in file (counts down) {
;!!   set free bit in VTOC for this sector
;!!   read sector from disk
;!!   possibly returns error: Disk read failure
;!!   get next sector number
;!!   if 7th bit of sector is set (EOF), exit (failsafe)
;!! }
                jsr     fs_write_vtoc
                bcs     fs_error_exit
                jmp     fs_success_exit

;*********************************************************************
; get file size, req: pathname of file
;*********************************************************************
                call    fs_wait_if_busy
                lda     #0              ; flags: 0=search for filename              
                jsr     fs_get_dirlist
                bcs     fs_error_exit
;!! remember file starting sector and number of sectors in file
                jsr     fs_calc_filesize
                bcs     fs_error_exit
;!! return file size
                jmp     fs_success_exit

;*********************************************************************
; set file size, req: pathname of file, new file size
;*********************************************************************
                jsr     fs_wait_if_busy
                lda     #0              ; flags: 0=search for filename              
                jsr     fs_get_dirlist
                bcs     fs_error_exit
                jsr     fs_get_perms
;!! possibly returns error: Read only
;!! remember file starting sector and number of sectors in file
                jsr     fs_calc_filesize
                bcs     fs_error_exit
;!! if file will stay the same size
                jmp     fs_success_exit
;!! if enlarging the file:
;!!   if current file size is 0, special case
;!!   ...
                jmp     fs_success_exit
;!! if truncating the file:
;!!   if new file size is 0, special case
;!!   ...
                jmp     fs_success_exit

;*********************************************************************
; get file attributes, req: pathname of file
;*********************************************************************
                jsr     fs_wait_if_busy
                lda     #0              ; flags: 0=search for filename              
                jsr     fs_get_dirlist
                bcs     fs_error_exit
                jsr     fs_get_perms
                bcs     fs_error_exit
;!! convert to LUnix permissions format
                jmp     fs_success_exit

;*********************************************************************
; set file attributes, req: pathname of file, date/time, permissions
;*********************************************************************
                jsr     fs_wait_if_busy
                lda     #0              ; flags: 0=search for filename              
                jsr     fs_get_dirlist
                bcs     fs_error_exit
                jsr     fs_get_perms
;!! convert from LUnix permissions format
;!! set permissions bits
                jsr     fs_set_perms
                jsr     fs_write_dirlist
                bcs     fs_error_exit
                jmp     fs_success_exit

;*********************************************************************
; read from file, req: pathname of file, starting position, number of bytes,
;                      pointer to buffer
;*********************************************************************
                jsr     fs_wait_if_busy
                lda     #0              ; flags: 0=search for filename              
                jsr     fs_get_dirlist
                bcs     fs_error_exit
; returns error if file is write only
                bit     #fs_write_only                      
                bne     +
                lda     #fserr_write_only
                sec
                jmp     fs_error_exit
        +
;   note: check starting position <= length of file
;   note: check trying to read past EOF
;   ...
                jmp     fs_success_exit

;*********************************************************************
; write to file, req: pathname of file, starting position, number of bytes,
;                     pointer to buffer
;*********************************************************************
                jsr     fs_wait_if_busy
                lda     #0              ; flags: 0=search for filename              
                jsr     fs_get_dirlist
                bcs     fs_error_exit
; returns error if file is read only
                bit     #fs_read_only                      
                bne     +
                lda     #fserr_read_only
                sec
                jmp     fs_error_exit
        +
;!! remember file starting sector and number of sectors in file
                jsr     fs_calc_filesize
;!! note: check starting position <= length of file
;!! note: check trying to write past EOF
;!! ...
                jmp     fs_success_exit

;*********************************************************************
; get pointer to directory
;*********************************************************************
                jsr     fs_wait_if_busy
;!! ...
;!! returns pointer to dirlist & entry
                jmp     fs_success_exit

;*********************************************************************
; get name of next file in directory, req:pointer to dir/entry, buffer
;*********************************************************************
                jsr     fs_wait_if_busy
;!! ...
;!! returns filename in buffer 
                jmp     fs_success_exit
