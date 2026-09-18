# CPC Tab Composer 2.0 - the Z80 port

A port of the 1986 Locomotive BASIC program (`tabcomp.bas`) to assembler.
Same screen, same file format, same keys - the point is that a song written
in 1986 loads, draws and plays identically, and only then does anything get
improved.

The screen is in English now, where the 1986 program was in German. The
field widths are unchanged, so the dotted columns of the panel still line
up: "Free Channels" is thirteen characters exactly as "Freie Kanaele" was,
and the right hand labels are eight - any longer and they run into the
column the numbers are printed in. The copyright sign is character 164,
which had to be added to the font copy alongside the rest symbol, the
playing marker and the panel's block.

Build with `./build.sh` (rasm + iDSK): it assembles to `TABCOMP.BIN` at
`#4000` and puts it on `tabcomp.dsk` with `BOUREE.MUS` to test against.
`RUN"TABCOMP` starts it.

## The file is read a line at a time

The loader used to read the whole file into a 10K buffer and parse it
afterwards. Then the program grew past #6000, where the song data lived,
and `clearsong` wiped the program's own tail - the panel and title text -
which appeared as a garbled information panel and nothing else. The same
shape as the font collision, and caught by neither assert.

The format is one pair to a line, so a sixty byte line buffer does the same
job as ten kilobytes: read a line, count the numbers on it, parse them.
Telling the two layouts apart works line by line rather than by scanning a
buffer, and the memory map now has room to grow:

    #4000  code and text        ends at #618F
    #7000  notes and lengths    700 positions x 3 voices, x2
    #8100  the font copy
    #9E00  AMSDOS's 2K scratch

    assert tabend < NOTES
    assert tabend < FONT

## Why #4000

Below `#4000` the lower ROM shadows RAM whenever the firmware pages it in,
so the sound manager read ROM where the sound block was meant to be and
nothing was ever heard - measured: identical code silent at `#1000` and
`#2000`, audible at `#4000` and `#9000`.

## What works

    load        L asks for a name and reads it through CAS_IN_CHAR. Both
                file layouts are read: tabcomp.bas writes the number of
                positions on a line of its own and eleven repeat pairs at the
                end, the older files are nothing but note/length pairs - a
                first line carrying one number can only be a count, because a
                data line always has a note AND a length. Notes stored as AY
                tone periods (the 1986 tape songs) are resolved back to a
                fingering the way TABCOMPX does it, lowest fret first
    save        S asks for a name and writes what line 1860 writes, byte for
                byte - " 190  2 " lines ending CR LF - so a song written here
                loads in the 1986 BASIC and the other way round. Where the
                BASIC asks "bis zu welcher Stelle" the end is worked out
                instead: as far as there is music
    display     pixel-identical to the BASIC: grid, six strings, fret digits
                as hex, rests as CHR$(206), and the occupancy bars
    play        P hands each note to the firmware sound queue with the flush
                bit, one position every 0.24 s. The nine amplitude envelopes
                of lines 230-310 and the eight tone envelopes of lines
                3380-3450 are all defined, per channel as ea/ta, eb/tb,
                ec/tc - defaulting to ENV 5 and ENT 7 as line 3320 does.
                A note's duration is its length in positions times the
                position time, which is line 3610's laenge(i,1)*w
    vibrato     V steps v from 0 to 15 and rebuilds the eight tone
                envelopes from it on the spot - they are all written in
                terms of v, so they cannot be constants
    speed       < and > change the position time, while playing or not.
                SPACE restarts a playback from the top, ESC stops it
    help        H shows the key list in the panel, two columns, in the same
                window the catalogue uses - the sheet above is not disturbed
                and there is nothing to redraw afterwards. Rows 3 and 4 of
                the sheet are left empty because that is where prompts and
                messages go: the BASIC's WINDOW #3 is row 3
    catalogue   C shows the disc directory in the panel area, and L shows it
                before asking which song to load. The BASIC does the same
                window swap for C (line 2130), but makes you remember the
                name when loading
    editing     ENTER on a cell that already carries a note on that string
                edits it - same voice, its fret to start from - instead of
                putting a second voice on the same string. One string sounds
                one note; the BASIC would let you stack the same fret on all
                three channels. A chord is still a chord: notes on DIFFERENT
                strings at the same position are untouched by this
    entry       ENTER starts a note, the cursor keys pick the fret, ENTER
                keeps it, SPACE makes it a rest, ESC abandons it. COPY still
                works for starting and keeping, which is what 1986 fingers
                will try - but it is awkward to reach on a modern keyboard,
                and ENTER to start and ENTER to keep reads better than ENTER
                meaning "give up". ESC therefore no longer quits the
                program: a key that cancels in one place must not throw the
                song away in another. Q quits, and asks first
    delete      DEL or CLR takes out the note on the string the cursor is on
    length      N cycles whole/half/quarter/eighth

