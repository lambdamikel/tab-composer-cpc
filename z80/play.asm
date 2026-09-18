;; ---------------------------------------------------------------
;; TABCOMP/CPC - playback
;;
;; The BASIC hands each note to the firmware sound queue and lets the
;; hardware do the work:
;;
;;   SOUND 129,array(s,n),laenge(i,1)*w,0,ea,ta,r
;;
;; 129, 130, 132 are the channel status bytes for A, B and C with bit 7
;; set, which means "flush". The BASIC flushes every step and paces
;; itself with FOR e=1 TO w/2 - an interpreted delay loop, so the tempo
;; there is a property of how fast BASIC happens to run.
;;
;; That does not port. In Z80 the same loop would be a thousand times
;; faster, so the pacing has to come from somewhere real: here each
;; channel's own queue does it. A note is queued with a duration of
;; laenge steps, the channel stays busy for exactly that long, and the
;; firmware sequences the queue. Nothing is flushed, nothing is timed by
;; counting, and the three voices cannot drift apart.
;; ---------------------------------------------------------------

SOUND_QUEUE     equ #BCAA       ; HL -> a 9 byte sound program
SOUND_CHECK     equ #BCAD       ; A = channel -> A = its status
KM_READ_CHAR    equ #BB09       ; carry set if a key was waiting

;; one step, in 1/100 s - the firmware's duration unit
STEPTIME        equ 12

SOUND_RESET     equ #BCA7
;; Measured, like everything else here: the value this returns grows by
;; exactly 300 per second, so it is the 1/300 s clock and a position can be
;; timed against it instead of counted out in a delay loop.
KL_TIME_PLEASE  equ #BD0D
SOUND_AMPL_ENV  equ #BCBC       ; A = envelope number, HL -> its data
SOUND_TONE_ENV  equ #BCBF       ; A = envelope number, HL -> its data

;; One step, in 50 Hz frames. The BASIC paces itself with FOR e=1 TO w/2,
;; an interpreted delay whose speed is an accident of how fast BASIC runs;
;; in Z80 the step has to be timed against something real, so it is timed
;; against the frame flyback.
STEPTICKS       equ 72          ; 72/300 s = 0.24 s per position

;; ---------------------------------------------------------------
;; The nine amplitude envelopes, lines 230 to 310, unchanged. Firmware
;; layout: a count byte, then that many sections of step count, step size,
;; pause time - which is exactly how BASIC's ENV lists its arguments, in
;; threes.
;; ---------------------------------------------------------------
env1:   defb 5 : defb 2,6,1   : defb 1,3,5  : defb 0,-1,10 : defb 5,-1,30
        defb 1,0,200
env2:   defb 2 : defb 1,15,1  : defb 15,-1,5
env3:   defb 3 : defb 5,3,1   : defb 1,0,10 : defb 15,-1,3
env4:   defb 1 : defb 1,15,1
env5:   defb 2 : defb 1,15,1  : defb 15,-1,20
env6:   defb 2 : defb 15,1,1  : defb 15,-1,20
env7:   defb 3 : defb 1,15,1  : defb 1,0,20 : defb 1,-15,1
env8:   defb 3 : defb 1,15,1  : defb 1,0,5  : defb 1,-15,1
env9:   defb 4 : defb 1,15,1  : defb 15,-1,1 : defb 1,15,1 : defb 15,-1,1

envtab: defw env1,env2,env3,env4,env5,env6,env7,env8,env9

