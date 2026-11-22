# Material You · bspwm

Минималистичный X11-десктоп без панели: bspwm, sxhkd, picom, rofi, dunst и
kitty. Цвета генерируются из обоев (Material You, matugen), движение —
сдержанные M3-анимации picom: окна плавно появляются, исчезают и **переезжают
при перестройке тайлинга**.

```
dotfiles/
├── install.sh              установка одной командой
├── doctor.sh               диагностика окружения
├── packages/               зависимости для Void / Arch / Debian / Fedora
├── config/                 статические конфиги (симлинки)
├── theme/                  matugen + шаблоны генерируемых конфигов
├── system/                 производительность, sysctl, udev/dhcpcd-хуки
├── bin/                    theme, dashboard, performance, screenshot, volume, …
└── wallpapers/default.png  дефолтные обои (сид палитры)
```

## Установка

```sh
git clone <this-repo> ~/dotfiles
cd ~/dotfiles
./install.sh
bspc wm -r          # или выйти и запустить startx
./doctor.sh
```

`install.sh` ставит пакеты (нужен sudo/doas), закидывает старые файлы в
`~/.local/state/dotfiles/backup-<дата>/` и только потом создаёт симлинки.
Повторный запуск безопасен.

> `~/.local/bin` должен быть в `PATH`, иначе `theme` и `doctor` в примерах
> ниже вызывайте как `~/.local/bin/theme`. Добавьте в `~/.bashrc`:
> `export PATH="$HOME/.local/bin:$PATH"`.

Полезные флаги:

```sh
./install.sh --dry-run        # показать, что будет сделано
./install.sh --no-packages    # без пакетов (шрифты и matugen всё равно скачаются)
./install.sh --uninstall      # удалить симлинки этого репозитория
```

Первый `bspc wm -r` переименует рабочие столы в `1…9` (окна сохранятся).

Автозапуск X уже настроен: `~/.xinitrc` запускает bspwm, а логин-шелл
**fish** (`~/.config/fish/config.fish`) на tty1 сам выполняет `startx`. Для
bash на всякий случай то же самое прописано в `~/.bash_profile`. Если
автозапуск не сработал, проверь, что нет старого `/tmp/.X0-lock`, и что вход
был именно на tty1.

### Alpine Linux

`install.sh` умеет `apk` и использует `packages/alpine.txt`. Но есть отличия:

- **matugen** в Alpine нет, а готовый бинарник — glibc. Нужно собрать:
  ```sh
  sudo apk add cargo
  cargo install matugen --root "$HOME/.local"
  ```
- `xss-lock` в репозитории нет — автоблокировка по idle не работает,
  `Super+Escape` работает.
- `snixembed` нет — трей покажет только XEmbed-приложения (AmneziaVPN),
  Discord/qBittorrent без SNI-иконок.
- `system/` — в основном Void-специфичные скрипты (xbps/runit). На Alpine
  настраивай polkit/PipeWire/AmneziaVPN вручную под OpenRC.
- Flatpak в Alpine есть, но Discord/Steam лучше проверять отдельно; Steam
  нативно не поддерживается.

### Другая машина

Конфиги переносятся, а **драйверы GPU — нет**. `install.sh` не устанавливает
драйверы видеокарты (кроме Alpine-списка); их ставит сама система.

Для RX 580:

```sh
# Void
sudo xbps-install -S mesa-dri mesa-vulkan-radeon vulkan-loader

# Arch
sudo pacman -S mesa vulkan-radeon vulkan-icd-loader

# Debian/Ubuntu
sudo apt install mesa-vulkan-drivers mesa-utils vulkan-tools

# Fedora
sudo dnf install mesa-dri-drivers mesa-vulkan-drivers vulkan-loader
```

Для Steam на RX 580 ещё нужны 32-битные Mesa/Vulkan — см. раздел Steam.

Если на другой машине NVIDIA/Intel — ставь драйвер под неё. `bar-temp`
понимает `amdgpu`, `radeon`, `nouveau`, `i915`, `xe`; для NVIDIA-температуры
пока покажет `--`.

