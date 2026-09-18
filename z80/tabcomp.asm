;; ---------------------------------------------------------------
;; TABCOMP/CPC - the 1986 Tabulations-Composer, in Z80
;; (C)2026 LAMBDAMIKEL + CLAUDE.  Assembles with rasm.
;;
;; Phase 1: draw the sheet, load a .MUS song, play it.
;;
;; The screen is the BASIC's screen, to the pixel - see LAYOUT.md. The
;; grid is graphics, the notes are text printed over it, and both go
;; through the firmware, so this looks like the original rather than
;; like a reimplementation of it.
;; ---------------------------------------------------------------

;; firmware
SCR_SET_MODE    equ #BC0E       ; A = mode
SCR_SET_OFFSET  equ #BC05       ; HL = offset
SCR_SET_INK     equ #BC32       ; A = ink, B/C = the two colours
SCR_SET_BORDER  equ #BC38       ; B/C = the two colours
TXT_OUTPUT      equ #BB5A       ; A = character
TXT_SET_CURSOR  equ #BB75       ; H = column, L = row, both 1 based
TXT_CUR_OFF     equ #BB84
TXT_VDU_ENABLE  equ #BB54       ; text to the screen, on...
TXT_VDU_DISABLE equ #BB57       ; ... and off, which is how AMSDOS is kept
                                ; quiet while it looks for a file
TXT_CLEAR_WIN   equ #BB6C
GRA_MOVE_ABS    equ #BBC0       ; DE = x, HL = y
GRA_LINE_ABS    equ #BBF6       ; DE = x, HL = y
KM_WAIT_CHAR    equ #BB06
MC_WAIT_FLYBACK equ #BD19

INVERSE         equ 24          ; the control code that swaps pen and paper

    ;; The code MUST live at #4000 or above. A binary loaded below that
    ;; leaves the firmware's sound manager mute: it accepts sounds, reports
    ;; the channel active, and never programs the AY. Measured: #1000 and
    ;; #2000 silent, #4000 and #9000 audible, with byte-identical code.
    org #4000
    jp start                    ; the first instruction must be the entry:
                                ; RUN" enters at the load address, whatever
                                ; the header's entry field says

    include "load.asm"
    include "play.asm"
    include "edit.asm"
    include "save.asm"
    include "screen.asm"
    include "takt.asm"
    include "bal.asm"
    include "midi.asm"

start:
    call buildfont              ; before anything is drawn
    call clearsong              ; nothing has cleared the note store yet, and
                                ; drawpage will happily render whatever RAM
                                ; happened to be at #6000
    call screen
    call setupenv               ; so a note can be auditioned before the
                                ; first time anything is played

    call fastgrid

    call labels

    call reveal

    call showinfo
mainloop:
    ;; The idle cursor: "<" one column right of the position, exactly
    ;; where the BASIC puts it while INKEY$ comes back empty.
    call curleft_lt
    call KM_WAIT_CHAR
    push af
    call curblank               ; erase it again before acting on the key
    call fixmarker              ; ... and put back the grid it sat on
    call clearmsg               ; and whatever was said last time goes now:
                                ; a message stays up until the next thing
                                ; you do, which is long enough to read and
                                ; short enough not to linger
    pop af

    cp 243 : jp z,goright
    cp 242 : jp z,goleft
    cp 241 : jp z,godown
    cp 240 : jp z,goup
    cp 't' : jp z,dotakt         ; T is the repeat key, as in 1986
    cp 'T' : jp z,dotakt
    cp 'a' : jp z,dotaktlist
    cp 'A' : jp z,dotaktlist
    cp 'p' : jp z,doplay
    cp 'P' : jp z,doplay
    cp 'l' : jp z,doload
    cp 'L' : jp z,doload
    cp 'n' : jp z,donotelen
    cp 'N' : jp z,donotelen
    cp 13  : jp z,doentry        ; ENTER starts a note
    cp 224 : jp z,doentry        ; ... and so does COPY, as in 1986
    cp 127 : jp z,dodelete       ; DEL
    cp 16  : jp z,dodelete       ; CLR
    cp 'b' : jp z,dobal          ; the song as a BASIC program
    cp 'B' : jp z,dobal
    cp 's' : jp z,dosave
    cp 'S' : jp z,dosave
    cp '+' : jp z,donextpage
    cp '-' : jp z,doprevpage
    cp 'c' : jp z,docat
    cp 'C' : jp z,docat
    cp 'h' : jp z,dohelp
    cp 'H' : jp z,dohelp
    cp 'i' : jp z,doinstr        ; which MIDI instrument
    cp 'I' : jp z,doinstr
    cp 'm' : jp z,domode         ; AY, MIDI, or both
    cp 'M' : jp z,domode
    cp 'v' : jp z,dovib
    cp 'V' : jp z,dovib
    cp '<' : jp z,dofaster
    cp '>' : jp z,doslower
    ;; ESC does NOT leave. It means "out of what I am in" during note
    ;; entry, and a key that cancels in one place must not throw the song
    ;; away in another. Q quits.
    cp 'q' : jp z,leave
    cp 'Q' : jp z,leave
    jp mainloop

