		;; memory map
		;; tells mpalloc and spalloc which pages are not available in
		;; "no I/O" mode

; the Famicom with disk system doesn't have RAM overlapping I/O.
io_map:	.byte $ff,$ff,$ff,$ff	; $0000-$1fff
		.byte $ff,$ff,$ff,$ff	; $2000-$3fff
		.byte $ff,$ff,$ff,$ff	; $4000-$5fff
		.byte $ff,$ff,$ff,$ff	; $6000-$7fff
		.byte $ff,$ff,$ff,$ff	; $8000-$9fff
		.byte $ff,$ff,$ff,$ff	; $a000-$bfff
		.byte $ff,$ff,$ff,$ff	; $c000-$dfff
		.byte $ff,$ff,$ff,$ff	; $e000-$ffff