;; ---------------------------------------------------------------
;; The eight tone envelopes, lines 3380 to 3450 - "Tonhuellkurven aus der
;; CPC-INTERNATIONAL", says the comment. They are the vibrato, and every
;; one of them is written in terms of v, so they cannot be constants: they
;; are rebuilt whenever v changes.
;;
;;     ENT -1,1,v,4,1,-v,4        ENT 5,1,-5*v,1,5,v,1
;;     ENT -2,1,v,2               ENT -6,1,v,2,1,-v,1
;;     ENT -3,1,-v,2              ENT -7,1,v,9,1,-v,9
;;     ENT  4,1,5*v,1,5,-v,1      ENT -8,1,v,1,v,-1,1
;;
;; A negative number in BASIC means the envelope repeats, which is bit 7 of
;; the count byte here. #F1 to #F4 stand for v, -v, 5v and -5v - no real
;; parameter is anywhere near that big, so they cannot be mistaken for one.
;; ---------------------------------------------------------------
enttmpl:
        defb #82 : defb 1,#F1,4 : defb 1,#F2,4      ; ENT -1
        defb #81 : defb 1,#F1,2                     ; ENT -2
        defb #81 : defb 1,#F2,2                     ; ENT -3
        defb 2   : defb 1,#F3,1 : defb 5,#F2,1      ; ENT  4
        defb 2   : defb 1,#F4,1 : defb 5,#F1,1      ; ENT  5
        defb #82 : defb 1,#F1,2 : defb 1,#F2,1      ; ENT -6
        defb #82 : defb 1,#F1,9 : defb 1,#F2,9      ; ENT -7
        defb #82 : defb 1,#F1,1 : defb #F1,-1,1     ; ENT -8

entbuf: defs 64
etsrc:  defw 0
etdst:  defw 0

vib:      defb 2                ; the BASIC's v, asked for at line 3330
chenv:    defb 5,5,5            ; ea, eb, ec - line 3320's defaults
chent:    defb 7,7,7            ; ta, tb, tc

setupenv:
    ld c,1                      ; the amplitude envelopes, 1 to 9
se1:
    ld a,c
    dec a
    add a,a
    ld e,a
    ld d,0
    ld hl,envtab
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    ex de,hl
    ld a,c
    push bc
    call SOUND_AMPL_ENV
    pop bc
    inc c
    ld a,c
    cp 10
    jr c,se1
    ;; fall through: the tone envelopes depend on v, so they are built

;; ---------------------------------------------------------------
;; Build the eight tone envelopes for the current v and hand them over
;; ---------------------------------------------------------------
buildents:
    ld hl,enttmpl
    ld (etsrc),hl
    ld hl,entbuf
    ld (etdst),hl
    ld c,1
be_next:
    ld hl,(etdst)
    push hl                     ; where this one starts
    ld hl,(etsrc)
    ld a,(hl)
    inc hl
    ld (etsrc),hl
    ld de,(etdst)
    ld (de),a
    inc de
    ld (etdst),de
    and #7F                     ; without the repeat bit, the section count
    ld b,a
    add a,a
    add a,b                     ; three bytes to a section
    ld b,a
be_byte:
    ld hl,(etsrc)
    ld a,(hl)
    inc hl
    ld (etsrc),hl
    cp #F1
    jr nz,be1
    ld a,(vib)
    jr be_put
be1:
    cp #F2
    jr nz,be2
    ld a,(vib)
    neg
    jr be_put
be2:
    cp #F3
    jr nz,be3
    call vib5
    jr be_put
be3:
    cp #F4
    jr nz,be_put
    call vib5
    neg
be_put:
    ld de,(etdst)
    ld (de),a
    inc de
    ld (etdst),de
    djnz be_byte
    pop hl
    ld a,c
    push bc
    call SOUND_TONE_ENV
    pop bc
    inc c
    ld a,c
    cp 9
    jr c,be_next
    ret

vib5:
    push bc
    ld a,(vib)
    ld b,a
    add a,a
    add a,a
    add a,b                     ; 5v, at most 75 - still a legal step size
    pop bc
    ret

playsong:
    ;; The key that started playback is still in the buffer, and the loop
    ;; below treats any key as "stop" - so six notes in, it stopped itself.
    ld b,20                     ; over frames, not in one burst: the key is
psflush:                        ; still physically down for a few of them
    push bc
    call MC_WAIT_FLYBACK
    pop bc
    push bc
psflush2:
    call KM_READ_CHAR
    jr c,psflush2
    pop bc
    djnz psflush

    xor a                       ; the clock starts at nought, and so does
    ld (takt),a                 ; the list of repeats to watch for
    ld (pshund),a
    ld hl,0
    ld (pstime),hl
    ld a,(outmode)              ; whichever instrument was chosen, before
    bit 1,a                     ; the first note rather than after it
    jr z,ps_noprog
    call midiprogram
