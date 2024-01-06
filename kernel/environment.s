		;; environment variables hander
		;;
		;; variables are kept in only one memory page in structure:
		;; "NAME=VALUE",0,"NAME=VALUE",0,0
		;; future extension might use first byte of this table as
		;; pointer to next page
		;;
		;; Maciej 'YTM/Elysium' Witkowiak <ytm@elysium.pl>
		;; 01.04.2002
		;;

#include <config.h>
#include <system.h>
#include <zp.h>

		.global getenv
		.global setenv

get_env_parameters:
		;; allocate syszp and store A/Y in syszp+0/1
#ifndef ALWAYS_SZU
		sei
		sta  syszp
		sty  syszp+1		; target pointer
		ldx  lk_ipid
		lda  #tstatus_szu
		ora  lk_tstatus,x
		sta  lk_tstatus,x
		cli
#else
		sta  syszp
		sty  syszp+1		; target pointer
#endif
		lda  #0
		sta  syszp+2
		ldy  #tsp_envpage
		lda  (lk_tsp),y
		sta  syszp+3
		rts

		;; function: getenv
		;; find environment variable
		;; changes: syszp(0,1,2,3,4,5)

		;; <A/Y=variable name "NAME",0
		;; >A/Y=pointer to "value",0
		;;      or 0/0 if not found (checking X offset is enough)
		;;	or 0/0 if no environment page (0 in env_page)

getenv:
		jsr  get_env_parameters
		beq  _not_found			; environment erased

		ldy  #0
	-	sty  syszp+4
		lda  (syszp+2),y		; not end of env page
		beq  _not_found
		ldy  #0
		sty  syszp+5
	-	ldy  syszp+4			; compare names in loop
		lda  (syszp+2),y
		ldy  syszp+5
		cmp  (syszp),y
		bne  +				; different - something found?
		inc  syszp+4
		inc  syszp+5
		lda  syszp+4
		bne  -
		beq  _not_found			; end of env page

	+	lda  (syszp),y			; end of target?
		bne  _rewind_src		; rewind source to next var
		ldy  syszp+4
		lda  (syszp+2),y
		cmp  #"="			; end of source?
		beq  _found_var

_rewind_src:	ldy  syszp+4
	-	iny
		lda  (syszp+2),y
		bne  -
	+	iny
		jmp  ---			; go to next variable

_not_found:	lda  #0
		tay
		rts

_found_var:	iny				; go past '='
		tya
		ldy  syszp+3
		rts

		;; function: setenv
		;; set environment variable, setting to empty value will delete variable
		;; changes: syszp(0,1,2,3,4,5)

		;; >A/Y=variable 'NAME=value',0
		;; C=0 no error
		;; C=1 if environment full (variable NAME will be erased if existed before)
		;;     if bad form (w/o '=')
		;;     if environment not present (0 as env_page)

_bad_form:	sec
		rts

setenv:
		jsr get_env_parameters
		bne +
		sec				; no environment page
		rts

	+	ldy #0
	-	lda (syszp),y			; search for '='
		beq _bad_form
		cmp #"="
		beq +
		iny
		bne -
	+	lda syszp+1			; getenv will change syszp0-5
		pha
		lda syszp
		pha
		tya
		pha				; remember offset of '='
		lda #0
		sta (syszp),y			; truncate to 'NAME'
		lda syszp
		ldy syszp+1
		jsr getenv
		sta syszp+2
		sty syszp+3			; remember position in env table
		pla
		sta syszp+4
		tay
		pla
		sta syszp
		pla
		sta syszp+1

		lda #"="
		sta (syszp),y			; restore 'NAME=value'
		iny
		lda (syszp),y			; get next character after '='
		bne +
		lda #0				; nothing - clear variable
		tay
		sta (syszp),y

    +		lda syszp+2
		ora syszp+3
		beq _do_strcat			; skip if variable was not found

		dec syszp+2			; one character for '='
		lda syszp+2
		sec
		sbc syszp+4			; variable name length
		sta syszp+2			; find start of string

		ldy #0
	-	lda (syszp+2),y			; find start of next variable
		beq +
		iny
		bne -
	+	iny
		sty syszp+4
		lda syszp+2
		clc
		adc syszp+4
		sta syszp+4
		lda syszp+3
		sta syszp+5			; now syszp+4/5 points to next variable

		ldy #0
	-	lda (syszp+4),y			; copyback env tab
		sta (syszp+2),y
		inc syszp+4
		inc syszp+2
		lda syszp+4
		bne -
		beq +				; syszp+4/5 points to start of env tab now

_do_strcat:	ldy #tsp_envpage		; concatenate variable to the end - set
		lda (lk_tsp),y			; syszp+4/5 to start of env tab
		sta syszp+5
		lda #0
		sta syszp+4

	+	ldy #0		
	-	lda (syszp+4),y
		beq +				; is it end of tab? (...,0,0)
		iny
		bne -
		beq _env_error			; crossed page - error
	+	iny
		lda (syszp+4),y			; is there next variable?
		bne -				; no - keep searching

		cpy #1				; fix for empty table
		bne +
		dey
	+	sty syszp+4			; syszp+4/5 points to end of tab - strcat

		ldy #0
	-	lda (syszp),y
		sta (syszp+4),y
		beq +				; end
		iny
		cpy #$ff
		bne -
		lda #0				; crossed page - error
		tay
		sta (syszp+4),y			; fix end marker in env tab
_env_error:	sec
		rts

	+	lda #0
		sta (syszp+4),y			; put end of env tab marker
		clc
		rts
