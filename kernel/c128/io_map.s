		;; memory map
		;; tells mpalloc and spalloc which pages are not available in
		;; "no I/O" mode
		
io_map:	.byte $ff,$ff,$ff,$ff	; $0000-$1fff
		.byte $ff,$ff,$ff,$ff	; $2000-$3fff
		.byte $ff,$ff,$ff,$ff	; $4000-$5fff
		.byte $ff,$ff,$ff,$ff	; $6000-$7fff
		.byte $ff,$ff,$ff,$ff	; $8000-$9fff
		.byte $ff,$ff,$ff,$ff	; $a000-$bfff
		.byte $ff,$ff,$00,$00	; $c000-$dfff ($d000-$dfff is I/O)
		.byte $ff,$ff,$ff,$fe	; $e000-$ffff ($ff00-$ff04 is MMU...)