ps_noprog:
    call SOUND_RESET            ; put the sound manager in a known state
    call setupenv
    ld hl,1
    ld (playpos),hl
    xor a
    ld (pskey),a

ps_step:
    call KL_TIME_PLEASE         ; when this position began
    ld (psstart),hl

    ld hl,(playpos)
    ld de,611
    or a
    sbc hl,de
    jp nc,ps_done

    ld hl,(playpos)             ; index = (pos-1)*3
    dec hl
    ld d,h
    ld e,l
    add hl,hl
    add hl,de
    ld (psidx),hl

    ld a,(outmode)              ; notes whose time is up must be stopped -
    bit 1,a                     ; the AY is told a duration and looks after
    jr z,ps_novoff              ; itself, MIDI has to be told
    call miditick
ps_novoff:
    ld c,1
ps_voice:
    push bc
    call ps_one
    pop bc
    inc c
    ld a,c
    cp 4
    jr c,ps_voice

    ;; The notes are queued BEFORE any drawing, and the sound manager runs
    ;; on interrupts - so the AY plays on while the screen is redrawn, and
    ;; a page turn is inaudible as long as it fits inside a position. It
    ;; does: 0.16 s against 0.24 s.
    call pagecheck
    call showplay

    ;; Hold the position until its time is up - measured against the clock,
    ;; not counted out in a delay loop. A delay loop makes every position as
    ;; long as the work in it PLUS the delay, so the one position that turns
    ;; the page took 0.16 s longer than the rest and the music stumbled once
    ;; a page. Timed this way the drawing happens inside the position it
    ;; belongs to and the rhythm does not know about it.
    ;;
    ;; NOT MC WAIT FLYBACK: that returns at once while flyback is asserted,
    ;; so a dozen calls finish inside one flyback and the song runs flat out.
ps_wait:
    ;; and the wait must KEEP what it reads: it used to call KM READ CHAR
    ;; and throw the key away, so ESC, SPACE, < and > all looked dead while
    ;; the music ran - a key pressed during a position, which is nearly all
    ;; of the time, never survived to be acted on.
    call KM_READ_CHAR
    jr nc,psw2
    ld (pskey),a
psw2:
    call KL_TIME_PLEASE
    ld de,(psstart)
    or a
    sbc hl,de                   ; how long this position has lasted
    ld a,(speed)
    ld e,a
    ld d,0
    or a
    sbc hl,de
    jr c,ps_wait

    ld hl,(playpos)
    inc hl
    ld (playpos),hl
    call taktcheck              ; line 3570: has it reached a repeat?

    ;; Only ESC stops it. Testing for "any key" meant the P that started
    ;; playback stopped it again six notes later. < and > change the tempo
    ;; while it plays, as line 3780 does; SPACE starts again from the top.
    ld a,(pskey)
    or a
    jr z,ps_nokey
    ld c,a
    xor a
    ld (pskey),a
    ld a,c
    jr ps_key
ps_nokey:
    call KM_READ_CHAR
    jp nc,ps_step
ps_key:
    cp 252
    jp z,ps_done
    cp '<'
    jp z,ps_faster
    cp '>'
    jp z,ps_slower
    cp ' '
    jp z,ps_restart
    ;; A B C step that channel's TONE envelope, a b c its AMPLITUDE
    ;; envelope, and 1 to 6 set one of the six back to nought - which,
    ;; since the volume passed is 0, is how you mute a channel. All of it
    ;; straight from lines 3890 to 4080.
    ;; The instrument, while it plays. + and - are the sheet keys in the
    ;; editor, but nothing uses them here - and hunting for a sound by ear
    ;; is something you do while listening.
    cp '+'
    jr z,ps_progup
    cp 'I'
    jr nz,ps_k1
ps_progup:
    ld a,(midiprog)
    inc a
    and #7F
    jr ps_setprog
ps_k1:
    cp '-'
    jr z,ps_progdn
    cp 'i'
    jr nz,ps_k2
ps_progdn:
    ld a,(midiprog)
    dec a
    and #7F
ps_setprog:
    ld (midiprog),a
    call midiprogram
    call showinfo
    jp ps_step
