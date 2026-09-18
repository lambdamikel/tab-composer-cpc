;; ---------------------------------------------------------------
;; TABCOMP/CPC - the editor
;;
;; ENTER starts note entry. Cursor up/down pick the fret 0..12, wrapping,
;; shown as a hex digit where the note will sit; ENTER commits it, ESC
;; escapes, SPACE turns it into a rest. COPY still works for both, which is
;; what 1986 fingers will try. The left arrow on a string row
;; deletes instead of moving - the 1986 keymap, kept for now.
;;
;; The note is written exactly as line 1690 writes it: the note itself at
;; the cursor, its length beside it, and art-1 held markers after it. The
;; BASIC uses 99 for those, the loader already turns 99 into #FE, so a
;; song typed in here and a song loaded from disc are the same thing in
;; memory - the busy bars and the playback both come out right with no
;; special case.
;;
;; One deliberate change from 1986. Line 1590 plays SOUND 130,100,10,15
;; every time the fret changes: a fixed click, the same pitch whichever
;; fret you are on, which is no help when the whole point is choosing a
;; note. Here you hear THE NOTE. It costs nothing - the player already
;; knows how to turn a packed note into a sound, so entry just asks it.
;; ---------------------------------------------------------------

KEY_COPY    equ 224             ; still accepted, but ENTER is the key now:
KEY_ENTER   equ 13              ; COPY is awkward to reach on a modern
KEY_ESC     equ 252             ; keyboard, and ENTER to start a note and
KEY_SPACE   equ 32              ; ENTER to keep it reads better than ENTER
                                ; meaning "give up on it"
KEY_UP      equ 240
KEY_DOWN    equ 241

;; the BASIC's "art": 8 whole, 4 half, 2 quarter, 1 eighth. Line 530
;; starts it at 8, and line 2530 changes it by asking a question. Here N
;; cycles it, because a question is a terrible way to set a value you
;; change every few notes.
art:        defb 8
;; the BASIC's "note" survives between entries - line 1560 jumps straight
;; to the PRINT HEX$(note), so a new entry starts on the fret you used
;; last. Kept: it means a run of notes on one fret is one keypress each.
entryfret:  defb 0
entryvoice: defb 0
packed:     defb 0
wert:       defw 0                  ; the value shown in the panel

;; ---------------------------------------------------------------
;; ENTER (or COPY). Line 990 refuses on the correction row; there is no
;; correction row any more, so every row the cursor can reach is a string.
;; ---------------------------------------------------------------
doentry:
    ;; Is there already a note on this string at this position? Then this
    ;; is an edit of that note, not a new one. Without this you could put
    ;; the same string and fret on all three channels at once - a chord no
    ;; guitar can play, since one string sounds one note.
    call findnote
    or a
    jr z,ent_fresh
    ld (entryvoice),a
    ld a,(hl)                   ; its fret is where the choosing starts
    cp #FF
    jr nz,ent_ed1
    xor a                       ; ... except a rest, which has none
    jr ent_ed2
ent_ed1:
    and #0F
ent_ed2:
    ld (entryfret),a
    call delnote                ; off the sheet, so its length may change
    jr ent_start

ent_fresh:
    call freevoice
    or a
    jp z,ent_busy
    ld (entryvoice),a
ent_start:
    call showfret
    call soundfret

ent_loop:
    call KM_WAIT_CHAR
    cp KEY_ENTER
    jp z,ent_accept
    cp KEY_COPY
    jp z,ent_accept
    cp KEY_ESC
    jr z,ent_cancel
    cp KEY_SPACE
    jp z,ent_rest
    cp KEY_UP
    jr z,ent_up
    cp KEY_DOWN
    jr z,ent_down
    jr ent_loop

ent_up:
    ld a,(entryfret)
    inc a
    cp 13
    jr c,ent_set
    xor a
    jr ent_set
ent_down:
    ld a,(entryfret)
    or a
    jr nz,ent_d1
    ld a,13
ent_d1:
    dec a
ent_set:
    ld (entryfret),a
    call showfret
    call soundfret
    jr ent_loop

