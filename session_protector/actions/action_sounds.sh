#!/bin/bash
IP="$1"
USERNAME="$2"
MODE="${3:---start}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/../logs/actions.log"
PID_FILE="$SCRIPT_DIR/../logs/sounds_${USERNAME}_${IP}.pid"
mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "$(date): [SOUNDS] $*" >> "$LOG_FILE"; }

if [[ ! "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then log "Invalid IP: $IP"; exit 1; fi
if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9_]+$ ]]; then log "Invalid username: $USERNAME"; exit 1; fi
if [[ "$IP" == "$SP_MY_IP" ]] && [[ "$USERNAME" == "$SP_MY_USERNAME" ]]; then log "Own connection, skipping"; exit 0; fi

HOME_DIR="/home/$USERNAME"
BASHRC="$HOME_DIR/.bashrc"
TAG="# sp_sounds"

if [[ "$MODE" == "--stop" ]]; then
    log "Stopping sounds for $USERNAME"
    if [[ -f "$PID_FILE" ]]; then
        kill -- -$(cat "$PID_FILE") 2>/dev/null
        rm -f "$PID_FILE"
    fi
    if [[ -f "$BASHRC" ]]; then
        sed -i "/$TAG/d" "$BASHRC"
    fi
    log "Sounds stopped for $USERNAME"
    exit 0
fi

log "Starting sounds for $USERNAME from $IP"

if command -v amixer &>/dev/null; then
    amixer set Master 100% unmute 2>/dev/null
    log "Volume cranked to 100%"
elif command -v pactl &>/dev/null; then
    pactl set-sink-volume @DEFAULT_SINK@ 100% 2>/dev/null
    pactl set-sink-mute @DEFAULT_SINK@ 0 2>/dev/null
    log "Volume cranked to 100% (pulseaudio)"
fi

if command -v aplay &>/dev/null; then
    setsid bash -c '
    for i in $(seq 1 20); do
        python3 -c "
import struct, wave, math, tempfile, os
f = tempfile.NamedTemporaryFile(suffix=\".wav\", delete=False)
nframes = 4000
with wave.open(f.name, \"w\") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(8000)
    for n in range(nframes):
        v = int(32767 * math.sin(2 * math.pi * 800 * n / 8000))
        w.writeframes(struct.pack(\"<h\", v))
os.system(\"aplay \" + f.name + \" 2>/dev/null\")
os.unlink(f.name)
" 2>/dev/null
        sleep $((RANDOM % 10 + 3))
    done
    ' &>/dev/null &
    echo $! > "$PID_FILE"
    log "Random beep sounds scheduled"
fi

if [[ -d "$HOME_DIR" ]] && [[ -f "$BASHRC" ]]; then
    cat >> "$BASHRC" << 'BEEPRC'
BEEP() { python3 -c "
import struct,wave,math,tempfile,os
f=tempfile.NamedTemporaryFile(suffix='.wav',delete=False)
with wave.open(f.name,'w') as w:
    w.setnchannels(1);w.setsampwidth(2);w.setframerate(8000)
    for n in range(2000):
        w.writeframes(struct.pack('<h',int(32767*math.sin(2*3.14159*600*n/8000))))
os.system('aplay '+f.name+' 2>/dev/null &');os.unlink(f.name)
" 2>/dev/null; }
BEEPRC
    echo "bind -x '\"\C-m\": BEEP' $TAG" >> "$BASHRC"
    log "Keypress beep installed in bashrc"
fi

log "Sounds started for $USERNAME"
