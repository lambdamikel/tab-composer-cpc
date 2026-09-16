# The DMV Correspondence, Transcribed

The letters in this folder are the contemporaneous record of Tab Composer CPC:
a submission to the DMV publishing house, which published *Schneider CPC
International*, and their reply. They are the reason the 1986/87 dating of the
program is documented rather than merely remembered.

Everything below is transcribed from the images in this folder. German first,
English after. The original spelling and punctuation are kept, mistakes
included. A `[?]` marks a word I could not read with confidence.

The key list and the variable list could be checked against the program itself:
they match the help page at line 2860 and the variable declarations in
[`../src/tabcomp.txt`](../src/tabcomp.txt), which is how most of the ambiguous
handwriting was resolved.

**Which image is which page.** The pages are numbered in a circle at the top
right. Two of them were photographed twice:

| Image | Page |
| --- | --- |
| `dmv-letter-1.jpg` | DMV's typed reply, 16 February 1987 |
| `dmv-letter-2.jpg` | ① covering letter |
| `dmv-letter-3.jpg` | ② program, purpose, function keys |
| `dmv-letter-4.jpg` | ③ play mode and the live keys |
| `dmv-letter-5.jpg` | ③ again, second photograph |
| `dmv-letter-6.jpg` | ④ remaining keys |
| `dmv-letter-7.jpg` | ⑤ the editor |
| `dmv-letter-8.jpg` | ⑥ corrections, and the screen layout |
| `dmv-letter-9.jpg` | ⑦ variables, first part |
| `dmv-letter-10.jpg` | ⑥ again, second photograph |
| `dmv-letter-11.jpg` | ⑧ variables continued, and the cassette contents |

---

## DMV's reply — `dmv-letter-1.jpg`

Printed letterhead: **DMV · Zeitschriften · Bücher · Software**, DMV-Daten &
Medien Verlagsges. mbH, Fuldaer Str. 6, 3440 Eschwege. Magazine logos for
*Schneider CPC International* and *PASCAL International* appear at the right.
Reference `SR/S`, **Datum 16.02.87**.

> Herrn
> Michael Wessel
> Quadenweg 2g
> 2000 Hamburg 61
>
> Sehr geehrter herr Wessel,
>
> vielen Dank für die Übersendung Ihres Programmes.
>
> Leider haben wir z. Z. keine Verwendung dafür, so daß Sie Ihre Unterlagen als
> Anlage zurückerhalten. Wir haben jedoch Ihre Anschrift notiert und werden uns
> ggf. wieder mit Ihnen in Verbindung setzen.
>
> Wir hoffen, daß Sie auch weiterhin als Anbieter von selbsterstellten
> Programmen zur Verfügung stehen werden.
>
> Mit freundlichen Grüßen
>
> D M V - Daten & Medien Verlagsgesellschaft mbH
> *(signature)* Stefan Ritter
> Chefredakteur

**In English:**

> Dear Mr Wessel,
>
> Thank you for sending us your program.
>
> Unfortunately we have no use for it at present, so your documents are returned
> herewith. We have however noted your address and will contact you again should
> the occasion arise.
>
> We hope you will continue to be available as a supplier of self-written
> programs.

---

## ① Covering letter — `dmv-letter-2.jpg`

> Sehr geehrte Herren von der D.M.V., "Schneider CPC International"
>
> Ich sende Ihnen hiermit die überarbeitete Version des Tabulations-Composers.
> Ich bin mir bewußt, daß es sich bei dem obig genannten Programm um ein sehr
> spezielles handelt, da es von praktischem Nutzen nur für Leute mit
> "Gitarrenkenntnissen" ist. So würde ich empfehlen, jenes Programm nicht in der
> "CPC International", sondern in einem Sonderheft o. der "Goldenen Sieben" zu
> veröffentlichen, falls Sie interessiert sind. Anbei befindet sich ein
> Datenträger mit dem Programm und einigen "Demos" sowie eine ausführliche
> Beschreibung.
>
> Mit freundlichen Grüßen
> Michael Wessel, Schüler, 16 J.

**In English:**

> Dear Sirs at D.M.V., "Schneider CPC International",
>
> I am sending you herewith the **revised version** of the Tabulations-Composer.
> I am aware that the program named above is a very specialised one, since it is
> of practical use only to people with "guitar knowledge". I would therefore
> suggest publishing that program not in "CPC International" but in a special
> issue or in the "Goldene Sieben", if you are interested. Enclosed is a data
> carrier with the program and a few "demos", as well as a detailed description.
>
> Yours sincerely,
> Michael Wessel, schoolboy, aged 16

Note the word **überarbeitete** — *revised*. A version existed before this one.

---

## ② Program and function keys — `dmv-letter-3.jpg`