## What the port changes on purpose

    audition    choosing a fret sounds THAT note. Line 1590 plays
                SOUND 130,100,10,15 - one fixed click whatever fret you are
                on. The player already turns a packed note into a sound, so
                entry just asks it to
    rests       can be deleted. The BASIC compares the string digit of 88
                against rows that stop at 6, so a rest was permanent
    bars        drawn once per note from its length, not once per position:
                the per-position version printed a space through the last
                letter of the bar before it
    N           cycles the note length instead of asking for it with INPUT
    no cassette the original can switch to tape (K = |TAPE, D = |DISC,
                G = SPEED WRITE 0/1). Disc only here. dsk_select is line
                120's |DISC and is not optional: AMSDOS puts the CASSETTE
                vectors back at &BC77 when RUN" hands over
    movement    all four cursor keys just move. In 1986 the left arrow deleted,
                so it could not also go back - which is the entire reason the
                Korrektursaite existed: a parking row above the top string
                where the left arrow could safely mean "move". With DEL and CLR
                doing the deleting, that row has nothing to do, and it is gone

## The screen is drawn directly now: 1.58 s -> 0.16 s

A full page was 1.6 s, and it was the whole feel of the program. Where it
went: clearsheet 0.98 s (576 firmware character writes at 1.7 ms each), the
note cells 0.26 s, grid and strings 0.34 s (~5700 firmware plot calls).

None of it needs the firmware. MODE 2 is one bit per pixel:

    addr = #C000 + (y AND 7)*2048 + (y/8)*80 + x

so a string is 64 bytes of #FF on one scanline, a bar line is one bit down a
column, and a character is the eight bytes of its matrix. Measured after:

    a whole page                 0.16 s   (was 1.58 s)
    a cursor move                nothing at all

