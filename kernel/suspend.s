#include <system.h>
		
.global suspend 
.global block

		;; function: block
		;; suspend current task
		;; < A=wait code 0 (waitc_...)
		;; < X=wait code 1 (additional parameter)		
		;; changes: context
		;; calls: p_remove
block:	
suspend:		; A/X=waitstate
		php
		sei
		ldy  #tsp_wait0
		sta  (lk_tsp),y
		txa
		ldy  #tsp_wait1
		sta  (lk_tsp),y
		ldx  lk_ipid
		jsr  p_remove
		plp
		jmp  force_taskswitch