> Programm: Tabulation composer
> Zweck: Dreistimmiges Kompositionsprogramm für Gitarrenspieler im
> Tabulatursystem.
>
> **Beschreibung der Funktionen:**
>
> A = Abfrage der Wiederholungseingaben. Alle Taktwiederholungseingaben, welche
> unter \<T\> gemacht wurden, werden aufgelistet
> B = Flucht aus dem Hauptprogramm ins BASIC. Mit \<F0\> kann ein Warmstart des
> Programms erfolgen
> C = Cat-Befehl. Alle Dateien werden auf dem Bildschirm ausgegeben. Flucht mit
> \<ESC\>.
> D = Die Diskettenstation wird eingeschaltet.
> G = Bestimmt die Geschwindigkeit des Recorders (SpeedWrite 0/1).
> H = Hilfe
> K = Die Kassettenstation wird eingeschaltet
> L = Laden eines Musikstückes
> M = Manuelle Eingabe, auf welchen Kanal eine Note sitzen soll. Ein o. Aus

**In English:** Program: Tabulation composer. Purpose: a three-voice
composition program for guitar players, in the tablature system. Then the
function keys — repeat list, exit to BASIC (warm start with `F0`), catalogue,
disc drive on, tape speed, help, tape on, load a piece, and manual choice of
which channel a note is placed on, on or off.

---

## ③ Play mode — `dmv-letter-4.jpg` (and `dmv-letter-5.jpg`)

> N = Die Art der Note wird angegeben
> P = Play-Modus. Das Musikstück wird gespielt
>
> Während die Musik läuft haben Sie folgende Möglichkeiten:
>
> a = Env Kanal A + 1 (Standard = 5)
> b = " " B + 1 "
> c = " " C + 1 "
> A = Ent " A + 1 (Standart = 7)
> B = " " B + 1 "
> C = " " C + 1 "
> \<CTRL\> a = Rauschen A + 1 ⎫ (Standard = 0)
> " b = " B + 1 ⎬ Aufpassen bei Akkorden mit verschiedener
> " c = " C + 1 ⎭ Rauschfrequenz, da nur ein Rauschgenerator!
>
> \<SHIFT\> \[cursor left\] = Speed = Speed − 10
> " \[cursor right\] = Speed = Speed + 10
>
> 1 = Env Kanal A = 0
> 2 = " " B = 0
> 3 = " " C = 0

**In English:** `N` sets the note value; `P` plays the piece. While the music
runs, the lower-case letters raise the volume envelope on channels A, B and C,
the capitals raise the tone envelope, and CTRL plus a letter raises the noise
setting — *"be careful with chords using different noise frequencies, since
there is only one noise generator!"* SHIFT with the cursor keys changes the
speed in steps of ten, and 1, 2, 3 reset an envelope to zero.

---

## ④ Remaining keys — `dmv-letter-6.jpg`

> 4 = Ent Kanal A = 0
> 5 = " " B = 0
> 6 = " " C = 0
> 7 = Rauschen A = 0
> 8 = " B = 0
> 9 = " C = 0
> E = Ende des Musikstücks, es wird unterbrochen
> \<SPACE\> = Musikstück wird von vorne gespielt.
>
> S = Abspeichern der Musikdaten auf Kassette o. Diskette.
> T = Sie werden gefragt, ab welcher Stelle das Musikstück sich wiederholen soll
> (1−600). Maximal können 10 Wiederholungen eingegeben werden.
> \+ = Es wird ein Notenblatt weiter geblättert
> − = Es wird ein Notenblatt zurück geblättert

**In English:** Keys 4–9 reset the tone envelopes and noise; `E` ends the piece,
SPACE restarts it from the beginning. `S` saves to tape or disc. `T` asks from
which position the piece should repeat (1–600); at most ten repeats can be
entered. `+` and `−` page through the sheets.

---

## ⑤ The editor — `dmv-letter-7.jpg`

> **Beschreibung des Editors**
>
> Sie sehen die 6 Saiten der Gitarre. Mit den Cursortasten können sie
> herumfahren und an einer geeigneten Stelle mit \<COPY\> eine Note eingeben. Es
> erscheint eine "Null", sie können nun mit Cursor ⇧ und Cursor ⇩ den Bund
> bestimmen, in welchem die Gitarre gespielt werden soll. Als Bestätigung
> drücken Sie \<COPY\>, als Flucht \<Enter\>.
>
> Wenn sie nicht vorher die Manuelle Kanalübergabe gewählt haben, so errechnet
> der Computer den Kanal, auf welchem die Note sitzt, ansonsten werden Sie
> gefragt, auf welchem Kanal die Note sitzen soll. Sie können Pausen setzen,
> indem Sie — nachdem Sie das 1. x \<Copy\> betätigt haben — die \<SPACE\>-Taste
> drücken und dann eine Pause eingeben. Sie können auf dem ganzen Notenblatt
> umherfahren, entweder …

