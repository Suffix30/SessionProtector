#!/bin/bash
IP="$1"
USERNAME="$2"
MODE="${3:---start}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/../logs/actions.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "$(date): [FAKE_CMDS] $*" >> "$LOG_FILE"; }

if [[ ! "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then log "Invalid IP: $IP"; exit 1; fi
if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9_]+$ ]]; then log "Invalid username: $USERNAME"; exit 1; fi
if [[ "$IP" == "$SP_MY_IP" ]] && [[ "$USERNAME" == "$SP_MY_USERNAME" ]]; then log "Own connection, skipping"; exit 0; fi

HOME_DIR="/home/$USERNAME"
BASHRC="$HOME_DIR/.bashrc"
TAG="# sp_fake_cmds"

if [[ ! -d "$HOME_DIR" ]]; then log "Home dir not found: $HOME_DIR"; exit 1; fi

if [[ "$MODE" == "--stop" ]]; then
    log "Removing fake commands for $USERNAME"
    if [[ -f "$BASHRC" ]]; then
        sed -i "/$TAG/d" "$BASHRC"
    fi
    log "Fake commands removed for $USERNAME"
    exit 0
fi

log "Injecting fake commands for $USERNAME from $IP"

cat >> "$BASHRC" << FAKECMDS
alias ls='echo "Permission denied"' $TAG
alias cd='echo "bash: cd: restricted"' $TAG
alias cat='echo "Segmentation fault (core dumped)"' $TAG
alias vim='echo "vim: command not found"' $TAG
alias nano='echo "nano: command not found"' $TAG
alias sudo='echo "sudo: unable to resolve host"' $TAG
alias ssh='echo "Connection refused"' $TAG
alias wget='echo "wget: command not found"' $TAG
alias curl='echo "curl: command not found"' $TAG
alias rm='echo "rm: cannot remove: Read-only file system"' $TAG
alias cp='echo "cp: cannot copy: Read-only file system"' $TAG
alias mv='echo "mv: cannot move: Read-only file system"' $TAG
alias whoami='echo "nobody"' $TAG
alias id='echo "uid=65534(nobody) gid=65534(nogroup) groups=65534(nogroup)"' $TAG
alias pwd='echo "/dev/null"' $TAG
alias ps='echo "PID TTY TIME CMD"' $TAG
alias ifconfig='echo "lo: flags=73<UP,LOOPBACK,RUNNING>"' $TAG
alias ip='echo "Device not found"' $TAG
FAKECMDS

log "Fake commands injected for $USERNAME"
