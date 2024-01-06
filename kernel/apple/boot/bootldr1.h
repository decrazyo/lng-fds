; What slot the disk controller is in.

#define DII_SLOT	6
#define DII_SLOT2	$0600

; How many sectors do we want to read from track 0? (valid: $1 to $E (15))

#define load_amt	$0E

; What page of memory do we want to start loading track 0, sector 1-x data?

#define load_adr	$10

; Define bloatware - code not necessary, but useful (prints a handy "loading"
; message)

#define BLOATWARE

; (end of user-definable variables)

; Zero-page location of buf pointer from Disk II ROM.
; This is a word that points to the location in Apple II memory to load
; disk bytes into (eg, $00 $08 for $0800 bootup code, etc)

#define DII_rdptr	$26			; PTR2BTBUF

; Disk II ROM's read sector subroutine which we will use to read sectors.
; Variables in zeropage that specify what track and sector to read.

#define DII_rdsec	$C05C+DII_SLOT2
#define DII_trk		$41			; BOOTRK
#define DII_sec		$3D			; BOOTSEC
#define DII_slt16	$2B			; SLT16ZPG