**In English:** You see the six strings of the guitar. With the cursor keys you
move around, and at a suitable place you enter a note with `COPY`. A "zero"
appears; you now choose the fret with cursor up and down. `COPY` confirms,
`ENTER` escapes. Unless you chose manual channel assignment beforehand, the
computer works out which channel the note sits on; otherwise it asks you. Rests
are entered by pressing SPACE after the first `COPY`.

---

## ⑥ Corrections, and the screen — `dmv-letter-8.jpg` (and `dmv-letter-10.jpg`)

> … \[auf\] der Korrektursaite, oder, indem sie \<SHIFT\> und ⇨ o. ⇦ drücken.
> ~~Vorwärts brauchen Sie nicht die Korrektursaite.~~
>
> **Korrektur**
>
> Wenn Sie eine Note löschen wollen, fahren Sie mit der Marke an die
> entsprechende Position und drücken ⇦. Schon ist die Note gelöscht.
>
> Beispiele: Bedeutet ⓪ ① ② ③ ④ … ⑩ ⑪ ⑫ Bund (E-Saite)
> ① = Wiederholungsnr. 1
>
> ```
>  E | 0  A  2  3  4   ...   A  B  C
>  A |
>  D |        [Pause]      0⇦ Eingabemarke
>  G |                      ⇦ = Korrektur
>  H |
> HE |
>      A A  A A A A A   - zeigt an, wie lange Kanal A BELEGT ist etc.
> ```

**In English:** To delete a note, move the marker to the position and press the
left arrow — the note is deleted. The diagram shows the six strings in German
naming (**H** is B, **HE** the high E), the fret numbers where 10, 11 and 12
appear as A, B and C, a rest, the input marker, and the row of `A`s underneath
showing how long channel A is occupied.

This page is where the **Korrektursaite** — the "correction string" — is
described: a seventh row used for editing, rather than editing in place.

---

## ⑦ Variables — `dmv-letter-9.jpg`

> array(6,12) = Notenwerte
> laenge(610,3) = ⎫
> note(610,3) = ⎬ Editordaten
> takta(11) = ⎫ Taktwiederholung von X
> taktb(11) = ⎬ zu X.
> i, ii = Zählschleifen
> wert = Editorwert
> art = Notenlaenge
> zeiger = Notenposition
> x = x f. Bildschirm
> y = y "
> controlle = Taktcontrolle
> c$ = Freie Kanäle
> kan$ = Freier Kanal
> cc$ = Besetzte Kanäle
> kan = Kanalnummer
> r = r=1 → Bildschirm neu
> a$, aa$ = Eingabe $
> ma = ma=1 → manuelle Kanalübergabe
> ge = Speed Write 1/0
> s = Saite der Gitarre aus Array
> fehler$ = Bei Fehlbedienung
> note = 0−12 = Bund der Gitarre
> p$ = Eingabe bei Pausen
> taktcount = Anzahl der Wiederholungseingaben
> w = "Speed" bei Play
> werta = bis zu welcher Stelle laden?
> ez = erste Zeile bei Basic-prg.
> za = Zeilenabstand " "
> z$ = Basiczeile
> n = Note aus Array

---

## ⑧ Variables continued, and the cassette — `dmv-letter-11.jpg`

> q = Pause o. nicht bei Basicprg.
> xa = Zähler für "x" bei Bildschirm-neu
> f = Pause o. nicht bei " "
> v = Vibrato
> ta$ = Eingabe $ bei Play
> ea = Env A
> eb = " B
> ec = " C
> ta = ENT A
> tb = " B
> tc = " C
> r = Rauschen A
> r1 = Rauschen B
> r2 = Rauschen C
> takt = taktcount bei Play
> blatt = Notenblatt
>
> **Ordnung auf der Kassette:**
>
> 1. Tabcomp 2
> 2. Andante.Mus (Demo) — Speed = 200, Vibrato = 1, INFO = Ja/Nein
> 3. The Sun.Mus (Demo) — Speed = 100, Vibrato = 0, INFO = Nein[?]
> 4. Andante.Bal (Basicdemo) \* Speed = 50
> 5. Bridge.Bal ( " ) \* Speed = 40
>
> \* Selbständige Basicprogramme, von Tabcomp erstellt. Mit "Run"X"" starten.

**In English:** the order of files on the cassette that was enclosed — the
program itself, two demo songs with their playback settings, and two
**stand-alone BASIC programs generated by Tab Composer**, started with
`RUN"X"`. That last line is the `.BAL` export feature described in the program
listing, in use.
