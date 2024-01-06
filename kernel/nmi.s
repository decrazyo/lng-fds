		;; For emacs: -*- MODE: asm; tab-width: 4; -*-
		
;
; new NMI, BRK routines, lock/unlock semaphores
;

#include <system.h>
#include <config.h>
#include MACHINE_H
          
.global nmi_handler
.global brk_handler
.global _nmi_jobptr

nmi_handler:  
		pha						; old kernal jumps in here
		txa
		pha
		tya
		pha
		tsx
		lda  $104,x
		and  #$10
		bne  brk_handler		; check if it was a BRK-instruction
		GETMEMCONF				; remeber memory-configuration
		pha
		lda  #MEMCONF_SYS		; value for (IRQ/NMI memory configuration)
		SETMEMCONF				; switch to LUnix memory configuration
_nmi_jobptr:
		bit  $ffff				; placeholder for one NMI-routine
		pla
		SETMEMCONF				; restore memory-configuration
		pla						; restore register and return
		tay
		pla
		tax
		pla
		rti
          
brk_handler:
		sei						; catch BRKs
		lda  $106,x				; BRK=breakpoint, will block process
		tay						; get the address of the BRK-command
		lda  $105,x				; add 1 to point to the next byte
		sec
		sbc  #1					; ((this is a 6502 bug ehhh feature !
		sta  tmpzp				;   rti after BRK will return 2 bytes
		bcs  +					;   after the BRK-command instead of 1
		dey						;   byte))
	+	sty  tmpzp+1
		ldy  #0
		lda  (tmpzp),y
		tax						; get byte <bb> after BRK-instruction
		lda  #waitc_brkpoint	; block with waitstate XX <bb>
		jsr  block
		cli
		;; return to programm
		rti





