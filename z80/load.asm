;; ---------------------------------------------------------------
;; TABCOMP/CPC - loading a .MUS song
;;
;; A .MUS file is plain ASCII written by BASIC's PRINT #9: pairs of
;; numbers, " note  length ", CR LF, three pairs per position. There is
;; no AMSDOS header and, in the old format, no count at the front - the
;; program simply reads until the file runs out.
;;
;; Two formats exist and this reads both:
;;
;;   old (tabcomp1, and every song restored from the 1986 tapes)
;;        the note is the AY TONE PERIOD, which is why those songs could
;;        not be edited after saving - the fingering is not in the file
;;   new (tabcomp.bas)
;;        the note is the tablature position itself, digit by digit:
;;        35 is string 3 fret 5, 212 is string 2 fret 12
;;
;; Telling them apart needs no flag: a value that is not a well formed
;; tablature position must be a period. 190 as a position would be string
;; 1 fret 90, which does not exist.
;;
;; PERIODS ARE AMBIGUOUS. The same pitch lives at several places on the
;; neck, so 190 is both string 1 fret 0 and string 3 fret 9. TABCOMPX
;; resolves it by searching FOR xs=0 TO 12 : FOR ys=1 TO 6 and taking the
;; first hit - lowest fret wins. That order is copied exactly here, or a
;; restored song would come back with different fingering from the one
;; the disc images already show.
;; ---------------------------------------------------------------

CAS_IN_OPEN    equ #BC77
CAS_IN_CLOSE   equ #BC7A
CAS_IN_CHAR    equ #BC80
CAS_IN_DIRECT  equ #BC83

;; The file used to be read whole into a 10K buffer and parsed afterwards.
;; It is read a LINE at a time now - the format is one pair to a line, so a
;; line buffer of sixty bytes does the same job and gives back ten
;; kilobytes. That mattered: the program grew past #6000, where the song
;; data was, and clearsong then wiped the program's own tail - the panel
;; and title text - which showed up as a garbled information panel.
LINEMAX equ 60
DSKBUF  equ #9E00               ; AMSDOS's 2K scratch
NOTES   equ #7000               ; 700 positions x 3 voices, one packed byte
LENS    equ NOTES+2100          ; ... and their lengths
NPOS    equ 700

;; A packed note byte:
;;     #00        nothing here
;;     #FE        held - the voice is still sounding the note that started
;;                earlier, which is what 99 means in the file and what
;;                draws the tail of the AA/BB/CC busy bar
;;     #FF        a rest
;;     s<<4 | f   string 1..6, fret 0..12

;; ---------------------------------------------------------------
;; When BASIC's RUN" hands over to a binary, AMSDOS puts the CASSETTE
;; vectors back at &BC77. Call them as they stand and the machine asks
;; for "Press PLAY then any key". Putting the disc vectors back is the
;; program's own job - the lesson TRACKER/CPC learned the hard way, and
;; what TADITRANS did at &937A in 1987.
;; ---------------------------------------------------------------
dsk_select:
    ld hl,dsk_vectors
    ld de,CAS_IN_OPEN
    ld bc,13*3
    ldir
    ret

dsk_vectors:
    repeat 13
    defb #DF,#8B,#A8            ; RST &18 / DEFW &A88B
    rend

;; ---------------------------------------------------------------
;; Load the file named at fname, then parse it into the arrays.
;; Carry set on success.
;; ---------------------------------------------------------------
clearsong:
    call cleartakt
    ld hl,NOTES
    ld de,NOTES+1
    ld bc,2100*2-1
    ld (hl),0
    ldir
    ret

loadmus:
    call dsk_select
    call TXT_VDU_DISABLE        ; "XYZZY .MUS not found" is AMSDOS talking
    ld a,(namelen)              ; to the screen, and it lands wherever the
    ld b,a                      ; cursor happens to be. The program says
    ld hl,namebuf               ; what happened itself, in its own place.
    ld de,DSKBUF
    call CAS_IN_OPEN
    jr c,lm_open
    call TXT_VDU_ENABLE
    or a                        ; carry clear: not found
    ret
lm_open:
    call clearsong
    ld hl,NOTES
    ld (noteptr),hl
    ld hl,LENS
    ld (lenptr),hl

    ;; Two layouts, told apart by the first line. tabcomp.bas writes the
    ;; number of positions on a line of its own (line 1870) before the
    ;; note/length pairs, and eleven repeat pairs after them; the older
    ;; files - and every song restored from the 1986 tapes - are nothing
    ;; but pairs. A line with one number on it can only be the count,
    ;; because a data line always carries a note AND a length.
    call readline
    jp nc,lm_done
    call countnums
    cp 1
    jr nz,lm_old

    ld hl,linebuf               ; the newer layout: how many positions
    ld (srcptr),hl
    call nextnum
    ld de,NPOS+1
    push hl
    or a
    sbc hl,de
    pop hl
    jr c,lm_cnt
    ld hl,NPOS                  ; more than the sheet holds: read what fits