;; ---------------------------------------------------------------
;; Movement. All four cursor keys just move.
;;
;; In 1986 the left arrow deleted the note on the current string, so it
;; could not also be used to go back - and that is the entire reason the
;; "Korrektursaite" exists: an extra row above the top string whose only
;; purpose was to give the left arrow somewhere harmless to mean "move".
;; With DEL and CLR doing the deleting, the left arrow moves like the
;; other three and the correction row has nothing left to do, so it is
;; gone: the cursor lives on rows 5 to 10, the six strings.
;; ---------------------------------------------------------------
dotest:
    call testnote
    jp mainloop

doplay:
    call playsong
    jp mainloop

;; The vibrato depth. Line 3330 asks for it before every playback; here it
;; is a key, and the eight tone envelopes are rebuilt from it on the spot.

;; ---------------------------------------------------------------
;; The key list, on a page of its own - line 2860's "H=Hilfe". Rows 3 and
;; 4 stay empty on the sheet, because that is where prompts and messages
;; go: the BASIC's window #3 is row 3 and nothing else may live there.
;; ---------------------------------------------------------------
docat:
    call showcat
    call waitkey                ; flush first: the C that asked for the
                                ; catalogue can still be in the buffer, and
                                ; it would dismiss the listing at once
    call restorepanel
    jp mainloop

;; The key list goes in the panel - the same window the catalogue uses,
;; which is where the BASIC puts anything needing room (WINDOW SWAP 0,4,
;; line 2130). Two columns, and the sheet above is never disturbed, so
;; there is nothing to redraw afterwards but the panel itself. The
;; coordinates in helptxt are relative to that window: its row 1 is
;; screen row 14.
dohelp:
    call clearpanel             ; the panel area, wiped - and the rows below
    ld hl,helptxt               ; are written straight to the screen, so no
    call putblock               ; window is needed to hold them in place
    call KM_WAIT_CHAR
    call restorepanel
    jp mainloop

;; ---------------------------------------------------------------
;; I: the General MIDI instrument, for all three channels - the tablature
;; is one guitar, so one choice covers it. While the music plays, + and -
;; step through them instead, which is how a sound gets found by ear.
;; ---------------------------------------------------------------
doinstr:
    ld hl,msg_instr
    call getnum
    jp nc,mainloop
    ld a,h
    or a
    jr nz,di_done               ; over 255: not a program number
    ld a,l
    or a
    jr z,di_done                ; and nor is nought
    cp 129
    jr nc,di_done
    dec a                       ; GM counts from 1, MIDI from 0
    ld (midiprog),a
    call midiprogram
di_done:
    call clrmsg
    call showinfo
    jp mainloop

msg_instr: defb "MIDI instrument, 1 to 128 (25 = guitar)? ",0

domode:
    ld a,(outmode)
    inc a
    cp 4
    jr c,dm1
    ld a,1
dm1:
    ld (outmode),a
    call midialloff             ; changing horses mid-stream leaves notes on
    call showinfo
    jp mainloop

dovib:
    ld a,(vib)
    inc a
    cp 16
    jr c,dv1
    xor a
