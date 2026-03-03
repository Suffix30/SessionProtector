#!/bin/bash
IP="$1"
USERNAME="$2"
MODE="${3:---start}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/../logs/actions.log"
PID_FILE="$SCRIPT_DIR/../logs/popups_${USERNAME}_${IP}.pid"
mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "$(date): [POPUPS] $*" >> "$LOG_FILE"; }

if [[ ! "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then log "Invalid IP: $IP"; exit 1; fi
if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9_]+$ ]]; then log "Invalid username: $USERNAME"; exit 1; fi
if [[ "$IP" == "$SP_MY_IP" ]] && [[ "$USERNAME" == "$SP_MY_USERNAME" ]]; then log "Own connection, skipping"; exit 0; fi

if [[ "$MODE" == "--stop" ]]; then
    log "Stopping popups for $USERNAME"
    if [[ -f "$PID_FILE" ]]; then
        kill -- -$(cat "$PID_FILE") 2>/dev/null
        rm -f "$PID_FILE"
    fi
    log "Popups stopped for $USERNAME"
    exit 0
fi

log "Starting popups for $USERNAME from $IP"

setsid python3 -c "
import random
import time

messages = [
    'TRY HARDER!!',
    'SESSION PROTECTOR IS WATCHING',
    'ALL YOUR BASE ARE BELONG TO US',
    'RESISTANCE IS FUTILE',
    'GIT GUD',
    'HACK THE PLANET... JUST NOT THIS ONE',
]

def spawn_popup():
    try:
        import tkinter as tk
        root = tk.Tk()
        root.title('Alert')
        root.configure(bg='black')
        root.attributes('-topmost', True)
        root.geometry('+%d+%d' % (random.randint(0, 800), random.randint(0, 600)))
        msg = random.choice(messages)
        tk.Label(root, text=msg, font=('Helvetica', 20, 'bold'),
                 fg='red', bg='black').pack(padx=20, pady=20)
        root.after(5000, root.destroy)
        root.mainloop()
    except:
        pass

for _ in range(15):
    spawn_popup()
    time.sleep(random.randint(5, 20))
" &>/dev/null &
echo $! > "$PID_FILE"
log "Popup spam launched for $USERNAME"