lm_cnt:
    ld d,h                      ; three voices to a position
    ld e,l
    add hl,hl
    add hl,de
    ld (pairsleft),hl
lm_new:
    ld hl,(pairsleft)
    ld a,h
    or l
    jr z,lm_reps
    dec hl
    ld (pairsleft),hl
    call readline
    jp nc,lm_done
    call parsepair
    jr lm_new

;; the eleven repeat pairs that close the newer layout
lm_reps:
    xor a
    ld (repidx),a
lm_r1:
    call readline
    jp nc,lm_done
    ld hl,linebuf
    ld (srcptr),hl
    call nextnum
    jp nc,lm_done
    push hl
    ld a,(repidx)
    ld c,a
    ld hl,takta
    call taktslot
    pop de
    ld (hl),e
    inc hl
    ld (hl),d
    call nextnum
    jp nc,lm_done
    push hl
    ld a,(repidx)
    ld c,a
    ld hl,taktb
    call taktslot
    pop de
    ld (hl),e
    inc hl
    ld (hl),d
    ld a,(repidx)
    inc a
    ld (repidx),a
    cp TAKTMAX
    jr c,lm_r1
    jr lm_done

;; the older layout: pairs until the file runs out
lm_old:
    call parsepair              ; the line already in hand
lm_o1:
    ld hl,(noteptr)
    ld de,NOTES+2100
    or a
    sbc hl,de
    jp nc,lm_done               ; the sheet is full
    call readline
    jp nc,lm_done
    call parsepair
    jr lm_o1

lm_done:
    call CAS_IN_CLOSE
    call TXT_VDU_ENABLE
    call taktcounted            ; how many repeats came back
    scf
    ret

;; ---------------------------------------------------------------
;; One line of the file into linebuf, zero terminated. Carry clear when
;; there is nothing left. Empty lines are skipped; a last line with no
;; newline after it still counts.
;; ---------------------------------------------------------------
readline:
    ld hl,linebuf
    ld c,0
    ld b,LINEMAX-1
rl1:
    push bc
    push hl
    call CAS_IN_CHAR
    pop hl
    pop bc
    jr nc,rl_eof
    cp #1A                      ; CP/M's end of file padding
    jr z,rl_eof
    cp 13
    jr z,rl_end
    cp 10
    jr z,rl_end
    ld (hl),a
    inc hl
    inc c
    djnz rl1
rl_end:
    ld (hl),0
    ld a,c
    or a
    jr z,readline               ; nothing on that line - take the next
    scf
    ret
rl_eof:
    ld (hl),0
    ld a,c
    or a
    ret z
    scf
    ret

;; -> A = how many numbers are on the line
countnums:
    ld hl,linebuf
    ld c,0
    ld b,0
cn1:
    ld a,(hl)
    or a
    jr z,cn_end
    cp '0'
    jr c,cn_gap
    cp '9'+1
    jr nc,cn_gap
    ld a,b
    or a
    jr nz,cn_next
    inc c                       ; the start of a number
    ld b,1
    jr cn_next
cn_gap:
    ld b,0
cn_next:
    inc hl
    jr cn1
cn_end:
    ld a,c
    ret

;; the note and its length, from the line in hand
parsepair:
    ld hl,linebuf
    ld (srcptr),hl
    call nextnum
    ret nc
    call packnote
    ld hl,(noteptr)
    ld (hl),a
    inc hl
    ld (noteptr),hl
    call nextnum
    ret nc
    ld a,l                      ; lengths are small
    ld hl,(lenptr)
    ld (hl),a
    inc hl
    ld (lenptr),hl
    ret

;; how many repeats are actually set
taktcounted:
    xor a
    ld (repidx),a
    ld b,0
tc1:
    push bc
    ld a,(repidx)
    ld c,a
    ld hl,takta
    call taktslot
    ld a,(hl)
    inc hl
    or (hl)
    pop bc
    jr z,tc2
    inc b
tc2:
    ld a,(repidx)
    inc a
    ld (repidx),a
    cp TAKTMAX
    jr c,tc1
    ld a,b
    ld (taktcount),a
    ret

linebuf:   defs LINEMAX
pairsleft: defw 0
repidx:    defb 0

;; -> HL = the next decimal number, carry set. Carry clear at end of data.
;; #1A is CP/M's end of file padding, which is what a BASIC written ASCII
;; file trails off into.
nextnum:
    ld hl,(srcptr)
