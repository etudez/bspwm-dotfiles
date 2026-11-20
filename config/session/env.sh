# Shared X session environment. Sourced by ~/.xinitrc and bspwmrc.
#
# After a hard power-off a stale DBUS_SESSION_BUS_ADDRESS can survive in the
# environment (or in ~/.dbus/session-bus) while its socket is gone. In that case
# start a fresh session bus instead of letting dunst/polkit hang.

if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    export XDG_RUNTIME_DIR="$HOME/.run"
fi
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true

bus_ok() {
    case "${DBUS_SESSION_BUS_ADDRESS:-}" in
        unix:path=*)
            p=${DBUS_SESSION_BUS_ADDRESS#unix:path=}
            p=${p%%,*}
            [ -S "$p" ]
            ;;
        *) return 1 ;;
    esac
}

# Drop a stale address inherited from a previous X session.
if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] && ! bus_ok; then
    unset DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID
fi

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -d "$HOME/.dbus/session-bus" ]; then
    for f in "$HOME"/.dbus/session-bus/*; do
        [ -r "$f" ] || continue
        . "$f"
        break
    done
fi

if ! bus_ok && command -v dbus-launch >/dev/null 2>&1; then
    eval "$(dbus-launch --sh-syntax)"
    export DBUS_SESSION_BUS_ADDRESS
    [ -n "${DBUS_SESSION_BUS_PID:-}" ] && export DBUS_SESSION_BUS_PID
fi

export PIPEWIRE_RUNTIME_DIR="$XDG_RUNTIME_DIR"
export PULSE_SERVER="${PULSE_SERVER:-unix:$XDG_RUNTIME_DIR/pulse/native}"

# GTK3/GTK4: use the dark Adwaita variant. GTK4 has no separate Adwaita-dark
# theme, so the dark variant is selected with the ":dark" suffix.
export GTK_THEME="${GTK_THEME:-Adwaita:dark}"

# Flatpak applications in rofi/Thunar menus. fish does not read /etc/profile.d,
# so add the export directories here explicitly.
if [ -d "$HOME/.local/share/flatpak/exports/share" ] || [ -d /var/lib/flatpak/exports/share ]; then
    case ":${XDG_DATA_DIRS:-}:" in
        *":$HOME/.local/share/flatpak/exports/share:"*) ;;
        *)
            export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
            ;;
    esac
fi
