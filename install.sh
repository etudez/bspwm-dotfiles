#!/usr/bin/env bash
# install.sh — one-shot setup for the Material You bspwm dotfiles.
#
#   ./install.sh                 packages + fonts + configs + palette
#   ./install.sh --no-packages   configs only
#   ./install.sh --dry-run       print actions, change nothing
#   ./install.sh --uninstall     remove the symlinks this repo created
#
# Existing files are never lost: they are moved to
# ~/.local/state/dotfiles/backup-<timestamp>/ first.

set -euo pipefail

DOTFILES=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
BACKUP="$STATE_DIR/backup-$(date +%Y%m%d-%H%M%S)"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"

DRY_RUN=0
SKIP_PACKAGES=0
UNINSTALL=0

for arg in "$@"; do
    case $arg in
        --dry-run)     DRY_RUN=1 ;;
        --no-packages) SKIP_PACKAGES=1 ;;
        --uninstall)   UNINSTALL=1 ;;
        -h|--help)
            sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "install.sh: unknown option $arg (try --help)" >&2
            exit 2
            ;;
    esac
done

if [ -t 1 ]; then
    BOLD=$'\033[1m'; DIM=$'\033[2m'; OK=$'\033[32m'
    WARN=$'\033[33m'; ERR=$'\033[31m'; OFF=$'\033[0m'
else
    BOLD=""; DIM=""; OK=""; WARN=""; ERR=""; OFF=""
fi

say()  { printf '%s\n' "$*"; }
head2() { printf '\n%s==> %s%s\n' "$BOLD" "$*" "$OFF"; }
warn() { printf '%s  !  %s%s\n' "$WARN" "$*" "$OFF" >&2; }
die()  { printf '%s  x  %s%s\n' "$ERR" "$*" "$OFF" >&2; exit 1; }

run() {
    if [ "$DRY_RUN" = 1 ]; then
        printf '%s  +  %s%s\n' "$DIM" "$*" "$OFF"
    else
        "$@"
    fi
}

