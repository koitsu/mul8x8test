; mul8x8test.asm
;
; Author: Jeremy Chadwick (koitsu) <jdc@koitsu.org>
;
; Intended for use with ca65/ld65 and Mesen (AppVeyor builds)
;
; https://github.com/cc65/cc65/blob/master/README.md
; https://ci.appveyor.com/project/Sour/mesen/build/artifacts
;
; Subroutines taken from their respective sources, and may have
; been slightly modified for the explicit constraints of the test and
; thus this program.
;
; To accomplish all of this, Mesen's Lua support is used to tell the
; emulator to print cycle counts in the Script Window log area.
; ------------------------------------------------------------------------

.setcpu "6502"

; Zero page locations for tests.  These must match the locations defined
; in mul8x8test.lua (particularly multiplier and multiplicand).
;
; Normally I'd have put these in .SEGMENT "ZEROPAGE" or some equivalent
; that mapped exactly where we expect, but it's a lot more logical to see
; the literal equates here than futz with ca65/ld65 segments and the like.
; I just prefer things the old/simple way (plus the ZP addresses end up
; being visible in the generated listing, vs. having to defer to ld65).

multiplier      = $00
multiplicand    = $01
resultL         = $02
resultH         = $03
temp1           = $04
ptr_str_algo    = $05   ; 2 bytes in size

.segment "CODE"

; Trigger Lua script to read multiplier/multiplicand and save current CPU
; cycle count

.macro triggerFactorSave
    sta $FFF0
.endmacro

; Trigger Mesen Lua script to log multiplier/multiplicand and CPU cycle
; count difference (see Lua script for details)

.macro triggerCountCycles
    sta $FFF1
.endmacro

.macro runAlgorithm algo, str
    lda #.lobyte(str)       ; Point ptr_str_algo to the address of the
    sta ptr_str_algo        ; algorithm name/string (NULL-terminated)
    lda #.hibyte(str)
    sta ptr_str_algo+1

    ;
    ; Generate code doing 0*255, 1*254, 2*253, etc...
    ;
    VAR2 .set 255
    .repeat 256, VAR1
        lda #VAR1
        sta multiplier
        lda #VAR2
        sta multiplicand
        jsr algo
        VAR2 .set VAR2 - 1
    .endrepeat
.endmacro

.proc RESET
    sei                     ; Inhibit some IRQs
    ldx #$00
    stx $2000               ; Disable NMI-on-VBlank
    stx $2001               ; Disable BG/sprites
    stx $4010               ; Disable DMC IRQ
    lda #%01000000
    sta $4017               ; Disable APU frame IRQ
    ldx #$ff
    txs                     ; Stack = $01FF

    lda #$00                ; Zero out zero page
    ldx #$00                ; Zero wing
:   sta $00,x               ; Sprite zero
    dex                     ; De héros à zéro
    bne :-

    runAlgorithm proc_hokkaidou, str_hokkaidou
    runAlgorithm proc_lance, str_lance
    runAlgorithm proc_tepples_mul8, str_tepples_mul8
    runAlgorithm proc_supercat, str_supercat

    ; Induce BRK to stop Mesen
    ; ca65 doesn't support a BRK signature byte >:/
    .byte $00, $42

     ; Infinite loop, just in case someone continues past the BRK
:    jmp :-

.endproc


.proc emptyvect
    rti
.endproc


.proc proc_hokkaidou
    triggerFactorSave
    lda #$00
    sta temp1
    sta resultL
    sta resultH
@A: lsr multiplier
    bcc @B
    clc
    lda multiplicand
    adc resultL
    sta resultL
    lda temp1
    adc resultH
    sta resultH
    lda #$ff
@B: beq @D
    asl multiplicand
    rol temp1
    bcc @A
@D:
    triggerCountCycles
    rts
.endproc
str_hokkaidou:      .asciiz "hokkaidou"


.proc proc_lance
    triggerFactorSave
    lda #0          ;LSB'S OF PRODUCT = ZERO
    sta resultH     ;MSB'S OF PRODUCT = ZERO
    ldx #8          ;NUMBER OF BITS IN MULTIPLIER = 8
@A: asl
    rol resultH
    asl multiplier  ;SHIFT MULTIPLIER LEFT
    bcc @B          ;NO ADDITION IF NEXT BIT IS ZERO
    clc
    adc multiplicand
    bcc @B
    inc resultH     ;WITH CARRY IF NECESSARY
@B: dex             ;LOOP UNTIL 8 BITS ARE MULTIPLIED
    bne @A
    sta resultL     ;STORE LSB'S OF PRODUCT
    triggerCountCycles
    rts
.endproc
str_lance: .asciiz "lance"


; @param A one factor
; @param Y another factor
; @return high 8 bits in A; low 8 bits in $0000
;         Y and $0001 are trashed; X is untouched
.proc proc_tepples_mul8
    lda multiplier
    ldy multiplicand
    triggerFactorSave
    lsr a
    sta resultL
    sty temp1
    lda #0
    ldy #8
    loop:
        bcc noadd
          clc
          adc temp1
        noadd:
        ror a
        ror resultL
        dey
        bne loop
    sta resultH
    triggerCountCycles
    rts
.endproc
str_tepples_mul8: .asciiz "tepples_mul8"


; Compute mul1*mul2+acc -> acc:mul1 [mul2 is unchanged]
.proc proc_supercat
    lda #0
    triggerFactorSave
    ldx #8
    dec multiplicand
@A: lsr
    ror multiplier
    bcc @B
    adc multiplicand
@B: dex
    bne @A
    inc multiplicand
    sta resultH
    lda multiplier
    sta resultL
    triggerCountCycles
    rts
.endproc
str_supercat: .asciiz "supercat"


.segment "HEADER"
    .byte "NES", $1A        ; "NES" string + $1A
    .byte 2                 ; Count of 16KB PRG-ROM banks
    .byte 0                 ; Count of 8KB CHR-ROM banks
    .byte $00               ; Lower mapper nybble, vertical mirroring
    .byte $00               ; Upper mapper nybble

.segment "VECTORS"
    .word emptyvect         ; $FFFA: NMI
    .word RESET             ; $FFFC: RESET
    .word emptyvect         ; $FFFE: IRQ/BRK
