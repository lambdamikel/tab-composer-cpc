;; ---------------------------------------------------------------
;; TABCOMP/CPC - bar repeats
;;
;;   1760  takta(taktcount)=zeiger : taktb(taktcount)=w
;;   3570  i=i+1 : IF takta(takt)=i THEN i=taktb(takt) : takt=takt+1
;;
;; So a repeat is "when the music reaches position takta, go to taktb",
;; and they fire IN ORDER: takt only ever advances, so a backward jump
;; plays its section once more and the next entry is then watched for.
;; That is what stops a repeat repeating forever, and it is why these are
;; a list rather than a pair of brackets.
;;
;; Eleven of them, which is what the file format has room for - the .MUS
;; file ends with eleven pairs whether they are used or not.
;; ---------------------------------------------------------------

TAKTMAX equ 11

takta:     defs TAKTMAX*2       ; the position that jumps
taktb:     defs TAKTMAX*2       ; ... and where it jumps to
taktcount: defb 0               ; how many are set
takt:      defb 0               ; which one playback is watching for

cleartakt:
    ld hl,takta
    ld de,takta+1
    ld bc,TAKTMAX*4-1
    ld (hl),0
    ldir
    xor a
    ld (taktcount),a
    ret

;; HL -> the pair table, C = index: HL -> that entry.
;; It works through BC and puts it back, because DE is how callers carry
;; the value they are about to write - taktdel moved entries down the list
;; and this routine was quietly eating them on the way.
taktslot:
    push bc
    ld a,c
    add a,a
    ld c,a
    ld b,0
    add hl,bc
    pop bc
    ret

;; ---------------------------------------------------------------
;; T: a repeat from here to wherever you say
;; ---------------------------------------------------------------
dotakt:
    ld a,(taktcount)
    cp TAKTMAX
    jr c,dt_ask
    ld hl,msg_taktfull
    jp entmsg
dt_ask:
    ld hl,msg_taktask
    call getnum
    jp nc,mainloop
    ld a,h
    or l
    jr nz,dt_set
    ;; Nought means "take the one here away". Positions start at 1, so 0
    ;; is free to mean something else, and a repeat wants deleting far
    ;; more often than position 0 wants naming.
    call taktfind
    or a
    jr z,dt_none
    dec a
    call taktdel
    call drawtakt
    ld hl,msg_taktdel
    jr dt_say
dt_none:
    ld hl,msg_takthere
dt_say:
    push hl
    call clrmsg
    ld h,1
    ld l,3
    call TXT_SET_CURSOR
    pop hl
    call putz
    call showinfo
    jp mainloop

dt_set:
    push hl
    ld de,NPOS+1
    or a
    sbc hl,de
    pop hl
    jp nc,dt_done

    ld a,(taktcount)            ; where it jumps TO
    ld c,a
    push hl
    ld hl,taktb
    call taktslot
    pop bc                      ; BC = the position it jumps to
    ld (hl),c
    inc hl
    ld (hl),b
    ld a,(taktcount)            ; ... and where it jumps FROM
    ld c,a
    ld hl,takta
    call taktslot
    ld bc,(zeiger)
    ld (hl),c
    inc hl
    ld (hl),b
    ld a,(taktcount)
    inc a
    ld (taktcount),a
    call drawtakt
dt_done:
    call clrmsg
    call showinfo
    jp mainloop

;; ---------------------------------------------------------------
;; The markers, on the row above the top string. Line 3120 walks the
;; positions and asks each of the eleven; this walks the eleven and asks
;; whether each is on the page, which is the same picture for a third of
;; the work.
;; ---------------------------------------------------------------
drawtakt:
    call clearrow4              ; row 2 carries the 1986 credit now, so the
    ld a,4                      ; markers share row 4 with the marker that
    ld (dcy),a                  ; follows the music - both of them say
                                ; something about the position underneath
    ld c,0
dt_loop:
    push bc
    xor a                       ; the position it jumps FROM, plain
    ld (dcinv),a
    ld hl,takta
    call taktslot
    call dt_mark
    pop bc
    push bc
    ld a,#FF                    ; ... and the one it jumps TO, inverted.
    ld (dcinv),a                ; The BASIC marks only the jump itself, so
    ld hl,taktb                 ; you had to remember where it went; both
    call taktslot               ; ends of it are worth seeing
    call dt_mark
    pop bc
    inc c
    ld a,c
    cp TAKTMAX
    jr c,dt_loop
    xor a
    ld (dcinv),a
    ret

;; HL -> a position, C = which repeat: mark it if it is on this page
dt_mark:
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld a,d
    or e
    ret z                       ; not set - and position 0 never matches
    ex de,hl
    ld de,(pagetop)
    or a
    sbc hl,de                   ; how far into the page it is
    ret c
    ld a,h
    or a
    ret nz
    ld a,l
    cp 32
    ret nc                      ; not on this page
    add a,a                     ; two columns to a position
    add a,3
    ld (dcx),a
    ld a,c                      ; its number, as the BASIC's HEX$
    inc a
    cp 10
    jr c,dt_dig
    add a,'A'-10
    jp drawch
dt_dig:
    add a,'0'
    jp drawch

;; ---------------------------------------------------------------
;; Line 3570, once per position: has the music reached the one we are
;; watching for?
;; ---------------------------------------------------------------
;; -> A = 1 + the index of the repeat that jumps from where the cursor is,
;; or 0 if there is none
taktfind:
    xor a
    ld (repidx2),a