ps_k2:
    cp 'A'
    jr c,ps_dig
    cp 'D'
    jr nc,ps_lower
    sub 'A'
    ld hl,chent
    jr ps_bump
ps_lower:
    cp 'a'
    jr c,ps_other
    cp 'd'
    jr nc,ps_other
    sub 'a'
    ld hl,chenv
ps_bump:
    ld e,a
    ld d,0
    add hl,de
    ld a,(hl)
    inc a
    cp 10
    jr c,ps_bset
    ld a,1
ps_bset:
    ld (hl),a
    call showinfo
    jp ps_step

ps_dig:
    cp '1'
    jp c,ps_step
    cp '7'
    jp nc,ps_step
    sub '1'                     ; 1 2 3 -> ENV A B C, 4 5 6 -> ENT A B C
    ld hl,chenv
    cp 3
    jr c,ps_zero
    sub 3
    ld hl,chent
ps_zero:
    ld e,a
    ld d,0
    add hl,de
    ld (hl),0
    call showinfo
    jp ps_step

ps_other:
    jp ps_step

ps_restart:
    ld hl,1
    ld (playpos),hl
    xor a
    ld (takt),a
    jp ps_step

ps_faster:
    ld a,(speed)
    cp 18
    jp c,ps_step
    sub 6
    jr ps_setsp
ps_slower:
    ld a,(speed)
    cp 240
    jp nc,ps_step
    add a,6
ps_setsp:
    ld (speed),a
    call setspeed
    call showinfo
    jp ps_step

ps_done:
    call midialloff             ; nothing left hanging on the wire
    call clearmark
    call editpage               ; and put the editing page back
    call drawpage
    jp redraw

;; ---------------------------------------------------------------
;; Follow the music: the page holds 32 positions, so when the playing
;; position passes the end of it, the next 32 are drawn.
;; ---------------------------------------------------------------
pagecheck:
    ld hl,(playpos)
    dec hl
    ld a,l
    and #E0                     ; the start of the 32 it belongs to
    ld l,a
    inc hl
    ld de,(pagetop)
    or a
    sbc hl,de
    add hl,de                   ; ADD HL,rr leaves Z alone, so this is safe
    ret z
    push hl
    call erasecells             ; the page on show comes off, the grid stays
    call clearmark              ; and the marker goes too: it sits on row 4,
                                ; which no redraw touches, so leaving it
                                ; there left a second one standing at the
                                ; end of the old page
    pop hl
    ld (pagetop),hl
    jp drawcells                ; the new page, over the grid already there

;; ---------------------------------------------------------------
;; The marker, one row above the top string, pointing at the position
;; being played. Two characters a step: erase the old, draw the new.
;; ---------------------------------------------------------------
;; take the marker off wherever it is
clearmark:
    ld a,(psmark)
    or a
    ret z
    ld (dcx),a
    ld a,4
    ld (dcy),a
    xor a
    ld (dcinv),a
    ld a,' '
    call drawch
    xor a
    ld (psmark),a
    ret

showplay:
    call drawtakt               ; clears the row and puts the repeat marks
                                ; back - so the marker moving along it
                                ; cannot rub one out on its way past
    ld a,4
    ld (dcy),a
    xor a
    ld (dcinv),a
    ld hl,(playpos)
    dec hl
    ld a,l
    and 31                      ; where it sits on this page
    add a,a
    add a,3
    ld (psmark),a
    ld (dcx),a
    ld a,241                    ; the down arrow
    call drawch

    ;; and the numbers line 3590 shows while it plays: what each channel is
    ;; sounding, where we are, and how long it has been going
    ld hl,(psidx)
    ld de,NOTES
    add hl,de
    ld (spptr),hl
    ld b,3
    ld c,15
sp2:
    push bc
    ld hl,(spptr)
    ld a,(hl)
    inc hl
    ld (spptr),hl
    call unpack                 ; the number the panel shows, as the file
    ex de,hl                    ; would write it
    ld h,48
    pop bc
    push bc
    ld l,c
    call putat3
    pop bc
    inc c
    djnz sp2

    ld de,(playpos)             ; Stelle
    ld h,48
    ld l,18
    call putat3

    ld a,(stephund)             ; Zeit, counted in the steps themselves
    ld b,a
    ld a,(pshund)
    add a,b
