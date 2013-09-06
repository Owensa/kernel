;; clearBuffer [Display]
;;  Turns off all pixels on a screen buffer.
;; Inputs:
;;  IY: Screen buffer
clearBuffer:
    push hl
    push de
        push bc
        push iy \ pop hl
        ld (hl), 0
        ld d, h
        ld e, l
        inc de
        ld bc, 767
        ldir
    pop bc
    pop de
    pop hl
    ret

;; fastCopy [Display]
;;  Copies the screen buffer to the LCD.
;; Inputs:
;;  IY: Screen buffer
;; Notes:
;;  This routine will return immediately without drawing to the LCD if the calling thead does not have an
;;  LCD lock. Acquire one with [[getLcdLock]].
fastCopy:
        call hasLCDLock
        ret nz
fastCopy_skipCheck:
        push hl
        push bc
        push af
        push de
            ld a, i
            push af
                di                    ;DI is only required if an interrupt will alter the lcd.
                push iy \ pop hl
    
                ld c, 0x10
                ld a, 0x80
.setRow:
                in f, (c)
                jp m, .setRow
                out (0x10), a
                ld de, 12
                ld a, 0x20
.col:
                in f, (c)
                jp m, .col
                out (0x10),a
                push af
                    ld b,64
.row:
                    ld a, (hl)
.rowWait:
                    in f, (c)
                    jp m, .rowWait
                    out (0x11), a
                    add hl, de
                    djnz .row
                pop af
                dec h
                dec h
                dec h
                inc hl
                inc a
                cp 0x2C
                jp nz, .col
            pop af
        jp po, _
        ei
_:  pop de
    pop af
    pop bc
    pop hl
    ret
    
;; getPixel [Display]
;;  Finds the address of and mask for a pixel on the screen buffer.
;; Inputs:
;;  IY: Screen buffer
;;  A,L: X, Y
;; Outputs:
;;  HL: Address of pixel
;;  A: Mask
;; Notes:
;;  If the pixel is on, HL & A is nonzero.
getPixel:
    push de
    push bc
        ld h, 0
        ld d, h
        ld e, l
    
        add hl, hl
        add hl, de
        add hl, hl
        add hl, hl
    
        ld e, a
        srl e
        srl e
        srl e
        add hl, de

        push iy \ pop de
        add hl, de
        and 7
        ld b, a
        ld a, 0x80
        jr z, _

        rrca
        djnz $-1
_:  pop bc
    pop de
    ret
    
;; setPixel [Display]
;;  Sets (turns on) a pixel on the screen buffer.
;; Inputs:
;;  IY: Screen buffer
;;  A,L: X, Y
setPixel:
    push hl
    push af
        call getPixel
        or (hl)
        ld (hl), a
    pop af
    pop hl
    ret

;; resetPixel [Display]
;;  Sets (turns on) a pixel on the screen buffer.
;; Inputs:
;;  IY: Screen buffer
;;  A,L: X, Y
resetPixel:
    push hl
    push af
        call getPixel
        cpl
        and (hl)
        ld (hl), a
    pop af
    pop hl
    ret

;; invertPixel [Display]
;;  Inverts a pixel on the screen buffer.
;; Inputs:
;;  IY: Screen buffer
;;  A,L: X, Y
invertPixel:
    push hl
    push af
        call getPixel
        xor (hl)
        ld (hl), a
    pop af
    pop hl
    ret
    
;; drawLine [Display]
;;  Draws a line on the screen buffer using OR (turns pixels ON) logic.
;; Inputs:
;;  IY: Screen buffer
;;  D, E: X1, Y1
;;  H, L: X2, Y2
;; Notes:
;;  This function does not clip lines to the screen boundaries.
drawLine: ; By James Montelongo
    push hl
    push de
    push bc
    push af
    push ix
    push iy
        call _drawLine
    pop iy
    pop ix
    pop af
    pop bc
    pop de
    pop hl
    ret

_drawLine:
        ld a, h
        cp d
        jp nc, .noswapx
        ex de, hl
.noswapx:

        ld a, h
        sub d
        jp nc, .posx
        neg
.posx:
        ld b, a
        ld a, l
        sub e
        jp nc, .posy
        neg
.posY:
        ld c, a
        ld a, l
        ld hl, -12
        cp e
        jp c, .lineup
        ld hl, 12