ent_cancel:
    call midiaudoff
    ld a,' '                        ; the digit was only ever on the screen
    call putatcursor
    call fixcursor                  ; ... and it broke the grid under it
    call showinfo
    jp mainloop                     ; mainloop dispatches with JP, so every
                                    ; way out of here has to jump back

;; ---------------------------------------------------------------
;; Commit. Line 1680 refuses if the note would run over one already
;; there; this checks the same positions on the same voice.
;; ---------------------------------------------------------------
ent_accept:
    ld a,(cy)                       ; packed: string in the high nibble
    sub 4
    rlca
    rlca
    rlca
    rlca
    ld b,a
    ld a,(entryfret)
    or b
ent_commit:
    ld (packed),a                   ; the note FIRST: midiaudoff does not
    call midiaudoff                 ; preserve A, and A is the note
    call ent_fits
    jr nc,ent_toolong
    call ent_store
    call setwert
    ;; Only what changed. A full drawpage here costs 1.3 seconds - 576
    ;; blanked cells, 96 redrawn ones and 39 firmware lines - and line 1690
    ;; does not do that either: it prints the note and its bar and nothing
    ;; else. The digit is already on the screen, put there while it was
    ;; being chosen.
    ld a,(packed)
    cp #FF
    jr nz,ent_bar
    ld a,206                        ; a rest, which was never drawn
    call putatcursor
ent_bar:
    ld a,(cx)
    ld (bcol),a
    ld a,(entryvoice)
    ld (bvoice),a
    ld a,(art)
    ld (blen),a
    ld a,(packed)
    cp #FF
    ld a,' '                        ; a rest names no string
    jr z,ent_bar2
    ld a,(cy)
    sub 4
    add a,'0'
ent_bar2:
    ld (bstr),a
    call drawbar
    call showinfo
    jp mainloop

;; SPACE during entry: a rest. The BASIC asks which channel first
;; (line 2640) - here it goes to the same channel the note would have
;; gone to, which is the answer that prompt gets given anyway.
ent_rest:
    ld a,#FF
    jr ent_commit

ent_toolong:
    ld hl,msg_long
    jr entmsg
ent_busy:
    ld hl,msg_busy
entmsg:
    push hl
    ld h,1
    ld l,3
    call TXT_SET_CURSOR
    pop hl
    call putz
    call errbeep
    call drawpage
    call redraw
    jp mainloop

;; Line 2590 sounds the error rather than only printing it: twelve steps
;; of two tones sliding past each other.
errbeep:
    ld b,6
eb1:
    push bc
    ld a,b
    add a,a
    add a,a
    add a,a
    add a,a                         ; 16, 32 ... 96
    ld l,a
    ld h,0
    ld (psper),hl
    ld a,13
    ld (psvol),a
    xor a
    ld (psenv),a
    ld a,1
    ld (pslen),a
    ld c,1
    call ps_queue
    pop bc
    djnz eb1
    ret

msg_busy: defb "No free voice here - all three are busy.",0
msg_long: defb "The note is too long to fit here.",0

;; ---------------------------------------------------------------
;; Writing the note away, as line 1690 does it
;; ---------------------------------------------------------------
ent_store:
    call noteslot
    push hl
    ld a,(packed)
    ld (hl),a
    pop hl
    push hl
    ld de,LENS-NOTES
    add hl,de
    ld a,(art)
    ld (hl),a
    pop hl
    ld a,(art)                      ; ... and the held markers behind it
    dec a
    ret z
    ld b,a
es1:
    push bc
    ld bc,3
    add hl,bc
    ld (hl),#FE
    pop bc
    djnz es1
    ret

;; carry set if a note of the current length fits here
ent_fits:
    ld a,(art)
    dec a
    scf
    ret z
    ld b,a
    call noteslot
ef1:
    push bc
    ld bc,3
    add hl,bc
    pop bc
    ld a,(hl)
    or a
    ret nz                          ; occupied, and OR A cleared the carry
    djnz ef1
    scf
    ret

;; the panel's "Notenwert": the value as the file writes it, string and
;; fret concatenated as decimal digits - 35 is string 3 fret 5, 212 is
;; string 2 fret 12, 88 is a rest
setwert:
    ld a,(packed)
    call unpack
    ld (wert),hl
    ret