`system/` — тоже про текущую машину: `rtw88_8821cu`, HDA-аудио, AmneziaVPN,
dhcpcd-хук. Не запускай `system/install.sh` на другой системе вслепую.

## Хоткеи

| Комбинация | Действие |
| --- | --- |
| `Super+Return` | kitty |
| `Super+E` | файлы (Thunar) |
| `Super+Shift+B` | браузер (Firefox) |
| `Super+Space` | launcher (rofi, иконки Papirus-Dark) |
| `Super+D` | control center: время, звук, сеть, диск, тема |
| `Super+Tab` | переключатель окон |
| `Super+{h,j,k,l}` | фокус (`+Shift` — поменять местами) |
| `Super+{1…9}` | рабочий стол (`+Shift` — перенести окно) |
| `Super+bracketleft/right` | предыдущий/следующий стол |
| `Super+f` | fullscreen (туда/обратно) |
| `Super+Shift+f` | аварийно вернуть окно в тайлинг |
| `Super+t` / `Super+s` | pseudo-tile / floating (туда-обратно) |
| `Super+ЛКМ` | переместить окно мышью |
| `Super+ПКМ` | размер за угол |
| `Super+СКМ` | размер за сторону |
| `Super+Shift+t` | выбрать обои и палитру |
| `Super+g` | анимированно убрать/вернуть отступы |
| `Super+m` | monocle |
| `Super+Shift+q` | меню питания (lock, suspend, reboot…) |
| `Super+Shift+v` | панель звука: громкость, mute, микшер |
| `Super+Shift+p` | включить/выключить композитор (игры) |
| `Super+Shift+r` | перезагрузить bspwm + композитор + уведомления |
| `Print` / `Shift+Print` | скриншот всего экрана / области |
| `XF86Audio*` | громкость |
| `Super+Shift+M` | настройка микрофона |
| `Super+Shift+A` | скрыть/показать верхний бар |
| `XF86MonBrightness*` | яркость |
| `Super+Escape` | заблокировать (blur, часы, индикатор) |
| `Super+F1` | справка по всем хоткеям |
| `Super+Alt+{q,r}` | выйти / перезапустить bspwm |

`sxhkdrc` — единственное место, где живут биндинги.

## Справка по хоткеям

`Super+F1` открывает поисковую шпаргалку в rofi. Она собирается из самого
`sxhkdrc`: описание хоткея — комментарий прямо над ним, поэтому список не
устаревает. Enter копирует команду выбранного хоткея в буфер обмена.

```sh
~/.local/bin/help --plain   # тот же список в терминал
```

Добавили биндинг — просто напишите комментарий над ним:

```sh
# Следующий трек
XF86AudioNext
    playerctl next
```

## Material You

Вся палитра выводится из одной картинки:

```sh
theme ~/Pictures/wall.jpg     # или Super+Shift+T
```

`matugen` строит тёмную M3-схему: `scheme-tonal-spot` для цветных обоев и
`scheme-content` для почти ч/б (иначе алгоритм придумывает голубой оттенок).
Если цвет из картинки не извлекается, используется нейтральный fallback
`#808080`, а не синий.

| Файл | Кто использует |
| --- | --- |
| `~/.config/bspwm/colors.sh` | рамки окон |
| `~/.config/picom/picom.conf` | тени, анимации |
| `~/.config/kitty/colors.conf` | терминал |
| `~/.config/rofi/colors.rasi` | launcher, дашборд, меню |
| `~/.config/dunst/dunstrc` | уведомления и OSD столов |
| `~/.config/gtk-3.0/gtk.css` | GTK3-приложения |
| `~/.config/gtk-4.0/gtk.css` | GTK4 / libadwaita / Flatpak |
| `~/.config/polybar/colors.ini` | верхний бар |
| `~/.config/X11/xresources` | Xft |