.lineup:
        ld ix, .xbit
        ld a, b
        cp c
        jp nc, .xline
        ld b, c
        ld c, a
        ld ix, .ybit
.xline:
        push hl
            ld a, d
            ld d, 0
            ld h, d
            sla e
            sla e
            ld l, e
            add hl, de
            add hl, de
            ld e, a
            and 0b00000111
            srl e
            srl e
            srl e
            add hl, de
            push iy \ pop de
            ;ld de, gbuf
            add hl, de
            add a, a
            ld e, a
            ld d, 0
            add ix, de
            ld e, (ix)
            ld d, (ix + 1)
            push hl \ pop ix
            ex de, hl
        pop de \ push hl
        ld h, b
        ld l, c
        ld a, h
        srl a
        inc b
        ret

.xbit:
    .dw .drawX0, .drawX1, .drawX2, .drawX3
    .dw .drawX4, .drawX5, .drawX6, .drawX7
.ybit:
    .dw .drawY0, .drawY1, .drawY2, .drawY3
    .dw .drawY4, .drawY5, .drawY6, .drawY7
    
.drawX0:
        set 7, (ix)
        add a, c
        cp h
        jp c, $ + 3 + 2 + 1
        add ix, de
        sub h
        djnz .drawX1
        ret
.drawX1:
        set 6, (ix)
        add a, c
        cp h
        jp c, $ + 3 + 2 + 1
        add ix, de
        sub h
        djnz .drawX2
        ret
.drawX2:
        set 5, (ix)
        add a, c
        cp h
        jp c, $ + 3 + 2 + 1
        add ix, de
        sub h
        djnz .drawX3
        ret
.drawX3:
        set 4, (ix)
        add a, c
        cp h
        jp c, $ + 3 + 2 + 1
        add ix, de
        sub h
        djnz .drawX4
        ret
.drawX4:
        set 3, (ix)
        add a, c
        cp h
        jp c, $ + 3 + 2 + 1
        add ix, de
        sub h
        djnz .drawX5
        ret
.drawX5:
        set 2, (ix)
        add a, c
        cp h
        jp c, $ + 3 + 2 + 1
        add ix, de
        sub h
        djnz .drawX6
        ret
.drawX6:
        set 1, (ix)
        add a, c
        cp h
        jp c, $ + 3 + 2 + 1
        add ix, de
        sub h
        djnz .drawX7
        ret
.drawX7:
        set 0, (ix)
        inc ix
        add a, c
        cp h
        jp c, $ + 3 + 2 + 1
        add ix, de
        sub h
        djnz .drawX0
        ret

.drawY0_:
        inc ix
        sub h
        dec b
        ret z
.drawY0:
        set 7, (ix)
        add ix, de
        add a, l
        cp h
        jp nc, .drawY1_
        djnz .drawY0
        ret
.drawY1_:
        sub h
        dec b
        ret z
.drawY1:
        set 6, (ix)
        add ix, de
        add a, l
        cp h
        jp nc, .drawY2_
        djnz .drawY1
        ret
.drawY2_:
        sub h
        dec b
        ret z
.drawY2:
        set 5, (ix)
        add ix, de
        add a, l
        cp h
        jp nc, .drawY3_
        djnz .drawY2
        ret
.drawY3_:
        sub h
        dec b
        ret z
.drawY3:
        set 4, (ix)
        add ix, de
        add a, l
        cp h
        jp nc, .drawY4_
        djnz .drawY3
        ret
.drawY4_:
        sub h
        dec b
        ret z
.drawY4:
        set 3, (ix)
        add ix, de
        add a, l
        cp h
        jp nc, .drawY5_
        djnz .drawY4
        ret
.drawY5_:
        sub h
        dec b
        ret z
.drawY5:
        set 2, (ix)
        add ix, de
        add a, l
        cp h
        jp nc, .drawY6_
        djnz .drawY5
        ret
.drawY6_:
        sub h
        dec b
        ret z
.drawY6:
        set 1, (ix)
        add ix, de
        add a, l
        cp h
        jp nc, .drawY7_
        djnz .drawY6
        ret
.drawY7_:
        sub h
        dec b
        ret z
.drawY7:
        set 0, (ix)
        add ix, de
        add a, l
        cp h
        jp nc, .drawY0_
        djnz .drawY7
        ret