nn1:
    ld a,(hl)
    or a
    jr z,nnend
    cp #1A
    jr z,nnend
    cp '0'
    jr c,nn2
    cp '9'+1
    jr c,nn3                    ; a digit: start of a number
nn2:
    inc hl
    jr nn1
nn3:
    ld de,0                     ; DE accumulates, HL walks the text
nn4:
    ld a,(hl)
    cp '0'
    jr c,nn5
    cp '9'+1
    jr nc,nn5
    push hl
    ex de,hl                    ; HL = accumulator
    add hl,hl                   ; x2
    ld d,h
    ld e,l
    add hl,hl                   ; x4
    add hl,hl                   ; x8
    add hl,de                   ; x10
    ex de,hl
    pop hl
    ld a,(hl)
    sub '0'
    ld c,a
    ld b,0
    ex de,hl
    add hl,bc
    ex de,hl
    inc hl                      ; ... and on to the next character
    jr nn4
nn5:
    ld (srcptr),hl
    ex de,hl
    scf
    ret
nnend:
    ld (srcptr),hl
    or a
    ret

;; ---------------------------------------------------------------
;; HL = a number from the file -> A = packed note byte
;; ---------------------------------------------------------------
packnote:
    ld a,h
    or l
    ret z                       ; 0: nothing here

    ld a,h                      ; 88 = rest, 99 = empty
    or a
    jr nz,pn_notsmall
    ld a,l
    cp 88
    jr nz,pn_n99
    ld a,#FF
    ret
pn_n99:
    cp 99
    jr nz,pn_notsmall
    ld a,#FE                    ; held, NOT empty: 99 keeps the busy bar
    ret

pn_notsmall:
    call tabpos                 ; already a tablature position?
    ret nz                      ; yes, A = packed
    jp findperiod               ; no, so it must be a period

;; HL = value -> A = packed and NZ if it is a well formed position,
;; Z if it is not. Positions are s*10+f for frets 0..9 and s*100+f for
;; frets 10..12, with the string 1..6.
tabpos:
    push hl
    ld a,h
    or a
    jr nz,tp_big                ; three digits, so s*100+f
    ld a,l
    cp 10
    jr c,tp_no
    cp 70
    jr nc,tp_no
    ld b,0                      ; A = s*10+f, split it
tp1:
    cp 10
    jr c,tp2
    sub 10
    inc b
    jr tp1
tp2:
    ld c,a                      ; C = fret 0..9, B = string
    ld a,b
    or a
    jr z,tp_no
    cp 7
    jr nc,tp_no
    rlca
    rlca
    rlca
    rlca
    or c
    pop hl
    or a                        ; NZ
    ret

tp_big:
    ld de,100
    ld b,0
tb1:
    or a
    sbc hl,de
    jr c,tb2
    inc b
    jr tb1
tb2:
    add hl,de                   ; B = hundreds, HL = remainder
    ld a,h
    or a
    jr nz,tp_no
    ld a,l
    cp 10
    jr c,tp_no
    cp 13
    jr nc,tp_no
    ld c,a
    ld a,b
    or a
    jr z,tp_no
    cp 7
    jr nc,tp_no
    rlca
    rlca
    rlca
    rlca
    or c
    pop hl
    or a
    ret

tp_no:
    pop hl
    xor a
    ret

;; HL = a tone period -> A = packed note, or 0 if it is not in the table.
;; Search order is fret 0..12 outer, string 1..6 inner, first hit wins -
;; the same order TABCOMPX uses, so the same fingering comes out.
findperiod:
    ld ix,periods
    ld b,0                      ; fret 0..12
fp_fret:
    ld c,5                      ; index in the row: 5 is string 1, 0 is string 6
fp_str:
    push bc
    ld a,c
    add a,a                     ; two bytes per entry
    ld e,a
    ld d,0
    push ix
    add ix,de
    ld e,(ix+0)
    ld d,(ix+1)
    pop ix
    push hl
    or a
    sbc hl,de
    pop hl
    pop bc
    jr z,fp_hit
    dec c
    jp p,fp_str
    ld de,12                    ; six entries to the next fret
    add ix,de
    inc b
    ld a,b
    cp 13
    jr c,fp_fret
    xor a                       ; not a period we know
    ret

fp_hit:
    ld a,6
    sub c                       ; string = 6 - index
    rlca
    rlca
    rlca
    rlca
    or b                        ; ... | fret
    ret

    include "periods.inc"

okmsg:   defb "Loaded.",0
failmsg: defb "File not found!",0



srcptr:  defw 0
noteptr: defw 0
lenptr:  defw 0
