#!/usr/bin/env bash
# doctor.sh — check that the desktop has everything it needs.

set -u

DOTFILES=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
issues=0
warnings=0

if [ -t 1 ]; then
    BOLD=$'\033[1m'; DIM=$'\033[2m'; OK=$'\033[32m'
    WARN=$'\033[33m'; ERR=$'\033[31m'; OFF=$'\033[0m'
else
    BOLD=""; DIM=""; OK=""; WARN=""; ERR=""; OFF=""
fi

ok()   { printf '%s  ✓  %s%s\n' "$OK" "$*" "$OFF"; }
bad()  { printf '%s  ✗  %s%s\n' "$ERR" "$*" "$OFF"; issues=$((issues + 1)); }
note() { printf '%s  !  %s%s\n' "$WARN" "$*" "$OFF"; warnings=$((warnings + 1)); }
dim()  { printf '%s     %s%s\n' "$DIM" "$*" "$OFF"; }

section() { printf '\n%s%s%s\n' "$BOLD" "$*" "$OFF"; }

section "Session"
if [ -f /etc/polkit-1/rules.d/49-desktop-power.rules ]; then
    ok "polkit power rule installed"
else
    note "polkit power rule is missing (power menu may fail)"
    dim "install: sudo ./system/polkit/install.sh"
fi
if [ -n "${DISPLAY:-}" ]; then ok "DISPLAY=$DISPLAY"; else note "not inside an X session"; fi
if [ -n "${DISPLAY:-}" ] && command -v xset >/dev/null 2>&1; then
    if xset q 2>/dev/null | grep -q 'DPMS is Disabled'; then
        ok "screen blanking/DPMS disabled"
    else
        note "DPMS is enabled — the screen may blank when idle"
        dim "run: ~/.local/bin/no-blank"
    fi
fi
for p in bspwm sxhkd picom dunst polybar; do
    if pgrep -x "$p" >/dev/null 2>&1; then
        ok "$p is running"
    else
        note "$p is not running (start it: bspc wm -r)"
    fi
done
if command -v snixembed >/dev/null 2>&1; then
    ok "snixembed (SNI tray)"
else
    note "snixembed is missing — Discord/qBittorrent tray icons stay hidden"
    dim "install: sudo xbps-install -S snixembed"
fi

section "Commands"
check_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        ok "$1"
    else
        bad "$1 is missing"
        [ -n "${2:-}" ] && dim "install: $2"
    fi
}
check_cmd bspwm        "packages/void.txt"
check_cmd sxhkd        "packages/void.txt"
check_cmd picom        "packages/void.txt"
check_cmd rofi         "packages/void.txt"
check_cmd dunst        "packages/void.txt"
check_cmd kitty        "packages/void.txt"
check_cmd feh          "packages/void.txt"
check_cmd maim         "packages/void.txt"
check_cmd slop         "packages/void.txt"
check_cmd xclip        "packages/void.txt"
check_cmd brightnessctl "packages/void.txt"
check_cmd i3lock       "packages/void.txt"
check_cmd xss-lock     "packages/void.txt"
check_cmd setxkbmap    "packages/void.txt"
check_cmd xrdb         "packages/void.txt"
check_cmd polybar      "packages/void.txt"
if command -v xrandr >/dev/null 2>&1 || [ -x "$HOME/.local/bin/xrandr" ]; then
    ok "xrandr (display refresh)"
else
    note "xrandr is missing — 144 Hz will not persist across sessions"
    dim "install: xrandr"
fi
if command -v matugen >/dev/null 2>&1; then
    ok "matugen ($(matugen --version 2>/dev/null | head -n1))"
elif [ -x "$HOME/.local/bin/matugen" ]; then
    ok "matugen ($("$HOME/.local/bin/matugen" --version 2>/dev/null | head -n1))"
else
    bad "matugen is missing"
    dim "install: packages/void.txt (or ~/.local/bin/matugen)"
fi

section "File manager"
if command -v thunar >/dev/null 2>&1; then
    ok "Thunar (Super+E, dashboard → Файлы)"
else
    note "Thunar is not installed (Super+E will not work)"
    dim "install: packages/void.txt (thunar, gvfs, udisks2, polkit-gnome)"
fi
if [ -d "$HOME/.icons/Bibata-Modern-Classic" ]; then
    ok "Bibata-Modern-Classic cursor"
else
    note "Bibata cursor theme is missing"
    dim "run: ./install.sh (or install bibata cursor manually)"
fi
if [ -d "$HOME/.local/share/icons/Papirus-Dark" ] ||
   [ -d /usr/share/icons/Papirus-Dark ]; then
    ok "Papirus-Dark icons"
else
    note "Papirus-Dark icons are missing"
    dim "install: papirus-icon-theme"
fi
if [ -x "$HOME/.local/bin/open-terminal" ]; then
    ok "Thunar → Open Terminal Here"
else
    note "Thunar terminal action is missing (bin/open-terminal)"
fi

section "Audio"
if command -v pipewire >/dev/null 2>&1; then
    for p in pipewire wireplumber pipewire-pulse; do
        if pgrep -x "$p" >/dev/null 2>&1; then
            ok "$p is running"
        else
            note "$p is not running"
            dim "start: ~/.local/bin/pipewire-start (or: pkill -x sxhkd; bspc wm -r)"
        fi
    done
else
    note "PipeWire is not installed (ALSA mode)"
    dim "install: sudo ./system/audio/pipewire-install.sh"
fi


