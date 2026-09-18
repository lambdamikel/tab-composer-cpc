#!/bin/bash
# Is it audible? The only test that counts.
#
#   audible.sh <dsk> <basic-run-command> <lua-key-script-fragment> <pitch-hz>
#
# Records the emulator's own audio (muted at the driver so it never reaches
# the speakers) and compares Goertzel energy at the expected pitch during
# playback against the same pitch before it. Counting AY register writes
# does NOT prove audibility - the mixer can still have tone disabled.
set -e
cd "$(dirname "$0")"
DSK="$1"; RUNCMD="$2"; KEYS="$3"; PITCH="${4:-658}"
SECS="${SECS:-58}"
EXITF=$(( SECS * 50 - 100 ))

cat > /tmp/aud.lua <<EOF
NK=manager.machine.natkeyboard
ROW={}
for i=0,9 do ROW[i]=manager.machine.ioport.ports[":kbrow."..i] end
HOLD=nil; TICK=0
function tapk(row,name) HOLD=ROW[row].fields[name]; TICK=4; HOLD:set_value(1) end
Q={}; function at(f,fn) Q[f]=fn end
at(250, function() NK.in_use=true; NK:post_coded('$RUNCMD') end)
at(1300,function() NK.in_use=false end)
$KEYS
at($EXITF,function() manager.machine:exit() end)
F=0
SUB=emu.add_machine_frame_notifier(function()
  F=F+1
  if HOLD then TICK=TICK-1; if TICK<=0 then HOLD:set_value(0); HOLD=nil end end
  if Q[F] then Q[F]() end end)
EOF

rm -f /tmp/aud.wav
SDL_AUDIODRIVER=dummy env -u WAYLAND_DISPLAY GDK_BACKEND=x11 xvfb-run -a \
  mame -rompath ~/claude/cpc/mame-roms -video none \
  cpc6128 -flop1 "$DSK" -autoboot_delay 0 -autoboot_script /tmp/aud.lua \
  -seconds_to_run $SECS -wavwrite /tmp/aud.wav 2>&1 | grep -v Average || true

python3 - "$PITCH" <<'PY'
import wave, struct, math, sys
f0=float(sys.argv[1])
w=wave.open('/tmp/aud.wav'); n=w.getnframes(); sr=w.getframerate(); ch=w.getnchannels()
raw=w.readframes(n); s=struct.unpack('<%dh'%(len(raw)//2), raw)
if ch==2: s=s[0::2]
def energy(t,f,dur=0.25):
    a=int(t*sr); N=int(dur*sr); c=s[a:a+N]
    if len(c)<N: return 0.0
    w0=2*math.pi*f/sr; cw=2*math.cos(w0); s1=s2=0.0
    for i in range(0,N,2):
        s0=c[i]+cw*s1-s2; s2=s1; s1=s0
    return math.sqrt(max(0.0,s1*s1+s2*s2-cw*s1*s2))/(N/2)
# the note can happen anywhere after the program starts, so scan the lot
dur=n/sr
before=max(energy(t,f0) for t in (6,10,14,18))
best=0.0; besti=0.0
t=20.0
while t < dur-0.3:
    e=energy(t,f0)
    if e>best: best,besti=e,t
    t+=0.25
print("  %.1f Hz   quiet: %8.2f   loudest after 20s: %8.2f at %5.1fs   ratio %5.1fx   -> %s"
      % (f0, before, best, besti, best/max(before,0.01),
         "AUDIBLE" if best > before*3 and best > 1.0 else "SILENT"))
PY
