#!/bin/bash
IP="$1"
USERNAME="$2"
MODE="${3:---start}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/../logs/actions.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "$(date): [SHELL_CHAOS] $*" >> "$LOG_FILE"; }

if [[ ! "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then log "Invalid IP: $IP"; exit 1; fi
if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9_]+$ ]]; then log "Invalid username: $USERNAME"; exit 1; fi
if [[ "$IP" == "$SP_MY_IP" ]] && [[ "$USERNAME" == "$SP_MY_USERNAME" ]]; then log "Own connection, skipping"; exit 0; fi

HOME_DIR="/home/$USERNAME"
BASHRC="$HOME_DIR/.bashrc"
TAG="# sp_shell_chaos"

if [[ ! -d "$HOME_DIR" ]]; then log "Home dir not found: $HOME_DIR"; exit 1; fi

if [[ "$MODE" == "--stop" ]]; then
    log "Removing shell chaos for $USERNAME"
    if [[ -f "$BASHRC" ]]; then
        sed -i "/$TAG/d" "$BASHRC"
    fi
    log "Shell chaos removed for $USERNAME"
    exit 0
fi

log "Applying shell chaos to $USERNAME from $IP"

cat >> "$BASHRC" << SHELLCHAOS
export PS1='\[\e[5;31m\]YOU HAVE BEEN PWNED > \[\e[0m\]' $TAG
PROMPT_COMMAND='sleep 0.\$((RANDOM % 5 + 1))' $TAG
export TERM=dumb $TAG
export LANG=C $TAG
export LC_ALL=C $TAG
trap '' 2 3 $TAG
if [ -t 1 ]; then echo -e "\e[41m\e[33m"; fi $TAG
SHELLCHAOS

log "Shell chaos applied to $USERNAME"
