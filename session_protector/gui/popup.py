import sys
import tkinter as tk
from tkinter import messagebox
import os
import subprocess
import re
from threading import Thread
import time

LOG_FILE = "/var/log/connection_popup.log"

def log_action(action, ip, username):
    with open(LOG_FILE, "a") as log:
        log.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} - {action} - {ip} ({username})\n")

def execute_command(command):
    try:
        subprocess.run(command, shell=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        log_action("SUCCESS", command, "")
    except subprocess.CalledProcessError as e:
        log_action("ERROR", command, e.stderr.decode().strip())

def kill_connection(ip, username):
    execute_command(f"/usr/local/bin/kill_connection.sh {ip} {username}")
    log_action("Kill Connection", ip, username)

def allow_connection(ip, username):
    execute_command(f"/usr/local/bin/allow_connection.sh {ip} {username}")
    log_action("Allow Connection", ip, username)

def popup(ip, username):
    root = tk.Tk()
    root.title("Connection Alert")

    window_width = 300
    window_height = 150
    screen_width = root.winfo_screenwidth()
    screen_height = root.winfo_screenheight()
    position_top = int(screen_height / 2 - window_height / 2)
    position_right = int(screen_width / 2 - window_width / 2)
    root.geometry(f"{window_width}x{window_height}+{position_right}+{position_top}")

    label = tk.Label(root, text=f"Incoming connection from {ip} ({username})", wraplength=280)
    label.pack(pady=10)

    button_frame = tk.Frame(root)
    button_frame.pack(pady=10)

    kill_button = tk.Button(button_frame, text="Kill Connection", command=lambda: [kill_connection(ip, username), root.destroy()])
    kill_button.pack(side="left", padx=10)

    allow_button = tk.Button(button_frame, text="Allow Connection", command=lambda: [allow_connection(ip, username), root.destroy()])
    allow_button.pack(side="right", padx=10)

    root.mainloop()

def monitor_connections():
    with open("/var/log/auth.log", "r") as log:
        log.seek(0, os.SEEK_END)
        while True:
            line = log.readline()
            if not line:
                time.sleep(1)
                continue

            match = re.search(r"Accepted password for (\w+) from (\d+\.\d+\.\d+\.\d+)", line)
            if match:
                username, ip = match.groups()
                log_action("New Connection Detected", ip, username)
                popup(ip, username)

if __name__ == "__main__":
    if not os.path.exists(LOG_FILE):
        open(LOG_FILE, "w").close()

    monitor_thread = Thread(target=monitor_connections)
    monitor_thread.daemon = True
    monitor_thread.start()

    try:
        print("Monitoring started. Press Ctrl+C to stop.")
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Exiting.")
