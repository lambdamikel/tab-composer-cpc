# Screen geometry of Tab Composer CPC, as the BASIC draws it

Derived from src/tabcomp.txt lines 590-770 (grid) and 3100-3240 (notes).

MODE 2, 80x25 text, 640x200 pixels. Graphics coordinates are 640x400, so two
graphics units per scanline, and one text row is 16 graphics units tall.

    INK 0,0 : BORDER 0 : INK 1,0      draw everything invisibly...
    ...draw grid...
    INK 1,24                          ...then reveal it

## The grid

    bar lines   MOVE i,330 : DRAW i,250     for i = 16 to 534 step 16
                every 8th line doubled (i+1) - a bar separator every 8 steps
    strings     MOVE 16,i : DRAW 528,i      for i = 330 down to 250 step -16

y = 330,314,298,282,266,250 are the six strings. Each falls in the middle of a
text row: (400-y)/2/8 gives rows 5,6,7,8,9,10 (1-based), high E first.

x = 16 steps of 16 pixels = 2 text columns, so step n sits at text column
2n+1 starting at column 3, and the visible sheet is 32 steps, columns 3..65.

## Rows

    2       repeat markers, HEX$(n+1)
    3       window #3, the message/prompt line
    5-10    the six strings: fret as HEX$(fret), so 10,11,12 show as A,B,C
            a rest is CHR$(206)
    11-13   channel occupancy for voices 1,2,3: string number, then "AA"/"BB"/"CC"
            in inverse video for as long as the channel stays busy
    14-25   window #4, the information panel
    15-23   the labelled fields: free channels, note position, channel number,
            screen position, position in bar

## Note encoding on screen

A note is stored as the decimal digits of its tablature position: first digit
the string, the rest the fret. 35 is string 3 fret 5, 212 is string 2 fret 12.
99 means empty, 88 a rest. The program reads them back with
MID$(STR$(n),2,1) for the string and MID$(STR$(n),3,2) for the fret.
