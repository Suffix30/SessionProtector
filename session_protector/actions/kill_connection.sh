#!/bin/bash

source /usr/local/etc/my_info.conf

IP=$1
USERNAME=$2

echo "$(date): Killing connection from IP: $IP, USERNAME: $USERNAME" >> /var/log/connection_actions.log

if [[ ! $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid IP address format: $IP" >> /var/log/connection_actions.log
  exit 1
fi

if [[ ! $USERNAME =~ ^[a-zA-Z0-9_]+$ ]]; then
  echo "Invalid USERNAME format: $USERNAME" >> /var/log/connection_actions.log
  exit 1
fi

if [[ "$IP" == "$MY_HTB_IP" ]] && [[ "$USERNAME" == "$MY_SSH_USERNAME" ]]; then
  echo "Connection from myself. No action taken." >> /var/log/connection_actions.log
  exit 0
fi

ssh $USERNAME@$IP 'bash -s' << 'ENDSSH'
  python3 - << 'ENDPYTHON'
import tkinter as tk
from tkinter import messagebox
from PIL import Image, ImageTk
import os
import time

def on_closing():
    root.destroy()
    os.system("pkill -u $USERNAME; sudo iptables -A INPUT -s $IP -j DROP")

root = tk.Tk()
root.title("Notification")

# Load the image
image_path = "/path/to/your/image.png"  # Replace with the actual path to your image
image = Image.open(image_path)
photo = ImageTk.PhotoImage(image)

# Display the image
image_label = tk.Label(root, image=photo)
image_label.pack(pady=10)

# Display the message
message = tk.Label(root, text="TRY HARDER!! Connection will terminate in 5 seconds.")
message.pack(pady=20)

# Countdown label
countdown_label = tk.Label(root, text="", font=("Helvetica", 16))
countdown_label.pack(pady=10)

def countdown(count):
    if count >= 0:
        countdown_label.config(text=str(count))
        root.after(1000, countdown, count-1)
    else:
        on_closing()

countdown(5)
root.protocol("WM_DELETE_WINDOW", on_closing)
root.mainloop()
ENDPYTHON
ENDSSH

iptables -A INPUT -s $IP -j DROP
echo "$(date): IP address $IP has been blocked using iptables" >> /var/log/connection_actions.log

pkill -u $USERNAME
echo "$(date): All processes for user $USERNAME have been killed" >> /var/log/connection_actions.log

userdel -r $USERNAME
echo "$(date): User $USERNAME has been removed from the system" >> /var/log/connection_actions.log

echo "$(date): Connection from IP: $IP, USERNAME: $USERNAME has been killed" >> /var/log/connection_actions.log
