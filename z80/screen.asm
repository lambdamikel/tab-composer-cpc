;; ---------------------------------------------------------------
;; TABCOMP/CPC - drawing the sheet into screen memory
;;
;; The firmware was doing all of this, and it was slow enough to be the
;; whole user experience: a full page was 1.6 s, and 0.98 s of that was
;; clearsheet alone - 576 calls asking the firmware to put a space
;; somewhere, at 1.7 ms each. The lines cost another 0.34 s, ~5700 calls
;; to plot one pixel at a time.
;;
;; None of it needs the firmware. MODE 2 is one bit per pixel, so a string
;; is 64 bytes of #FF on one scanline and a bar line is one bit down a
;; column, and the sheet is a few thousand byte writes: milliseconds.
;;
;; Screen layout, the CPC's famous interleave:
;;     addr = #C000 + (y AND 7)*2048 + (y/8)*80 + x
;; with y the scanline 0..199 and x the byte column 0..79, eight pixels to
;; the byte, bit 7 leftmost.
;;
;; Where the sheet lives, in those terms - LAYOUT.md has it in the BASIC's
;; own coordinates:
;;     strings     MOVE 16,i : DRAW 528,i, i = 330 to 250 step -16
;;                 scanline = (399-i)/2, so 34, 42, 50, 58, 66, 74 - and
;;                 it is 399, not 400: measured against the firmware's own
;;                 line, which lands one scanline higher than (400-i)/2
;;                 pixels 16..528 = bytes 2..65 solid, then bit 7 of 66
;;     bar lines   x = 16 to 528 step 16, y 330 down to 250
;;                 byte column 2 to 66 step 2, scanlines 34..74
;;                 every eighth one is two pixels wide - the separator
;; ---------------------------------------------------------------

SCRBASE   equ #C000
SHEETY0   equ 32                ; text row 5, first scanline
SHEETY1   equ 103               ; text row 13, last - and row 13 ENDS at 103.
                                ; 111 is the last scanline of row 14, which
                                ; is the first row of the panel's blocks, so
                                ; every redraw wiped a line of it
SHEETX    equ 2                 ; text column 3
SHEETW    equ 65                ; ... through column 67
STRY0     equ 34                ; first string
STRY1     equ 74                ; last, and the foot of the bar lines

;; B = scanline, C = byte column -> HL = screen address
;;
;; The (y/8)*80 used to be a loop of up to 24 additions, and this is called
;; once per character drawn - several hundred times for a page. A table of
;; the 25 row offsets costs 50 bytes and takes that out of the inner loop.
rowtab:
    defw 0,80,160,240,320,400,480,560,640,720,800,880,960,1040,1120
    defw 1200,1280,1360,1440,1520,1600,1680,1760,1840,1920

scraddr:
    ld a,b
    rrca
    rrca
    rrca
    and #1F                     ; y/8, the character row
    add a,a                     ; two bytes to a table entry
    ld e,a
    ld d,0
    ld hl,rowtab
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    ex de,hl                    ; HL = the row's offset
    ld e,c
    ld d,0
    add hl,de                   ; + the byte column
    ld a,b
    and 7                       ; (y AND 7) * 2048, which is *8 in the high
    add a,a                     ; byte
    add a,a
    add a,a
    add a,SCRBASE/256
    add a,h
    ld h,a
    ret

;; the note rows and the busy rows, blanked
fastclear:
    ld b,SHEETY0
fc1:
    push bc
    ld c,SHEETX
    call scraddr
    ld b,SHEETW
    xor a
fc2:
    ld (hl),a
    inc hl
    djnz fc2
    pop bc
    inc b
    ld a,b
    cp SHEETY1+1
    jr c,fc1
    ret

;; the six strings and the thirty-three bar lines
fastgrid:
    ld b,STRY0
fg1:
    push bc
    ld c,SHEETX
    call scraddr
    ld b,SHEETW-1
    ld a,#FF
fg2:
    ld (hl),a
    inc hl
    djnz fg2
    ld (hl),#80                 ; pixel 528, where the BASIC's DRAW ends
    pop bc
    ld a,b
    add a,8
    ld b,a
    cp STRY1+1
    jr c,fg1

    ld b,STRY0
fg3:
    push bc
    ld c,SHEETX
    call scraddr
    ld e,0
fg4:
    ld a,e
    and 7
    ld a,#80
    jr nz,fg5
    ld a,#C0                    ; every eighth is the bar separator
fg5:
    or (hl)
    ld (hl),a
    inc hl
    inc hl                      ; two text columns to a position
    inc e
    ld a,e
    cp 33
    jr c,fg4
    pop bc
    inc b
    ld a,b
    cp STRY1+1
    jr c,fg3
    ret

