#!/bin/bash
# Assemble CPC Tab Composer and put it on a disc with a song to test against.
#
# Tools: rasm (http://rasm.wikidot.com/) and iDSK
# (https://github.com/cpcsdk/idsk). Either put them on the PATH or point
# RASM and IDSK at them:
#
#     RASM=~/tools/rasm IDSK=~/tools/iDSK ./build.sh
set -e
cd "$(dirname "$0")"
RASM=${RASM:-$(command -v rasm || echo ~/claude/midi80/toolchain/rasm/rasm)}
IDSK=${IDSK:-$(command -v iDSK || echo ~/claude/midi80/toolchain/idsk/iDSK)}
SONGS=${SONGS:-../cpc/SONGS-TCX.dsk}

for t in "$RASM" "$IDSK"; do
  [ -x "$t" ] || { echo "not found: $t - see the comment at the top of this script"; exit 1; }
done

# rasm reports a failed assembly on stdout and still exits 0, so the build
# has to look for the line that says it wrote something
if ! "$RASM" tabcomp.asm | sed 's/\x1b\[[0-9;]*m//g' | grep -q "Write binary file"; then
  echo "ASSEMBLY FAILED:"; "$RASM" tabcomp.asm 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | tail -5; exit 1
fi

rm -f tabcomp.dsk
"$IDSK" tabcomp.dsk -n >/dev/null 2>&1
"$IDSK" tabcomp.dsk -i TABCOMP.BIN -t 2 -f >/dev/null 2>&1
# one song from the 1986 tapes, to load and play
rm -f BOUREE.MUS; "$IDSK" "$SONGS" -g "BOUREE.MUS" >/dev/null 2>&1 || true
[ -f BOUREE.MUS ] && "$IDSK" tabcomp.dsk -i BOUREE.MUS -t 0 -f >/dev/null 2>&1
"$IDSK" tabcomp.dsk -l