Затем всё перезагружается на лету: `bspc config`, `picom -USR1`,
`dunstctl reload`, `kitty @ set-colors`. Текущие обои хранятся в
`~/.cache/dotfiles/wallpaper`.

Тёмная тема включена на трёх уровнях, чтобы её видели разные тулкиты:

- `~/.config/gtk-3.0/settings.ini` и `~/.config/gtk-4.0/settings.ini` —
  тёмная Adwaita, иконки Papirus-Dark, курсор Bibata;
- `GTK_THEME=Adwaita:dark` из `config/session/env.sh` — тёмный вариант для
  GTK3 и GTK4 (у GTK4 нет отдельной темы `Adwaita-dark`);
- GSettings `color-scheme=prefer-dark` — через xdg-desktop-portal её видят
  GTK4/libadwaita, Flatpak-приложения и Firefox;
- `gtk.css` в обоих каталогах перекрашивает Adwaita в Material-палитру.

Проверка и ручная починка:

```sh
gsettings get org.gnome.desktop.interface color-scheme
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark
gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark
```

Qt-приложения тему GTK не читают — для них нужен `qt6ct`/`qt5ct`
(или `QT_QPA_PLATFORMTHEME`), если такие программы появятся.

Шаблоны лежат в `theme/*.tmpl`, точки вывода — в `theme/matugen.toml`.
Хотите другой характер палитры — поменяйте `--type` в `bin/theme`
(`scheme-neutral` — почти монохром, `scheme-vibrant` — ярче).

## Звук и яркость

Отдельную программу настроек ставить не нужно.

- `XF86AudioRaiseVolume` / `XF86AudioLowerVolume` — громкость на 5 %, `XF86AudioMute` — mute.
- `Super+Shift+V`, либо `Super+D` → **Sound** — панель: текущий уровень, mute и шаги 0–100 %. Выбрал процент — он применился, панель осталась открытой. Esc закрывает.
- **Mixer** в этой панели открывает `alsamixer` в kitty: стрелки меняют уровень, `M` — mute, Esc — выход. Это полноценный микшер ALSA.
- Звук уже идёт через **PipeWire** (`pipewire-pulse`); ALSA-панель остаётся запасным вариантом.

Яркость: `XF86MonBrightnessUp/Down` через `brightnessctl`. На десктопе без backlight строка Brightness просто скрывается.

### PipeWire

PipeWire уже установлен и запускается из `bspwmrc` через `bin/pipewire-start`
(`pipewire`, WirePlumber, `pipewire-pulse`). Проверка:

```sh
pactl info | grep 'Server Name'
# PulseAudio (on PipeWire 1.6.10) — это нормально
wpctl status
```

`pactl info` намеренно показывает «PulseAudio (on PipeWire …)»: это
pulse-совместимый слой, через который PipeWire видят Firefox, Discord, Steam
и остальные клиенты. Если там просто `PulseAudio` без «on PipeWire», значит
работает старый pulseaudio, а не PipeWire.

Поставить на новой машине:

```sh
sudo ~/dotfiles/system/audio/pipewire-install.sh
pkill -x sxhkd; bspc wm -r
```

Скрипт ставит `pipewire`, `wireplumber`, `alsa-pipewire`, `pavucontrol` и
применяет ALSA-фикс (HDA power save + микрофон).

- `Super+Shift+M` открывает **pavucontrol** (вход, уровень, mute, выбор устройства);
- `bin/volume`, `Super+Shift+V` и дашборд автоматически используют `wpctl`;
- в панели звука появляется **Sound settings**;
- после переустановки PipeWire перезапусти Firefox/плеер, чтобы они
  переподключились.

Конфиг PipeWire — `config/pipewire/pipewire.conf.d/99-desktop.conf`
(48 кГц, quantum 1024, меньше xrun/щелчков). Лог запуска:
`~/.cache/pipewire-start.log`.

### Треск и микрофон