;; ---------------------------------------------------------------
;; The busy bar under a note: the string number, then the channel letter
;; twice per position the note lasts, in inverse video. Line 1690 draws
;; art*2-1 of them, one short of the next note's digit column.
;; ---------------------------------------------------------------
bcol:   defb 0
bvoice: defb 0
bstr:   defb 0
blen:   defb 0

drawbar:
    ld a,(bcol)
    ld (dcx),a
    ld a,(bvoice)
    add a,10
    ld (dcy),a
    xor a
    ld (dcinv),a
    ld a,(bstr)
    call drawch
    ld a,(blen)
    add a,a
    dec a
    ld c,a                          ; 2L-1 letters
    ld a,67                         ; ... but not past the sheet
    ld b,a
    ld a,(bcol)
    ld e,a
    ld a,b
    sub e
    cp c
    jr nc,dbr1
    ld c,a
dbr1:
    ld a,c
    or a
    ret z
    ld b,c
    ld a,#FF                    ; the letters go in inverse video, which is
    ld (dcinv),a                ; the glyph with every bit flipped
dbr2:
    push bc
    ld a,(dcx)
    inc a
    ld (dcx),a
    ld a,(bvoice)
    add a,'A'-1
    call drawch
    pop bc
    djnz dbr2
    xor a
    ld (dcinv),a
    ret

;; blank a bar instead of drawing it
clearbar:
    ld a,(bcol)
    ld (dcx),a
    ld a,(bvoice)
    add a,10
    ld (dcy),a
    xor a
    ld (dcinv),a
    ld a,(blen)
    add a,a
    ld c,a                          ; 2L cells, the digit included
    ld a,67
    ld b,a
    ld a,(bcol)
    ld e,a
    ld a,b
    sub e
    cp c
    jr nc,cbr1
    ld c,a
cbr1:
    ld a,c
    or a
    ret z
    ld b,c
cbr2:
    push bc
    ld a,' '
    call drawch
    ld a,(dcx)
    inc a
    ld (dcx),a
    pop bc
    djnz cbr2
    ret



;; ---------------------------------------------------------------
;; DEL or CLR takes out the note on the string the cursor is on, with its
;; held markers - lines 1370 to 1390, on a key that cannot be confused
;; with going back a position.
;; ---------------------------------------------------------------
;; -> A = the voice carrying a note on this string at this position, or 0
;; if there is none; HL is left pointing at that note.
findnote:
    call noteindex
    ld c,1
    ld b,3
fn1:
    ld a,(hl)
    or a
    jr z,fn2
    cp #FE
    jr z,fn2                        ; a held marker names no string
    cp #FF
    jr z,fn_hit                     ; a rest belongs to no string, so the row
                                    ; the cursor is on is the right one. The
                                    ; BASIC compares the string digit of 88,
                                    ; which is 8, against rows that only go up
                                    ; to 6 - so in 1986 a rest, once entered,
                                    ; could not be taken out again
    rrca
    rrca
    rrca
    rrca
    and #0F
    ld d,a
    ld a,(cy)
    sub 4
    cp d
    jr z,fn_hit
fn2:
    inc hl
    inc c
    djnz fn1
    xor a
    ret
fn_hit:
    ld a,c
    ret

dodelete:
    call findnote
    or a
    jp z,mainloop
    ld (bvoice),a
    call delnote
    call showinfo
    jp mainloop

;; HL -> a note, (bvoice) = the voice it is on: take it and everything it
;; holds over out of the arrays, and off the screen
delnote:
    push hl                         ; how long was it?
    ld de,LENS-NOTES
    add hl,de
    ld a,(hl)
    or a
    jr nz,del_len
    inc a
del_len:
    ld (blen),a
    pop hl
    call delslot
del3:
    ld de,3                         ; and everything it holds over
    add hl,de
    ld a,(hl)
    cp #FE
    jr nz,del4
    call delslot
    jr del3
del4:
    ld a,(cx)
    ld (bcol),a
    call clearbar
    ld a,' '
    call putatcursor
    jp fixcursor

delslot:
    ld (hl),0
    push hl
    ld de,LENS-NOTES
    add hl,de
    ld (hl),0
    pop hl
    ret