;; putSpriteXOR [Display]
;;  Draws an 8xB sprite on the screen buffer using XOR (invert) logic.
;; Inputs:
;;  IY: Screen buffer
;;  HL: Sprite pointer
;;  D, E: X, Y
;;  B: Height
putSpriteXOR:
    push af
    push bc
    push hl
    push de
    push ix
        push hl \ pop ix
        call _clipSprXOR
    pop ix
    pop de
    pop hl
    pop bc
    pop af
    ret
    
_clipSprXOR:
        ; Start by doing vertical clipping
        ld a, 0b11111111            ; Reset clipping mask
        ld (clip_mask), a
        ld a, e                    ; If ypos is negative
        or a                    ; try clipping the top
        jp m, clipTop            ;
        sub 64                    ; If ypos is >= 64
        ret nc                    ; sprite is off-screen
        neg                        ; If (64 - ypos) > height
        cp b                    ; don't need to clip
        jr nc, vertClipDone        ;
        ld b, a                    ; Do bottom clipping by
        jr vertClipDone            ; setting height to (64 - ypos)

clipTop:
        ld a, b                    ; If ypos <= -height
        neg                        ; sprite is off-screen
        sub e                    ;
        ret nc                    ;
        push af
            add a, b            ; Get the number of clipped rows
            ld e, 0                ; Set ypos to 0 (top of screen)
            ld b, e                ; Advance image data pointer
            ld c, a
            add ix, bc
        pop af
        neg                        ; Get the number of visible rows
        ld b, a                    ; and set as height

vertClipDone:
        ; Now we're doing horizontal clipping
        ld c, 0                    ; Reset correction factor
        ld a, d
        cp -7                    ; If 0 > xpos >= -7
        jr nc, clipLeft            ; clip the left side
        cp 96                    ; If xpos >= 96
        ret nc                    ; sprite is off-screen
        cp 89                    ; If 0 <= xpos < 89
        jr c, horizClipDone        ; don't need to clip

clipRight:
        and 7                    ; Determine the clipping mask
        ld c,a
        ld a, 0b11111111
findRightMask:
        add a, a
        dec c
        jr nz, findRightMask
        ld (clip_mask), a
        ld a, d
        jr horizClipDone
    
clipLeft:
        and 7                    ; Determine the clipping mask
        ld c, a
        ld a, 0b11111111
findLeftMask:
        add a, a
        dec c
        jr nz, findLeftMask
        cpl
        ld (clip_mask), A
        ld a, d
        add a, 96                ; Set xpos so sprite will "spill over"
        ld c, 12                ; Set correction

horizClipDone:
        ; A = xpos
        ; E = ypos
        ; B = height
        ; IX = image address

        ; Now we can finally display the sprite.
        ld h, 0
        ld d, h
        ld l, e
        add hl, hl
        add hl, de
        add hl, hl
        add hl, hl

        ld e, a
        srl e
        srl e
        srl e
        add hl, de

        push iy \ pop de        ; ld de, plotSScreen
        add hl, de

        ld d, 0                    ; Correct graph buffer address
        ld e, c                    ; if clipping the left side
        sbc hl, de

        and 7
        jr z, _aligned

        ld c, a
        ld de, 11

_rowLoop:
        push bc
            ld b, c
            ld a, (clip_mask)        ; Mask out the part of the sprite
            and (ix)                ; to be horizontally clipped
            ld c, 0

_shiftLoop:
            srl a
            rr c
            djnz _shiftLoop

            xor (hl)
            ld (hl), a

            inc hl
            ld a, c
            xor (hl)
            ld (hl), a

            add    hl, de
            inc    ix
        pop    bc
        djnz   _rowLoop
        ret

_aligned:
        ld     de, 12

_putLoop:
        ld     a, (ix)
        xor    (hl)
        ld     (hl), a
        inc    ix
        add    hl, de
        djnz   _putLoop
        ret
    
;; putSpriteAND [Display]
;;  Draws an 8xB sprite on the screen buffer using AND (turns pixels OFF) logic.
;; Inputs:
;;  IY: Screen buffer
;;  HL: Sprite pointer
;;  D, E: X, Y
;;  B: Height
PutSpriteAND:
    push af
    push bc
    push hl
    push de
    push ix
        push hl \ pop ix
        call _ClipSprAND
    pop ix
    pop de
    pop hl
    pop bc
    pop af
    ret
    
