
; page(s)	| disable reason
; 0 		| zeropage
; 1 		| stack
; 8-15		| mirror of pages 0-7
; 16-23		| mirror of pages 0-7
; 24-31		| mirror of pages 0-7
; 32-63		| PPU registers and mirrors
; 64		| APU registers, I/O registers, FDS registers, and unmapped addresses
; 65-95		| unmapped addresses
; 223		| system memory data and pseudo-reset vectors
; 224-255	| FDS BIOS ROM

_initmemmap:
		.byte $3f,$00,$00,$00 ; $0000-$1fff system RAM and mirrors
		.byte $00,$00,$00,$00 ; $2000-$3fff PPU registers and mirrors
		.byte $00,$00,$00,$00 ; $4000-$5fff APU registers, I/O registers, FDS registers, and unmapped addresses
		.byte $ff,$ff,$ff,$ff ; $6000-$7fff cartridge RAM
		.byte $ff,$ff,$ff,$ff ; $8000-$9fff cartridge RAM
		.byte $ff,$ff,$ff,$ff ; $a000-$bfff cartridge RAM
		.byte $ff,$ff,$ff,$fe ; $c000-$dfff cartridge RAM, system memory, and pseudo-reset vectors
		.byte $00,$00,$00,$00 ; $e000-$ffff FDS BIOS ROM
