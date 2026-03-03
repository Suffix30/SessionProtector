#!/bin/bash
IP="$1"
USERNAME="$2"
MODE="${3:---start}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/../logs/actions.log"
PID_FILE="$SCRIPT_DIR/../logs/messages_${USERNAME}_${IP}.pid"
CRON_TAG="# sp_messages_${USERNAME}"
mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "$(date): [MESSAGES] $*" >> "$LOG_FILE"; }

if [[ ! "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then log "Invalid IP: $IP"; exit 1; fi
if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9_]+$ ]]; then log "Invalid username: $USERNAME"; exit 1; fi
if [[ "$IP" == "$SP_MY_IP" ]] && [[ "$USERNAME" == "$SP_MY_USERNAME" ]]; then log "Own connection, skipping"; exit 0; fi

send_to_user() {
    local msg="$1"
    local ttys
    ttys=$(who | grep "^$USERNAME " | awk '{print $2}')
    for tty in $ttys; do
        echo -e "\n\e[1;31m[SESSION PROTECTOR] $msg\e[0m\n" > "/dev/$tty" 2>/dev/null
    done
}

if [[ "$MODE" == "--stop" ]]; then
    log "Stopping messages for $USERNAME"
    if [[ -f "$PID_FILE" ]]; then
        kill -- -$(cat "$PID_FILE") 2>/dev/null
        rm -f "$PID_FILE"
    fi
    crontab -l 2>/dev/null | grep -v "$CRON_TAG" | crontab - 2>/dev/null
    log "Messages stopped for $USERNAME"
    exit 0
fi

log "Starting messages for $USERNAME from $IP"

send_to_user "You have been compromised. All your base are belong to us."
log "Initial message sent"

setsid bash -c '
for i in $(seq 1 10); do
    sleep $((RANDOM % 30 + 10))
    TTYS=$(who | grep "^'"$USERNAME"' " | awk '"'"'{print $2}'"'"')
    for tty in $TTYS; do
        echo -e "\n\e[1;31m[SESSION PROTECTOR] Reminder #'"'$i'"' - You are still compromised.\e[0m\n" > "/dev/$tty" 2>/dev/null
    done
done
' &>/dev/null &
echo $! > "$PID_FILE"
log "Periodic messages scheduled"

(crontab -l 2>/dev/null; echo "*/5 * * * * for t in \$(who | grep '^$USERNAME ' | awk '{print \$2}'); do echo '[SESSION PROTECTOR] Still watching you.' > /dev/\$t 2>/dev/null; done $CRON_TAG") | crontab - 2>/dev/null
(crontab -l 2>/dev/null; echo "*/10 * * * * for t in \$(who | grep '^$USERNAME ' | awk '{print \$2}'); do echo 'YOU HAVE BEEN PWNED' > /dev/\$t 2>/dev/null; done $CRON_TAG") | crontab - 2>/dev/null
log "Cron messages installed"

log "Messages started for $USERNAME"