_ClipSprAND:
        ; Start by doing vertical clipping
        ld a,0b11111111            ; Reset clipping mask
        ld     (clip_mask), a
        ld     a, e                ; If ypos is negative
        or     a                    ; try clipping the top
        jp     m, ClipTop2

        sub    64                    ; If ypos is >= 64
        ret nc                    ; sprite is off-screen

        neg                        ; If (64 - ypos) > height
        cp b                    ; don't need to clip
        jr nc, VertClipDone2

        ld b, a                    ; Do bottom clipping by
        jr     VertClipDone2        ; setting height to (64 - ypos)

ClipTop2:
        ld     a, b                 ; If ypos <= -height
        neg                         ; sprite is off-screen
        sub    e                    ;
        ret    nc                   ;

        push   af
            add    a, b                 ; Get the number of clipped rows
            ld     e,0                 ; Set ypos to 0 (top of screen)
            ld     b, e                 ; Advance image data pointer
            ld     c, a                 ;
            add    ix, bc               ;
        pop    af
        neg                         ; Get the number of visible rows
        ld     b, a                 ; and set as height

VertClipDone2:
        ; Now we're doing horizontal clipping
        ld     c, 0                 ; Reset correction factor
        ld     a, d

        cp     -7                   ; If 0 > xpos >= -7
        jr     nc, ClipLeft2         ; clip the left side

        cp     96                   ; If xpos >= 96
        ret    nc                   ; sprite is off-screen

        cp     89                   ; If 0 <= xpos < 89
        jr     c, HorizClipDone2     ; don't need to clip

ClipRight2:
        and    7                    ; Determine the clipping mask
        ld     c, a
        ld     a, 0b11111111
FindRightMask2:
        add    a, a
        dec    c
        jr     nz, FindRightMask2
        ld     (clip_mask), a
        ld     a, d
        jr     HorizClipDone2

ClipLeft2:
        and    7                    ; Determine the clipping mask
        ld     c, a
        ld     a, 0b11111111
FindLeftMask2:
        add    a, a
        dec    c
        jr     nz, FindLeftMask2
        cpl
        ld     (clip_mask), a
        ld     a, d
        add    a, 96                ; Set xpos so sprite will "spill over"
        ld     c, 12                ; Set correction

HorizClipDone2:
        ; A = xpos
        ; E = ypos
        ; B = height
        ; IX = image address

        ; Now we can finally display the sprite.
        ld     h, 0
        ld     d, h
        ld     l, e
        add    hl, hl
        add    hl, de
        add    hl, hl
        add    hl, hl

        ld     e, a
        srl    e
        srl    e
        srl    e
        add    hl, de

        push iy \ pop de            ; LD DE, PlotSScreen
        add    hl, de

        ld     d, 0                 ; Correct graph buffer address
        ld     e, c                 ; if clipping the left side
        sbc    hl, de

        and    7
        jr     z, _Aligned2

        ld     c, a
        ld     de, 11

_RowLoop2:
        push   bc
            ld     b, c
            ld     a, (clip_mask)       ; Mask out the part of the sprite
            and    (ix)                 ; to be horizontally clipped
            ld     c, 0

_ShiftLoop2:
            srl    a
            rr     c
            djnz   _ShiftLoop2

            cpl
            and    (hl)
            ld     (hl), a

            inc    hl
            ld     a, c
            cpl
            and    (hl)
            ld     (hl), a
            
            add    hl, de
            inc    ix
        pop    bc
        djnz   _RowLoop2
        ret

_Aligned2:
        ld     de, 12

_PutLoop2:
        ld     a, (ix)
        cpl
        and    (hl)
        ld     (hl), a
        inc    ix
        add    hl, de
        djnz   _PutLoop2
        ret
    
;; putSpriteOR [Display]
;;  Draws an 8xB sprite on the screen buffer using OR (turns pixels ON) logic.
;; Inputs:
;;  IY: Screen buffer
;;  HL: Sprite pointer
;;  D, E: X, Y
;;  B: Height
PutSpriteOR:
    push af
    push bc
    push hl
    push de
    push ix
        push hl \ pop ix
        call _ClipSprOR
    pop ix
    pop de
    pop hl
    pop bc
    pop af
    ret
    
_ClipSprOR:
        ; Start by doing vertical clipping
        ld     a, 0b11111111         ; Reset clipping mask
        ld     (clip_mask), a
        ld     a, e                 ; If ypos is negative
        or     a                    ; try clipping the top
        jp     m, ClipTop3           ;

        sub    64                   ; If ypos is >= 64
        ret    nc                   ; sprite is off-screen

        neg                         ; If (64 - ypos) > height
        cp     b                    ; don't need to clip
        jr     nc, VertClipDone3     ;

        ld     b, a                 ; Do bottom clipping by
        jr     VertClipDone3         ; setting height to (64 - ypos)