;; ---------------------------------------------------------------
;; Put back the grid inside one character cell. Printing anything - a
;; space over the marker, a digit, a rest - clears the cell to paper and
;; takes the lines with it. The BASIC's answer was to draw all six strings
;; again after every keypress; this touches eight bytes.
;; H = column, L = row, both 1 based, as TXT SET CURSOR takes them
;; ---------------------------------------------------------------
fixcell:
    ld a,l
    dec a
    add a,a
    add a,a
    add a,a                     ; (row-1)*8: the cell's first scanline
    ld b,a
    ld a,h
    dec a
    ld c,a                      ; byte column

    ld e,0                      ; does a bar line run down this column?
    ld a,c
    cp SHEETX
    jr c,fx1
    cp 67
    jr nc,fx1
    bit 0,a
    jr nz,fx1                   ; bars sit on even byte columns only
    sub SHEETX
    and 15
    ld e,#80
    jr nz,fx1
    ld e,#C0                    ; and every eighth is the separator
fx1:
    ld d,8                      ; the eight scanlines of the cell
fx2:
    push de
    push bc
    call scraddr
    pop bc
    pop de
    ld a,b
    cp STRY0
    jr c,fx_blank               ; above the top string
    cp STRY1+1
    jr nc,fx_blank              ; below the bottom one
    sub STRY0
    and 7
    jr nz,fx_bar                ; not on a string
    ld a,#FF                    ; on one: the whole byte
    jr fx_put
fx_bar:
    ld a,e
    jr fx_put
fx_blank:
    xor a
fx_put:
    ld (hl),a
    inc b
    dec d
    jr nz,fx2
    ret

;; the cell the marker sits in, which is the one just blanked
fixmarker:
    ld a,(cx)
    inc a
    ld h,a
    ld a,(cy)
    ld l,a
    jp fixcell

;; the cell the cursor points at
fixcursor:
    ld a,(cx)
    ld h,a
    ld a,(cy)
    ld l,a
    jp fixcell

;; ---------------------------------------------------------------
;; A private copy of the character matrices.
;;
;; TXT GET MATRIX hands back the address of a character's eight bytes, and
;; for the standard set that address is in the LOWER ROM - #3800 and up.
;; This program cannot read it: below #4000 the ROM is only there while the
;; firmware has paged it in, and reading it from here gets RAM. The first
;; version of drawch did exactly that and drew nothing but blanks, which
;; inverse video turned into solid blocks. Same rule that made the sound
;; block unreadable at #1000, from the other side.
;;
;; So the font is copied out once, with the ROM paged in for the copy, and
;; after that a glyph is eight bytes at FONT + character*8.
;; ---------------------------------------------------------------
KL_L_ROM_ENABLE  equ #B906      ; Measured, not looked up. The byte at
KL_L_ROM_DISABLE equ #B909      ; #3A08 - where TXT GET MATRIX says the
                                ; letter A lives - reads 00 before the call
                                ; to #B906 and 18 after it, which is the
                                ; apex of an A. #BCCE, which the manuals in
                                ; my head insisted on, changes nothing.
FONT             equ #8100      ; printable characters, eight bytes each,
                                ; ABOVE the song data and the file buffer.
                                ; It lived at #5800 until the program grew
                                ; past it and the font was written over the
                                ; panel and title text - which is what a
                                ; screen full of nonsense turned out to be.
FONTLO           equ 32         ; the range that is copied
FONTHI           equ 127
FONTREST         equ FONT+(FONTHI-FONTLO+1)*8    ; 206, the rest symbol
FONTARROW        equ FONTREST+8                  ; 241, the playing marker
FONTDITH         equ FONTARROW+8                 ; 233, the panel's pattern
FONTCOPY         equ FONTDITH+8                  ; 164, the copyright sign

buildfont:
    ld hl,FONT
    ld (bfdst),hl
    ld a,FONTLO
    ld (bfchr),a
bf1:
    call bfcopy
    ld a,(bfchr)
    inc a
    ld (bfchr),a
    cp FONTHI+1
    jr c,bf1
    ld a,206                    ; and the three beyond the printable range
    ld (bfchr),a                ; that this program draws: the rest, the
    call bfcopy                 ; marker that follows the playing position,
    ld a,241                    ; and the block the panel is made of
    ld (bfchr),a
    call bfcopy
    ld a,233
    ld (bfchr),a
    call bfcopy
    ld a,164
    ld (bfchr),a
    jp bfcopy

;; one character, from wherever the firmware keeps it to the copy
bfcopy:
    ld a,(bfchr)
    call TXT_GET_MATRIX
    ld (bfsrc),hl
    call KL_L_ROM_ENABLE        ; the standard matrices are in the lower
    ld hl,(bfsrc)               ; ROM, and this program cannot read there
    ld de,(bfdst)               ; without asking for it
    ld bc,8
    ldir
    ld (bfdst),de
    jp KL_L_ROM_DISABLE

bfsrc: defw 0
bfdst: defw 0
bfchr: defb 0

