						
_initmemmap:
		.byte $3f,$ff,$ff,$ff	; $0000-$1fff  (pages 0,1 not available)
		.byte $ff,$ff,$ff,$ff	; $2000-$3fff
		.byte $ff,$ff,$ff,$ff	; $4000-$5fff
		.byte $ff,$ff,$ff,$ff	; $6000-$7fff
		.byte $ff,$ff,$ff,$ff	; $8000-$9fff
		.byte $ff,$ff,$ff,$ff	; $a000-$bfff
		.byte $ff,$ff,$00,$00	; $c000-$dfff
		.byte $ff,$ff,$ff,$fe	; $e000-$ffff  (page 255 not available)
		
		;; I/O area is disabled since switching I/O area on/off is not
		;; implemented yet

		;; HAVE_REU -> $d200-$d3ff locked !