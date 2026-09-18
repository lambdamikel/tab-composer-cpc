;; ---------------------------------------------------------------
;; TABCOMP/CPC - saving a .MUS song
;;
;; Line 1860 onwards:
;;
;;     OPENOUT "!"+a$+".muS"
;;     PRINT #9,werta                       how many positions follow
;;     FOR i=1 TO werta : FOR ii=1 TO 3
;;       PRINT #9,note(i,ii);laenge(i,ii)   one pair per line
;;     FOR i=0 TO 10 : PRINT #9,takta(i);taktb(i)
;;
;; PRINT of a positive number writes a space where the sign would go, the
;; digits, and a trailing space - so a line reads " 190  2 " and ends CR LF.
;; Written byte for byte the same way here, so a song saved by this program
;; loads in the 1986 BASIC and the other way round.
;;
;; The BASIC asks how far to save ("Bis zu welcher Stelle", 1-600). It does
;; not need to: the answer is always "as far as there is music", so that
;; question is gone and the end is worked out instead.
;; ---------------------------------------------------------------

CAS_OUT_OPEN   equ #BC8C
CAS_OUT_CLOSE  equ #BC8F
CAS_OUT_ABANDON equ #BC92
CAS_OUT_CHAR   equ #BC95

dosave:
    call getname
    jp nc,mainloop
    call dsk_select             ; which moves HL, so the name comes after
    ld a,(namelen)
    ld b,a
    ld hl,namebuf
    ld de,DSKBUF
    call TXT_VDU_DISABLE        ; AMSDOS keeps its opinions to itself
    call CAS_OUT_OPEN
    push af
    call TXT_VDU_ENABLE
    pop af
    jp nc,save_err

    call lastpos                ; how many positions carry anything
    ld a,h
    or l
    jr nz,sv_go
    call CAS_OUT_ABANDON
    ld hl,msg_empty
    jp savemsgw
sv_go:
    ld (svend),hl
    call outnum                 ; the count line
    call outeol

    ld hl,NOTES
    ld (svptr),hl
    ld hl,(svend)
    ld (svcount),hl
sv_pos:
    ld c,3                      ; the three voices of this position
sv_voice:
    push bc
    ld hl,(svptr)
    ld a,(hl)
    inc hl
    ld (svptr),hl
    push af
    call unpack                 ; packed byte -> the number the file wants
    call outnum
    pop af
    ld hl,(svptr)               ; ... and the length beside it
    dec hl
    ld de,LENS-NOTES
    add hl,de
    ld l,(hl)
    ld h,0
    call outnum
    call outeol
    pop bc
    dec c
    jr nz,sv_voice

    ld hl,(svcount)
    dec hl
    ld (svcount),hl
    ld a,h
    or l
    jr nz,sv_pos

    ld c,0                      ; and the eleven repeat pairs, which the
sv_rep:                         ; 1986 loader reads whether they are set or
    push bc                     ; not
    ld hl,takta
    call taktslot
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    call outnum
    pop bc
    push bc
    ld hl,taktb
    call taktslot
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    call outnum
    call outeol
    pop bc
    inc c
    ld a,c
    cp TAKTMAX
    jr c,sv_rep

    call CAS_OUT_CLOSE
    ld hl,msg_saved
    jp savemsg

;; Something went wrong: say so and HOLD it, because after typing a name
;; there is usually a keystroke still in the buffer and it would take the
;; message away before it could be read.
save_err:
    ld hl,msg_saveerr
savemsgw:
    call savemsg0
    call waitkey
    jp mainloop

;; It worked: say so, and empty the buffer so the message survives until
;; something is actually pressed.
savemsg:
    call savemsg0
    call flushkeys
    jp mainloop

savemsg0:
    push hl
    call clrmsg
    pop hl
    push hl
    ld h,1
    ld l,3
    call TXT_SET_CURSOR
    pop hl
    jp putz

flushkeys:
    call KM_READ_CHAR
    jr c,flushkeys
    ret

;; -> HL = the highest position that carries anything, 0 if the sheet is
;; empty. Saving stops there; everything past it is silence anyway.
lastpos:
    ld hl,NOTES+NPOS*3-1
    ld bc,NPOS*3