;; ---------------------------------------------------------------
;; N: the note length. Line 2530 asks for it with INPUT.
;; ---------------------------------------------------------------
donotelen:
    ld a,(art)
    srl a
    or a
    jr nz,dn1
    ld a,8
dn1:
    ld (art),a
    call redraw
    jp mainloop

;; ---------------------------------------------------------------
;; HL -> NOTES entry for voice 1 at the cursor's position.
;; The page starts at zeiger - (cx-3)/2, the cursor sits at zeiger.
;; ---------------------------------------------------------------
noteindex:
    ld hl,(zeiger)
    dec hl
    ld d,h
    ld e,l
    add hl,hl
    add hl,de                       ; x3
    ld de,NOTES
    add hl,de
    ret

;; ... and for the voice the entry is going to
noteslot:
    call noteindex
    ld a,(entryvoice)
    dec a
    ld e,a
    ld d,0
    add hl,de
    ret

;; -> A = a free voice here, 1..3, or 0 if all three are busy.
;; Line 2800 runs through the free channels without leaving the loop, so
;; the LAST one wins: with nothing playing, a note goes to C. That reads
;; like a slip, but it is what every song on the 1986 discs was written
;; with, so it stays.
freevoice:
    call noteindex
    ld b,3
    ld c,1
    xor a
    ld d,a
fv1:
    ld a,(hl)
    or a
    jr nz,fv2
    ld d,c                          ; free: remember it and keep looking
fv2:
    inc hl
    inc c
    djnz fv1
    ld a,d
    ret

;; -> HL = the free channels as text, for the panel
freestr:
    ld hl,fbuf
    ld (hl),' '
    inc hl
    ld (hl),' '
    inc hl
    ld (hl),' '
    call noteindex
    ld de,fbuf
    ld b,3
    ld c,'A'
fs1:
    ld a,(hl)
    or a
    jr nz,fs2
    ld a,c
    ld (de),a
    inc de
fs2:
    inc hl
    inc c
    djnz fs1
    ld hl,fbuf
    ret
fbuf: defb 0,0,0,0

;; ---------------------------------------------------------------
;; The fret digit, where the note will go
;; ---------------------------------------------------------------
showfret:
    ld a,(entryfret)
    cp 10
    jr c,sf1
    add a,'A'-10
    jr putatcursor
sf1:
    add a,'0'

;; A = a character, printed in the cell the cursor marks
putatcursor:
    push af
    ld a,(cx)
    ld h,a
    ld a,(cy)
    ld l,a
    call TXT_SET_CURSOR
    pop af
    jp TXT_OUTPUT

;; ... and the sound of it
soundfret:
    ld a,(outmode)
    bit 1,a
    jr z,sf_ay
    push af
    ld a,(cy)                       ; MIDI hears it too - the same packed
    sub 4                           ; note, one addition away from a note
    rlca                            ; number
    rlca
    rlca
    rlca
    ld b,a
    ld a,(entryfret)
    or b
    ld (psnote),a
    call midiaudit
    pop af
    bit 0,a
    ret z                           ; MIDI only: the AY stays quiet
sf_ay:
    ld a,(cy)
    sub 4
    rlca
    rlca
    rlca
    rlca
    ld b,a
    ld a,(entryfret)
    or b
    call noteperiod
    ld (psper),de
    ld a,15
    ld (psvol),a
    ld a,1
    ld (psenv),a
    ld a,1
    ld (pslen),a
    ld c,1                          ; auditioned on A, whichever voice it
    jp ps_queue                     ; is going to end up on

;; ---------------------------------------------------------------
;; The rest of line 810: the fields showinfo does not already draw
;; ---------------------------------------------------------------
mi_three:
    ld (miptr),hl
    ld b,3
mi3:
    push bc
    ld hl,(miptr)
    ld e,(hl)
    inc hl
    ld (miptr),hl
    ld d,0                      ; a zero here means the channel is switched
    ld h,72                     ; off - the digit says so, as he asked
    ld l,c
    call putat3
    pop bc
    inc c
    djnz mi3
    ret

miptr: defw 0