У HDA-кодека был включён `power_save=1` — это частая причина щелчков и
треска при старте/паузе звука. Одна команда отключает его и сохраняет
нормальные настройки микрофона:

```sh
sudo ~/dotfiles/system/audio/install.sh
```

После неё перезагрузись (чтобы применился modprobe-параметр). Микрофон:

- `Super+Shift+M` или `Super+D` → **Микрофон** — панель: `Rear Mic` /
  `Front Mic` / `Line`, уровень Capture, mute, буст 0–3 и микшер;
- текущий вход — **Rear Mic**, Capture 60 %, буст 0; если тихо/громко,
  поправь в панели;
- `alsamixer` из панели показывает все каналы, `F4` — захват.

Если после отключения `power_save` треск останется, проверь кабель и буст
микрофона, а также `wpctl status` — PipeWire уже установлен и запускается
автоматически из `bspwmrc`.

## Файлы

Проводник — **Thunar**. Он GTK3, не тянет GNOME/KDE-стек, умеет вкладки,
боковую панель, корзину, архивы, миниатюры и съёмные диски. Подхватывает
Adwaita-dark и наш сгенерированный акцент.

На этой машине пакеты ещё не установлены (нужен пароль sudo):

```sh
sudo xbps-install -Sy thunar thunar-volman thunar-archive-plugin \
    tumbler ffmpegthumbnailer gvfs gvfs-mtp file-roller udisks2 \
    polkit-gnome gnome-themes-extra papirus-icon-theme xfconf xz
sudo ln -sfn /etc/sv/udisks2 /var/service/udisks2     # автоподключение USB
```

После этого: `Super+E`, либо `Super+D` → **Файлы**. `xdg-open ~/` тоже будет
открывать Thunar (ассоциацию ставит `install.sh`). На других дистрибутивах
пакеты уже перечислены в `packages/*.txt`; `udisks2` включается через
`systemctl enable --now udisks2`.

Вид Thunar настраивается скриптом `bin/thunar-setup` (он же вызывается из
`install.sh`): тёмный CSD-заголовок, менюбар скрыт (`F10` — показать),
хлебные крошки вместо поля пути, крупные иконки 150 %, Papirus-Dark,
миниатюры, папки сверху, подтверждение удаления в корзину. Настройки Thunar
живут в Xfconf, поэтому скрипт — единая точка правды для новых машин.

ПКМ по папке → **Open Terminal Here** открывает kitty в этой папке. Действие
лежит в `config/thunar/uca.xml` и вызывает `bin/open-terminal`; стандартный
`exo-open` с пустым helper'ом больше не используется.

По умолчанию `Super+Return` (kitty) и `Super+E` (Thunar) открываются в
домашней папке. Из Thunar терминал открывается уже в выбранной папке.

## Курсор и иконки

- **Курсор:** Bibata Modern Classic (чёрный, 24 px). `install.sh` скачивает
  его в `~/.icons`, прописывает в `settings.ini`, `Xresources`, `.xinitrc` и
  `XCURSOR_*`.
- bspwm сам не задаёт курсор корневого окна, поэтому X показывал запасной
  «X». `bin/cursor` ставит Bibata на корень при старте сессии (`bspwmrc`).
- **Иконки:** Papirus-Dark (пакет `papirus-icon-theme` или локальная копия).
- Уже открытые приложения подхватят курсор после перезапуска; новые окна —
  сразу. Для полного обновления можно выйти и зайти в сессию заново.

## Дисплей

`bin/display` при старте bspwm берёт текущее разрешение и включает максимальную
доступную частоту — у тебя это **1920×1080 @ 144 Гц** на DVI-D-1. Ничего
руками настраивать не нужно; при смене монитора скрипт выберет максимум для
нового текущего режима.

Пакет `xrandr` добавлен в списки; проверить вручную:

```sh
~/.local/bin/display
xrandr --current
```

## Производительность и сеть

Одна команда ставит режим максимальной производительности и отключает
энергосбережение Wi-Fi:

```sh
sudo ~/dotfiles/system/install.sh
```

Что настраивается:

- CPU governor `performance` на всех ядрах (у тебя Xeon E5-2670 v2, сейчас был
  `schedutil`);
- AMD GPU `power_dpm_force_performance_level = high` (RX 580);
- Wi-Fi power save **off**, USB runtime PM для адаптера **off**; у тебя
  Realtek RTL8821CU и power save был включён;
- `rtw88_8821cu.disable_lps_deep=1` — глубокий power save драйвера
  отключится после перезагрузки;
- TCP BBR + `fq`, увеличенные буферы сокетов, отключение slow-start after idle;
- Wake-on-LAN и EEE у проводной сетевой карты (если поддерживается);
- автозапуск через `/etc/rc.local` (Void/runit) или systemd-юнит, плюс
  dhcpcd/udev-хуки, чтобы Wi-Fi power save не возвращался после реконнекта.

Проверка и откат:

```sh
sudo /usr/local/bin/performance status
sudo /usr/local/bin/performance balanced   # schedutil + GPU auto
```

Файлы режима лежат в `system/`; `bin/performance` — тот же скрипт для ручного
запуска. Учти: `high` на GPU и `performance` на CPU дают больше тепла и
потребления; если станет шумно/жарко — `balanced`.

## Раскладка

Переключение раскладки — `Alt+Shift` (задаётся в `bspwmrc`). При смене
`bin/layout-osd` показывает **снизу по центру** компактный OSD **EN** или
**РУ**; он же стартует вместе с bspwm и слушает XKB-группу. Туда же выводятся
OSD громкости, яркости и рабочих столов.

## AmneziaVPN

Официальный `.run`-установщик Amnezia умеет запускать только systemd-службу
(`systemctl enable --now AmneziaVPN`), поэтому на Void демон не поднимается.
Для runit есть отдельный сервис:

```sh
sudo ~/dotfiles/system/amnezia/install.sh
sudo sv status amneziavpn
```

Скрипт ставит `/etc/sv/amneziavpn`, запускает
`/opt/AmneziaVPN/bin/AmneziaVPN-service` от root и создаёт
`/var/run/amneziavpn/daemon.socket`, к которому подключается GUI. После
установки перезапусти окно AmneziaVPN.

Если VPN подключается, но не работает DNS, доставь резолвер:

```sh
sudo xbps-install -Sy openresolv nftables
```

Логи службы: `/var/log/AmneziaVPN/service/current`.
На системах с systemd установщик вместо runit включит родной
`AmneziaVPN.service`.

## Fish

Пакет в Void называется **`fish-shell`**:

```sh
sudo xbps-install -S fish-shell
fish
```

Если всё нравится, сделай fish логин-шеллом:

```sh
grep -qx /usr/bin/fish /etc/shells || echo /usr/bin/fish | sudo tee -a /etc/shells
chsh -s /usr/bin/fish
```

Новый shell применится после выхода и входа. Вернуться обратно:

```sh
chsh -s /bin/bash
```

Конфиг лежит в `config/fish/config.fish` и линкуется в
`~/.config/fish/config.fish` установщиком. Там же PATH для `~/.local/bin` и
`~/.opencode/bin`, пустое приветствие и пара алиасов.

Цвета **Tide** генерируются из Material-палитры в
`~/.config/fish/conf.d/tide-colors.fish` (фон сегментов, текст, иконка дома).
Новые терминалы подхватывают их сами; в уже открытом fish после смены темы:

```sh
source ~/.config/fish/conf.d/tide-colors.fish
tide reload
```

## Экран

Экран не гаснет при неактивности: `bin/no-blank` выполняет `xset s off`,
`xset s noblank` и `xset -dpms`. Он вызывается из `.xinitrc` при старте X и из
`bspwmrc` при перезагрузке конфига.

Вернуть стандартное поведение:

```sh
xset s on
xset +dpms
xset dpms 600 600 600
```