;; ---------------------------------------------------------------
;; One character, straight into the screen.
;;
;; In MODE 2 a character cell is eight pixels wide and one bit deep, so it
;; is exactly the eight bytes the firmware keeps as the character matrix -
;; TXT GET MATRIX hands them over. Writing them is 8 stores; asking the
;; firmware to print the same character costs about 1.7 ms, and a page is
;; several hundred characters.
;;
;; Consecutive scanlines inside one cell are 2048 bytes apart - the cell
;; never crosses a block boundary, because character rows are eight
;; scanlines and the blocks are too.
;;
;; A = character, (dcx),(dcy) = cell, (dcinv) = 0 or #FF for inverse
;; ---------------------------------------------------------------
TXT_GET_MATRIX  equ #BBA5

drawch:
    push bc                     ; callers keep counters and voice numbers in
    push de                     ; these - drawpage keeps the voice in C
    ld hl,FONTCOPY              ; the glyph, in the copy taken at startup
    cp 164
    jr z,dc_mat
    ld hl,FONTDITH
    cp 233
    jr z,dc_mat
    ld hl,FONTREST
    cp 206
    jr z,dc_mat
    ld hl,FONTARROW
    cp 241
    jr z,dc_mat
    cp FONTLO
    jr c,dc_blank
    cp FONTHI+1
    jr nc,dc_blank
    sub FONTLO
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    ld de,FONT
    add hl,de
    jr dc_mat
dc_blank:
    ld hl,FONT                  ; anything else prints as a space
dc_mat:
    ld (dcmat),hl
    ld a,(dcy)
    dec a
    add a,a
    add a,a
    add a,a                     ; the cell's first scanline
    ld b,a
    ld a,(dcx)
    dec a
    ld c,a
    call scraddr
    ex de,hl                    ; DE -> the screen
    ld hl,(dcmat)
    ld a,(dcinv)
    ld c,a
    ld b,8
dch1:
    ld a,(hl)
    xor c
    ld (de),a
    inc hl
    ld a,d
    add a,8                     ; next scanline: 2048 bytes on
    ld d,a
    djnz dch1
    pop de
    pop bc
    ret

dcx:   defb 0
dcy:   defb 0
dcinv: defb 0
dcmat: defw 0

;; ---------------------------------------------------------------
;; The information panel's background: rows 14 to 25, every cell the same
;; block. Through the firmware that is 880 characters at about 1.7 ms each
;; - a second and a half, and it runs again every time the panel comes back
;; after a catalogue, a help page or a load.
;;
;; Every cell being the same glyph means every scanline of a row is ONE
;; byte repeated eighty times, so the whole panel is 88 runs of 80 bytes.
;; ---------------------------------------------------------------
fastpanel:
    ld b,104                    ; scanlines 104..191 are text rows 14..24
fp_row:
    push bc
    ld c,0
    call scraddr                ; HL -> the left edge of this scanline
    pop bc
    push bc
    ld a,b
    and 7                       ; which row of the glyph this scanline is
    ld e,a
    ld d,0
    push hl
    ld hl,FONTDITH
    add hl,de
    ld a,(hl)
    pop hl
    ld b,10                     ; eighty bytes, eight at a time
fp_b:
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    djnz fp_b
    pop bc
    inc b
    ld a,b
    cp 200                      ; rows 14 to 25 - the last one finishes the
    jr c,fp_row                 ; frame under the bottom line of text
    ret

;; the same area, wiped to nothing - what the help page is drawn on
clearpanel:
    ld b,104
cp_row:
    push bc
    ld c,0
    call scraddr
    ld b,10
    xor a
cp_b:
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    djnz cp_b
    pop bc
    inc b
    ld a,b
    cp 200
    jr c,cp_row
    ret

;; ---------------------------------------------------------------
;; Row 3, the message line. Wiped directly: this runs after every
;; keypress, so that a message stays up until the next thing you do and
;; then goes, and 76 firmware characters a keystroke would cost an eighth
;; of a second each time. Row 4 is NOT cleared here any more - it carries
;; the repeat marks, and drawtakt looks after it.
;; ---------------------------------------------------------------
clearmsg:
    ld b,16                     ; scanlines 16..23 are text row 3
cm_row:
    push bc
    ld c,0
    call scraddr
    ld b,10
    xor a
cm_b:
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    djnz cm_b
    pop bc
    inc b
    ld a,b
    cp 24
    jr c,cm_row
    ret

;; row 2, where the repeat markers live
clearrow4:
    ld b,24                     ; scanlines 24..31 are text row 4
cr4_row:
    push bc
    ld c,0
    call scraddr
    ld b,10
    xor a
cr4_b:
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    djnz cr4_b
    pop bc
    inc b
    ld a,b
    cp 32
    jr c,cr4_row
    ret

;; a zero terminated string, straight to the screen at (dcx,dcy)
dputz:
    ld a,(hl)
    or a
    ret z
    inc hl
    push hl
    call drawch
    pop hl
    ld a,(dcx)
    inc a
    ld (dcx),a
    jr dputz