moreinfo:
    ;; These two sit in the same five column field the numbers use - space,
    ;; three columns, space - or their dots would start a column before
    ;; everyone else's and the left edge of the panel would wander.
    ld h,2                          ; 15: which channels are free here
    ld l,15
    call TXT_SET_CURSOR
    ld a,' '
    call TXT_OUTPUT
    call freestr
    call putz
    ld a,' '
    call TXT_OUTPUT

    ld h,2                          ; 17: the one a note would go to
    ld l,17
    call TXT_SET_CURSOR
    ld a,' '
    call TXT_OUTPUT
    ld a,' '
    call TXT_OUTPUT
    ld a,' '
    call TXT_OUTPUT
    call freevoice
    or a
    jr z,mi_none
    add a,'A'-1
    jr mi_put
mi_none:
    ld a,206                        ; line 2790's "no channel" marker
mi_put:
    call TXT_OUTPUT
    ld a,' '
    call TXT_OUTPUT

    ld hl,(pagetop)                 ; 18: which sheet of 32 this is
    dec hl
    ld b,5
mi_bl:
    srl h
    rr l
    djnz mi_bl
    inc hl
    ld e,18
    call putval

    ld hl,(wert)                    ; 19: the last value entered
    ld e,19
    call putval

    ;; The five fields that only mean something while the music plays are
    ;; blanked here, so they are spaces rather than the panel's pattern
    ;; showing through beside the colon. showplay fills them in as it goes,
    ;; and ps_done comes back through here to clear them again.
    ld c,15
mi_blank:
    ld h,48
    ld l,c
    push bc
    call TXT_SET_CURSOR
    ld a,' '
    call TXT_OUTPUT
    ld a,' '
    call TXT_OUTPUT
    ld a,' '
    call TXT_OUTPUT
    pop bc
    inc c
    ld a,c
    cp 20
    jr c,mi_blank

    ;; The right hand half, where line 3490 and 3510 put it. Numbers go in
    ;; three right aligned columns, which is the PRINT USING "###" the
    ;; BASIC uses for every one of them.
    ld a,(vib)
    ld l,a
    ld h,0
    ex de,hl
    ld h,48
    ld l,20
    call putat3

    ld a,(stephund)                 ; the position length in 1/100 s, which
    ld e,a                          ; means something - unlike the BASIC's w
    ld d,0
    ld h,48
    ld l,21
    call putat3

    ;; ENV then ENT, for the three channels. The pointer is kept in memory,
    ;; not in IX: put3 walks its own table of powers of ten with IX, so a
    ;; caller holding a pointer there gets it back pointing at 10000.
    ld hl,chenv
    ld c,15
    call mi_three
    ld hl,chent
    ld c,18
    call mi_three

    ld h,48                         ; which way the notes go out. Two
                                    ; columns, so the right edge lines up
                                    ; with the numbers above it - and a
                                    ; space first, or the panel's own
                                    ; pattern shows through beside the
                                    ; colon where every other row has the
                                    ; leading blank of a number
    ld l,22
    call TXT_SET_CURSOR
    ld a,(outmode)
    dec a
    ld hl,t_ay
    jr z,mi_out
    dec a
    ld hl,t_midi
    jr z,mi_out
    ld hl,t_both
mi_out:
    call putz

    ld a,(midiprog)                 ; the instrument, in GM numbering
    inc a
    ld e,a
    ld d,0
    ld h,48
    ld l,23
    call putat3

    ld h,10                         ; 22: the note length, in words
    ld l,22
    call TXT_SET_CURSOR
    ld a,(art)
    cp 8
    ld hl,t_ganz
    jr z,mi_len
    cp 4
    ld hl,t_halb
    jr z,mi_len
    cp 2
    ld hl,t_viertel
    jr z,mi_len
    ld hl,t_achtel
mi_len:
    jp putz

t_ay:      defb " A ",0             ; slot one is the AY, slot two is MIDI
t_midi:    defb "  M",0
t_both:    defb " AM",0
t_ganz:    defb "Whole Notes..",0
t_halb:    defb "Half Notes...",0
t_viertel: defb "Quarter Notes",0
t_achtel:  defb "Eighth Notes.",0
