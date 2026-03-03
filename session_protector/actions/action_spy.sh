#!/bin/bash
IP="$1"
USERNAME="$2"
MODE="${3:---start}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/../logs/actions.log"
REC_DIR="$SCRIPT_DIR/../recordings"
mkdir -p "$(dirname "$LOG_FILE")" "$REC_DIR"

log() { echo "$(date): [SPY] $*" >> "$LOG_FILE"; }

if [[ ! "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then log "Invalid IP: $IP"; exit 1; fi
if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9_]+$ ]]; then log "Invalid username: $USERNAME"; exit 1; fi
if [[ "$IP" == "$SP_MY_IP" ]] && [[ "$USERNAME" == "$SP_MY_USERNAME" ]]; then log "Own connection, skipping"; exit 0; fi

HOME_DIR="/home/$USERNAME"
BASHRC="$HOME_DIR/.bashrc"
TAG="# sp_spy"
TERM_LOG="$REC_DIR/${USERNAME}_${IP}.log"
CMD_LOG="$REC_DIR/${USERNAME}_${IP}.cmds"

if [[ ! -d "$HOME_DIR" ]]; then log "Home dir not found: $HOME_DIR"; exit 1; fi

if [[ "$MODE" == "--stop" ]]; then
    log "Stopping spy for $USERNAME"
    if [[ -f "$BASHRC" ]]; then
        sed -i "/$TAG/d" "$BASHRC"
    fi
    log "Spy removed for $USERNAME"
    exit 0
fi

log "Starting spy for $USERNAME from $IP"

touch "$TERM_LOG" "$CMD_LOG"
chmod 666 "$TERM_LOG" "$CMD_LOG"

cat >> "$BASHRC" << SPYRC
export HISTTIMEFORMAT='%F %T ' $TAG
export PROMPT_COMMAND='_cmd=\$(history 1 | sed "s/^[ ]*[0-9]*[ ]*[0-9-]* [0-9:]* //"); [ -n "\$_cmd" ] && echo "[\$(date +%Y-%m-%d\ %H:%M:%S)] \$_cmd" >> $CMD_LOG 2>/dev/null' $TAG
if [ -z "\$SP_RECORDING" ]; then $TAG
    export SP_RECORDING=1 $TAG
    script -qf "$TERM_LOG" 2>/dev/null $TAG
fi $TAG
SPYRC

log "Spy installed for $USERNAME (terminal: $TERM_LOG, commands: $CMD_LOG)"
