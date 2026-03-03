# SessionProtector (KOTH / EPO)

A defensive prank tool for King of the Hill CTF matches. Monitors SSH connections on a target machine, detects intruders in real time, and gives you a web dashboard with granular toggleable actions to mess with them.

## Features

- Real-time SSH connection monitoring via `/var/log/auth.log`
- Auto-ignores your own connections
- Live terminal viewer with full session recording
- Command history logging (timestamps + commands)
- 11 individual action buttons per attacker, most toggleable (start/stop)
- Spy streams start automatically for every attacker on connect
- All session data buffered -- switch between attackers without losing history
- Structured log export for post-match review

## Action Buttons

| Button | Type | What It Does |
|--------|------|-------------|
| **Fake Files** | Toggle | Plants fake documents, downloads, desktop files, and credentials |
| **Fake Cmds** | Toggle | Injects 18 fake command aliases into their `.bashrc` |
| **Shell Chaos** | Toggle | Flashing prompt, random command delays, dumb terminal, red background |
| **Keyboard** | Toggle | `bash bind` key remaps + `stty` chaos (swap backspace/enter, etc.) |
| **Sounds** | Toggle | Cranks volume, random beeps, keypress beeps |
| **Messages** | Toggle | Targeted terminal messages via `write`, periodic reminders, cron messages |
| **Popups** | Toggle | Spawns tkinter popup windows with troll messages (graphical sessions only) |
| **Passwords** | One-shot | Rotates root and attacker passwords to random strings |
| **Spy** | Toggle | Session recording via `script` + command logging (auto-started) |
| **Kill** | One-shot | Blocks IP with iptables, kills processes, deletes user account |
| **Reset** | One-shot | Kills processes, deletes and recreates user with new random password |

## Dashboard Layout

- **Left sidebar**: Attacker list with active action badges and command counts
- **Center**: Large live terminal viewer showing everything the attacker types and sees
- **Right panel**: Action button grid (2-column) + scrolling command history
- **Bottom bar**: Collapsible event log

## Directory Structure

```
SessionProtector/
  requirements.txt
  .gitignore
  session_protector/
    app.py                         # Flask web dashboard + API + SSE
    monitor.py                     # auth.log watcher + disconnect detection
    config.env                     # Your IP + username (gitignored)
    actions/
      action_fake_files.sh
      action_fake_cmds.sh
      action_shell_chaos.sh
      action_keyboard.sh
      action_sounds.sh
      action_messages.sh
      action_popups.sh
      action_passwords.sh
      action_spy.sh
      action_kill.sh
      action_reset.sh
    templates/
      dashboard.html
    static/
      style.css
      app.js
```

## Setup

### 1. Configure

Set environment variables or create `session_protector/config.env`:

```bash
MY_HTB_IP="10.10.14.XX"
MY_SSH_USERNAME="your_username"
```

Or export them directly:

```bash
export SP_MY_IP="10.10.14.XX"
export SP_MY_USERNAME="your_username"
```

### 2. Deploy to Target

Copy the `session_protector/` directory and `requirements.txt` to the target machine:

```bash
scp -r session_protector/ requirements.txt user@target:/var/tmp/.sp/
```

### 3. Start on Target

SSH in and run as root:

```bash
ssh user@target
sudo bash
cd /var/tmp/.sp/session_protector
export SP_MY_IP="10.10.14.XX" SP_MY_USERNAME="your_username"
chmod +x actions/*.sh
pip3 install flask
python3 app.py
```

The dashboard runs on port 5000. Access it via SSH tunnel or directly if the network allows.

### 4. Access Dashboard

Option A -- SSH tunnel:
```bash
ssh -L 5000:localhost:5000 user@target
# then open http://localhost:5000
```

Option B -- Direct (if Flask binds to 0.0.0.0):
```
http://<target_ip>:5000
```

## Usage

1. Attackers appear in the sidebar as they SSH in
2. Spy recording starts automatically
3. Click an attacker to see their live terminal and full command history
4. Press action buttons to activate/deactivate effects
5. Attacker must reload their shell (`bash`) for `.bashrc` changes to take effect
6. Use **Kill** to permanently boot them, **Reset** to lock them out with a new password

## Prerequisites

Target machine needs:
- Python 3 with Flask
- `bash`, `sudo`, `script`, `iptables`, `chpasswd`
- Optional: `aplay` (sounds), `python3-tk` (popups), `xmodmap` (graphical keyboard scramble)

## Log Export

Click "Download Logs" in the dashboard header to get a zip of all session recordings and action logs.

## Cleanup

Remove all traces from a target:

```bash
sudo rm -rf /var/tmp/.sp
sudo crontab -r
sudo iptables -F
```

## License

MIT
