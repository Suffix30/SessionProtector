#!/bin/bash

TARGET_MACHINES=("username1@target_ip_1" "username2@target_ip_2") # List of target machines
TARGET_DIR="/var/tmp/.cache"
LOCAL_DIR="$(pwd)"
CONFIG_FILE="garbage/scooby_snacks.conf"
ENCRYPTED_CONFIG_FILE="garbage/scooby_snacks.conf.enc"
PASSWORD="your_password" # Replace with your encryption password
REQUIREMENTS_FILE="requirements.txt"
LOG_FILE="deployment.log"

encrypt_config() {
    if [ -f "$LOCAL_DIR/$CONFIG_FILE" ]; then
        echo "[*] Encrypting the configuration file..."
        openssl enc -aes-256-cbc -salt -in "$LOCAL_DIR/$CONFIG_FILE" -out "$LOCAL_DIR/$ENCRYPTED_CONFIG_FILE" -k "$PASSWORD"
        if [ $? -ne 0 ]; then
            echo "[!] Encryption failed."
            exit 1
        fi
        echo "[*] Encryption successful."
    else
        echo "[!] Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
}

deploy_to_machine() {
    local MACHINE=$1

    echo "[*] Starting deployment to $MACHINE..." | tee -a "$LOG_FILE"
    scp -r "$LOCAL_DIR" $MACHINE:"$TARGET_DIR" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "[!] File transfer to $MACHINE failed." | tee -a "$LOG_FILE"
        return 1
    fi

    ssh $MACHINE << EOF
cd "$TARGET_DIR"

echo "[*] Installing dependencies on $MACHINE..."
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y python3 python3-pip python3-tk python3-pil python3-pil.imagetk openssl x11-xserver-utils iptables > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "[!] Dependency installation on $MACHINE failed."
    exit 1
fi

if [ -f "$REQUIREMENTS_FILE" ]; then
    pip3 install -r "$REQUIREMENTS_FILE" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "[!] Python dependencies installation on $MACHINE failed."
        exit 1
    fi
fi

chmod +x actions/*.sh
chmod +x monitor/*.sh
chmod +x gui/popup.py

echo "[*] Running the main.sh script on $MACHINE..."
./monitor/main.sh & > /dev/null 2>&1
EOF

    if [ $? -eq 0 ]; then
        echo "[*] Deployment to $MACHINE successful." | tee -a "$LOG_FILE"
        return 0
    else
        echo "[!] Deployment to $MACHINE failed." | tee -a "$LOG_FILE"
        return 1
    fi
}

health_check() {
    local MACHINE=$1
    ssh $MACHINE << EOF
ps aux | grep -v grep | grep -q "./monitor/main.sh"
EOF
    if [ $? -eq 0 ]; then
        echo "[*] Health check passed on $MACHINE. Monitoring script is running." | tee -a "$LOG_FILE"
    else
        echo "[!] Health check failed on $MACHINE. Monitoring script is not running." | tee -a "$LOG_FILE"
    fi
}

encrypt_config

for MACHINE in "${TARGET_MACHINES[@]}"; do
    deploy_to_machine "$MACHINE"
    if [ $? -eq 0 ]; then
        health_check "$MACHINE"
    fi
done

echo "[*] Deployment process complete." | tee -a "$LOG_FILE"
