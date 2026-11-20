#!/usr/bin/env bash
# Install PipeWire + WirePlumber + pavucontrol and apply the ALSA fixes.
#
#   sudo ./system/audio/pipewire-install.sh
#
# Then restart sxhkd and bspwm so the new session environment is picked up:
#   pkill -x sxhkd; bspc wm -r

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "run as root: sudo $0" >&2
    exit 1
fi

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
PKGS_VOID="pipewire wireplumber alsa-pipewire pavucontrol"
PKGS_ARCH="pipewire pipewire-alsa pipewire-pulse wireplumber pavucontrol"
PKGS_DEB="pipewire pipewire-alsa pipewire-pulse wireplumber pavucontrol"
PKGS_FEDORA="pipewire pipewire-alsa pipewire-pulseaudio wireplumber pavucontrol"

if command -v xbps-install >/dev/null 2>&1; then
    xbps-install -Sy $PKGS_VOID
elif command -v pacman >/dev/null 2>&1; then
    pacman -S --needed --noconfirm $PKGS_ARCH
elif command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y $PKGS_DEB
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y $PKGS_FEDORA
else
    echo "unknown package manager; install PipeWire manually" >&2
    exit 1
fi

# HDA power saving and sane ALSA defaults; PipeWire will take over the streams.
if [ -x "$REPO/system/audio/install.sh" ]; then
    "$REPO/system/audio/install.sh" || true
fi

echo
echo "PipeWire installed. Now restart the session services:"
echo "  pkill -x sxhkd; bspc wm -r"
echo "Then restart Firefox/player windows so they connect to PipeWire."
echo "Mic settings: pavucontrol (Super+Shift+M)."
