# tab-composer-cpc
The World's First (?) Tablature Composer Software - written in 1986 on an Amstrad CPC 464 

## Latest News

### 5-3-2026 

I have restored many of the **old songs** I made with Tab Composer CPC back in ~1986 from 40 year old cassette tapes! Check out [the YouTube video for the details.](https://youtu.be/yU8MmQVJ87o)

There is now a [DSK image for CPC emulators with the restored songs and a special version of Tab Composer CPC that can play back these older songs.](cpc/SONGS-TCX.dsk) Note that the songs were originally created with an earlier version of Tab Composer CPC, before I owned a DD1 disk drive. This older version (`tabcomp1.bas`) used a different data format and also  had the drawback of not allowing round trip editing of the songs once saved. This shortcoming was fixed in [the latest "official" version of `tabcomp.bas`](cpc/tabcomp.dsk). But most of the songs I had already created with the earlier version (`tablcomp1.bas`) - to read these back with the latest more capable version I hence added a data conversion routine to the song loader. This version is on [the song disk](cpc/SONGS-TCX.dsk): `tabcompx.bas` (`x` for conversion). So please use this version to load the songs included on the disk and not `tabcomp1.bas`. 

To use `tabcompx.bas` for loading a song and play it back, first use the `l` key to load the song. Just enter the filename *without the .mus extension.* You can see all the songs on disk with the cataloge function: `c`. To play back a song, use `p` and answer the questions ("Geschwindigkeit" = "Speed", use 50, 100, ..., depending on the song; the other input prompts should be understandable for English speakers). You can always get the help page with the `h` key. 

Note that loading songs with `tabcompx.bas` takes a bit longer than with `tabcomp1.bas` or  [the "official" Tablature Composer on the tabcomp.dsk image](cpc/tabcomp.dsk), due to the required data conversion. 

Moreover, I also retrieved [the very first *Version 0 of Tab Composer CPC*](cpc/TABCOMP0.dsk) from tape! This is a very primitive "first sketch of an idea" prototype version, so don't use it for anything - it is archived here for the sake of completeness and "just for fun". A few songs are also included for it on the disk - you can use the `6` on the number
pad, hit `SPACE`, enter song name (e.g., `wilsons's`), hit `j` for `LIED SPIELEN?`, use 50 for playback speed, etc. Enjoy! 


## Background & Purpose  

Having a keen interest in the history of computer music and music
composition software, I am researching what officially counts as the
**world's first tablature composer software.** 

Currently, the [Wikipedia page
https://en.wikipedia.org/wiki/Tablature_editor](https://en.wikipedia.org/wiki/Tablature_editor)
still lists "Tab Composer CPC" as the first such program (created in
1986), but the purpose of this Github repo and Wikipedia page entry is
to have a correct historical account - **so if you should know of any
earlier Tablature programs that fit the bill, please let me know, so
that the Wikipedia page can be corrected!**

This GitHub repo exists to provide evidence for the [claims
on the Wikipedia page.](https://en.wikipedia.org/wiki/Tablature_editor)

![Wikipedia Page 2026-05-04 with Tab Comp CPC Entry](pics/wikipedia-2026-05-04.png)

## Tab Composer CPC ("Tabulations Composer")

So here is my contender for "The World's First" such program -
"Tabulations Composer", written in 1986 on my [Amstrad CPC
464](https://en.wikipedia.org/wiki/Amstrad_CPC_464) in [Locomotive
BASIC 1.0](https://en.wikipedia.org/wiki/Locomotive_BASIC).  I
mainly wrote it to help me practice for my guitar lessons.

![Tab Composer CPC](pics/tab-composer.png)

The [YT video](https://youtu.be/F6k4eq10DJg) demonstrates how to enter
a piece of music in tablature notation using the WYSIWYG graphical
editor, and also [music playback.](https://youtu.be/F6k4eq10DJg?t=537)
Playback uses the CPC's 3-voice polyphonic [GI AY-3-8912 sound
chip](https://en.wikipedia.org/wiki/General_Instrument_AY-3-8910),
which was ubiquitous and quite capable for the time.

Here you can find [the Locomotive BASIC program
sources](src/tabcomp.txt), as well as [a DSK image](cpc/tabcomp.dsk)
that you can run in [a CPC Emulator.](http://www.winape.net/)

I used this program myself to create the music for my BASIC games back
in the day, e.g., the [6 highly polyphonic songs in
"MANIC".](https://youtu.be/_FTJe2Av1iw)

### Development & Historical Context

I started the project in spring 1986 and didn't own a disc drive yet,
so first versions of this rather large BASIC program were developed on
a purley cassette-based CPC system. This definitely required a lot of
patience.

I worked on this program for months, and transcribed [dozens of songs
from my guitar tab](https://youtu.be/_FTJe2Av1iw) book with it.

In May 2026, I have restored many of the **old songs** I made with Tab Composer CPC back in ~1986 from 40 year old cassette tapes! Check out [the YouTube video for the details.](https://youtu.be/yU8MmQVJ87o) As a results of these efforts, there is now a [DSK image for CPC emulators with the restored songs and an included special version of Tab Composer CPC (`tabcompx.bas`)](cpc/SONGS-TCX.dsk) that can play load these older songs doing some data conversion. 

Guitar tablature creator software became available much later on the
PC AFAIK, and I had no inspiration for this program. I might have seen
[Chris Hülsbeck's 1986 "Sound Monitor
1.0"](https://www.c64-wiki.de/wiki/Soundmonitor) on the C64, which is
considered the first Sound Tracker program, but no Sound Tracker or
something remotely similar was available on the CPC at that time.

There were [other CPC music composition
programs](http://tacgr.emuunlim.com/interviews/daverogers.html)
available though (e.g., "The Music System" by Rainbird), some as early
as 1985 when the CPC 464 was released. However, these used standard
sheet music notation, not Tablature, and don't count as Sound Trackers
either.

### Publication Attempts 

It never got published - I made two attempts by sending it to the
editors of ["Happy
Computer"](https://archive.org/details/happycomputer-magazine), and
then to the [DMV Verlag](https://www.cpcwiki.eu/index.php/DMV), which
was the publisher of the premier CPC magazine in Germany back in the
day, ["Schneider CPC
International"](https://archive.org/search?query=subject%3A%22Schneider%2FAmstrad+CPC%2FPC+International%22). It
was rejected twice due to high complexity, poor documentation, and
being of interest to a limited readership / audience only. My publishing 
attempts probably started in September 1986,
and the latest letter of rejection arrived in February 1987 (from
DMV). [Here is the evidence.](evidence/dmv-letter-1.jpg)


[The documentation](evidence/) I wrote back in the day was a mess - I
didn't own a printer yet, and my handwriting was poor, so from that
point of view it is not surprising that the program got rejected.

I [succeeded in selling / publishing other type-in programs for both
the CPC and later the Amiga
though](https://www.michael-wessel.info/anniversary.html) and
eventually made enough money so that I could afford the CPC disk drive
as well as an Amiga 500 with 1084 monitor back in the day.

### Reflections 

Even 40 years later, this is still a usable piece of software, and you
can see that entering a piece of Tab music doesn't take long! With a
bit of practice, as you can see in [the
video,](https://youtu.be/F6k4eq10DJg) it only takes about 5 minutes
for the first part of the demonstrated Bach Minuet. 

I definitely paid some attention to usability aspects as well and went
through a number of iterations - you can see how different and primitive the
very first version [`tabcomp0.bas`](cpc/TABCOMP0.dsk) looks compared to the final 
"product" [`tabcomp.bas`](cpc/tabcomp.dsk), and
the intermediate version [`tabcomp1.bas`](cpc/SONGS-TCX.dsk) that did not 
allow to continue editing of the tablature after loading it back from tape. 

Correcting false notes is not very
convenient - the idea was that "content" should be protected 
from accidental deletions. A single left arrow key hence only deletes
the note immediately left to it, and does not go back further,
potentially deleting more stuff by accident (there was no
UNDO). Hence, the special "correction string" at the top was used to
manoeuvre the cursor back / to the left.  Definitely not very
convenient - I'd implement that differently today. However, note
correction is rarely needed anyway.

### The Evidence

My letter including the hand-written program documentation to, and
response from, the ["DMV
Verlag"](https://www.cpcwiki.eu/index.php/DMV) is presented in [the
`evidence/` folder.](evidence/)

The handwriting is now transcribed and translated in
[`evidence/TRANSCRIPTION.md`](evidence/TRANSCRIPTION.md), German first and
English after, so the documentation can be read without deciphering 1987
handwriting. Two things in it are worth pointing out:

- **DMV's reply is dated 16 February 1987** and is signed by the editor in
  chief of *Schneider CPC International* - a dated, third party record that the
  program existed and had been submitted by then.
- My covering letter offers them "die **überarbeitete** Version des
  Tabulations-Composers" - the *revised* version, so an earlier one already
  existed - and is signed "Michael Wessel, Schüler, 16 J."

The key list and the variable list in those pages match the program's own help
page and variable declarations, which is a further check that the letters and
the surviving code are the same program.

### An Independent Check of the "First Tablature Composer" Claim

Since this repository exists to support a claim on Wikipedia, I asked
[Claude](https://claude.com/claude-code) (Anthropic) to look for evidence
**against** it as well as for it, and to give its own verdict. The method is
written out below so that anyone can repeat it.

**What was searched.**

- The **complete archived run of *Schneider CPC International***, the magazine
  this program was submitted to: twenty monthly issues from March 1985 to
  October 1986 plus two Sonderhefte, downloaded from the Internet Archive and
  searched in full text.
- The release dates of the tablature editors that are usually named as the
  early ones.
- Guitar and music software for other home computers of the period, and
  academic work on computer tablature.
- The provenance of the sources that currently repeat the claim.

**What was found.**

- In those twenty months of *Schneider CPC International*, the word "Gitarre"
  **does not occur once**, in any spelling, and neither does "Tabulatur". The
  only near misses are "Tabulator", meaning a tab stop in a word processor, and
  two mentions of "Musiknoten", one of them a game. The OCR is sound: "Musik",
  "Programm", "Listing" and "Sound" all appear in all twenty-two issues. Guitar
  was simply not a subject in that magazine.
- Every tablature editor with a documented date is later, and not by a little:
  Wayne Cripps' lute `tab` is copyright **1991**, TablEdit's own release history
  gives **1997** for its first version, Guitar Pro is **1997**.
- Guitar software of the mid eighties on other machines was tuners and chord
  dictionaries - type in a chord name, see it on a fretboard - rather than
  anything you could compose with. Tablature shared on bulletin boards was
  plain text, not software.
- One genuine rival exists: a project at the University of Ottawa on the
  automated translation of 16th century lute tablatures, running **1985 to
  1990**, which built "a special tablature editor" for German, French and
  Italian lute tablature. It is a data entry tool feeding a transcription
  pipeline - no composition, no playback - and it is not dated more precisely
  than that five year window.
- **The online agreement is circular.** Every source that currently states
  "the first tablature program was written for the Amstrad CPC 464 in 1986"
  traces back to the Wikipedia entry this repository supports. It should not be
  cited as independent corroboration, and is not treated as such here.

**The verdict, as calibrated as it can honestly be.**

- **"The first tablature *composer*"** - a program for writing tablature
  interactively, with playback - **survives a deliberate attempt to refute it.**
  Nothing earlier was found, and nothing close.
- **"The first tablature *editor*"**, read broadly, is the weaker claim. The
  Ottawa lute editor may well be contemporaneous, and an editor for entering
  historical tablature is an editor. The narrower wording is the defensible one.
- This is **unrefuted, not independently corroborated**. Magazine type-in
  listings from 1983 to 1986 are badly indexed and largely invisible to
  searching, and that is exactly where a rival would hide. A single dated
  listing in some 1985 magazine would settle it the other way.

The strongest evidence remains the correspondence in
[`evidence/`](evidence/), [transcribed and translated
here](evidence/TRANSCRIPTION.md): a letter from the editor in chief of
*Schneider CPC International* **dated 16 February 1987**, replying to a
submission whose covering letter offers the *revised* version of the program.
That does not prove "first" - nothing can - but it does date the program
through a third party, which is what the claim needs most.

### Reading the Programs on the Disk Images

The BASIC programs on the disk images are stored tokenised, which is how
Locomotive BASIC saves unless you ask for `,A`. [`tools/debas.py`](tools/)
turns them back into a listing, so you can read them without a CPC or an
emulator:

```sh
iDSK cpc/SONGS-TCX.dsk -g TABCOMP1.BAS
python3 tools/debas.py TABCOMP1.BAS
```

It handles the AMSDOS header, string literals with embedded control codes
(the listings are full of `CHR$(24)` for inverse video), `|RSX` commands,
and the variable type suffixes, which are implied by `DEFINT a-y` rather
than stored. It was checked by detokenising `TAB-COMP.BAS` and comparing
it against [`src/tabcomp.txt`](src/tabcomp.txt), the listing transcribed
from the original: all 444 lines come back identical.

The listings it produces are in [`src/`](src/), so the programs can simply
be read here:

| Listing | Program |
| --- | --- |
| [`src/tabcomp0.txt`](src/tabcomp0.txt) | the 1986 prototype, Version 0 - one array per string (`e`, `a`, `d`, `g`, `h`, `he`) |
| [`src/tabcomp1.txt`](src/tabcomp1.txt) | the first real version, which stored the AY sound period per note and so could not be edited again after saving |
| [`src/tabcomp.txt`](src/tabcomp.txt) | the finished version: notes are stored as the tablature position itself, which is what made round trip editing work |
| [`src/tabcompx.txt`](src/tabcompx.txt) | the same, plus the routine that converts the old period based songs into the new format |