dv1:
    ld (vib),a
    call buildents
    call showinfo
    jp mainloop

dofaster:
    ld a,(speed)
    cp 18
    jp c,mainloop
    sub 6
    jr dsp1
doslower:
    ld a,(speed)
    cp 240
    jp nc,mainloop
    add a,6
dsp1:
    ld (speed),a
    call setspeed
    call showinfo
    jp mainloop

doload:
    call showcat                ; what is on the disc, before asking for a
    call getname                ; name - the BASIC makes you remember, or
    jr c,dl_go                  ; press C first
    call restorepanel
    jp mainloop
dl_go:
    call loadmus
    jr c,dl_ok
    ;; A failure has to be READ, so it is held until a key is pressed -
    ;; and then this must NOT fall into the path below. It used to, and
    ;; that path printed again from whatever HL held after the firmware's
    ;; key call: putz walked off into memory until it met a zero, spraying
    ;; characters across the screen and flashing the border with whatever
    ;; control codes it found on the way.
    ld hl,failmsg
    call showmsg
    call waitkey
    call clrmsg                 ; the key that acknowledged it takes it away
    jr dl_end
dl_ok:
    ld hl,okmsg
    call showmsg
    call flushkeys              ; so a key left over from typing the name
                                ; does not wipe the message at once
dl_end:
    call restorepanel
    call drawpage
    call redraw
    jp mainloop

;; HL -> a message: on the message line, alone
showmsg:
    push hl
    call clrmsg
    ld h,1
    ld l,3
    call TXT_SET_CURSOR
    pop hl
    jp putz

goright:
    ld a,(cx)
    cp 65                       ; last column of the sheet?
    jr c,gr_same
    ;; Off the end of the page. The BASIC stops here and asks "Notenblatt
    ;; korekt <J><N>" before moving to the next sheet (line 1200); the page
    ;; just turns.
    ld hl,(zeiger)
    ld de,NPOS-1
    or a
    sbc hl,de
    jp nc,mainloop              ; ... but not past the end of the store
    ld hl,(pagetop)
    ld de,32
    add hl,de
    ld (pagetop),hl
    ld hl,(zeiger)
    inc hl
    ld (zeiger),hl
    ld a,3
    ld (cx),a
    call bumptakt
    call drawpage
    call redraw
    jp mainloop
gr_same:
    add a,2
    ld (cx),a
    ld hl,(zeiger)
    inc hl
    ld (zeiger),hl
    ld a,(controlle)
    inc a
    cp 9
    jr c,gr1
    ld a,1
gr1:
    ld (controlle),a
    call redraw
    jp mainloop

goleft:
    ld a,(cx)
    cp 3
    jr nz,gl_same
    ld hl,(pagetop)             ; back a page, if there is one
    ld de,32
    or a
    sbc hl,de
    jp c,mainloop
    ld a,h
    or l
    jp z,mainloop
    ld (pagetop),hl
    ld hl,(zeiger)
    dec hl
    ld (zeiger),hl
    ld a,65
    ld (cx),a
    call dropfakt
    call drawpage
    call redraw
    jp mainloop
gl_same:
    sub 2
    ld (cx),a
    ld hl,(zeiger)
    dec hl
    ld (zeiger),hl
    ld a,(controlle)
    dec a
    jr nz,gl1
    ld a,8
gl1:
    ld (controlle),a
    call redraw
    jp mainloop

;; ---------------------------------------------------------------
;; A whole sheet at a time - the BASIC's + and - (lines 4300 and 4350),
;; which set x=3 and controlle=1 and move zeiger by 32. Same here, minus
;; the "Blatt Nummer 18. Weiter blaettern unmoeglich!!!" fanfare.
;; ---------------------------------------------------------------
MAXPAGE equ 641                 ; 1 + 20*32: the last page that fits in 700

donextpage:
    ld hl,(pagetop)
    ld de,32
    add hl,de
    ld de,MAXPAGE+1
    or a
    sbc hl,de
    jp nc,mainloop
    add hl,de
    jr setpage

doprevpage:
    ld hl,(pagetop)
    ld de,32
    or a
    sbc hl,de
    jp c,mainloop
    ld a,h
    or l
    jp z,mainloop

