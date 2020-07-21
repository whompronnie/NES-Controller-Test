  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring
  

;;;;;;;;;;;;;;;

    
  .bank 0
  .org $C000 
RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait1

clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x
  INX
  BNE clrmem
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2


LoadPalettes:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006             ; write the high byte of $3F00 address
  LDA #$00
  STA $2006             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        ; load data from address (palette + the value in x)
                          ; 1st time through loop it will load palette+0
                          ; 2nd time through loop it will load palette+1
                          ; 3rd time through loop it will load palette+2
                          ; etc
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down



LoadSprites:
  LDX #$00              ; start at 0
LoadSpritesLoop:
  LDA sprites, x        ; load data from address (sprites +  x)
  STA $0200, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16
  BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to 16, keep going down
              
              

LoadBlue:				; Load blue background
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$20
  STA $2006             ; write the high byte of $2000 address
  LDA #$00
  STA $2006             ; write the low byte of $2000 address
  LDX #$00              ; start out at 0
  LDY #$00
LoadBlueLoop:
  LDA background     ; load data from address (background + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $20, decimal 32 - copying 32 bytes
  BEQ BlueIncrementY	
  JMP LoadBlueLoop
BlueIncrementY:
  LDX #$00
  INY                   ; At the end of each row, jump to the next row using Y
  CPY #$1E
  BNE LoadBlueLoop
  
LoadBackground:			; Load controller background
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$21
  STA $2006             ; write the high byte of $2000 address
  LDA #$40
  STA $2006             ; write the low byte of $2000 address
  LDX #$00              ; start out at 0
  LDY #$00
LoadBackgroundLoop:
  LDA background, x     ; load data from address (background + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$80              ; Compare X to hex $80, decimal 128 - copying 128 bytes
  BEQ BGIncrementY
  JMP LoadBackgroundLoop
BGIncrementY:
  LDX #$00
  INY
  CPY #$01
  BNE LoadBackgroundLoop
              
              
LoadAttribute:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$23
  STA $2006             ; write the high byte of $23C0 address
  LDA #$C0
  STA $2006             ; write the low byte of $23C0 address
  LDX #$00              ; start out at 0
LoadAttributeLoop:
  LDA attribute, x      ; load data from address (attribute + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$08              ; Compare X to hex $08, decimal 8 - copying 8 bytes
  BNE LoadAttributeLoop  ; Branch to LoadAttributeLoop if compare was Not Equal to zero
                        ; if compare was equal to 128, keep going down


              
              
              
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000

  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001

Forever:
  JMP Forever     ;jump back to Forever, infinite loop
  
 

NMI:
  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer


LatchController:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016       		; tell both the controllers to latch buttons
  
ClearSprites:
  LDX #$01              ; start at 1
ClearSpritesLoop:
  LDA sprites, x        ; load data from address (sprites +  x)
  STA $0200, x          ; store into RAM address ($0200 + x)
  TXA
  CLC
  ADC #$04
  TAX
  CPX #$21              ; Compare X to hex $21, decimal 33
  BNE ClearSpritesLoop

ReadButtons:
  LDX #$00
  LDY #$00
ReadButtonsLoop:
  LDA $4016
  AND #%00000001
  BEQ ReadSkip
  LDA spritesOff, x
  STA $0201, y
ReadSkip:
  INX
  TXA
  CLC
  ASL A
  CLC
  ASL A
  TAY
  CPX #$08
  BNE ReadButtonsLoop
ReadFinish:


  ;;This is the PPU clean up section, so rendering the next frame starts properly.
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000
  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001
  LDA #$00        ;;tell the ppu there is no background scrolling
  STA $2005
  STA $2005
  
  RTI             ; return from interrupt
 
;;;;;;;;;;;;;;  
  
  
  
  .bank 1
  .org $E000
palette:
  .db $22,$20,$15,$0D,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $22,$27,$17,$0F   ;;background palette
  .db $22,$15,$30,$1D,  $22,$02,$38,$3C,  $22,$1C,$15,$14,  $22,$02,$38,$3C   ;;sprite palette

sprites:
     ;vert tile attr horiz
  .db $5E, $00, $00, $94   ;A
  .db $5E, $01, $00, $8A   ;B
  .db $5E, $02, $00, $76   ;Select
  .db $5E, $02, $40, $7E   ;Start
  .db $58, $03, $00, $66   ;Up
  .db $60, $03, $80, $66   ;Down
  .db $5D, $04, $00, $62   ;Left
  .db $5D, $04, $40, $6A   ;Right
  
spritesOff:
  .db $10, $11, $12, $12, $13, $13, $14, $14


background:
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$54,$54,$54,$54,$54,$54,$54,$55,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 1 - Controller BG Sprites
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$59,$5B,$5B,$5B,$5B,$5B,$5B,$5B,$5B,$5A,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 2
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$59,$5B,$5B,$5B,$5B,$5B,$5B,$5B,$5B,$5A,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 3
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$56,$57,$57,$57,$57,$57,$57,$57,$57,$58,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 4
  
attribute:
  .db %00000000, %00010000, %01010000, %00010000, %00000000, %00000000, %00000000, %00110000

  .db $24,$24,$24,$24, $47,$47,$24,$24 ,$47,$47,$47,$47, $47,$47,$24,$24 ,$24,$24,$24,$24 ,$24,$24,$24,$24, $24,$24,$24,$24, $55,$56,$24,$24  ;;brick bottoms



  .org $FFFA     ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial
  
  
;;;;;;;;;;;;;;  
  
  
  .bank 2
  .org $0000
  .incbin "custom.chr"   ;includes 8KB graphics file from SMB1