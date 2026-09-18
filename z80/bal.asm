;; ---------------------------------------------------------------
;; TABCOMP/CPC - writing the song out as a BASIC program
;;
;; Lines 2170 to 2440. The file is not data: it IS a Locomotive BASIC
;; program, so a song can be played on any CPC with nothing else loaded.
;; The BASIC asks for the first line number and the spacing; ten and ten
;; are what everyone used, so they are simply the numbers here, which is
;; one less question and lets the jumps be written out plainly.
;;
;;   10  a comment, with the name of the song
;;   20  on error goto 110 : restore      - runs off the end and starts over
;;   30  ENV 1,15,-1,20
;;   40  input "Speed";w
;;   50  read a,al,b,bl,c,cl
;;   60  if a=0 then 70 else if a=-1 then sound 129,3,al*w,0
;;                                  else sound 129,a,al*w,0,1
;;   70  the same for b on channel 130
;;   80  the same for c on channel 132
;;   90  for o=1 to w*2:next
;;   100 goto 50
;;   110 call &bb06:run
;;   120 DATA ...
;;
;; A voice's value is the AY tone period, 0 for nothing or a held note,
;; and -1 for a rest - line 2480. Ten positions to a DATA line.
;; ---------------------------------------------------------------

BALSTART equ 120                ; the first DATA line

dobal:
    call showcat
    call getname
    jr c,bal_go
    call restorepanel
    jp mainloop
bal_go:
    ld a,(namelen)              ; the name came back as NAME.MUS - this one
    sub 4                       ; wants NAME.BAL
    ld e,a
    ld d,0
    ld hl,nameb
    add hl,de
    push hl
    ld (hl),'.'
    inc hl
    ld (hl),'B'
    inc hl
    ld (hl),'A'
    inc hl
    ld (hl),'L'
    pop hl
    ld (balname),hl             ; where the extension starts, for line 10

    call dsk_select
    ld a,(namelen)
    ld b,a
    ld hl,namebuf
    ld de,DSKBUF
    call TXT_VDU_DISABLE        ; AMSDOS keeps its opinions to itself
    call CAS_OUT_OPEN
    push af
    call TXT_VDU_ENABLE
    pop af
    jp nc,bal_err

    call lastpos
    ld a,h
    or l
    jr nz,bal_head
    call CAS_OUT_ABANDON
    ld hl,msg_empty
    jp savemsgw
bal_head:
    ld (svend),hl

    ld hl,txt_bal1              ; the comment line, then the song's name
    call outstr
    ld hl,nameb
    ld (balptr),hl
bal_nm:
    ld hl,(balptr)
    ld a,(hl)
    inc hl
    ld (balptr),hl
    cp '.'                      ; ... without the extension
    jr z,bal_nm2
    call outch
    jr bal_nm
bal_nm2:
    call outeol
    ld hl,txt_balprog           ; and the player itself
    call outlines

    ld hl,BALSTART
    ld (balline),hl
    ld hl,1
    ld (balpos),hl

bal_line:
    ld hl,(balline)             ; "120 DATA "
    call outdec
    ld hl,txt_data
    call outstr
    ld b,10                     ; ten positions to the line
bal_slot:
    push bc
    ld c,1
bal_voice:
    push bc
    call bal_one                ; this voice's period and length
    pop bc
    ;; a comma after every number but the last one on the line
    ld a,c
    cp 3
    jr nz,bal_comma
    pop de                      ; D is the position counter: no comma after
    push de                     ; the very last number on the line
    ld a,d
    cp 1
    jr z,bal_nocomma
bal_comma:
    ld a,','
    call outch
bal_nocomma:
    inc c
    ld a,c
    cp 4
    jr c,bal_voice
    ld hl,(balpos)
    inc hl
    ld (balpos),hl
    pop bc
    djnz bal_slot
    call outeol

    ld hl,(balline)             ; on to the next line
    ld de,10
    add hl,de
    ld (balline),hl
    ld hl,(balpos)              ; more music left?
    ld de,(svend)
    or a
    sbc hl,de
    jr c,bal_line
    jr z,bal_line

    call CAS_OUT_CLOSE
    ld hl,msg_balsaved
    jp savemsg

bal_err:
    ld hl,msg_saveerr
    jp savemsgw

;; one voice at (balpos): its period, a comma, its length
bal_one:
    push bc
    ld hl,(balpos)              ; index = (pos-1)*3 + voice-1
    dec hl
    ld d,h
    ld e,l
    add hl,hl
    add hl,de
    ld a,c
    dec a
    ld e,a
    ld d,0
    add hl,de
    push hl
    ld de,NOTES
    add hl,de
    ld a,(hl)
    pop hl
    push hl
    push af
    ld de,LENS
    add hl,de
    ld a,(hl)
    ld (ballen),a
    pop af
    pop hl

    or a                        ; nothing here, or a note still sounding
    jr z,bal_zero
    cp #FE
    jr z,bal_zero
    cp #FF
    jr z,bal_rest
    call noteperiod             ; a note: the AY period, as line 2480 does
    ex de,hl
    call outdec
    jr bal_len
bal_zero:
    ld hl,0
    call outdec
    jr bal_len
bal_rest:
    ld hl,txt_minus1
    call outstr
bal_len:
    ld a,','
    call outch
    ld a,(ballen)
    ld l,a
    ld h,0
    call outdec
    pop bc
    ret

balline:  defw 0
balpos:   defw 0
balptr:   defw 0
balname:  defw 0
ballen:   defb 0

txt_bal1:  defb "10 'BASIC music program from CPC Tab Composer 2.0. Song: ",0
txt_data:  defb " DATA ",0
txt_minus1: defb "-1",0

txt_balprog:
    defb "20 on error goto 110:restore",0
    defb "30 ENV 1,15,-1,20",0
    defb "40 input",34,"Speed",34,";w",0
    defb "50 read a,al,b,bl,c,cl",0
    defb "60 if a=0 then 70 else if a=-1 then sound 129,3,al*w,0 else sound 129,a,al*w,0,1",0
    defb "70 if b=0 then 80 else if b=-1 then sound 130,3,bl*w,0 else sound 130,b,bl*w,0,1",0
    defb "80 if c=0 then 90 else if c=-1 then sound 132,3,cl*w,0 else sound 132,c,cl*w,0,1",0
    defb "90 for o=1 to w*2:next",0
    defb "100 goto 50",0
    defb "110 call &bb06:run",0
    defb 0

msg_balsaved: defb "Saved as a BASIC program.",0
