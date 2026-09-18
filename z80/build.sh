#!/bin/bash
# Assemble TABCOMP and put it on a disc with a song to test against.
set -e
cd "$(dirname "$0")"
RASM=~/claude/midi80/toolchain/rasm/rasm
IDSK=~/claude/midi80/toolchain/idsk/iDSK
SONGS=~/claude/cpc/tab-composer-cpc/cpc/SONGS-TCX.dsk

if ! $RASM tabcomp.asm | sed 's/\x1b\[[0-9;]*m//g' | grep -q "Write binary file"; then
  echo "ASSEMBLY FAILED:"; $RASM tabcomp.asm 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | tail -5; exit 1
fi
rm -f tabcomp.dsk
$IDSK tabcomp.dsk -n >/dev/null 2>&1
$IDSK tabcomp.dsk -i TABCOMP.BIN -t 2 -f >/dev/null 2>&1
# a song from the 1986 tapes, to load and play later
rm -f BOUREE.MUS; $IDSK $SONGS -g "BOUREE.MUS" >/dev/null 2>&1 || true
[ -f BOUREE.MUS ] && $IDSK tabcomp.dsk -i BOUREE.MUS -t 0 -f >/dev/null 2>&1
$IDSK tabcomp.dsk -l