setpage:
    ld (pagetop),hl
    ld (zeiger),hl              ; the cursor goes to the head of the sheet
    ld a,3
    ld (cx),a
    ld a,1
    ld (controlle),a
    call drawpage
    call redraw
    jp mainloop

bumptakt:
    ld a,(controlle)
    inc a
    cp 9
    jr c,bt1
    ld a,1
bt1:
    ld (controlle),a
    ret

dropfakt:
    ld a,(controlle)
    dec a
    jr nz,dt1
    ld a,8
dt1:
    ld (controlle),a
    ret

godown:
    ld a,(cy)
    cp 10
    jp nc,mainloop
    inc a
    ld (cy),a
    call redraw
    jp mainloop

goup:
    ld a,(cy)
    cp 5                        ; the top string, with nothing above it
    jp z,mainloop
    dec a
    ld (cy),a
    call redraw
    jp mainloop

;; Empty the keyboard first - after typing a name there is usually a key
;; still waiting, and it would take the message away before it was read -
;; then hold until something is pressed.
waitkey:
    call KM_READ_CHAR
    jr c,waitkey
    jp KM_WAIT_CHAR

leave:
    ld h,1                      ; ask first - this throws the song away, and
    ld l,3                      ; there is no way back from it
    call TXT_SET_CURSOR
    ld hl,msg_quit
    call putz
    call KM_WAIT_CHAR
    and #DF                     ; either case will do
    cp 'J'
    jr z,doleave
    cp 'Y'
    jr z,doleave
    call clrmsg
    jp mainloop

doleave:
    ei
    jp 0                        ; reset: the only clean way back to BASIC

msg_quit: defb "Really quit? (Y/N)",0

;; Blanking the marker punches a hole in the grid under it. The BASIC
;; redraws all six strings after every keypress - line 1520 ends in GOTO
;; 730, "Saiten zeichnen" - which here would be a quarter of a second per
;; move. The hole is one cell, so one cell is repaired, by whoever made it.
redraw:
    jp showinfo

;; the page the editing cursor is on - the cursor moves across the page and
;; zeiger moves with it, so the page starts (cx-3)/2 positions before it
editpage:
    ld a,(cx)
    sub 3
    srl a                       ; two columns to a position
    ld c,a
    ld b,0
    ld hl,(zeiger)
    or a
    sbc hl,bc
    ld (pagetop),hl
    ret

;; ---------------------------------------------------------------
;; Draw the visible page: 32 positions from zeiger, two columns apart
;; starting at column 3. A fret is one HEX digit, so 10, 11 and 12 show
;; as A, B and C - which is what the 1986 manual's diagram says. A rest
;; is CHR$(206). Underneath, rows 11 to 13 show which voice is busy,
;; as the string number followed by AA, BB or CC in inverse video.
;; ---------------------------------------------------------------
drawpage:
    call clearsheet
    call fastgrid               ; the grid goes down first: a digit printed
                                ; on top of it keeps its own cell, where a
                                ; line drawn afterwards would run straight
                                ; through the glyph
    ;; fall through: the page on show, drawn over the grid
drawcells:
    call drawtakt               ; the repeat markers belong to the page too
    ld hl,(pagetop)             ; which 32 positions are on show
    dec hl                      ; index = (page-1)*3
    ld d,h
    ld e,l
    add hl,hl
    add hl,de
    ld de,NOTES
    add hl,de
    ld (dpptr),hl
    ld a,3
    ld (dpcol),a
    ld b,32
dp_slot:
    push bc
    ld c,1                      ; voice 1..3
dp_voice:
    push bc
    ld hl,(dpptr)
    ld a,(hl)
    inc hl
    ld (dpptr),hl
    or a
    jp z,dp_next                ; nothing on this voice here

    push af
    cp #FE
    jr z,dp_busy                ; held: only the busy bar, no new digit
    cp #FF
    jr z,dp_rest

    ;; a note: fret on the string's row
    ld b,a
    and #0F                     ; fret
    cp 10
    jr c,dp_dig
    add a,'A'-10
    jr dp_put
dp_dig:
    add a,'0'
