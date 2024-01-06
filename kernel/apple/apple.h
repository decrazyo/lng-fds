#ifndef _APPLE_H
#define _APPLE_H

;// hardware related

#define STORE80off      $c000   ; write
#define STORE80on       $c001   ; write
#define RAMRDoff        $c002   ; write
#define RAMRDon         $c003   ; write
#define RAMWRToff       $c004   ; write
#define RAMWRTon        $c005   ; write
#define slotcxROMoff    $c006   ; write = 0
#define slotcxROMon     $c007   ; write internalrom  c100-cfff
#define ALTZPoff        $c008   ; write
#define ALTZPon         $c009   ; write
#define slotc3ROMoff    $c00a   ; write internalC3rom
#define slotc3ROMon     $c00b   ; write
#define VID80off        $c00c   ; write
#define VID80on         $c00d   ; write
#define ALTCHARoff      $c00e   ; write
#define ALTCHARon       $c00f   ; write
;#define c010           clear keyboard strobe
;#define c011           and 
Press any key to return to index.am card status
#define RAMRD           $c013   ; read  for status
#define RAMWRT          $c014   ; read  for status
#define slotcxrom       $c015   ; read  status 
#define ALTZP           $c016   ; read  for status
#define slotc3rom       $c017   ; read  status
#define STORE80         $c018   ; read  for status
#define VBL             $c019   ; is the  switch (use random numbers)
#define TEXT            $c01a   ; read  for status
#define MIXED           $c01b   ; read  for status
#define PAGE2           $c01c   ; read  for status
#define HIRES           $c01d   ; read  for status
#define ALTCHAR         $c01e   ; read  for status
#define VID80           $c01f   ; read  for status 
#define CASSO           $c020   ; W
#define TEXToff         $c050   ; R/W   for (graphics on)
#define TEXTon          $c051   ; R/W   for
#define MIXEDoff        $c052   ; R/W   for (only text or only graphics)
#define MIXEDon         $c053   ; R/W   for
#define PAGE2off        $c054   ; R/W   for
#define PAGE2on         $c055   ; R/W   for
#define HIRESoff        $c056   ; R/W   for
#define HIRESon         $c057   ; R/W   for
#define DHGRon          $c05e   ; R/W   for
#define DHGRoff         $c05f   ; R/W   for
#define CASSIN          $c060   ; R
#define BUTTON0         $c061   ; read  for 
#define BUTTON1         $c062   ; read  for 
#define PDLTRIG         $c070   ; R/W
#define DHGR            $c07f   ; read  for status

#endif