Ручная блокировка `Super+Escape` продолжает работать; автоблокировка по
бездействию отключена вместе с screensaver.

## Верхний бар

Сверху по центру — тонкий **Polybar** высотой 26 px: 50 % ширины экрана,
отступ 4 px сверху, квадратный, без скруглений. Цвета берутся из текущих
обоев.

- слева: рабочие столы bspwm (клик — перейти) и раскладка `US/RU`;
- центр: часы;
- справа: громкость (клик — панель звука, правый клик — mute),
  температуры **CPU** и **GPU**, имя Wi-Fi-сети, иконки трея и кнопка
  питания.

Температуры читаются напрямую из `hwmon` (`coretemp`/`k10temp` и `amdgpu`),
`lm_sensors` не нужен. Имя сети берётся из `iw` (SSID), для Ethernet
показывается имя интерфейса.

Трей — модуль Polybar `internal/tray`. XEmbed-приложения (AmneziaVPN) видны
сразу, а для SNI (Discord, qBittorrent) нужен мост:

```sh
sudo xbps-install -S snixembed
```

`bspwmrc` запускает `snixembed` автоматически, если он установлен. После
установки перезайди в сессию или запусти `snixembed &` и перезапусти нужное
приложение — иконка появится в баре.

`Super+Shift+A` скрывает/показывает бар; `top_padding` у bspwm меняется
вместе с ним, поэтому окна не заезжают под бар.

Обводка бара — 2 px в цвет Material `primary`; у окон тоже 2 px: активное
окно — `primary`, остальные — `primary_container`. Обводка входит в расчёт
`top_padding` (сейчас 34 px: 26 + 4 + 2×2).

```sh
bar start|stop|restart|toggle|status
```

Цвета генерируются в `~/.config/polybar/colors.ini` при смене обоев, бар
перезапускается автоматически. Конфиг: `config/polybar/config.ini` и
`config/polybar/modules.ini`.

## Уведомления

Dunst показывает уведомления по центру сверху — сразу под баром:
`origin = top-center`, `offset = 0x2a` (42 px: бар заканчивается на 34 px
плюс 8 px зазор). Ширина до 340 px, новые уведомления встают вниз.
Если меняешь высоту бара, поправь `offset` в `theme/dunstrc.tmpl`.

## Блокировка

`Super+Escape` (и `xss-lock`) вызывают `bin/lock`. Если установлен
**i3lock-color**, экран блокировки получает:

- размытие текущего рабочего стола;
- часы и дату;
- текущую раскладку (`US`/`RU`);
- Material-кольцо ввода: `primary` при проверке, `error` при ошибке;
- тёмную полупрозрачную подложку.

Установка:

```sh
sudo xbps-remove -R i3lock
sudo xbps-install -Sy i3lock-color
pkill -x xss-lock; bspc wm -r
```

Без `i3lock-color` `bin/lock` откатывается на обычный i3lock с цветом
`surface`.

## Discord

В репозиториях Void Discord не пакетируется — ставим через Flatpak.

```sh
sudo xbps-install -S flatpak xdg-desktop-portal xdg-desktop-portal-gtk
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub com.discordapp.Discord
```

Запуск: `discord` (обёртка `bin/discord`) или
`flatpak run com.discordapp.Discord`. После перезахода в сессию Discord
появляется в rofi — `config/session/env.sh` добавляет flatpak-каталоги в
`XDG_DATA_DIRS` (fish не читает `/etc/profile.d`).

Альтернатива — **Vesktop** (Vencord, меньше памяти, удобнее шаринг экрана):

```sh
flatpak install --user flathub dev.vencord.Vesktop
```

Звук и микрофон идут через PipeWire; при первом звонке выбери устройство в
Discord → Voice & Video.

Без Flatpak можно распаковать официальный tar.gz в `~/.local/opt/discord` —
`bin/discord` подхватит его автоматически.

## Steam

В Void Steam живёт в multilib-репозитории, по умолчанию он не подключён.