dp_put:
    push af
    ld a,b
    rrca
    rrca
    rrca
    rrca
    and #0F                     ; string 1..6
    add a,4                     ; row 5..10
    ld (dcy),a
    ld a,(dpcol)
    ld (dcx),a
    xor a
    ld (dcinv),a
    pop af
    call drawch
    jr dp_busy

dp_rest:
    ld a,(dpcol)                ; a rest sits on its string's row too
    ld (dcx),a
    ld a,10                     ; the packed rest carries no string, so it
    ld (dcy),a                  ; goes on the bottom string row, as the
    xor a                       ; BASIC does when the string digit is 8
    ld (dcinv),a
    ld a,206
    call drawch

dp_busy:
    pop af                      ; the voice's busy marker underneath
    push af
    cp #FE
    jr z,dp_bdone               ; held: the bar of the note it belongs to
                                ; already reaches this far, and drawing one
                                ; per position put a space through the last
                                ; letter of the one before
    rrca
    rrca
    rrca
    rrca
    and #0F
    cp 9
    jr nc,dp_b1                 ; a rest has no string number
    add a,'0'
    jr dp_b2
dp_b1:
    ld a,' '
dp_b2:
    ld (bstr),a
    ld a,(dpcol)
    ld (bcol),a
    ld a,c
    ld (bvoice),a
    ld hl,(dpptr)               ; the length this note was given
    dec hl
    ld de,LENS-NOTES
    add hl,de
    ld a,(hl)
    or a
    jr nz,dp_b3
    inc a
dp_b3:
    ld (blen),a
    push bc
    call drawbar
    pop bc
dp_bdone:
    pop af

dp_next:
    pop bc
    inc c
    ld a,c
    cp 4
    jp c,dp_voice
    ld a,(dpcol)                ; on to the next position, two columns over
    add a,2
    ld (dpcol),a
    pop bc
    dec b
    jp nz,dp_slot
    ret

;; ---------------------------------------------------------------
;; Take the page on show off the screen WITHOUT touching the grid - the
;; grid is the same on every page, and redrawing it was most of what a
;; page turn cost. The bar rows have no grid in them and are cleared
;; outright; on the string rows only the cells that carry a digit are
;; touched, and fixcell puts the grid back in each one.
;; ---------------------------------------------------------------
erasecells:
    ld b,80                     ; scanlines 80..103: rows 11, 12 and 13
ec1:
    push bc
    ld c,SHEETX
    call scraddr
    ld b,SHEETW
    xor a
ec2:
    ld (hl),a
    inc hl
    djnz ec2
    pop bc
    inc b
    ld a,b
    cp 104
    jr c,ec1

    ld hl,(pagetop)             ; index = (page-1)*3
    dec hl
    ld d,h
    ld e,l
    add hl,hl
    add hl,de
    ld de,NOTES
    add hl,de
    ld (dpptr),hl
    ld a,3
    ld (dpcol),a
    ld b,32
ec3:
    push bc
    ld c,3
ec4:
    push bc
    ld hl,(dpptr)
    ld a,(hl)
    inc hl
    ld (dpptr),hl
    or a
    jr z,ec5                    ; nothing was drawn here
    cp #FE
    jr z,ec5                    ; a held marker draws no digit of its own
    cp #FF
    jr nz,ec_note
    ld a,10                     ; a rest sits on the bottom string row
    jr ec_fix
ec_note:
    rrca
    rrca
    rrca
    rrca
    and #0F
    add a,4                     ; the string's row
ec_fix:
    ld l,a
    ld a,(dpcol)
    ld h,a
    call fixcell
ec5:
    pop bc
    dec c
    jr nz,ec4
    ld a,(dpcol)
    add a,2
    ld (dpcol),a
    pop bc
    djnz ec3
    ret

;; blank the note rows and the busy rows
clearsheet:
    jp fastclear

dpptr: defw 0
dpcol: defb 3

;; ---------------------------------------------------------------
;; The marker, at column cx+1 on row cy
;; ---------------------------------------------------------------
curleft_lt:
    ld a,'<'
    jr curput
curblank:
    ld a,' '
