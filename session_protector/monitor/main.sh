#!/bin/bash

ENCRYPTED_CONFIG_FILE="/usr/local/etc/scooby_snacks.conf.enc"
DECRYPTED_CONFIG_FILE=$(mktemp)
MAIN_LOG_FILE="/var/log/main.log"

openssl enc -aes-256-cbc -d -in $ENCRYPTED_CONFIG_FILE -out $DECRYPTED_CONFIG_FILE -k "your_password" 2>/dev/null
if [ $? -ne 0 ]; then
  echo "$(date): Error - Failed to decrypt configuration file." >> $MAIN_LOG_FILE
  exit 1
fi

source $DECRYPTED_CONFIG_FILE
shred -u $DECRYPTED_CONFIG_FILE

if [ -z "$MY_HTB_IP" ] || [ -z "$MY_SSH_USERNAME" ]; then
  echo "$(date): Error - Environment variables MY_HTB_IP and MY_SSH_USERNAME must be set." >> $MAIN_LOG_FILE
  exit 1
fi

echo "$(date): Starting connection monitoring..." >> $MAIN_LOG_FILE

/usr/local/bin/monitor_connections.sh &

reset_credentials() {
    local USERNAME=$1
    echo "$(date): Resetting credentials for USERNAME: $USERNAME" >> $MAIN_LOG_FILE
    /usr/local/bin/reset_creds.sh $USERNAME
}

tail -Fn0 /var/log/auth.log | while read line; do
    if echo "$line" | grep -q "Accepted password for"; then
        IP=$(echo "$line" | awk '{print $11}')
        USERNAME=$(echo "$line" | awk '{print $9}')
        
        if [[ "$IP" == "$MY_HTB_IP" ]] && [[ "$USERNAME" == "$MY_SSH_USERNAME" ]]; then
            echo "$(date): Connection from myself. No action taken." >> $MAIN_LOG_FILE
        else
            /usr/local/bin/popup.py "$IP" "$USERNAME"
        fi
    fi
done