sp3:
    cp 100
    jr c,sp4
    sub 100
    push af
    ld hl,(pstime)
    inc hl
    ld (pstime),hl
    pop af
    jr sp3
sp4:
    ld (pshund),a
    ld de,(pstime)
    ld h,48
    ld l,19
    jp putat3

psmark: defb 0
spptr:  defw 0
pshund: defb 0
pstime: defw 0

;; ---------------------------------------------------------------
;; One voice at the current position. C = voice 1..3. Nothing is queued
;; for an empty or a held position - the note already sounding simply
;; carries on, which is what the BASIC does when it skips s=0 and 99.
;; ---------------------------------------------------------------
ps_fetch:
    ld hl,(psidx)
    ld b,0
    dec c
    add hl,bc
    inc c
    push hl
    ld de,NOTES
    add hl,de
    ld a,(hl)
    ld (psnote),a
    pop hl
    ld de,LENS
    add hl,de
    ld a,(hl)
    or a
    jr nz,psf1
    inc a
psf1:
    ld (pslen),a
    ret

ps_one:
    ld a,(outmode)              ; whichever engines are switched on
    bit 1,a
    jr z,ps_noteget
    push bc
    call ps_fetch               ; MIDI wants the note and its length too
    pop bc
    push bc
    call midiplay
    pop bc
    ld a,(outmode)
    bit 0,a
    ret z                       ; MIDI only: the AY is not asked
ps_noteget:
    ld hl,(psidx)
    ld b,0
    dec c
    add hl,bc
    inc c
    push hl
    ld de,NOTES
    add hl,de
    ld a,(hl)
    ld (psnote),a
    pop hl
    ld de,LENS
    add hl,de
    ld a,(hl)
    or a
    jr nz,ps_l1
    inc a                       ; a zero length would be silent forever
ps_l1:
    ld (pslen),a

    ld a,(psnote)
    or a
    ret z                       ; empty
    cp #FE
    ret z                       ; held: leave the note alone
    cp #FF
    jr z,ps_rest

    ld a,(psnote)               ; a real note
    call noteperiod
    ld (psper),de
    xor a                       ; line 3610 passes volume 0 and lets the
    ld (psvol),a                ; amplitude envelope do the work
    ld b,0                      ; this channel's ENV and ENT - ea/ta, eb/tb,
    ld hl,chenv-1               ; ec/tc in the BASIC
    add hl,bc
    ld a,(hl)
    ld (psenv),a
    ld hl,chent-1
    add hl,bc
    ld a,(hl)
    ld (psent),a
    jr ps_queue

ps_rest:
    ld de,3                     ; the BASIC's silent note
    ld (psper),de
    xor a
    ld (psvol),a
    ld (psenv),a
    ld (psent),a

ps_queue:
    ;; Duration = the note's length in positions x how long a position
    ;; lasts, which is what "laenge(i,1)*w" means at line 3610. A note now
    ;; stops when it is written to stop, instead of being held until the
    ;; next one on that channel flushes it.
    ld a,(pslen)
    or a
    jr nz,psq0
    inc a
psq0:
    ld b,a
    ld a,(stephund)
    ld e,a
    ld d,0
    ld hl,0
psq1:
    add hl,de
    djnz psq1
    ;; THE BUG THAT COST AN EVENING, and why scaling the duration is safe
    ;; now: a duration shorter than the amplitude envelope takes to RAISE
    ;; the volume means the note is cut before anything is heard, while
    ;; SOUND QUEUE still reports success and the channel still reports
    ;; "active". The envelope in use then was CPCSYNTH's - fifteen steps of
    ;; pause 5, so 75 hundredths before it reached full - against steps of
    ;; 12 to 48. The BASIC's own ENV 5 is at full volume after ONE
    ;; hundredth (1,15,1), so any real note length outlasts it.
    ld (psdur),hl

    ld a,129                    ; channel A with bit 7 - flush, as the
    dec c                       ; BASIC and the MIDI synth both do
    jr z,psq2
    inc a
    dec c
    jr z,psq2
    inc a
    inc a