```sh
sudo xbps-install -S void-repo-multilib void-repo-multilib-nonfree void-repo-nonfree
sudo xbps-install -S steam
```

Для AMD RX 580 (RADV/Vulkan, в том числе 32-битные игры):

```sh
sudo xbps-install -S mesa-dri-32bit mesa-vulkan-radeon vulkan-loader-32bit \
    mesa-vulkan-radeon-32bit
```

Проверка после установки:

```sh
sudo xbps-install -S Vulkan-Tools   # даёт vulkaninfo
vulkaninfo --summary                # должен появиться GPU id / radv
```

(В Void пакет называется `mesa-vulkan-radeon`, а не `vulkan-radeon`.)

Запуск — `steam` из терминала или из меню приложений. Первый запуск скачает
Steam Runtime. **Steam не запускать от root.**

Proton: Steam → Settings → Compatibility → включить Steam Play для всех
игр, выбрать Proton Experimental. Библиотеку игр лучше держать на ext4, не на
NTFS.

Если Steam не стартует — запусти из терминала и посмотри ошибку; чаще всего
это нехватка 32-битной Mesa/Vulkan (`mesa-dri-32bit`,
`vulkan-radeon-32bit`). Альтернатива без multilib — Flatpak
`com.valvesoftware.Steam`, но для AMD и Proton нативный пакет лучше.

## Анимации

Всё в `theme/picom.conf.tmpl` (и генерируется в `~/.config/picom/picom.conf`):

| Событие | Длительность | Кривая |
| --- | --- | --- |
| открытие окна: fade + slide 10px | 220 мс | emphasized decelerate |
| закрытие: fade + slide | 150 мс | emphasized accelerate |
| смена стола: fade | 120–180 мс | M3 |
| изменение геометрии (тайлинг, gaps, swap) | 200 мс | `geometry-change` |

Тайминги меняются в блоке `animations` шаблона. Чтобы применить:

```sh
theme --no-reload    # перегенерировать конфиг
pkill -USR1 picom    # перечитать
```

Для игр/записи экрана — `Super+Shift+p` (композитор целиком отключается).

## Заметки

- **Панели нет.** Статус — `Super+D`; при переключении стола на 650 мс
  появляется короткое уведомление с номером.
- **Дистрибутивы.** Void и Arch дают picom с анимациями из коробки. На Debian
  bookworm picom 10 — `doctor.sh` предупредит, нужна сборка из исходников
  (ветка `next`) или testing/sid. matugen при отсутствии скачивается бинарником
  в `~/.local/bin`.
- **Шрифты.** JetBrains Mono, Roboto и Symbols Nerd Font (иконки) ставятся
  пакетом или скачиваются в `~/.local/share/fonts`.
- **Раскладка.** `us,ru` с переключением по Alt+Shift задаётся в `bspwmrc`;
  поменяйте строку `setxkbmap`, если нужна другая.
- **Ручной resize.** `geometry-change` анимирует и перетаскивание рамок
  (`Super` + ПКМ). Если это кажется вязким, удалите блок `triggers = [ "geometry" ]`
  из `theme/picom.conf.tmpl` и перезапустите picom.
- **Мультимонитор.** bspwmrc создаёт 9 столов на текущем мониторе; добавьте
  столы для второго монитора вручную (`bspc monitor <name> -a 4 5 6`).
- **Выключение/перезагрузка.** Меню питания использует `loginctl`; чтобы оно
  не висело на запросе пароля, поставь правило polkit:
  ```sh
  sudo ~/dotfiles/system/polkit/install.sh
  ```
  После этого `Super+Shift+Q` → Выключить/Перезагрузить работает без диалога.
  Команда `shutdown` в runit сама по себе требует root: из консоли —
  `sudo shutdown -h now`, либо меню/`loginctl --no-ask-password poweroff`.
- **Прозрачность.** kitty — 94 %, rofi/dunst — тональное стекло с blur.
  Отключить blur: `blur-background = false` в шаблоне picom.