lp1:
    ld a,(hl)
    or a
    jr nz,lp2
    dec hl
    dec bc
    ld a,b
    or c
    jr nz,lp1
    ld hl,0                     ; nothing at all
    ret
lp2:
    dec bc                      ; BC = index of the last non-empty slot
    ld h,b                      ; position = index/3 + 1
    ld l,c
    ld de,3
    ld bc,0
lp3:
    or a
    sbc hl,de
    jr c,lp4
    inc bc
    jr lp3
lp4:
    ld h,b
    ld l,c
    inc hl
    ret

;; A = packed note -> HL = the number the file stores. The file keeps the
;; tablature position as decimal digits stuck together, which is what makes
;; the old files readable at a glance: 35 is string 3 fret 5, 212 is string
;; 2 fret 12. 99 is a held position, 88 a rest.
unpack:
    or a
    jr nz,up1
    ld hl,0
    ret
up1:
    cp #FE
    jr nz,up2
    ld hl,99
    ret
up2:
    cp #FF
    jr nz,up3
    ld hl,88
    ret
up3:
    ld b,a
    and #0F
    ld c,a                      ; fret
    ld a,b
    rrca
    rrca
    rrca
    rrca
    and #0F                     ; string
    ld de,10
    ld b,a
    ld a,c
    cp 10
    jr c,up4
    ld de,100                   ; two fret digits push the string up a place
up4:
    ld hl,0
up5:
    add hl,de
    djnz up5
    ld e,c
    ld d,0
    add hl,de
    ret

;; HL = value, written as PRINT does it: " digits "
outnum:
    ld a,' '
    call outch
    ld ix,decpow
    ld b,5
    ld c,0
on1:
    ld e,(ix+0)
    ld d,(ix+1)
    inc ix
    inc ix
    ld a,'0'-1
on2:
    inc a
    or a
    sbc hl,de
    jr nc,on2
    add hl,de
    cp '0'
    jr nz,on3
    ld a,c
    or a
    jr nz,on4
    ld a,b
    cp 1
    jr nz,on5                   ; a leading zero, and not the last digit
on4:
    ld a,'0'
on3:
    ld c,1
    push bc
    push hl
    push ix
    call outch
    pop ix
    pop hl
    pop bc
on5:
    djnz on1
    ld a,' '
    jp outch

;; HL = value, written as plain digits - no room for PRINT's spaces in a
;; BASIC line number
outdec:
    ld ix,decpow
    ld b,5
    ld c,0
od1:
    ld e,(ix+0)
    ld d,(ix+1)
    inc ix
    inc ix
    ld a,'0'-1
od2:
    inc a
    or a
    sbc hl,de
    jr nc,od2
    add hl,de
    cp '0'
    jr nz,od3
    ld a,c
    or a
    ld a,'0'
    jr nz,od3
    ld a,b
    cp 1
    ld a,'0'
    jr z,od3
    jr od4                      ; a leading zero writes nothing at all
od3:
    ld c,1
    push bc
    push hl
    push ix
    call outch
    pop ix
    pop hl
    pop bc
od4:
    djnz od1
    ret

;; HL -> a zero terminated string; HL is left past the terminator
outstr:
    ld a,(hl)
    inc hl
    or a
    ret z
    push hl
    call outch
    pop hl
    jr outstr

;; HL -> zero terminated lines, the block ended by an empty one
outlines:
    ld a,(hl)
    or a
    ret z
    call outstr
    call outeol
    jr outlines

outeol:
    ld a,13
    call outch
    ld a,10
outch:
    push af
    push bc
    push de
    push hl
    push ix
    call CAS_OUT_CHAR
    pop ix
    pop hl
    pop de
    pop bc
    pop af
    ret

;; ---------------------------------------------------------------
;; The directory, where the BASIC puts it: line 2130 does WINDOW SWAP 0,4
;; and CATs into the lower window, the one the information panel sits in.
;; A text window keeps the listing - and its scrolling - inside those rows
;; instead of pushing the whole screen up.
;; ---------------------------------------------------------------
TXT_WIN_ENABLE equ #BB66
CAS_CATALOG    equ #BC9B