curput:
    push af
    ld a,(cx)
    inc a
    ld h,a
    ld a,(cy)
    ld l,a
    call TXT_SET_CURSOR
    pop af
    jp TXT_OUTPUT

;; ---------------------------------------------------------------
;; The live fields in the panel: note position, screen position, which
;; string the marker is on, and where it sits in the bar.
;; ---------------------------------------------------------------
showinfo:
    ld hl,(zeiger)              ; row 16: Notenposition
    ld e,16
    call putval

    ld a,(cy)                   ; row 20: the string number, and then the
    sub 4                       ; label right after it, which is how the
    ld l,a                      ; BASIC does it - PRINT y-4; then the text,
    ld h,0                      ; so the label follows the trailing space
    ld e,20
    call putval
    ld hl,saitetxt
    call putz

    ld a,(cx)                   ; row 21: Bildschirmposition
    sub 2
    ld l,a
    ld h,0
    ld e,21
    call putval

    ld a,(controlle)            ; row 23: Position im Takt
    ld l,a
    ld h,0
    ld e,23
    call putval
    jp moreinfo

;; HL = value, E = row. Prints at column 2 as " digits ", left aligned,
;; which is what Locomotive BASIC's PRINT does with a positive integer:
;; a space where the sign would go, the digits, and a trailing space.
;; The cursor is left just after it, so a label can follow.
putval:
    ;; A FIXED five columns - space, three right aligned digits, space - so
    ;; that the dotted part of every label begins in the same column. With
    ;; a number printed at its natural width, a 1 and a 612 pushed the dots
    ;; two columns apart and the left edge of the panel wandered.
    push hl
    ld h,2                      ; column 2
    ld l,e
    call TXT_SET_CURSOR
    pop hl
    ld a,' '
    call TXT_OUTPUT
    call put3
    ld a,' '
    jp TXT_OUTPUT

;; HL = value, printed without leading zeros. C stays 0 while leading
;; zeros are still being suppressed; the last digit always prints, so 0
;; comes out as "0" rather than as nothing.
putdec:
    ld ix,decpow
    ld b,5
    ld c,0
pd1:
    ld e,(ix+0)
    ld d,(ix+1)
    inc ix
    inc ix
    ld a,'0'-1
pd2:
    inc a
    or a
    sbc hl,de
    jr nc,pd2
    add hl,de                   ; A = this digit as a character
    cp '0'
    jr nz,pdprint               ; a real digit always prints
    ld a,c
    or a
    jr nz,pdzero                ; already past the leading zeros
    ld a,b
    cp 1
    jr nz,pdskip                ; still leading, and not the last digit
pdzero:
    ld a,'0'
pdprint:
    ld c,1
    push bc
    push hl
    push ix
    call TXT_OUTPUT
    pop ix
    pop hl
    pop bc
pdskip:
    djnz pd1
    ret

;; HL = zero terminated string, printed where the cursor is
putz:
    ld a,(hl)
    inc hl
    or a
    ret z
    push hl
    call TXT_OUTPUT
    pop hl
    jr putz

decpow: defw 10000,1000,100,10,1

;; HL = value in three columns, right aligned: PRINT USING "###"
put3:
    ld ix,decpow+4              ; 100, 10, 1
    ld b,3
    ld c,0
p31:
    ld e,(ix+0)
    ld d,(ix+1)
    inc ix
    inc ix
    ld a,'0'-1
p32:
    inc a
    or a
    sbc hl,de
    jr nc,p32
    add hl,de
    ;; A holds this digit - and it must still hold it at p33. Testing C and
    ;; B for "print it anyway" overwrites A with those, so reloading '0' is
    ;; not optional: without it a trailing zero printed CHR$(1), which the
    ;; firmware takes as "print the next character literally". The nought
    ;; vanished and ate the character after it, so a channel switched off
    ;; kept showing its old envelope and an empty one showed the panel
    ;; through. LD does not touch the flags, so the tests still stand.
    cp '0'
    jr nz,p33                   ; a real digit prints as itself
    ld a,c
    or a
    ld a,'0'
    jr nz,p33                   ; already past the leading zeros
    ld a,b
    cp 1
    ld a,'0'
    jr z,p33                    ; the last digit always prints
    ld a,' '                    ; ... a leading zero is a space
    jr p34
