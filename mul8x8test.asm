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
    runAlgorithm proc_keldon, str_keldon

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


.proc proc_keldon
mul:
    triggerFactorSave
    ; --- A (21 cycles)
    ldx multiplier
    txa
    eor multiplicand
    and #$f0
    eor multiplicand
    tay
    lda table_mul, y
    sta resultH
    ; --- B (47 cycles)
    txa
    eor multiplicand
    and #$f
    eor multiplicand
    tay
    lda table_mul, y
    clc
    adc resultH
    tay
    lda table_flip, y
    tay
    and #$f
    bcc mul_1
    ; add carry to high nibble
    ora #$10
    clc
mul_1:
    sta resultH
    tya
    and #$f0
    sta resultL
    ; --- C (26 cycles)
    lda table_flip, x
    eor multiplicand
    tax
    and #$f0
    eor multiplicand
    tay
    lda table_mul, y
    adc resultL
    sta resultL
    ; --- D (19 cycles)
    txa
    and #$f
    eor multiplicand
    tay
    lda table_mul, y
    adc resultH
    sta resultH
    triggerCountCycles
    rts ; mul(a,b)

table_mul:
    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    .byte 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
    .byte 0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30
    .byte 0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39, 42, 45
    .byte 0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60
    .byte 0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75
    .byte 0, 6, 12, 18, 24, 30, 36, 42, 48, 54, 60, 66, 72, 78, 84, 90
    .byte 0, 7, 14, 21, 28, 35, 42, 49, 56, 63, 70, 77, 84, 91, 98, 105
    .byte 0, 8, 16, 24, 32, 40, 48, 56, 64, 72, 80, 88, 96, 104, 112, 120
    .byte 0, 9, 18, 27, 36, 45, 54, 63, 72, 81, 90, 99, 108, 117, 126, 135
    .byte 0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150
    .byte 0, 11, 22, 33, 44, 55, 66, 77, 88, 99, 110, 121, 132, 143, 154, 165
    .byte 0, 12, 24, 36, 48, 60, 72, 84, 96, 108, 120, 132, 144, 156, 168, 180
    .byte 0, 13, 26, 39, 52, 65, 78, 91, 104, 117, 130, 143, 156, 169, 182, 195
    .byte 0, 14, 28, 42, 56, 70, 84, 98, 112, 126, 140, 154, 168, 182, 196, 210
    .byte 0, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 180, 195, 210, 225
table_flip:
    .byte 0, 16, 32, 48, 64, 80, 96, 112, 128, 144, 160, 176, 192, 208, 224, 240
    .byte 1, 17, 33, 49, 65, 81, 97, 113, 129, 145, 161, 177, 193, 209, 225, 241
    .byte 2, 18, 34, 50, 66, 82, 98, 114, 130, 146, 162, 178, 194, 210, 226, 242
    .byte 3, 19, 35, 51, 67, 83, 99, 115, 131, 147, 163, 179, 195, 211, 227, 243
    .byte 4, 20, 36, 52, 68, 84, 100, 116, 132, 148, 164, 180, 196, 212, 228, 244
    .byte 5, 21, 37, 53, 69, 85, 101, 117, 133, 149, 165, 181, 197, 213, 229, 245
    .byte 6, 22, 38, 54, 70, 86, 102, 118, 134, 150, 166, 182, 198, 214, 230, 246
    .byte 7, 23, 39, 55, 71, 87, 103, 119, 135, 151, 167, 183, 199, 215, 231, 247
    .byte 8, 24, 40, 56, 72, 88, 104, 120, 136, 152, 168, 184, 200, 216, 232, 248
    .byte 9, 25, 41, 57, 73, 89, 105, 121, 137, 153, 169, 185, 201, 217, 233, 249
    .byte 10, 26, 42, 58, 74, 90, 106, 122, 138, 154, 170, 186, 202, 218, 234, 250
    .byte 11, 27, 43, 59, 75, 91, 107, 123, 139, 155, 171, 187, 203, 219, 235, 251
    .byte 12, 28, 44, 60, 76, 92, 108, 124, 140, 156, 172, 188, 204, 220, 236, 252
    .byte 13, 29, 45, 61, 77, 93, 109, 125, 141, 157, 173, 189, 205, 221, 237, 253
    .byte 14, 30, 46, 62, 78, 94, 110, 126, 142, 158, 174, 190, 206, 222, 238, 254
    .byte 15, 31, 47, 63, 79, 95, 111, 127, 143, 159, 175, 191, 207, 223, 239, 255
.endproc
str_keldon: .asciiz "keldon"


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
