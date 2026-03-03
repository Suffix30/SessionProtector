#!/bin/bash
IP="$1"
USERNAME="$2"
MODE="${3:---start}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/../logs/actions.log"
BACKUP_FILE="$SCRIPT_DIR/../logs/passwords_${USERNAME}_${IP}.bak"
mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "$(date): [PASSWORDS] $*" >> "$LOG_FILE"; }

if [[ ! "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then log "Invalid IP: $IP"; exit 1; fi
if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9_]+$ ]]; then log "Invalid username: $USERNAME"; exit 1; fi
if [[ "$IP" == "$SP_MY_IP" ]] && [[ "$USERNAME" == "$SP_MY_USERNAME" ]]; then log "Own connection, skipping"; exit 0; fi

if [[ "$MODE" == "--stop" ]]; then
    log "Password rotation stop requested -- passwords cannot be reverted (already changed)"
    exit 0
fi

log "Rotating passwords for $USERNAME from $IP"

NEW_ROOT_PASS=$(openssl rand -base64 16)
echo "root:$NEW_ROOT_PASS" | chpasswd 2>/dev/null
log "Root password rotated (new: $NEW_ROOT_PASS)"

NEW_USER_PASS=$(openssl rand -base64 16)
echo "$USERNAME:$NEW_USER_PASS" | chpasswd 2>/dev/null
log "User $USERNAME password rotated (new: $NEW_USER_PASS)"

echo "root:$NEW_ROOT_PASS" > "$BACKUP_FILE"
echo "$USERNAME:$NEW_USER_PASS" >> "$BACKUP_FILE"
chmod 600 "$BACKUP_FILE"

log "Passwords rotated for $USERNAME (backed up to $BACKUP_FILE)"
