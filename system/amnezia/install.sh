#!/usr/bin/env bash
# Install AmneziaVPN's background service on a non-systemd system (Void/runit).
#
#   sudo ./system/amnezia/install.sh
#
# The GUI talks to /var/run/amneziavpn/daemon.socket; the .run installer only
# knows how to start it with systemctl, which does not exist on Void.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "run as root: sudo $0" >&2
    exit 1
fi

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SERVICE=/opt/AmneziaVPN/bin/AmneziaVPN-service

if [ ! -x "$SERVICE" ]; then
    echo "AmneziaVPN is not installed in /opt/AmneziaVPN" >&2
    exit 1
fi

if ! command -v resolvconf >/dev/null 2>&1; then
    echo "warning: resolvconf is missing; install openresolv for DNS inside the VPN"
fi

# systemd systems can use the unit shipped by Amnezia itself.
if command -v systemctl >/dev/null 2>&1; then
    install -Dm644 /opt/AmneziaVPN/AmneziaVPN.service \
        /etc/systemd/system/AmneziaVPN.service
    systemctl daemon-reload
    systemctl enable --now AmneziaVPN.service
    echo "systemd: AmneziaVPN.service enabled"
    exit 0
fi

# Void/runit.
if [ -d /etc/sv ] && command -v sv >/dev/null 2>&1; then
    install -Dm755 "$REPO/system/amnezia/run" /etc/sv/amneziavpn/run
    install -Dm755 "$REPO/system/amnezia/log-run" /etc/sv/amneziavpn/log/run
    mkdir -p /var/log/AmneziaVPN/service
    chmod 755 /var/log/AmneziaVPN/service

    ln -sfn /etc/sv/amneziavpn /var/service/amneziavpn

    # Drop sockets from a manual/user-level run so the GUI uses the root daemon.
    rm -f /tmp/amneziavpn.socket /tmp/local:AmneziaVpnIpcInterface

    # runsvdir notices the new symlink asynchronously; wait for supervise/
    # before calling sv, otherwise it fails with "file does not exist".
    i=0
    while [ ! -d /var/service/amneziavpn/supervise ] && [ "$i" -lt 20 ]; do
        sleep 0.25
        i=$((i + 1))
    done

    sv up amneziavpn 2>/dev/null || true
    sleep 1

    echo "runit: amneziavpn service started"
    sv status amneziavpn || true
    ls -l /var/run/amneziavpn 2>/dev/null || true
    echo "logs: /var/log/AmneziaVPN/service/current"
    exit 0
fi

echo "neither systemd nor runit was detected" >&2
exit 1