showcat:
    ld h,0                      ; rows 14 to 25, all 80 columns, 0 based
    ld d,79
    ld l,13
    ld e,24
    call TXT_WIN_ENABLE
    call TXT_CLEAR_WIN
    call dsk_select
    ld de,DSKBUF
    call CAS_CATALOG
    ld h,0                      ; and the whole screen back, or every
    ld d,79                     ; TXT SET CURSOR after this would be
    ld l,0                      ; measured from the corner of the window
    ld e,24
    call TXT_WIN_ENABLE
    ret

;; Put the furniture back: the panel, and the labels around the sheet.
;; AMSDOS prints its own messages wherever the cursor happens to be, and a
;; "not found" long enough to wrap lands on the string names in columns 1
;; and 2 - which drawpage does not touch, since the sheet starts at column
;; 3. That left an O from BOUREE sitting where the top string's E belongs.
restorepanel:
    call panelfill
    ld hl,paneltxt
    call putblock
    ld hl,strnames
    call putblock
    ld hl,titletxt
    call putblock
    jp showinfo

;; ---------------------------------------------------------------
;; The file name. A prompt is the right shape for this one - it is a name,
;; not a parameter that could be a keypress - but it is a line editor, not
;; an INPUT: printable characters up to eight, DEL rubs one out, ENTER
;; accepts, ESC gives up.
;; ---------------------------------------------------------------
getname:
    ld h,1
    ld l,3
    call TXT_SET_CURSOR
    ld hl,msg_name
    call putz
    xor a
    ld (namelen),a
gn_loop:
    call KM_WAIT_CHAR
    cp 13
    jr z,gn_done
    cp 252
    jr z,gn_cancel
    cp 127
    jr z,gn_del
    cp ' '
    jr c,gn_loop
    cp 127
    jr nc,gn_loop
    ld b,a
    ld a,(namelen)
    cp 8
    jr nc,gn_loop
    ld a,b
    cp 'a'                      ; AMSDOS names are upper case
    jr c,gn_put
    cp 'z'+1
    jr nc,gn_put
    sub 32
gn_put:
    ld hl,nameb
    ld e,a
    ld a,(namelen)
    ld c,a
    ld b,0
    add hl,bc
    ld (hl),e
    inc a
    ld (namelen),a
    ld a,e
    call TXT_OUTPUT
    jr gn_loop

gn_del:
    ld a,(namelen)
    or a
    jr z,gn_loop
    dec a
    ld (namelen),a
    ld a,8                      ; back up, blank, back up again
    call TXT_OUTPUT
    ld a,' '
    call TXT_OUTPUT
    ld a,8
    call TXT_OUTPUT
    jr gn_loop

gn_cancel:
    call clrmsg
    or a                        ; carry clear: nothing to do
    ret

gn_done:
    ld a,(namelen)
    or a
    jr z,gn_cancel
    ld hl,nameb                 ; ... and the extension the format wants
    ld c,a
    ld b,0
    add hl,bc
    ld (hl),'.'
    inc hl
    ld (hl),'M'
    inc hl
    ld (hl),'U'
    inc hl
    ld (hl),'S'
    ld a,(namelen)
    add a,4                     ; ".MUS"
    ld (namelen),a
    call clrmsg
    scf
    ret

clrmsg:
    jp clearmsg

namelen: defb 0
;; The BASIC writes OPENOUT "!"+a$+".muS" - on tape the leading "!" means
;; "no messages", but AMSDOS does not strip it, it looks for a file called
;; !BOUREE. So the name goes in plain and the screen is repaired afterwards
;; instead: AMSDOS prints "not found" wherever the cursor happens to be.
namebuf:
nameb:   defs 16

svptr:   defw 0
svend:   defw 0
svcount: defw 0

msg_name:    defb "Name (8 characters): ",0
msg_saved:   defb "Saved.",0
msg_saveerr: defb "Error while saving!",0
msg_empty:   defb "Nothing to save.",0
