#!/bin/bash
IP="$1"
USERNAME="$2"
MODE="${3:---start}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/../logs/actions.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "$(date): [FAKE_FILES] $*" >> "$LOG_FILE"; }

if [[ ! "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then log "Invalid IP: $IP"; exit 1; fi
if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9_]+$ ]]; then log "Invalid username: $USERNAME"; exit 1; fi
if [[ "$IP" == "$SP_MY_IP" ]] && [[ "$USERNAME" == "$SP_MY_USERNAME" ]]; then log "Own connection, skipping"; exit 0; fi

HOME_DIR="/home/$USERNAME"
if [[ ! -d "$HOME_DIR" ]]; then log "Home dir not found: $HOME_DIR"; exit 1; fi

if [[ "$MODE" == "--stop" ]]; then
    log "Removing fake files for $USERNAME"
    rm -rf "$HOME_DIR/Documents/important_passwords.txt" \
           "$HOME_DIR/Documents/financial_records.xlsx" \
           "$HOME_DIR/Documents/secret_plans.doc" \
           "$HOME_DIR/Documents/bitcoin_wallet.dat" \
           "$HOME_DIR/Documents/admin_credentials.csv" \
           "$HOME_DIR/Downloads/totally_not_a_virus.exe" \
           "$HOME_DIR/Downloads/free_bitcoin.sh" \
           "$HOME_DIR/Downloads/hack_tool.zip" \
           "$HOME_DIR/Desktop/todo.txt" \
           "$HOME_DIR/.secret/credentials.txt" 2>/dev/null
    rmdir "$HOME_DIR/Documents" "$HOME_DIR/Downloads" "$HOME_DIR/Desktop" \
          "$HOME_DIR/Pictures" "$HOME_DIR/.secret" 2>/dev/null
    log "Fake files removed for $USERNAME"
    exit 0
fi

log "Planting fake files for $USERNAME from $IP"

mkdir -p "$HOME_DIR/Documents" "$HOME_DIR/Downloads" "$HOME_DIR/Desktop" \
         "$HOME_DIR/Pictures" "$HOME_DIR/.secret"

echo "GOTCHA! This file is fake." > "$HOME_DIR/Documents/important_passwords.txt"
echo "GOTCHA! This file is fake." > "$HOME_DIR/Documents/financial_records.xlsx"
echo "GOTCHA! This file is fake." > "$HOME_DIR/Documents/secret_plans.doc"
echo "GOTCHA! This file is fake." > "$HOME_DIR/Documents/bitcoin_wallet.dat"
echo "GOTCHA! This file is fake." > "$HOME_DIR/Documents/admin_credentials.csv"
echo "Nice try." > "$HOME_DIR/Downloads/totally_not_a_virus.exe"
echo "Nice try." > "$HOME_DIR/Downloads/free_bitcoin.sh"
echo "Nice try." > "$HOME_DIR/Downloads/hack_tool.zip"
echo "TODO: Stop getting trolled" > "$HOME_DIR/Desktop/todo.txt"
echo "The password is: TryHarder123" > "$HOME_DIR/.secret/credentials.txt"

chown -R "$USERNAME:$USERNAME" "$HOME_DIR/Documents" "$HOME_DIR/Downloads" \
    "$HOME_DIR/Desktop" "$HOME_DIR/Pictures" "$HOME_DIR/.secret" 2>/dev/null

log "Fake files planted for $USERNAME"
