#!/bin/bash
# Build the three distribution discs - the program with the restored songs -
# as DSK images and as HFE images for a Gotek or HxC.
#
#     IDSK=... HXCFE=... ./dist.sh
#
# hxcfe is the HxC command line tool (https://hxc2001.com/). It is linked
# against libhxcfe.so, so LD_LIBRARY_PATH has to point at the directory the
# tool was built in.
set -e
cd "$(dirname "$0")"
./build.sh >/dev/null
IDSK=${IDSK:-$(command -v iDSK || echo ~/claude/midi80/toolchain/idsk/iDSK)}
HXCFE=${HXCFE:-$(command -v hxcfe || echo ~/claude/midi80/toolchain/hxc/build/hxcfe)}
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-$(dirname "$HXCFE")}
SONGS=${SONGS:-../cpc/SONGS-TCX.dsk}
OUT=../cpc; HFE=../hfe
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# the songs come out of the restored song disc, one at a time
for f in $("$IDSK" "$SONGS" -l 2>/dev/null | grep MUS | sed 's/\..*//;s/ *$//'); do
  (cd "$TMP" && "$IDSK" "$OLDPWD/$SONGS" -g "$f.MUS" >/dev/null 2>&1) || true
done
ls "$TMP" >/dev/null

disc () {           # disc <name> <songs...>
  local name=$1; shift
  rm -f "$OUT/$name.dsk"
  "$IDSK" "$OUT/$name.dsk" -n >/dev/null 2>&1
  "$IDSK" "$OUT/$name.dsk" -i TABCOMP.BIN -t 2 -f >/dev/null 2>&1
  for s in "$@"; do "$IDSK" "$OUT/$name.dsk" -i "$TMP/$s" -t 0 -f >/dev/null 2>&1; done
  "$HXCFE" -finput:"$OUT/$name.dsk" -foutput:"$HFE/$name.hfe" -conv:HXC_HFE >/dev/null 2>&1
  echo "$name: $("$IDSK" "$OUT/$name.dsk" -l 2>/dev/null | grep -c '\.') files, $(stat -c%s "$HFE/$name.hfe") byte HFE"
}

cd "$TMP" >/dev/null; ALL=$(ls *.MUS); cd - >/dev/null
disc tabcomp-all $ALL
disc tabcomp-1 BRIDGE.MUS BOUREE.MUS JESUS.MUS GRISE.MUS STREETS.MUS "WILSON'S.MUS" A-LEAVES.MUS BLUES.MUS ESTUDIO.MUS
disc tabcomp-2 MENUETT.MUS SCARBORO.MUS SPAGNOLE.MUS WHISKEY.MUS JENNIFER.MUS MISTRESS.MUS THE-PARL.MUS UNA-LAGR.MUS BOUREE-2.MUS
