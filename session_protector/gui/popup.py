import sys
import tkinter as tk
import os
from tkinter import messagebox

def kill_connection(ip, username):
    os.system(f"/usr/local/bin/kill_connection.sh {ip} {username}")

def allow_connection(ip, username):
    os.system(f"/usr/local/bin/allow_connection.sh {ip} {username}")

def popup(ip, username):
    root = tk.Tk()
    root.title("Connection Alert")

    window_width = 300
    window_height = 150
    screen_width = root.winfo_screenwidth()
    screen_height = root.winfo_screenheight()
    position_top = int(screen_height / 2 - window_height / 2)
    position_right = int(screen_width / 2 - window_width / 2)
    root.geometry(f'{window_width}x{window_height}+{position_right}+{position_top}')

    label = tk.Label(root, text=f"Incoming connection from {ip} ({username})")
    label.pack(pady=10)

    button_frame = tk.Frame(root)
    button_frame.pack(pady=10)

    kill_button = tk.Button(button_frame, text="Kill Connection", command=lambda: kill_connection(ip, username))
    kill_button.pack(side="left", padx=10)

    allow_button = tk.Button(button_frame, text="Allow Connection", command=lambda: allow_connection(ip, username))
    allow_button.pack(side="right", padx=10)

    root.mainloop()

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: popup.py <IP> <USERNAME>")
        sys.exit(1)

    popup(sys.argv[1], sys.argv[2])
