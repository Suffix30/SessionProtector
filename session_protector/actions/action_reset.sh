#!/bin/bash
IP="$1"
USERNAME="$2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/../logs/actions.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "$(date): [RESET] $*" >> "$LOG_FILE"; }

if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9_]+$ ]]; then log "Invalid username: $USERNAME"; exit 1; fi
if [[ "$USERNAME" == "$SP_MY_USERNAME" ]]; then log "Attempt to reset own credentials, skipping"; exit 0; fi
if [[ "$USERNAME" == "root" ]]; then log "Attempt to reset root, skipping"; exit 0; fi

log "Resetting credentials for $USERNAME"

pkill -u "$USERNAME" 2>/dev/null
userdel -rf "$USERNAME" 2>/dev/null
useradd -m "$USERNAME" 2>/dev/null
NEW_PASSWORD=$(openssl rand -base64 12)
echo "$USERNAME:$NEW_PASSWORD" | chpasswd

log "Credentials reset for $USERNAME (new password: $NEW_PASSWORD)"
echo "Password for $USERNAME: $NEW_PASSWORD"