psq2:
    ld (sndblk),a
    ld a,(psenv)
    ld (sndblk+1),a
    ld a,(psent)
    ld (sndblk+2),a
    ld hl,(psper)
    ld (sndblk+3),hl
    ld a,(psvol)
    ld (sndblk+6),a
    ld hl,(psdur)
    ld (sndblk+7),hl

    ;; With the flush bit set there is nothing to wait for: the call
    ;; replaces whatever that channel is playing instead of queueing
    ;; behind it. That is the whole point of 129/130/132 - the program
    ;; decides the tempo by when it steps, and a note's duration only has
    ;; to outlast the step, so the three voices cannot drift apart.
    ;; One queue, no delays. The double queue and the pauses that used to
    ;; live here were compensating for the real fault: the sound block sat
    ;; below #4000, so the sound manager read the lower ROM instead of it.
    ld hl,sndblk
    call SOUND_QUEUE
    ret


;; A = packed note -> DE = its tone period
;; The table is one row per fret, strings 6 down to 1, so string s sits
;; at offset (6-s)*2 inside the row.
noteperiod:
    ld b,a
    and #0F                     ; fret
    ld l,a
    ld h,0
    add hl,hl                   ; x2
    add hl,hl                   ; x4
    ld d,h                      ; keep x4 - capturing x2 here gave x10, and
    ld e,l                      ; ten bytes is not the row length
    add hl,hl                   ; x8
    add hl,de                   ; x8 + x4 = x12, twelve bytes per fret row
    ld de,periods
    add hl,de
    ld a,b
    rrca
    rrca
    rrca
    rrca
    and #0F                     ; string 1..6
    ld b,a
    ld a,6
    sub b                       ; 6 - string
    add a,a
    ld e,a
    ld d,0
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    ret

;; the nine byte sound program the firmware wants
sndblk:
    defb 1                      ; channel status
    defb 0                      ; amplitude envelope
    defb 0                      ; tone envelope
    defw 0                      ; tone period
    defb 0                      ; noise period
    defb 12                     ; starting amplitude
    defw 0                      ; duration

playpos: defw 1
pskey:   defb 0
psstart: defw 0
psidx:   defw 0
psnote:  defb 0
pslen:   defb 0
psper:   defw 0
psvol:   defb 0
psenv:   defb 0
psent:   defb 0
psdur:   defw 0

;; How long a position lasts. The BASIC asks for it ("Geschwindigkeit",
;; line 3290) before every playback and then lets < and > change it while
;; the music runs; here only the second half is kept.
;; Which way out: 1 = AY, 2 = MIDI, 3 = both. The tablature drives either
;; engine from the same note, which is the whole reason for keeping the
;; fingering in the file rather than a tone period.
outmode:  defb 1

speed:    defb 72               ; the step, in ticks of the wait loop
stephund: defb 24               ; ... and in 1/100 s, for note durations

setspeed:
    ld a,(speed)
    ld b,0
ss1:
    cp 3
    jr c,ss2
    sub 3
    inc b
    jr ss1
ss2:
    ld a,b
    ld (stephund),a
    ret

;; ---------------------------------------------------------------
;; One note, with CPCSYNTH's exact values, and nothing else. If this is
;; silent the fault is environmental; if it sounds, bisect towards the
;; values playsong uses.
;; ---------------------------------------------------------------
testnote:
    ;; Byte for byte what SYNTH2 does, the program that is audible.
    ld hl,tenv1
    ld a,1
    call SOUND_AMPL_ENV
    ld hl,tblk
    call SOUND_QUEUE
    ld de,#0040
tnd1:
    dec de
    ld a,d
    or e
    jr nz,tnd1
    ld hl,tblk
    call SOUND_QUEUE
    ret

tenv1:  defb 1
        defb 15,127,5

tblk:   defb 129                ; channel A with flush
        defb 1                  ; amplitude envelope 1
        defb 0                  ; no tone envelope
        defw 478                ; period - the same note SYNTH2 plays
        defb 0                  ; noise
        defb 15                 ; amplitude
        defw 1000               ; duration