p33:
    ld c,1
p34:
    push bc
    push hl
    push ix
    call TXT_OUTPUT
    pop ix
    pop hl
    pop bc
    djnz p31
    ret

;; H = column, L = row, HL after: the value at that spot in three columns
putat3:
    push de
    call TXT_SET_CURSOR
    pop hl
    jp put3

saitetxt: defb "...Guitar String......",0

zeiger:    defw 1
pagetop:   defw 1               ; the first position of the 32 on screen.
                                ; While editing it follows the cursor; while
                                ; playing it follows the music.
cx:        defb 3
cy:        defb 5
controlle: defb 1

;; ---------------------------------------------------------------
;; Mode 2, everything black, so the grid can be drawn unseen and
;; then revealed in one go - exactly what the BASIC does with
;; INK 1,0 ... INK 1,24.
;; ---------------------------------------------------------------
screen:
    ld a,2
    call SCR_SET_MODE
    ;; The CPC scrolls in HARDWARE - the display start moves, the memory
    ;; does not. The firmware's own text output follows that, but writing
    ;; to #C000 directly does not, so one scroll and the grid is drawn
    ;; somewhere the screen no longer starts. Put the offset back to zero
    ;; and keep every print inside the 80 columns.

    xor a                       ; ink 0 = black
    ld b,0
    ld c,0
    call SCR_SET_INK
    ld b,0                      ; border black
    ld c,0
    call SCR_SET_BORDER
    ld a,1                      ; ink 1 = black for now: invisible
    ld b,0
    ld c,0
    call SCR_SET_INK
    call TXT_CUR_OFF
    ret

reveal:
    ld a,1
    ld b,24                     ; the BASIC's INK 1,24
    ld c,24
    call SCR_SET_INK
    ret

;; ---------------------------------------------------------------
;; The grid. Bar lines every 16 pixels from x=16 to x=534, every
;; eighth one doubled; then the six strings across.
;; ---------------------------------------------------------------

;; ---------------------------------------------------------------
;; The static text: the string names down the left, the title, and
;; the labels in the information panel.
;; ---------------------------------------------------------------
labels:
    call panelfill
    ld hl,strnames
    call putblock
    ld hl,titletxt
    call putblock
    ld hl,paneltxt
    call putblock
    ret

;; Rows 14 to 24 are filled with CHR$(233), the dither block, which is
;; what the information panel sits on. 11 rows of 80, printed as one run
;; exactly as the BASIC does it.
panelfill:
    jp fastpanel

;; A block is a list of (column, row, string) runs, terminated by 0.
;; Strings are zero terminated.
putblock:
putb1:
    ld a,(hl)
    or a
    ret z
    ld (dcx),a                  ; column
    inc hl
    ld a,(hl)
    ld (dcy),a                  ; row
    inc hl
    xor a
    ld (dcinv),a
putb2:
    ld a,(hl)
    inc hl
    or a
    jr z,putb1
    cp INVERSE
    jr nz,putb3
    ld a,(dcinv)                ; the control code flips inverse video, as
    cpl                         ; it would if the firmware were printing
    ld (dcinv),a
    jr putb2
putb3:
    push hl
    call drawch
    pop hl
    ld a,(dcx)
    inc a
    ld (dcx),a
    jr putb2

;; ---------------------------------------------------------------

strnames:
    defb 1,5  : defb "E",INVERSE,"1",INVERSE,0
    defb 1,6  : defb "H",INVERSE,"2",INVERSE,0
    defb 1,7  : defb "G",INVERSE,"3",INVERSE,0
    defb 1,8  : defb "D",INVERSE,"4",INVERSE,0
    defb 1,9  : defb "A",INVERSE,"5",INVERSE,0
    defb 1,10 : defb "E",INVERSE,"6",INVERSE,0
    defb 0

