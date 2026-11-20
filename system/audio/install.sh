#!/usr/bin/env bash
# Audio fixes: disable HDA power saving (clicks/pops) and set sane mic levels.
#
#   sudo ./system/audio/install.sh

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "run as root: sudo $0" >&2
    exit 1
fi

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
CARD=$(aplay -l 2>/dev/null | sed -n 's/^card \([0-9]*\):.*Analog.*/\1/p' | head -n1)
[ -n "$CARD" ] || CARD=0

install -Dm644 "$REPO/system/audio/snd-hda-power-save.conf" \
    /etc/modprobe.d/snd-hda-power-save.conf

for f in /sys/module/snd_hda_intel/parameters/power_save; do
    [ -w "$f" ] && echo 0 > "$f"
done
for f in /sys/module/snd_hda_intel/parameters/power_save_controller; do
    [ -w "$f" ] && echo N > "$f"
done

amixer -c "$CARD" sset Capture 60% cap >/dev/null 2>&1 || true
amixer -c "$CARD" sset Capture,1 60% cap >/dev/null 2>&1 || true
amixer -c "$CARD" sset 'Rear Mic Boost' 0 >/dev/null 2>&1 || true
amixer -c "$CARD" sset 'Front Mic Boost' 0 >/dev/null 2>&1 || true
amixer -c "$CARD" cset name='Input Source' 0 >/dev/null 2>&1 || true
amixer -c "$CARD" cset name='Loopback Mixing' 0 >/dev/null 2>&1 || true
amixer -c "$CARD" cset name='Auto-Mute Mode' 0 >/dev/null 2>&1 || true

# Keep the mixer across reboots on runit systems.
mkdir -p /var/lib/alsa
alsactl store >/dev/null 2>&1 || true
if [ -f /etc/rc.local ] && ! grep -q 'alsactl restore' /etc/rc.local; then
    {
        echo ""
        echo "# --- restore ALSA mixer ---"
        echo '[ -x /usr/sbin/alsactl ] && /usr/sbin/alsactl restore 2>/dev/null || true'
    } >> /etc/rc.local
    chmod 755 /etc/rc.local
fi

echo "audio: HDA power save disabled (runtime + modprobe)"
echo "audio: mixer saved; reboot recommended for the modprobe option"
echo "mic: Rear Mic, capture 60%, boost 0"
