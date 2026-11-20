#!/usr/bin/env bash
# Allow wheel users to power off/reboot/suspend without a password prompt.
#
#   sudo ./system/polkit/install.sh

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "run as root: sudo $0" >&2
    exit 1
fi

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
install -Dm644 "$REPO/system/polkit/49-desktop-power.rules" \
    /etc/polkit-1/rules.d/49-desktop-power.rules

# polkitd reloads its rules from disk; HUP is harmless if it is D-Bus activated.
pkill -HUP -x polkitd 2>/dev/null || true

echo "polkit: power actions allowed for the wheel group"
echo "test as your user: pkcheck --action-id org.freedesktop.login1.power-off --process \$\$"