section "AmneziaVPN"
if [ -x /opt/AmneziaVPN/bin/AmneziaVPN-service ]; then
    if pgrep -f '^/opt/AmneziaVPN/bin/AmneziaVPN-service' >/dev/null 2>&1 &&
       [ -S /var/run/amneziavpn/daemon.socket ]; then
        ok "amneziavpn service is running"
    else
        note "AmneziaVPN service is not running"
        dim "install: sudo ./system/amnezia/install.sh"
    fi
else
    note "AmneziaVPN is not installed"
fi

section "picom animations"
if command -v picom >/dev/null 2>&1; then
    ver=$(picom --version 2>/dev/null | head -n1)
    ok "picom $ver"
    support=0
    for f in /usr/share/man/man1/picom.1 /usr/local/share/man/man1/picom.1; do
        if [ -f "$f" ] && grep -qi 'ANIMATIONS' "$f"; then support=1; fi
    done
    for f in /usr/share/man/man1/picom.1.gz /usr/local/share/man/man1/picom.1.gz; do
        if [ -f "$f" ] && command -v zcat >/dev/null 2>&1 &&
           zcat "$f" 2>/dev/null | grep -qi 'ANIMATIONS'; then
            support=1
        fi
    done
    if [ "$support" = 0 ] && command -v man >/dev/null 2>&1 &&
       man picom 2>/dev/null | grep -qi 'ANIMATIONS'; then
        support=1
    fi
    if [ "$support" = 0 ] && picom --help 2>&1 | grep -qi 'animation'; then
        support=1
    fi
    if [ "$support" = 1 ]; then
        ok "animation framework available"
    else
        note "this picom looks too old for animations (need 12+)"
        dim "Debian bookworm: build picom from source or use testing/sid"
    fi
else
    bad "picom is missing"
fi

section "Fonts"
if command -v fc-list >/dev/null 2>&1; then
    fc-list : family 2>/dev/null | grep -qiF 'JetBrains Mono' &&
        ok "JetBrains Mono" || bad "JetBrains Mono is missing"
    fc-list : family 2>/dev/null | grep -qiF 'Roboto' &&
        ok "Roboto" || bad "Roboto is missing"
    if fc-list : family 2>/dev/null | grep -qiF 'Symbols Nerd Font'; then
        ok "Symbols Nerd Font (icons)"
    else
        note "Symbols Nerd Font is missing — icons will show as boxes"
    fi
else
    bad "fontconfig (fc-list) is missing"
fi

section "Generated files"
for f in \
    "$HOME/.config/bspwm/colors.sh" \
    "$HOME/.config/picom/picom.conf" \
    "$HOME/.config/kitty/colors.conf" \
    "$HOME/.config/rofi/colors.rasi" \
    "$HOME/.config/dunst/dunstrc" \
    "$HOME/.config/gtk-3.0/gtk.css" \
    "$HOME/.config/gtk-4.0/gtk.css" \
    "$HOME/.config/X11/xresources"
do
    if [ -s "$f" ]; then
        ok "${f#"$HOME"/}"
    else
        bad "${f#"$HOME"/} is missing — run: theme --no-reload"
    fi
done

if command -v gsettings >/dev/null 2>&1; then
    scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
    if [ "$scheme" = "prefer-dark" ]; then
        ok "GTK colour-scheme prefer-dark"
    else
        note "GTK colour-scheme is '${scheme:-unknown}' (GTK4/Flatpak may stay light)"
        dim "run: gsettings set org.gnome.desktop.interface color-scheme prefer-dark"
    fi
fi

section "Symlinks"
if [ -x "$HOME/.config/bspwm/bspwmrc" ]; then
    ok ".config/bspwm/bspwmrc is executable"
else
    bad ".config/bspwm/bspwmrc is not executable — bspwm will ignore it"
    dim "fix: chmod +x ~/.config/bspwm/bspwmrc"
fi
for f in \
    "$HOME/.config/bspwm/bspwmrc" \
    "$HOME/.config/sxhkd/sxhkdrc" \
    "$HOME/.config/kitty/kitty.conf" \
    "$HOME/.config/rofi/config.rasi" \
    "$HOME/.config/rofi/theme.rasi" \
    "$HOME/.config/rofi/state.rasi" \
    "$HOME/.config/rofi/help.rasi" \
    "$HOME/.config/rofi/sound.rasi" \
    "$HOME/.config/rofi/mic.rasi" \
    "$HOME/.xinitrc" \
    "$HOME/.bash_profile" \
    "$HOME/.local/bin/theme"
do
    if [ -L "$f" ]; then
        case $(readlink "$f") in
            "$DOTFILES"/*) ok "${f#"$HOME"/}" ;;
            *) note "${f#"$HOME"/} points elsewhere" ;;
        esac
    elif [ -e "$f" ]; then
        note "${f#"$HOME"/} is a regular file (run ./install.sh)"
    else
        bad "${f#"$HOME"/} is missing (run ./install.sh)"
    fi
done

section "Wallpaper"
if [ -f "$STATE_DIR/wallpaper" ]; then
    wall=$(cat "$STATE_DIR/wallpaper" 2>/dev/null || true)
    if [ -f "$wall" ]; then
        ok "$wall"
    else
        bad "wallpaper path is stale: $wall"
    fi
else
    note "no wallpaper recorded yet (run: theme)"
fi

printf '\n'
if [ "$issues" -eq 0 ] && [ "$warnings" -eq 0 ]; then
    printf '%s  all good%s\n\n' "$OK" "$OFF"
elif [ "$issues" -eq 0 ]; then
    printf '%s  ok, %d warning(s)%s\n\n' "$WARN" "$warnings" "$OFF"
else
    printf '%s  %d issue(s), %d warning(s)%s\n\n' "$ERR" "$issues" "$warnings" "$OFF"
fi

[ "$issues" -eq 0 ]
