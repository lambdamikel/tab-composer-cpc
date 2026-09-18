;; ---------------------------------------------------------------
;; TABCOMP/CPC - MIDI OUT through the BluePillCPC "Ultimate MIDI Card"
;;
;;   &FBEE  write : send a MIDI byte
;;   &FBFE  read  : status
;;
;; The pacing is the important part and it is taken from TRACKER/CPC,
;; where it was learned the hard way. MIDI is 31250 baud, 1 start + 8 data
;; + 1 stop, so a byte owns the wire for 320 us and nothing can go out
;; faster whatever the card's FIFO says. TRACKER's first CPC version sent
;; them 98 us apart, 88% of bytes too fast; the ones lost were program
;; changes, and a channel that loses its program change stays on Acoustic
;; Grand Piano. Michael heard piano on track 2 of BOOGIE on a real 6128.
;;
;; So the wait lives inside midiout and no caller can forget it.
;;
;; The tablature maps onto MIDI more directly than onto the AY: a note is
;; the open string plus the fret, and that is all. Where the AY needs a
;; period from a table, MIDI needs one addition - which is what makes the
;; tablature position the right thing to have kept in the file.
;; ---------------------------------------------------------------

MDATA    equ #FBEE
MSTAT    equ #FBFE
MIDIWAIT equ 44                 ; 44 * 7 us = 308 us, plus the call and the
                                ; OUT: comfortably over one byte time

MIDIVEL  equ 100                ; how hard the notes are struck

;; The General MIDI program, as it goes on the wire - one less than the
;; number everyone quotes, because GM counts from 1 and MIDI from 0.
;; 24 here is GM 25, Acoustic Guitar (nylon), which is what a tablature
;; wants to be. Without a program change a channel stays on GM 1, Acoustic
;; Grand Piano - which is how TRACKER came to play piano on track 2 of
;; BOOGIE when its program changes were going out too fast to survive.
midiprog: defb 24

;; send the byte in A, then hold the wire for one byte time.
;; Everything preserved, flags included.
midiout:
    push bc
    ld bc,MDATA
    out (c),a
    pop bc
    push af
    push hl
    ld hl,MIDIWAIT
midiow:
    dec hl
    ld a,h
    or l
    jr nz,midiow
    pop hl
    pop af
    ret

;; Tell all three channels which instrument to be
midiprogram:
    ld c,1
mpr1:
    push bc
    ld a,c
    dec a
    add a,#C0                   ; program change, channel 1, 2 or 3
    call midiout
    ld a,(midiprog)
    call midiout
    pop bc
    inc c
    ld a,c
    cp 4
    jr c,mpr1
    ret

;; The open strings as MIDI note numbers, high E first - the same order
;; the rows are in, so string s indexes straight in.
midiopen: defb 0,64,59,55,50,45,40

;; A = packed note -> A = its MIDI note number
midinote:
    ld b,a
    and #0F
    ld c,a                      ; fret
    ld a,b
    rrca
    rrca
    rrca
    rrca
    and #0F                     ; string 1..6
    ld e,a
    ld d,0
    ld hl,midiopen
    add hl,de
    ld a,(hl)
    add a,c
    ret

;; what each voice is sounding, and for how many more positions
mnote: defb 0,0,0
mleft: defb 0,0,0

;; C = voice 1..3, A = note: start it
midion:
    ld (mtmp),a
    ld a,c
    dec a
    add a,#90                   ; note on, channel 1, 2 or 3
    call midiout
    ld a,(mtmp)
    call midiout
    ld a,MIDIVEL
    jp midiout

;; C = voice 1..3, A = note: stop it
midioff:
    ld (mtmp),a
    ld a,c
    dec a
    add a,#80
    call midiout
    ld a,(mtmp)
    call midiout
    xor a
    jp midiout

mtmp: defb 0

;; C = voice: silence whatever it is sounding
midiquiet:
    ld hl,mnote-1
    ld b,0
    add hl,bc
    ld a,(hl)
    or a
    ret z
    ld (hl),0
    jp midioff

;; every voice quiet - at the end of a piece, and before one starts
midialloff:
    ld c,1
mao1:
    push bc
    call midiquiet
    pop bc
    inc c
    ld a,c
    cp 4
    jr c,mao1
    ret

;; ---------------------------------------------------------------
;; One position's worth of counting down. A note lasts as many positions
;; as it was written for, and MIDI has to be told when that is up - the
;; AY is told once, in the duration, and looks after itself.
;; ---------------------------------------------------------------
miditick:
    ld c,1
mt1:
    push bc
    ld hl,mleft-1
    ld b,0
    add hl,bc
    ld a,(hl)
    or a
    jr z,mt2                    ; nothing sounding on this voice
    dec a
    ld (hl),a
    or a
    jr nz,mt2
    call midiquiet              ; its time is up
mt2:
    pop bc
    inc c
    ld a,c
    cp 4
    jr c,mt1
    ret

;; ---------------------------------------------------------------
;; This voice, this position: (psnote) packed, (pslen) positions
;; ---------------------------------------------------------------
midiplay:
    ld a,(psnote)
    or a
    ret z                       ; nothing starts here
    cp #FE
    ret z                       ; held: it is already sounding
    push bc
    call midiquiet              ; whatever was there stops first
    pop bc
    ld a,(psnote)
    cp #FF
    ret z                       ; a rest is silence, and that is all it is
    push bc
    ld a,(psnote)
    call midinote
    pop bc
    push af
    ld hl,mnote-1               ; remember it, to stop it later
    ld b,0
    add hl,bc
    pop af
    ld (hl),a
    push af
    ld hl,mleft-1
    ld b,0
    add hl,bc
    ld a,(pslen)
    or a
    jr nz,mp1
    inc a
mp1:
    ld (hl),a
    pop af
    jp midion

;; the note being chosen during entry, so it can be stopped again
audnote: defb 0

midiaudit:
    call midiaudoff
    ld a,(psnote)
    call midinote
    ld (audnote),a
    ld c,1
    jp midion

midiaudoff:
    ld a,(audnote)
    or a
    ret z
    ld c,1
    push af
    xor a
    ld (audnote),a
    pop af
    jp midioff