# --- uninstall ---------------------------------------------------------------
uninstall_links() {
    head2 "Removing symlinks that point into $DOTFILES"
    local link target removed=0
    while IFS= read -r link; do
        [ -L "$link" ] || continue
        target=$(readlink "$link")
        case $target in
            "$DOTFILES"/*)
                run rm -f "$link"
                say "  -  ${link#"$HOME"/}"
                removed=$((removed + 1))
                ;;
        esac
    done < <(
        find "$HOME/.config" -maxdepth 4 -type l 2>/dev/null
        find "$HOME/.local/bin" -maxdepth 1 -type l 2>/dev/null
        if [ -L "$HOME/.xinitrc" ]; then printf '%s\n' "$HOME/.xinitrc"; fi
    )
    say ""
    say "removed: $removed"
    say "backups: $STATE_DIR/backup-*"
    say "restore manually with: cp -a <backup>/. \"\$HOME\"/"
}

if [ "$UNINSTALL" = 1 ]; then
    uninstall_links
    exit 0
fi

# --- distro / package manager ------------------------------------------------
distro_file=""
if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case " ${ID:-} ${ID_LIKE:-} " in
        *void*)                    distro_file=void ;;
        *arch*)                    distro_file=arch ;;
        *debian*|*ubuntu*)         distro_file=debian ;;
        *fedora*|*rhel*|*centos*)  distro_file=fedora ;;
        *alpine*)                  distro_file=alpine ;;
    esac
fi

PM=none
if command -v xbps-install >/dev/null 2>&1; then
    PM=xbps
elif command -v pacman >/dev/null 2>&1; then
    PM=pacman
elif command -v apt-get >/dev/null 2>&1; then
    PM=apt
elif command -v dnf >/dev/null 2>&1; then
    PM=dnf
elif command -v apk >/dev/null 2>&1; then
    PM=apk
fi

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO=sudo
    elif command -v doas >/dev/null 2>&1; then
        SUDO=doas
    fi
fi

pm_install() {
    case $PM in
        xbps)
            local installed missing=() p
            installed=$(xbps-query -l 2>/dev/null |
                awk '$1 == "ii" {print $2}' |
                sed -E 's/-[0-9][^-]*$//')
            for p in "$@"; do
                if ! grep -qxF "$p" <<< "$installed"; then
                    missing+=("$p")
                fi
            done
            if [ ${#missing[@]} -eq 0 ]; then
                return 0
            fi
            $SUDO xbps-install -y "${missing[@]}"
            ;;
        pacman) $SUDO pacman -S --needed --noconfirm "$@" ;;
        apt)    $SUDO apt-get install -y "$@" ;;
        dnf)    $SUDO dnf install -y "$@" ;;
        apk)    $SUDO apk add --no-cache "$@" ;;
        *)      return 1 ;;
    esac
}

install_packages() {
    if [ "$SKIP_PACKAGES" = 1 ]; then
        say "packages: skipped (--no-packages)"
        return 0
    fi
    if [ -z "$SUDO" ] && [ "$(id -u)" -ne 0 ]; then
        warn "no sudo/doas: skipping packages"
        return 0
    fi
    if [ "$PM" = none ] || [ -z "$distro_file" ] ||
       [ ! -f "$DOTFILES/packages/$distro_file.txt" ]; then
        warn "unknown distribution/package manager: skipping packages"
        warn "install the dependencies from packages/*.txt manually"
        return 0
    fi

    local pkgs=()
    while IFS= read -r p; do pkgs+=("$p"); done < <(
        grep -vE '^[[:space:]]*(#|$)' "$DOTFILES/packages/$distro_file.txt"
    )
    say "package manager: $PM ($distro_file), ${#pkgs[@]} packages"
    if [ "$DRY_RUN" = 1 ]; then
        printf '%s  +  %s %s%s\n' "$DIM" "$SUDO" "$PM" "${pkgs[*]}" "$OFF"
        return 0
    fi

    if [ "$PM" = apt ]; then
        $SUDO apt-get update -qq || warn "apt-get update failed"
    fi
    if [ "$PM" = xbps ]; then
        $SUDO xbps-install -S -y >/dev/null 2>&1 || true
    fi
    if [ "$PM" = apk ]; then
        $SUDO apk update >/dev/null 2>&1 || warn "apk update failed"
    fi

    if ! pm_install "${pkgs[@]}"; then
        warn "batch install failed, retrying one by one"
        local p failed=()
        for p in "${pkgs[@]}"; do
            pm_install "$p" >/dev/null 2>&1 || failed+=("$p")
        done
        if [ ${#failed[@]} -gt 0 ]; then
            warn "not found in repositories: ${failed[*]}"
            warn "the setup still works; install the missing ones manually"
        fi
    fi
}

# --- symlinks ----------------------------------------------------------------
link() { # link <repo-relative-src> <absolute-dest>
    local src="$DOTFILES/$1" dest="$2" rel
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        say "  ok  ${dest#"$HOME"/}"
        return 0
    fi
    if [ "$DRY_RUN" = 1 ]; then
        say "  +   ${dest#"$HOME"/} -> $1"
        return 0
    fi
    mkdir -p "$(dirname "$dest")"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        rel=${dest#"$HOME"/}
        mkdir -p "$BACKUP/$(dirname "$rel")"
        mv "$dest" "$BACKUP/$rel"
        say "  bak ${rel}"
    fi
    ln -s "$src" "$dest"
    say "  ln  ${dest#"$HOME"/}"
}

install_links() {
    head2 "Linking configuration"
    local pair src dest
    while IFS='|' read -r src dest; do
        [ -n "$src" ] || continue
        link "$src" "$HOME/$dest"
    done <<'EOF'
config/bspwm/bspwmrc|.config/bspwm/bspwmrc
config/sxhkd/sxhkdrc|.config/sxhkd/sxhkdrc
config/kitty/kitty.conf|.config/kitty/kitty.conf
config/rofi/config.rasi|.config/rofi/config.rasi
config/rofi/theme.rasi|.config/rofi/theme.rasi
config/rofi/dialog.rasi|.config/rofi/dialog.rasi
config/rofi/state.rasi|.config/rofi/state.rasi
config/rofi/help.rasi|.config/rofi/help.rasi
config/rofi/sound.rasi|.config/rofi/sound.rasi
config/rofi/mic.rasi|.config/rofi/mic.rasi
config/thunar/uca.xml|.config/Thunar/uca.xml
config/gtk-3.0/settings.ini|.config/gtk-3.0/settings.ini
config/gtk-4.0/settings.ini|.config/gtk-4.0/settings.ini
config/polybar/config.ini|.config/polybar/config.ini
config/polybar/modules.ini|.config/polybar/modules.ini
config/session/env.sh|.config/session/env.sh
config/pipewire/pipewire.conf.d/99-desktop.conf|.config/pipewire/pipewire.conf.d/99-desktop.conf
config/fish/config.fish|.config/fish/config.fish
config/bash/bash_profile|.bash_profile
config/icons/default/index.theme|.icons/default/index.theme
config/xinit/xinitrc|.xinitrc
EOF

    local f
    for f in "$DOTFILES"/bin/*; do
        [ -f "$f" ] || continue
        link "bin/$(basename "$f")" "$HOME/.local/bin/$(basename "$f")"
    done
}

# --- fonts -------------------------------------------------------------------
FONTS_CHANGED=0

have_font() {
    command -v fc-list >/dev/null 2>&1 || return 1
    local families
    families=$(fc-list : family 2>/dev/null) || return 1
    grep -qiF "$1" <<< "$families"
}

fetch_font() { # fetch_font <family> <url...>
    local family=$1; shift
    have_font "$family" && return 0

    local url dest name got=0
    for url in "$@"; do
        name=${url##*/}
        name=${name//%5B/[}
        name=${name//%5D/]}
        name=${name//%2C/,}
        dest="$HOME/.local/share/fonts/$name"

        if [ "$DRY_RUN" = 1 ]; then
            say "  font: $name"
            FONTS_CHANGED=1
            got=1
            continue
        fi
        mkdir -p "$HOME/.local/share/fonts"
        if [ -s "$dest" ]; then
            got=1
            continue
        fi
        say "  font: $name"
        if curl -fsSL "$url" -o "$dest"; then
            FONTS_CHANGED=1
            got=1
        else
            rm -f "$dest"
            warn "download failed: $url"
        fi
    done

    [ "$got" = 1 ] || warn "could not install font family: $family"
    return 0
}

install_fonts() {
    head2 "Fonts"
    local jb=https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/ttf
    fetch_font "JetBrains Mono" \
        "$jb/JetBrainsMono-Regular.ttf" \
        "$jb/JetBrainsMono-Bold.ttf" \
        "$jb/JetBrainsMono-Italic.ttf" || true
    fetch_font "Roboto" \
        "https://raw.githubusercontent.com/google/fonts/main/ofl/roboto/Roboto%5Bwdth,wght%5D.ttf" \
        "https://raw.githubusercontent.com/google/fonts/main/ofl/roboto/Roboto-Italic%5Bwdth,wght%5D.ttf" || true
    fetch_font "Symbols Nerd Font" \
        "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/NerdFontsSymbolsOnly/SymbolsNerdFont-Regular.ttf" || true
    if [ "$FONTS_CHANGED" = 1 ] && [ "$DRY_RUN" = 0 ]; then
        command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1 || true
    fi
}

# --- cursor ------------------------------------------------------------------
ensure_cursor() {
    local theme=Bibata-Modern-Classic
    [ -d "$HOME/.icons/$theme" ] && return 0
    if [ "$DRY_RUN" = 1 ]; then
        say "  +   download cursor theme: $theme"
        return 0
    fi

    local url tmp
    url=$(curl -fsSL https://api.github.com/repos/ful1e5/Bibata_Cursor/releases/latest 2>/dev/null |
        grep -o 'https://[^"]*Bibata-Modern-Classic\.tar\.xz' | head -n1 || true)
    [ -n "$url" ] || { warn "no Bibata release URL found"; return 1; }

    tmp=$(mktemp -d)
    if ! curl -fsSL "$url" -o "$tmp/bibata.tar.xz"; then
        rm -rf "$tmp"
        warn "cursor download failed"
        return 1
    fi

    mkdir -p "$HOME/.icons"
    if ! tar -xJf "$tmp/bibata.tar.xz" -C "$HOME/.icons" 2>/dev/null; then
        if command -v python3 >/dev/null 2>&1; then
            python3 - "$tmp/bibata.tar.xz" "$HOME/.icons" <<'PY'
import sys, tarfile
with tarfile.open(sys.argv[1], "r:xz") as t:
    t.extractall(sys.argv[2])
PY
        else
            warn "need xz or python3 to extract the cursor theme"
        fi
    fi
    rm -rf "$tmp"
    [ -d "$HOME/.icons/$theme" ]
}

# --- matugen -----------------------------------------------------------------
ensure_matugen() {
    if command -v matugen >/dev/null 2>&1; then return 0; fi
    if [ -x "$HOME/.local/bin/matugen" ]; then return 0; fi
    if ls /lib/ld-musl-*.so.1 >/dev/null 2>&1; then
        warn "musl libc detected: prebuilt matugen is glibc-only"
        warn "install it manually: cargo install matugen --root \"$HOME/.local\""
        return 1
    fi
    if [ "$DRY_RUN" = 1 ]; then
        say "  +   download matugen to ~/.local/bin"
        return 0
    fi
    case $(uname -m) in
        x86_64|amd64) ;;
        *) warn "no prebuilt matugen for $(uname -m); install it with cargo"; return 1 ;;
    esac
    local url tmp
    url=$(curl -fsSL https://api.github.com/repos/InioX/matugen/releases/latest 2>/dev/null |
        grep -o 'https://[^"]*matugen-[0-9.]*-x86_64\.tar\.gz' | head -n1 || true)
    [ -n "$url" ] || { warn "could not resolve the matugen release URL"; return 1; }
    tmp=$(mktemp -d)
    if curl -fsSL "$url" | tar -xz -C "$tmp" && [ -f "$tmp/matugen" ]; then
        mkdir -p "$HOME/.local/bin"
        install -m755 "$tmp/matugen" "$HOME/.local/bin/matugen"
        say "  matugen installed to ~/.local/bin/matugen"
        rm -rf "$tmp"
        return 0
    fi
    rm -rf "$tmp"
    warn "matugen download failed"
    return 1
}

