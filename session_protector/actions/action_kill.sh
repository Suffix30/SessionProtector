#!/bin/bash
IP="$1"
USERNAME="$2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/../logs/actions.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "$(date): [KILL] $*" >> "$LOG_FILE"; }

if [[ ! "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then log "Invalid IP: $IP"; exit 1; fi
if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9_]+$ ]]; then log "Invalid username: $USERNAME"; exit 1; fi
if [[ "$IP" == "$SP_MY_IP" ]] && [[ "$USERNAME" == "$SP_MY_USERNAME" ]]; then log "Own connection, skipping"; exit 0; fi

log "Killing connection from $IP ($USERNAME)"

iptables -A INPUT -s "$IP" -j DROP
log "Blocked $IP with iptables"

pkill -u "$USERNAME" 2>/dev/null
log "Killed processes for $USERNAME"

userdel -r "$USERNAME" 2>/dev/null
log "Removed user $USERNAME"

for pidfile in "$SCRIPT_DIR/../logs/"*"_${USERNAME}_${IP}.pid"; do
    if [[ -f "$pidfile" ]]; then
        kill -- -$(cat "$pidfile") 2>/dev/null
        rm -f "$pidfile"
    fi
done

crontab -l 2>/dev/null | grep -v "sp_messages_${USERNAME}" | crontab - 2>/dev/null

log "Kill complete for $IP ($USERNAME)"
