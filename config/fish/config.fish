# fish — минимальный конфиг под этот десктоп.

set -g fish_greeting ""

# Пользовательские бинарники и opencode.
fish_add_path $HOME/.local/bin
fish_add_path $HOME/.opencode/bin

alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias grep='grep --color=auto'

# Start X automatically on the first virtual console (login shell only).
if status is-login; and not set -q DISPLAY; and not set -q SSH_CONNECTION; and test (tty) = /dev/tty1; and not test -e /tmp/.X0-lock
    exec startx
end
