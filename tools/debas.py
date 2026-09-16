"""Detokenise Locomotive BASIC (CPC), with or without an AMSDOS header.

Validated by round-tripping TAB-COMP.BAS against the ASCII listing that
ships beside it in the tab-composer-cpc repo.
"""
import sys
sys.stdout.reconfigure(encoding="latin-1", errors="replace")

T = {
0x80:"AFTER",0x81:"AUTO",0x82:"BORDER",0x83:"CALL",0x84:"CAT",0x85:"CHAIN",
0x86:"CLEAR",0x87:"CLG",0x88:"CLOSEIN",0x89:"CLOSEOUT",0x8A:"CLS",0x8B:"CONT",
0x8C:"DATA",0x8D:"DEF",0x8E:"DEFINT",0x8F:"DEFREAL",0x90:"DEFSTR",0x91:"DEG",
0x92:"DELETE",0x93:"DIM",0x94:"DRAW",0x95:"DRAWR",0x96:"EDIT",0x97:"ELSE",
0x98:"END",0x99:"ENT",0x9A:"ENV",0x9B:"ERASE",0x9C:"ERROR",0x9D:"EVERY",
0x9E:"FOR",0x9F:"GOSUB",0xA0:"GOTO",0xA1:"IF",0xA2:"INK",0xA3:"INPUT",
0xA4:"KEY",0xA5:"LET",0xA6:"LINE",0xA7:"LIST",0xA8:"LOAD",0xA9:"LOCATE",
0xAA:"MEMORY",0xAB:"MERGE",0xAC:"MID$",0xAD:"MODE",0xAE:"MOVE",0xAF:"MOVER",
0xB0:"NEXT",0xB1:"NEW",0xB2:"ON",0xB3:"ON BREAK",0xB4:"ON ERROR GOTO",0xB5:"ON SQ",
0xB6:"OPENIN",0xB7:"OPENOUT",0xB8:"ORIGIN",0xB9:"OUT",0xBA:"PAPER",0xBB:"PEN",
0xBC:"PLOT",0xBD:"PLOTR",0xBE:"POKE",0xBF:"PRINT",0xC0:"'",0xC1:"RAD",
0xC2:"RANDOMIZE",0xC3:"READ",0xC4:"RELEASE",0xC5:"REM",0xC6:"RENUM",0xC7:"RESTORE",
0xC8:"RESUME",0xC9:"RETURN",0xCA:"RUN",0xCB:"SAVE",0xCC:"SOUND",0xCD:"SPEED",
0xCE:"STOP",0xCF:"SYMBOL",0xD0:"TAG",0xD1:"TAGOFF",0xD2:"TROFF",0xD3:"TRON",
0xD4:"WAIT",0xD5:"WEND",0xD6:"WHILE",0xD7:"WIDTH",0xD8:"WINDOW",0xD9:"WRITE",
0xDA:"ZONE",0xDB:"DI",0xDC:"EI",0xDD:"FILL",0xDE:"GRAPHICS",0xDF:"MASK",
0xE0:"FRAME",0xE1:"CURSOR",0xE3:"ERL",0xE4:"FN",0xE5:"SPC",0xE6:"STEP",
0xE7:"SWAP",0xEA:"TAB",0xEB:"THEN",0xEC:"TO",0xED:"USING",0xEE:">",0xEF:"=",
0xF0:">=",0xF1:"<",0xF2:"<>",0xF3:"<=",0xF4:"+",0xF5:"-",0xF6:"*",0xF7:"/",
0xF8:"^",0xF9:"\\",0xFA:"AND",0xFB:"MOD",0xFC:"OR",0xFD:"XOR",0xFE:"NOT",
}
X = {
0x00:"ABS",0x01:"ASC",0x02:"ATN",0x03:"CHR$",0x04:"CINT",0x05:"COS",0x06:"CREAL",
0x07:"EXP",0x08:"FIX",0x09:"FRE",0x0A:"INKEY",0x0B:"INP",0x0C:"INT",0x0D:"JOY",
0x0E:"LEN",0x0F:"LOG",0x10:"LOG10",0x11:"LOWER$",0x12:"PEEK",0x13:"REMAIN",
0x14:"SGN",0x15:"SIN",0x16:"SPACE$",0x17:"SQ",0x18:"SQR",0x19:"STR$",0x1A:"TAN",
0x1B:"UNT",0x1C:"UPPER$",0x1D:"VAL",
0x40:"EOF",0x41:"ERR",0x42:"HIMEM",0x43:"INKEY$",0x44:"PI",0x45:"RND",0x46:"TIME",
0x47:"XPOS",0x48:"YPOS",0x49:"DERR",
0x71:"BIN$",0x72:"DEC$",0x73:"HEX$",0x74:"INSTR",0x75:"LEFT$",0x76:"MAX",
0x77:"MIN",0x78:"POS",0x79:"RIGHT$",0x7A:"ROUND",0x7B:"STRING$",0x7C:"TEST",
0x7D:"TESTR",0x7E:"COPYCHR$",0x7F:"VPOS",
}