ClipTop3:
        ld     a, b                 ; If ypos <= -height
        neg                         ; sprite is off-screen
        sub    e                    ;
        ret    nc                   ;

        push   af
            add    a, b                 ; Get the number of clipped rows
            ld     e, 0                 ; Set ypos to 0 (top of screen)
            ld     b, e                 ; Advance image data pointer
            ld     c, a                 ;
            add    ix, bc               ;
        pop    af
        neg                         ; Get the number of visible rows
        ld     b, a                 ; and set as height

VertClipDone3:
        ; Now we're doing horizontal clipping
        ld     c, 0                 ; Reset correction factor
        ld     a, d

        cp     -7                   ; If 0 > xpos >= -7
        jr     nc, ClipLeft3         ; clip the left side

        cp     96                   ; If xpos >= 96
        ret    nc                   ; sprite is off-screen

        cp     89                   ; If 0 <= xpos < 89
        jr     c, HorizClipDone3     ; don't need to clip

ClipRight3:
        and    7                    ; Determine the clipping mask
        ld     c, a
        ld     a, 0b11111111
FindRightMask3:
        add    a, a
        dec    c
        jr     nz, FindRightMask3
        ld     (clip_mask), a
        ld     a, d
        jr     HorizClipDone3

ClipLeft3:
        and    7                    ; Determine the clipping mask
        ld     c, a
        ld     a, 0b11111111
FindLeftMask3:
        add    a, a
        dec    c
        jr     nz, FindLeftMask3
        cpl
        ld     (clip_mask), a
        ld     a, d
        add    a, 96                ; Set xpos so sprite will "spill over"
        ld     c, 12                ; Set correction

HorizClipDone3:
        ; A = xpos
        ; E = ypos
        ; B = height
        ; IX = image address

        ; Now we can finally display the sprite.
        ld     h, 0
        ld     d, h
        ld     l, e
        add    hl, hl
        add    hl, de
        add    hl, hl
        add    hl, hl

        ld     e, a
        srl    e
        srl    e
        srl    e
        add    hl, de

        push iy \ pop de ; LD     DE, PlotSScreen
        add    hl, de

        ld     d, 0                 ; Correct graph buffer address
        ld     e, c                 ; if clipping the left side
        sbc    hl, de               ;

        and    7
        jr     z, _Aligned3

        ld     c, a
        ld     de, 11

_RowLoop3:
        push   bc
            ld     b, c
            ld     a, (clip_mask)       ; Mask out the part of the sprite
            and    (ix)                 ; to be horizontally clipped
            ld     c, 0

_ShiftLoop3:
            srl    a
            rr     c
            djnz   _ShiftLoop3

            or    (hl)
            ld     (hl), a

            inc    hl
            ld     a, c
            or    (hl)
            ld     (hl), a

            add    hl, de
            inc    ix
        pop    bc
        djnz   _RowLoop3
        ret

_Aligned3:
        ld     de, 12

_PutLoop3:
        ld     a, (ix)
        or    (hl)
        ld     (hl), a
        inc    ix
        add    hl, de
        djnz   _PutLoop3
        ret
    
;; rectXOR [Display]
;;  Draws a filled rectangle on the screen buffer using XOR (invert) logic.
;; Inputs:
;;  IY: Screen buffer
;;  E, L: X, Y
;;  C, B: Width, height
RectXOR: ; by Quigibo
    ld    a, 96        ;Clip Top
    sub    e
    ret    c
    ret    z
    cp    c        ;Clip Bottom
    jr    nc, $ + 3
    ld    c, a
    ld    a, 64        ;Clip Left
    sub    l
    ret    c
    ret    z
    cp    b        ;Clip Right
    jr    nc, $ + 3
    ld    b, a

    xor    a        ;More clipping...
    cp    b
    ret    z
    cp    c
    ret    z
    ld    h,a
    ld    d,a

    push    bc
        push    iy \ pop    bc
        ld    a, l
        add    a, a
        add    a, l
        ld    l, a
        add    hl, hl
        add    hl, hl        ;(e,_) = (X,Y)
        add    hl, bc        ;(_,_) = (width,height)

        ld    a, e
        srl    e
        srl    e
        srl    e
        add    hl, de
        and    0b00000111    ;(a,_) = (X^8,Y)
    pop    de        ;(e,d) = (width,height)

    ld    b, a
    add    a, e
    sub    8
    ld    e, 0
    jr    c, __BoxInvSkip
    ld    e, a
    xor    a