helptxt:
    defb 2,14  : defb "CURSOR",0
    defb 12,14 : defb "Move the marker",0
    defb 2,15  : defb "ENTER",0
    defb 12,15 : defb "Enter a note",0
    defb 4,16  : defb "UP/DOWN",0
    defb 12,16 : defb "Choose the fret",0
    defb 4,17  : defb "ENTER",0
    defb 12,17 : defb "Keep it",0
    defb 4,18  : defb "SPACE",0
    defb 12,18 : defb "Rest",0
    defb 4,19  : defb "ESC",0
    defb 12,19 : defb "Cancel",0
    defb 2,20  : defb "DEL CLR",0
    defb 12,20 : defb "Delete the note",0
    defb 2,21  : defb "N",0
    defb 12,21 : defb "Note length",0
    defb 2,22  : defb "+ -",0
    defb 12,22 : defb "Sheet forward / back",0
    defb 2,23 : defb "L S C B",0
    defb 12,23: defb "Load Save Catalogue Basic",0
    defb 2,24 : defb "V I",0
    defb 12,24: defb "Vibrato / instrument",0

    defb 42,14 : defb "P",0
    defb 52,14 : defb "Play",0
    defb 42,15 : defb "< >",0
    defb 52,15 : defb "Tempo",0
    defb 42,16 : defb "SPACE",0
    defb 52,16 : defb "From the top",0
    defb 42,17 : defb "ESC",0
    defb 52,17 : defb "Stop",0
    defb 42,18 : defb "M + -",0
    defb 52,18 : defb "AY / MIDI / both, instrument",0
    defb 42,19 : defb "T A",0
    defb 52,19 : defb "Set / show a repeat",0
    defb 42,20 : defb "A B C",0
    defb 52,20 : defb "ENT of that voice + 1",0
    defb 42,21 : defb "a b c",0
    defb 52,21 : defb "ENV of that voice + 1",0
    defb 42,22 : defb "1 2 3",0
    defb 52,22 : defb "ENV to 0: voice muted",0
    defb 42,23 : defb "4 5 6",0
    defb 52,23 : defb "ENT to 0: no vibrato",0
    defb 42,24 : defb "H Q",0
    defb 52,24 : defb "Help / Quit",0
    defb 66,24 : defb "Press any key",0
    defb 0

titletxt:
    defb 1,1  : defb "CPC Tab Composer Version 2.0  ",164," 2026 Claude & Michael Wessel",0
    defb 72,1 : defb "H = HELP",0
    defb 1,2  : defb "Original BASIC   Version 1.0  ",164," 1986 Michael Wessel",0
    defb 0

paneltxt:
    defb 40,15: defb "Voice A:",0
    defb 40,16: defb "Voice B:",0
    defb 40,17: defb "Voice C:",0
    defb 40,18: defb "Playing:",0
    defb 40,19: defb "Time   :",0
    defb 40,20: defb "Vibrato:",0
    defb 40,21: defb "Speed  :",0
    defb 40,22: defb "Output :",0
    defb 40,23: defb "Instr. :",0
    defb 60,15: defb "ENV Voice A:",0
    defb 60,16: defb "ENV Voice B:",0
    defb 60,17: defb "ENV Voice C:",0
    defb 60,18: defb "ENT Voice A:",0
    defb 60,19: defb "ENT Voice B:",0
    defb 60,20: defb "ENT Voice C:",0
    defb 60,22: defb "A B C = ENT +1 ",0
    defb 60,23: defb "a b c = ENV +1 ",0
    defb 60,24: defb "1 - 6 = off    ",0
    defb 2,15 : defb " .......Free Channels......",0
    defb 2,16 : defb "........Note Position......",0
    defb 2,17 : defb " .......Channel Number.....",0
    defb 2,18 : defb " .......Sheet Number.......",0
    defb 2,19 : defb " .......Note Value.........",0
    defb 2,21 : defb "........Screen Position....",0
    defb 2,22 : defb "     ......................",0
    defb 2,23 : defb "........Position in Bar....",0
    defb 0

tabend:

;; The font is copied to FONT at startup. If the program ever grows into
;; it, that copy lands on the program's own tail - which is the text tables
;; at the end of this file - and the screen fills with nonsense. Fail here
;; instead.
    assert tabend < NOTES        ; the song data comes first now
    assert tabend < FONT

    save "TABCOMP.BIN", #4000, tabend-#4000, AMSDOS, start