def fp40(b):
    m = b[0] | b[1]<<8 | b[2]<<16 | (b[3]&0x7f)<<24
    e = b[4]
    if e == 0: return "0"
    v = (m | 0x80000000) / 2**32 * 2**(e-128)
    if b[3] & 0x80: v = -v
    s = repr(round(v, 9))
    return s[:-2] if s.endswith(".0") else s

SUFFIX = {0x02:"%", 0x03:"$", 0x04:"!", 0x0B:"", 0x0C:"", 0x0D:""}

def detok(data):
    if len(data) > 128 and (sum(data[:67]) & 0xffff) == (data[67] | data[68]<<8):
        data = data[128:]          # AMSDOS header, verified by its checksum
    out=[]; i=0
    while i+3 < len(data):
        ln = data[i] | data[i+1]<<8
        if ln == 0: break
        num = data[i+2] | data[i+3]<<8
        j = i+4; end = i+ln-1
        s = "%d " % num
        instr = False              # inside a "..." literal
        literal = False            # after REM / \' / DATA: raw to end of statement
        while j < end:
            c = data[j]
            if instr:
                s += chr(c); j += 1
                if c == 0x22: instr = False
                continue
            if literal:
                if c == 0x01: literal = False; continue   # ':' ends a DATA item list
                s += chr(c); j += 1
                continue
            if c == 0x00: break
            elif c == 0x22: s += '"'; instr = True; j += 1
            elif c == 0x7C:                      # |RSX - one filler byte, then the name
                j += 2; nm = ""
                while j < end:
                    ch = data[j]; j += 1
                    nm += chr(ch & 0x7f)
                    if ch & 0x80: break
                s += "|" + nm
            elif c == 0x01:
                if j+1 < end and data[j+1] in (0xC0, 0x97): pass
                else: s += ":"
                j += 1
            elif c in SUFFIX:
                t = c; j += 3                    # type byte + 2 byte runtime pointer
                nm = ""
                while j < end:
                    ch = data[j]; j += 1
                    nm += chr(ch & 0x7f)
                    if ch & 0x80: break
                s += nm + SUFFIX[t]
            elif 0x0E <= c <= 0x18: s += str(c-0x0E); j += 1
            elif c == 0x19: s += str(data[j+1]); j += 2
            elif c == 0x1A: s += str(data[j+1] | data[j+2]<<8); j += 3
            elif c == 0x1B: s += "&X" + format(data[j+1] | data[j+2]<<8, "b"); j += 3
            elif c == 0x1C: s += "&" + format(data[j+1] | data[j+2]<<8, "X"); j += 3
            elif c in (0x1D,0x1E): s += str(data[j+1] | data[j+2]<<8); j += 3
            elif c == 0x1F: s += fp40(data[j+1:j+6]); j += 6
            elif 0x20 <= c <= 0x7F: s += chr(c); j += 1
            elif c == 0xFF:
                s += X.get(data[j+1], "{X%02X}" % data[j+1]); j += 2
            else:
                kw = T.get(c, "{%02X}" % c)
                s += kw; j += 1
                if c in (0xC0, 0xC5, 0x8C): literal = True    # \' REM DATA
        out.append(s)
        i += ln
    return out

if __name__ == "__main__":
    for l in detok(open(sys.argv[1],'rb').read()): print(l)
