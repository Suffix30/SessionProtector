import sys
import os
import subprocess
import re
import time
from threading import Thread

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

def covert_notify(ip, username):
    log_action("Covert Notification", ip, username)

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
                covert_notify(ip, username)
                kill_connection(ip, username)

if __name__ == "__main__":
    if not os.path.exists(LOG_FILE):
        open(LOG_FILE, "w").close()

    monitor_thread = Thread(target=monitor_connections)
    monitor_thread.daemon = True
    monitor_thread.start()

    try:
        print("Covert monitoring started. Press Ctrl+C to stop.")
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Exiting.")
