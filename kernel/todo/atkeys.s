
; this code is placed here only to have in place draft for R/W PCAT keyboard
; protocol implementation

;PC AT KEYBOARD SCANNER
;SEEMS TO WORK RELIABLY
;(SCANNER IS BELIEVED TO WORK SUCH
; WITH SEI)

;THERE ARE UNKNOWN PROBLEMS WITH
;WRITE, MAYBE IT'S BECAUSE A.REPLAY...

;BASED ON JIM ROSEMARY'S AND
;ILKER FICICILAR'S CODE

;MACIEJ WITKOWIAK <YTM@FRIKO.ONET.PL>
;11.02.2000


BYTE     = $FF

         *= $2000




         JMP READKEYBOARD
         JMP WRITEKEYBOARD

RESETKEYBOARD
       ;  INC $D030
RKLP     LDA #$FF
       ;  JSR WRITEKEYBOARD
         JSR READKEYBOARD
         CMP #$FA
       ;  BNE RKLP
RKLP2  ;  JSR READKEYBOARD
         INC $D020
         CMP #$AA
       ;  BNE RKLP2

         INC $D020
RKLP3    LDA #$ED
         JSR WRITEKEYBOARD
         JSR READKEYBOARD
         LDA #$ED
       ;  JSR WRITEKEYBOARD
         STA $0400
        ; CMP #$FE
        ; BEQ RKLP3
        ; JSR READKEYBOARD
        ; LDA $DC0D
RKLP4   ; INC $D020
         LDA #3
         JSR WRITEKEYBOARD
         JSR READKEYBOARD
         LDA #3
         JSR WRITEKEYBOARD
         STA $0401
        ; BEQ FINFF
        ; CMP #$FA
        ; BNE RKLP4
        ; DEC $D030
FINFF    RTS

;---------------------------------------
READKEYBOARD
         SEI
         JSR SCAN
         CLI
         RTS

;---------------------------------------
         SEI
         LDA #<IRQ
         LDX #>IRQ
         STA $0314
         STX $0315
         LDA $DC0D
         CLI
         RTS

IRQ      INC $D020
         JSR SCAN
         BEQ DD
         STA $0400
DD
         DEC $D020
         JMP $EA31

SCAN
         ; ALLOW KEYBOARD SENDING
         ; DATA (CLK=H, DATA=H)

         LDA 0
         AND #%11100111
         STA 0

         LDA $D012
         CLC
         ADC #$28
         TAY

         ;WAIT FOR START BIT
         ;TIMEOUT IS SET TO $24 RASTER
         ;LINES (ABOUT 0.00225S)
         ;($28=0.0025S)

         LDA #%00011000
L0       CPY $D012
         BEQ LX
         BIT 1
         BNE L0

         LDA #$08
L1       BIT 1
         BEQ L1

         ;CLEAR ANY CLOCK TICKS
         LDA $DC0D

         ;GET 8 BITS

         LDY #9
L2       LDA $DC0D
         BEQ *-3

         LDA 1
         AND #$10
         CMP #$10
         ROR BYTE

         LDA #8
L3       BIT 1
         BEQ L3

         DEY
         BNE L2

         ROL BYTE

         ; GET STOP BIT

         LDA $DC0D
         BEQ *-3

L5       BIT 1
         BEQ L5

         ; PREVENT KEYBOARD FROM
         ; SENDING ANYTHING MORE
         ; (CLK=L, DATA=H)

L6       LDA 0
         ORA #%00011000
         STA 0
         LDA 1
         AND #%11100111
         ORA #%00010000
         STA 1
         LDA BYTE
FIN
         RTS

         ; THIS IS EXIT IN CASE NOTHING
         ; WAS RECEIVED WHEN TIMEOUT
         ; OCCURED

LX       LDA #0
         STA BYTE
         BEQ L6

;---------------------------------------

WRITEKEYBOARD STA $FF

WRITE
         SEI
         ;PRESERVE EVERYTHING
         LDA $00
         PHA
         LDA $01
         PHA

         ;TAKEOVER CLOCK AND DATA
         ;(BOTH BECOME LOW)

         LDA $00
         AND #%11100111
         ORA #%00011000
         STA $00
         LDA $01
         AND #%11100111
         STA $01

         ;CLEAR ICR

         LDA $DC0D

         ;NOW WAIT 60US

         LDX #$C0
         DEX
         BNE *-1

         ;RELEASE CLOCK (INPUT)

         LDA $00
         AND #%11100111
         ORA #%00010000
         STA $00

         ;SEND STARTBIT (DATA IS STILL
         ;LOW)

         LDA $DC0D
         BEQ *-3

;         LDA #8
;S0       BIT 1
;         BEQ S0
;
;S1       BIT 1
;         BNE S1

         ;SEND 8 DATABITS

         LDX #8
         LDY #1
WRLP     LSR BYTE

;WRITEBIT
         LDA $00
         AND #%11101111
         BCS WBSEND1
         ORA #%00010000
         INY
WBSEND1  STA $00

;         LDA #8
;WB0      BIT 1
;         BEQ WB0
;WB1      BIT 1
;         BNE WB1
         LDA $DC0D
         BEQ *-3

;WRITEBITEND

         DEX
         BNE WRLP

         ;SEND PARITY (POSITIVE)

         TYA
         LSR A

;WRITEBIT
         LDA $00
         AND #%11101111
         BCS WBSEND11
         ORA #%00010000
         INY
WBSEND11 STA $00

;         LDA #8
;WB10     BIT 1
;         BEQ WB10
;WB11     BIT 1
;         BNE WB11
         LDA $DC0D
         BEQ *-3
;WRITEBITEND

         ;WAIT FOR HANDSHAKE

         LDA #8
S2       BIT 1
         BNE S2

         ;RESTORE CONFIG
         PLA
         STA $01
         PLA
         STA $00
         CLI
         RTS

;---------------------------------------