tf1:
    ld a,(repidx2)
    ld c,a
    ld hl,takta
    call taktslot
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld a,d
    or e
    jr z,tf2                    ; not set
    ld hl,(zeiger)
    or a
    sbc hl,de
    jr nz,tf2
    ld a,(repidx2)
    inc a
    ret
tf2:
    ld a,(repidx2)
    inc a
    ld (repidx2),a
    cp TAKTMAX
    jr c,tf1
    xor a
    ret

;; A = the one to remove. The list is CLOSED UP behind it, not left with a
;; hole: playback walks the entries in order and stops at the first unset
;; one, so a hole would kill every repeat after it.
taktdel:
    ld (repidx2),a
td1:
    ld a,(repidx2)
    inc a
    cp TAKTMAX
    jr nc,td_last
    ld c,a                      ; the one after it, moved down
    ld hl,takta
    call taktslot
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld a,(repidx2)
    ld c,a
    ld hl,takta
    call taktslot
    ld (hl),e
    inc hl
    ld (hl),d
    ld a,(repidx2)
    inc a
    ld c,a
    ld hl,taktb
    call taktslot
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld a,(repidx2)
    ld c,a
    ld hl,taktb
    call taktslot
    ld (hl),e
    inc hl
    ld (hl),d
    ld a,(repidx2)
    inc a
    ld (repidx2),a
    jr td1
td_last:
    ld c,TAKTMAX-1              ; and the last one is emptied
    ld hl,takta
    call taktslot
    ld (hl),0
    inc hl
    ld (hl),0
    ld c,TAKTMAX-1
    ld hl,taktb
    call taktslot
    ld (hl),0
    inc hl
    ld (hl),0
    ld a,(taktcount)
    or a
    ret z
    dec a
    ld (taktcount),a
    ret

repidx2: defb 0

taktcheck:
    ld a,(takt)
    cp TAKTMAX
    ret nc
    ld c,a
    ld hl,takta
    call taktslot
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld a,d
    or e
    ret z                       ; nothing set here
    ld hl,(playpos)
    or a
    sbc hl,de
    ret nz
    ld a,(takt)                 ; reached it: go where it says
    ld c,a
    ld hl,taktb
    call taktslot
    ld e,(hl)
    inc hl
    ld d,(hl)
    ex de,hl
    ld (playpos),hl
    ld a,(takt)
    inc a
    ld (takt),a
    ret

;; ---------------------------------------------------------------
;; A: what the repeats are - line 4400's table, in the panel
;; ---------------------------------------------------------------
dotaktlist:
    call clearpanel
    ld c,0
tl_row:
    push bc
    ld a,c
    add a,14
    ld (dcy),a
    ld a,2
    ld (dcx),a
    xor a
    ld (dcinv),a
    ld a,c                      ; which one
    inc a
    cp 10
    jr c,tl_dig
    add a,'A'-10
    jr tl_num
tl_dig:
    add a,'0'
tl_num:
    call drawch
    ld a,(dcx)
    inc a
    ld (dcx),a
    ld hl,txt_von
    call dputz
    pop bc
    push bc

    ld hl,takta                 ; from
    call taktslot
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld a,(dcy)
    ld l,a
    ld h,10                     ; three columns, 10 to 12 - and the text
    call putat3                 ; after it must start clear of them

    ld a,14
    ld (dcx),a
    ld hl,txt_zu
    call dputz
    pop bc
    push bc

    ld hl,taktb                 ; to
    call taktslot
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld a,(dcy)
    ld l,a
    ld h,17
    call putat3

    pop bc
    inc c
    ld a,c
    cp TAKTMAX
    jr c,tl_row

    ld a,24                     ; on the last row of the panel, clear of
    ld (dcy),a                  ; the list itself
    ld a,50
    ld (dcx),a
    ld hl,txt_taste
    call dputz
    call KM_WAIT_CHAR
    call restorepanel
    call drawtakt
    jp mainloop

;; ---------------------------------------------------------------
;; A number, typed on the message line. Digits, ENTER to accept, ESC to
;; give up, DEL to rub one out - the same shape as the name prompt.
;; ---------------------------------------------------------------
getnum:
    push hl
    ld h,1
    ld l,3
    call TXT_SET_CURSOR
    pop hl
    call putz
    ld hl,0
    ld (gnval),hl
gnum_loop:
    call KM_WAIT_CHAR
    cp 13
    jr z,gnum_done
    cp 252
    jr z,gnum_cancel
    cp '0'
    jr c,gnum_loop
    cp '9'+1
    jr nc,gnum_loop
    push af
    ld hl,(gnval)               ; value = value*10 + digit
    ld d,h
    ld e,l
    add hl,hl
    add hl,hl
    add hl,de
    add hl,hl
    pop af
    push af
    sub '0'
    ld e,a
    ld d,0
    add hl,de
    ld (gnval),hl
    pop af
    call TXT_OUTPUT
    jr gnum_loop

gnum_cancel:
    call clrmsg
    or a
    ret

gnum_done:
    ld hl,(gnval)
    scf
    ret

gnval: defw 0

txt_von:   defb ". from",0
txt_zu:    defb "to",0
txt_taste: defb "Press any key",0

msg_taktfull: defb "No room for another repeat.",0
msg_taktask:  defb "Repeat from here to which position (0 deletes)? ",0
msg_taktdel:  defb "Repeat deleted.",0
msg_takthere: defb "There is no repeat here.",0