__BoxInvSkip:

__BoxInvShift:            ;Input:  b = Left shift
    add    a, 8        ;Input:  a = negative right shift
    sub    b        ;Output: a = mask
    ld    c, 0
__BoxInvShift1:
    scf
    rr    c
    dec    a
    jr    nz, __BoxInvShift1
    ld    a, c
    inc    b
    rlca
__BoxInvShift2:
    rrca
    djnz    __BoxInvShift2

__BoxInvLoop1:            ;(e,d) = (width,height)
    push    hl        ;    a = bitmask
        ld    b, d
        ld    c, a
        push    de
            ld    de, 12
__BoxInvLoop2:
            ld    a, c
            xor    (hl)
            ld    (hl), a
            add    hl, de
            djnz    __BoxInvLoop2
        pop    de
    pop    hl
    inc    hl
    ld    a, e
    or    a
    ret    z
    sub    8
    ld    e, b
    jr    c, __BoxInvShift
    ld    e, a
    ld    a, 0b11111111
    jr    __BoxInvLoop1
__BoxInvEnd:

;; rectOR [Display]
;;  Draws a filled rectangle on the screen buffer using OR (turns pixels ON) logic.
;; Inputs:
;;  IY: Screen buffer
;;  E, L: X, Y
;;  C, B: Width, height
RectOR:
    ld    a, 96        ;Clip Top
    sub    e
    ret    c
    ret    z
    cp    c        ;Clip Bottom
    jr    nc, $ + 3
    ld    c, a
    ld    a, 64        ;Clip Left
    sub    l
    ret    c
    ret    z
    cp    b        ;Clip Right
    jr    nc, $ + 3
    ld    b, a

    xor    a        ;More clipping...
    cp    b
    ret    z
    cp    c
    ret    z
    ld    h, a
    ld    d, a

    push    bc
        push iy \ pop bc
        ld    a, l
        add    a, a
        add    a, l
        ld    l, a
        add    hl, hl
        add    hl, hl        ;(e,_) = (X,Y)
        add    hl, bc        ;(_,_) = (width,height)

        ld    a, e
        srl    e
        srl    e
        srl    e
        add    hl, de
        and    0b00000111    ;(a,_) = (X^8,Y)
    pop    de        ;(e,d) = (width,height)

    ld    b, a
    add    a, e
    sub    8
    ld    e, 0
    jr    c, __BoxORSkip
    ld    e, a
    xor    a
__BoxORSkip:

__BoxORShift:            ;Input:  b = Left shift
    add    a, 8        ;Input:  a = negative right shift
    sub    b        ;Output: a = mask
    ld    c, 0
__BoxORShift1:
    scf
    rr    c
    dec    a
    jr    nz, __BoxORShift1
    ld    a, c
    inc    b
    rlca
__BoxORShift2:
    rrca
    djnz    __BoxORShift2

__BoxORLoop1:            ;(e,d) = (width,height)
    push    hl        ;    a = bitmask
        ld    b, d
        ld    c, a
        push    de
            ld    de, 12
__BoxORLoop2:
            ld    a, c
            or    (hl)
            ld    (hl), a
            add    hl, de
            djnz    __BoxORLoop2
        pop    de
    pop    hl
    inc    hl
    ld    a,e
    or    a
    ret    z
    sub    8
    ld    e, b
    jr    c, __BoxORShift
    ld    e, a
    ld    a, 0b11111111
    jr    __BoxORLoop1
__BoxOREnd:

;; rectAND [Display]
;;  Draws a filled rectangle on the screen buffer using AND (turns pixels OFF) logic.
;; Inputs:
;;  IY: Screen buffer
;;  E, L: X, Y
;;  C, B: Width, height
RectAND:
    ld    a, 96        ;Clip Top
    sub    e
    ret    c
    ret    z
    cp    c        ;Clip Bottom
    jr    nc, $ + 3
    ld    c, a
    ld    a, 64        ;Clip Left
    sub    l
    ret    c
    ret    z
    cp    b        ;Clip Right
    jr    nc, $ + 3
    ld    b,a

    xor    a        ;More clipping...
    cp    b
    ret    z
    cp    c
    ret    z
    ld    h, a
    ld    d, a

    push    bc
        push iy \ pop bc
        ld    a, l
        add    a, a
        add    a, l
        ld    l, a
        add    hl, hl
        add    hl, hl        ;(e,_) = (X,Y)
        add    hl, bc        ;(_,_) = (width,height)

        ld    a, e
        srl    e
        srl    e
        srl    e
        add    hl, de
        and    0b00000111    ;(a,_) = (X^8,Y)
    pop    de        ;(e,d) = (width,height)

    ld    b, a
    add    a, e
    sub    8
    ld    e, 0
    jr    c, __BoxANDSkip
    ld    e, a
    xor    a
__BoxANDSkip:

__BoxANDShift:            ;Input:  b = Left shift
    add    a, 8        ;Input:  a = negative right shift
    sub    b        ;Output: a = mask
    ld    c, 0
__BoxANDShift1:
    scf
    rr    c
    dec    a
    jr    nz, __BoxANDShift1
    ld    a, c
    inc    b
    rlca
__BoxANDShift2:
    rrca
    djnz    __BoxANDShift2

__BoxANDLoop1:            ;(e,d) = (width,height)
    push    hl        ;    a = bitmask
        ld    b, d
        ld    c, a
        push    de
            ld    de, 12
__BoxANDLoop2:
            ld    a, c
            cpl
            and    (hl)
            ld    (hl), a
            add    hl, de
            djnz    __BoxANDLoop2
        pop    de
    pop    hl
    inc    hl
    ld    a, e
    or    a
    ret    z
    sub    8
    ld    e, b
    jr    c, __BoxANDShift
    ld    e, a
    ld    a, 0b11111111
    jr    __BoxANDLoop1
__BoxANDEnd:

;; putSprite16XOR [Display]
;;  Draws a 16xB sprite on the screen buffer using XOR (invert) logic.
;; Inputs:
;;  IY: Screen buffer
;;  HL: Sprite pointer
;;  D, E: X, Y
;;  B: Height
;; Notes:
;;  Each 16-wide group of pixels is represented by two adjacent octets.
PutSprite16XOR: ; By Jon Martin
    push af
    push hl
    push bc
    push de
    push ix
        push hl \ pop ix
        ld a, d
        call _PutSprite16XOR
    pop ix
    pop de
    pop bc
    pop hl
    pop af
    ret

_PutSprite16XOR:                
    ld h, 0             ;7
    ld l, e            ;4
    ld d, h         ;4
    add hl, hl        ;11
    add hl, de        ;11
    add hl, hl        ;11
    add hl, hl        ;11
    push iy \ pop de    ;10
    add hl, de        ;11
    ld e, a            ;4
    srl e            ;8
    srl e            ;8
    srl e            ;8
    ld d, 0            ;7
    add hl, de        ;11
    ld d, h            ;4
    ld e, l            ;4
    and 7            ;4
    jp z, aligned        ;10
    ld c, a            ;4
    ld de, 12        ;10
rowloop:        ;total: 194
    push bc        ;11
        ld b, c         ;4
        xor a            ;4
        ld d, (ix)        ;19
        ld e, (ix+1)        ;19
shiftloop:        ;60 per loop
        srl d            ;8
        rr e            ;8
        rra            ;4
        djnz shiftloop        ;13/8,37 per loop
        inc hl
        inc hl
        xor (hl)
        ld (hl), a
        ld a, e
        dec hl
        xor (hl)
        ld (hl), a
        ld a, d
        dec hl
        xor (hl)
        ld (hl), a    
    pop bc            ;10
    ld de, 12        ;10
    add hl, de        ;11
    inc ix            ;10
    inc ix            ;10
    djnz rowloop        ;13/8
    ret            ;10
aligned:
    ld de, 11 
alignedloop:
    ld a, (ix)
    xor (hl)
    ld (hl), a
    ld a, (ix+1)
    inc hl
    xor (hl)
    ld (hl), a
    add hl, de
    inc ix
    inc ix
    djnz alignedloop
    ret