# --- main --------------------------------------------------------------------
say ""
say "${BOLD}Material You bspwm dotfiles${OFF}"
say "${DIM}uniform borders, gaps, motion and colour from one wallpaper${OFF}"
say "repo: $DOTFILES"
if [ "$DRY_RUN" = 1 ]; then say "mode: ${WARN}dry-run${OFF}"; fi

install_packages

head2 "Directories"
run mkdir -p \
    "$HOME/.config/bspwm" "$HOME/.config/sxhkd" "$HOME/.config/picom" \
    "$HOME/.config/kitty" "$HOME/.config/rofi" "$HOME/.config/dunst" \
    "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.config/Thunar" "$HOME/.config/fish" \
    "$HOME/.config/polybar" \
    "$HOME/.config/pipewire/pipewire.conf.d" \
    "$HOME/.config/session" \
    "$HOME/.config/X11" "$HOME/.local/bin" \
    "$HOME/.local/share/icons" "$HOME/.icons/default" \
    "$CACHE_DIR" "$HOME/Pictures/Screenshots"

install_links

head2 "Runtime helpers"
if [ "$DRY_RUN" = 0 ]; then
    chmod +x "$DOTFILES"/bin/* \
        "$DOTFILES/install.sh" "$DOTFILES/doctor.sh" \
        "$DOTFILES/config/bspwm/bspwmrc" "$DOTFILES/config/xinit/xinitrc" \
        2>/dev/null || true
fi
ensure_matugen || true
install_fonts

head2 "Appearance"
ensure_cursor || true
if [ "$DRY_RUN" = 0 ] && [ -n "${DISPLAY:-}" ] &&
   command -v python3 >/dev/null 2>&1; then
    "$DOTFILES/bin/cursor" || true
fi
if [ "$DRY_RUN" = 0 ] && [ -n "${DISPLAY:-}" ]; then
    "$DOTFILES/bin/display" || true
fi
if [ "$DRY_RUN" = 0 ] && command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
fi

head2 "Palette"
if [ "$DRY_RUN" = 1 ]; then
    say "  +   generate configs with matugen from wallpapers/default.png"
else
    if DOTFILES="$DOTFILES" "$DOTFILES/bin/theme" --no-reload; then
        :
    else
        warn "palette generation failed; run ./bin/theme after fixing matugen"
    fi
fi

head2 "Default applications"
if command -v thunar >/dev/null 2>&1 && command -v xdg-mime >/dev/null 2>&1; then
    run xdg-mime default thunar.desktop inode/directory
else
    say "thunar is not installed yet — file-manager association skipped"
fi
if command -v thunar >/dev/null 2>&1 && command -v xfconf-query >/dev/null 2>&1; then
    run "$DOTFILES/bin/thunar-setup" || true
fi

head2 "Done"
if [ "$DRY_RUN" = 1 ]; then
    say "dry-run finished; nothing was changed."
    exit 0
fi

say "Next steps:"
say "  1. reload bspwm:  ${BOLD}bspc wm -r${OFF}"
say "     (or log out and run ${BOLD}startx${OFF} next time)"
say "  2. check the setup: ${BOLD}./doctor.sh${OFF}"
say "  3. change palette:  ${BOLD}theme ~/Pictures/wall.jpg${OFF}  or  ${BOLD}Super+Shift+T${OFF}"
say "  4. performance/network: ${BOLD}sudo ./system/install.sh${OFF}"
say ""
say "${DIM}make sure ~/.local/bin is in PATH to use 'theme' directly${OFF}"
say ""
say "backups (if any): $BACKUP"
say "hotkeys: see README.md"