The cursor move is the bigger win. Blanking the marker damages exactly one
character cell, so one cell is repaired - eight bytes - where the BASIC
redraws all six strings after every keypress (line 1520's GOTO 730).

Three things that had to be got right:

    the font      TXT GET MATRIX hands back an address in the LOWER ROM, and
                  this program cannot read it: below #4000 the ROM is only
                  there while the firmware has paged it in. Reading it gets
                  RAM, so every glyph came out blank - and blank XOR inverse
                  is a solid block, which is what the screen filled with.
                  The font is copied out once at startup with
                  KL L ROM ENABLE around the copy
    the stepping  the eight scanlines of a cell are NOT contiguous, but they
                  are exactly 2048 apart - a character row is eight
                  scanlines and the interleave blocks are too, so (y/8)*80
                  does not change and only (y AND 7) steps. That is "add 8
                  to D" per line, no recomputation
    registers     drawch must preserve BC: drawpage keeps the voice number
                  in C, and without it every bar was drawn for the wrong one

The line sits at scanline (399-i)/2, not (400-i)/2 - measured against the
firmware's own line rather than worked out, and it is one scanline higher
than the arithmetic suggests.

## What this buys: the tablature can scroll while it plays

A page turn is now 0.16 s, comfortably inside one 0.24 s position, and the
firmware sound queue is interrupt-driven - the AY plays on regardless of
what the main code is doing. Queue the step's notes before drawing and
there is nothing to hear. The playback marker itself is two characters.

## The key nobody could press

Every key was dead while the music played - ESC, SPACE, < and >. Not a
keyboard or emulator problem: the wait between positions called KM READ
CHAR and threw away what came back, so a key pressed during a position,
which is almost all of the time, was swallowed there. The test after the
wait only ever saw a key pressed in the gap between. The wait keeps the key
now, and the step acts on it.

## Two traps in the memory map and the ROM

**The font was overwritten by the program itself.** `buildfont` copied the
character matrices to #5800; the program grew past #5800; the copy landed on
the program's own tail, which is where the title and panel text tables live,
and the screen filled with nonsense. The font now sits at #9A00, above the
song data and the file buffer, and the build fails rather than repeats it:

    assert tabend < FONT

**#B906 enables the lower ROM, not #BCCE.** The standard character matrices
live at #3800 and up, in the lower ROM, which this program cannot read
unless it asks. I "corrected" a working #B906 to the #BCCE the manuals in my
head insisted on, and the font copied 768 bytes of zeros - which drew
nothing, and which inverse video turned into solid blocks. Measured, not
recalled: the byte at #3A08, where TXT GET MATRIX says the letter A lives,
reads 00 normally and 18 after calling #B906. That is the apex of an A.

## Following the music, and moving about

    marker      a down arrow above the top string, on the row the old
                Korrektursaite used to occupy, moving with the position
                being played - two characters a step
    page turns  the page follows the music by itself: 32 positions to a
                page, and when the playing position passes the end of one
                the next is drawn. The notes are queued BEFORE the drawing,
                and the position is timed against the 1/300 s clock (KL TIME
                PLEASE, #BD0D - measured at exactly 300 ticks a second)
                rather than counted out in a delay loop. A delay loop makes
                a position last its work PLUS the delay, so the one position
                that turned the page ran 0.16 s long and the music stumbled
                once a page. Measured after: every position 12 frames, the
                page turn included
    editing     the cursor turns the page at either edge, and + and - move a
                whole sheet at a time (the BASIC's lines 4300 and 4350) -
                without "Notenblatt korekt <J><N>"
    panel       the whole of line 3490 and 3510: what each channel is
                sounding, the position, the elapsed time, vibrato, speed,
                and ENV and ENT per channel. A B C step a channel's tone
                envelope while it plays, a b c its amplitude envelope, and
                1 to 6 set one back to nought - which, with the volume
                passed as 0, is how a channel is muted

## The nought that ate the next character

`put3` prints a number in three right-aligned columns. Its "the last digit
always prints" test was `ld a,b / cp 1 / jr z,print` - and A no longer holds
the digit at that point, it holds B. So a number ending in zero printed
CHR$(1), which the firmware reads as "print the next character literally":
the nought vanished AND swallowed the character after it. A channel switched
off kept showing its old envelope, and an empty channel showed the panel
pattern through the hole. LD does not touch the flags, so reloading '0'
before the jump costs nothing. The older `putdec` had it right all along.

## Making the page turn cheap

Turning the page redrew the whole sheet - clear, grid, cells - for 0.16 s
inside a 0.24 s position. The music never gapped (the sound queue runs on
interrupts and the notes are queued before any drawing) but it was audible.

The grid is the same on every page, so a turn need not touch it:

    erasecells  clears the three bar rows outright - there is no grid in
                them - and puts the grid back cell by cell under the digits
                that were drawn, which is what fixcell is for
    drawcells   draws the new page over the grid that is already there

and scraddr, called once per character, now looks the row offset up in a
table of 25 words instead of adding 80 to itself up to 24 times.

    a page turn   0.16 s -> 0.093 s, measured on the 1/300 s clock

## The panel, drawn directly

The information panel's background is 880 cells of the same block. Through
the firmware that is about 1.7 ms each - a second and a half - and it ran
again every time the panel came back after a catalogue, a help page or a
load. Every cell being the same glyph means each scanline of a row is ONE
byte repeated eighty times, so the whole panel is 88 runs of 80 bytes.
putblock draws its text through the same direct path, handling the INVERSE
control code itself.

    panel and every label   ~1.9 s -> 0.187 s, measured on the 1/300 s clock

The help page no longer needs a text window to hold it in place, since it
is written to absolute rows now.

## A message printed from nowhere

After a failed load the program said so, waited for a key - and then fell
through into the path that reports success, which printed again from
whatever HL held after the firmware's key call. `putz` walked off into
memory until it met a zero byte, spraying characters across the screen and
flashing the border with whatever control codes it passed through. It
looked like a crash and was a fall-through: the two paths now meet only
after both have finished printing.

Worth remembering: a firmware call does not preserve HL, and a routine
that takes a pointer in HL will happily print from anywhere.

## Keeping AMSDOS quiet

A load that finds nothing used to produce TWO messages: the program's own,
and AMSDOS printing "XYZZY .MUS not found" wherever the cursor happened to
be - over the sheet, or the string names, until the next redraw.

AMSDOS says its piece through the text VDU, so the VDU is switched off
around the disc calls - TXT VDU DISABLE (&BB57) before, TXT VDU ENABLE
(&BB54) after - and the program reports the outcome itself, in its own
place. Direct screen writing is unaffected by it, so nothing else changes.

## Messages

A failure is HELD until a key is pressed, and the keyboard is emptied
first: after typing a file name there is usually a keystroke still in the
buffer, and it would take the message away before it could be read. That
applies to a load that finds nothing, to both save paths, and to the
catalogue. A message that reports success only flushes the buffer, so it
stays until something is actually pressed.

Row 2 carries the 1986 credit, so the repeat markers moved to row 4 and
share it with the marker that follows the music - both say something about
the position underneath. The row is cleared and redrawn once per position,
so the moving marker cannot rub a repeat mark out on its way past, and
clearmsg no longer touches row 4.

Every value in the left panel is printed in a FIXED five column field -
space, three right aligned digits, space - so the dotted part of each label
starts in the same column. Printed at its natural width, a 1 and a 612 put
the dots two columns apart and the left edge of the panel wandered.



A message stays on row 3 until the next thing you do, and goes when you do
it - long enough to read, short enough not to linger. mainloop clears rows
3 and 4 after every keypress, which is only affordable because the clearing
is direct: through the firmware it is 152 characters, a quarter of a second
per keystroke.

Row 4 is cleared with it because AMSDOS prints its own messages wherever
the cursor happens to be, and a "not found" long enough to wrap lands on
the string names in columns 1 and 2 - which drawpage never touches, since
the sheet starts at column 3. That left an O from BOUREE where the top
string's E belongs, so restorepanel puts the labels back too.

## Repeats, and the BASIC program

    T           marks a repeat: from where the cursor is, to a position you
                name. Eleven of them, which is what the file has room for
    A           lists them, in the panel
    T then 0    takes the repeat at the cursor away - positions start at 1,
                so 0 is free to mean something, and a repeat wants deleting
                more often than position 0 wants naming. The list is CLOSED
                UP behind it, never left with a hole: playback walks the
                entries in order and stops at the first unset one, so a hole
                would kill every repeat after it
    row 2       the markers - a hex digit where the jump is, and the same
                digit INVERTED where it jumps to. The BASIC marks only the
                jump itself (line 1780), so you had to remember where it
                went; both ends are worth seeing
    playing     line 3570, once per position: takta(takt)=i means go to
                taktb(takt), and takt then advances - so a repeat fires once
                and the next one is watched for. That is what stops a
                backward jump repeating for ever
    B           writes the song as a BASIC program - lines 2170 to 2440.
                The file IS a Locomotive BASIC program: ENV, INPUT"Speed",
                a READ/DATA loop and three SOUND statements, with the AY
                period per voice, 0 for nothing or a held note and -1 for a
                rest. Ten positions to a DATA line. The BASIC asks for the
                first line number and the spacing; ten and ten are what
                everyone used, so they are simply the numbers here

Verified the whole way through: composed two notes, exported, quit to
BASIC, RUN"TEST.BAL, answered "Speed" - and both notes came out at the
pitches they were written at, 786 Hz and 880 Hz.

## MIDI OUT

    M           cycles the output: AY, MIDI, AY+MIDI. Shown in the panel as
                "Ausgabe:". Both engines play the same three voices - the
                file holds three, and widening that is a format decision,
                not a player one
    the card    the BluePillCPC "Ultimate MIDI Card" at &FBEE, and the
                pacing comes from TRACKER/CPC where it was learned the hard
                way: MIDI is 31250 baud, so a byte owns the wire for 320 us
                and nothing may go out faster. TRACKER's first CPC version
                sent them 98 us apart, and the bytes it lost were program
                changes - a channel that loses one stays on Acoustic Grand
                Piano, which is what he heard on track 2 of BOOGIE. The wait
                is inside midiout, so no caller can forget it
    notes       a MIDI note is the open string plus the fret, and nothing
                else: 64 59 55 50 45 40 for strings 1 to 6. The AY needs a
                period from a table; MIDI needs one addition. That is the
                argument for having kept the FINGERING in the file rather
                than a tone period
    lengths     the AY is told a duration and looks after itself; MIDI has
                to be told when to stop, so each voice carries how many
                positions it has left and gets a Note Off when they run out.
                Everything is silenced when playback ends, and when the
                output mode changes mid-piece
    instrument  I asks for a General MIDI program, 1 to 128, and sends it
                to all three channels - the tablature is one guitar, so one
                choice covers it. 25, Acoustic Guitar (nylon), is where it
                starts. While the music plays, + and - step through them
                instead (they are the sheet keys in the editor, and unused
                here), which is how a sound gets found by ear. Shown in the
                panel as "Instr. :", in GM numbering - one more than what
                goes on the wire, because GM counts from 1 and MIDI from 0.
                Sent before the first note of a playback, because a channel
                that never receives one stays on GM 1, Acoustic Grand Piano
    entry       auditioning a note sends it to MIDI too, and the note being
                chosen is stopped when the next one is chosen or the entry
                is committed

Measured on the wire, with a tap on the card's port:

    92 43 64   Note On  channel 3, note 67 = E4 + fret 3, velocity 100
    82 43 00   Note Off channel 3, 477.7 ms later = 2 positions x 0.24 s
    gaps of 345 to 350 us between bytes, over the 320 us a byte takes

## Still to do

    six voices  .MUS holds exactly three voices per position, because the
                AY has three channels. MIDI has no such limit, and six - one
                per string - is what a guitar chord actually is. Widening it
                means the file no longer round-trips with the 1986 BASIC,
                so it is a decision rather than a change
    M           the BASIC's manual channel choice (line 1030), never ported
    testnote    the single-note sound test in play.asm is now unreachable -
                T is the repeat key again. Harmless, and still the quickest
                way to ask "does this machine make a sound at all"

## What the vibrato looks like when it works

One whole note, string 1 fret 0 (period 190), v=15, ENT 7 - which is
"one step of +v, hold 9 hundredths; one step of -v, hold 9" and repeats.
Goertzel energy every 0.09 s at the two periods it swings between:

     t       658Hz   610Hz
     36.45    235    1052
     36.54   1044     242
     36.63    224     849
     ...       ...     ...
     38.34     32      44      note over: 1.95 s = 8 positions x 0.24 s

The alternation is the vibrato, that it keeps alternating is the repeat bit
(bit 7 of the count byte), and the fall from 1052 to 44 is ENV 5 decaying.

## Testing

**MAME never writes a .dsk back.** It opens the image read/write and the
emulated machine sees its own writes - `CAT` lists the new file - but the
host file is byte-identical afterwards, because the DSK format is load-only.
So a disc write is verified inside the machine: save, load it back, and read
the load buffer at `#7100` from Lua to see the bytes that were written.

Nothing about sound is believed unless `audible.sh` says so - it records the
emulator and measures Goertzel energy at the expected pitch. Counting AY
register writes proves nothing, the mixer can have tone disabled. Entry and
playback were last measured together: 658 Hz when COPY opened entry on the
open string, 880 Hz when the fifth cursor-up reached fret 5, and 880 Hz again
when P played the stored note back.