;; putSprite16OR [Display]
;;  Draws a 16xB sprite on the screen buffer using OR (turns pixels ON) logic.
;; Inputs:
;;  IY: Screen buffer
;;  HL: Sprite pointer
;;  D, E: X, Y
;;  B: Height
;; Notes:
;;  Each 16-wide group of pixels is represented by two adjacent octets.
PutSprite16OR:
    push af
    push hl
    push bc
    push de
    push ix
        push hl \ pop ix
        ld a, d
        call _PutSprite16OR
    pop ix
    pop de
    pop bc
    pop hl
    pop af
    ret

_PutSprite16OR:                
        ld h, 0             ;7
        ld l, e            ;4
        ld d, h         ;4
        add hl, hl        ;11
        add hl, de        ;11
        add hl, hl        ;11
        add hl, hl        ;11
        push iy \ pop de    ;10
        add hl, de        ;11
        ld e, a            ;4
        srl e            ;8
        srl e            ;8
        srl e            ;8
        ld d, 0            ;7
        add hl, de        ;11
        ld d, h            ;4
        ld e, l            ;4
        and 7            ;4
        jp z, alignedOR        ;10
        ld c, a            ;4
        ld de, 12        ;10
rowloopOR:        ;total: 194
        push bc        ;11
            ld b, c         ;4
            xor a            ;4
            ld d, (ix)        ;19
            ld e, (ix+1)        ;19
shiftloopOR:        ;60 per loop
            srl d            ;8
            rr e            ;8
            rra            ;4
            djnz shiftloopOR        ;13/8,37 per loop
            inc hl
            inc hl
            xor (hl)
            ld (hl), a
            ld a, e
            dec hl
            or (hl)
            ld (hl), a
            ld a, d
            dec hl
            or (hl)
            ld (hl), a    
        pop bc            ;10
        ld de, 12        ;10
        add hl, de        ;11
        inc ix            ;10
        inc ix            ;10
        djnz rowloopOR        ;13/8
        ret            ;10
alignedOR:
        ld de, 11 
alignedloopOR:
        ld a, (ix)
        or (hl)
        ld (hl), a
        ld a, (ix+1)
        inc hl
        or (hl)
        ld (hl), a
        add hl, de
        inc ix
        inc ix
        djnz alignedloopOR
        ret

;; putSprite16AND [Display]
;;  Draws a 16xB sprite on the screen buffer using AND (turns pixels OFF) logic.
;; Inputs:
;;  IY: Screen buffer
;;  HL: Sprite pointer
;;  D, E: X, Y
;;  B: Height
;; Notes:
;;  Each 16-wide group of pixels is represented by two adjacent octets.
PutSprite16AND:
    push af
    push hl
    push bc
    push de
    push ix
        push hl \ pop ix
        ld a, d
        call _PutSprite16AND
    pop ix
    pop de
    pop bc
    pop hl
    pop af
    ret

_PutSprite16AND:                
        ld h, 0             ;7
        ld l, e            ;4
        ld d, h         ;4
        add hl, hl        ;11
        add hl, de        ;11
        add hl, hl        ;11
        add hl, hl        ;11
        push iy \ pop de    ;10
        add hl, de        ;11
        ld e, a            ;4
        srl e            ;8
        srl e            ;8
        srl e            ;8
        ld d, 0            ;7
        add hl, de        ;11
        ld d, h            ;4
        ld e, l            ;4
        and 7            ;4
        jp z, alignedAND        ;10
        ld c, a            ;4
        ld de, 12        ;10
rowloopAND:        ;total: 194
        push bc        ;11
            ld b, c         ;4
            xor a            ;4
            ld d, (ix)        ;19
            ld e, (ix+1)        ;19
shiftloopAND:        ;60 per loop
            srl d            ;8
            rr e            ;8
            rra            ;4
            djnz shiftloopAND        ;13/8,37 per loop
            inc hl
            inc hl
            xor (hl)
            ld (hl), a
            ld a, e
            dec hl
            cpl
            and (hl)
            ld (hl), a
            ld a, d
            dec hl
            cpl
            and (hl)
            ld (hl), a
        pop bc            ;10
        ld de, 12        ;10
        add hl, de        ;11
        inc ix            ;10
        inc ix            ;10
        djnz rowloopAND        ;13/8
        ret            ;10
alignedAND:
        ld de, 11
alignedloopAND:
        ld a, (ix)
        cpl
        and (hl)
        ld (hl), a
        ld a, (ix+1)
        inc hl
        cpl
        and (hl)
        ld (hl), a
        add hl, de
        inc ix
        inc ix
        djnz alignedloopAND
        ret
