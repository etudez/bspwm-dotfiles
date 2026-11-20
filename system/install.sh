#!/usr/bin/env bash
# Install the system-wide performance mode.
#
#   sudo ./system/install.sh
#
# Installs:
#   /usr/local/bin/performance
#   /etc/sysctl.d/99-performance.conf
#   /etc/modprobe.d/rtw88.conf
#   /etc/udev/rules.d/80-wifi-powersave.rules
#   /usr/libexec/dhcpcd-hooks/99-wifi-powersave
#   /etc/rc.local hook (Void/runit) or a systemd unit
#
# and applies the settings immediately.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "run as root: sudo $0" >&2
    exit 1
fi

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

backup() {
    [ -e "$1" ] || return 0
    local b="$1.bak.$(date +%Y%m%d-%H%M%S)"
    cp -a "$1" "$b"
    echo "backup: $b"
}

install -Dm755 "$REPO/bin/performance" /usr/local/bin/performance

backup /etc/sysctl.d/99-performance.conf
install -Dm644 "$REPO/system/sysctl.d/99-performance.conf" \
    /etc/sysctl.d/99-performance.conf

backup /etc/modprobe.d/rtw88.conf
install -Dm644 "$REPO/system/modprobe.d/rtw88.conf" \
    /etc/modprobe.d/rtw88.conf

if [ -d /usr/libexec/dhcpcd-hooks ]; then
    backup /usr/libexec/dhcpcd-hooks/99-wifi-powersave
    install -Dm755 "$REPO/system/dhcpcd-hooks/99-wifi-powersave" \
        /usr/libexec/dhcpcd-hooks/99-wifi-powersave
fi

if [ -d /etc/udev/rules.d ]; then
    backup /etc/udev/rules.d/80-wifi-powersave.rules
    install -Dm644 "$REPO/system/udev/rules.d/80-wifi-powersave.rules" \
        /etc/udev/rules.d/80-wifi-powersave.rules
    udevadm control --reload-rules 2>/dev/null || true
    udevadm trigger --subsystem-match=net 2>/dev/null || true
fi

# Void uses runit and executes /etc/rc.local from /etc/runit/2.
if [ -f /etc/runit/2 ] && [ -f /etc/rc.local ]; then
    if ! grep -q 'performance apply' /etc/rc.local; then
        backup /etc/rc.local
        {
            echo ""
            echo "# --- performance mode ---"
            echo '[ -x /usr/local/bin/performance ] && /usr/local/bin/performance apply'
        } >> /etc/rc.local
        echo "runit: added /etc/rc.local hook"
    fi
fi

# systemd distributions.
if command -v systemctl >/dev/null 2>&1; then
    backup /etc/systemd/system/performance.service
    install -Dm644 "$REPO/system/systemd/performance.service" \
        /etc/systemd/system/performance.service
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable performance.service 2>/dev/null || true
fi

/usr/local/bin/performance apply || true

echo
echo "status:"
/usr/local/bin/performance status
echo
echo "Deep Wi-Fi power save (disable_lps_deep) activates after the next reboot."
