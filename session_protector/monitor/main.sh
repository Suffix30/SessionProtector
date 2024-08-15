#!/bin/bash

ENCRYPTED_CONFIG_FILE="/usr/local/etc/scooby_snacks.conf.enc"

DECRYPTED_CONFIG_FILE=$(mktemp)

openssl enc -aes-256-cbc -d -in $ENCRYPTED_CONFIG_FILE -out $DECRYPTED_CONFIG_FILE -k "your_password"

source $DECRYPTED_CONFIG_FILE

if [ -z "$MY_HTB_IP" ] || [ -z "$MY_SSH_USERNAME" ]; then
  echo "$(date): Error - Environment variables MY_HTB_IP and MY_SSH_USERNAME must be set." >> /var/log/main_error.log
  shred -u $DECRYPTED_CONFIG_FILE
  exit 1
fi

shred -u $DECRYPTED_CONFIG_FILE

MAIN_LOG_FILE="/var/log/main.log"

echo "$(date): Starting connection monitoring..." >> $MAIN_LOG_FILE

/usr/local/bin/monitor_connections.sh &

reset_credentials() {
    local USERNAME=$1
    echo "$(date): Resetting credentials for USERNAME: $USERNAME" >> $MAIN_LOG_FILE
    /usr/local/bin/reset_creds.sh $USERNAME
}

tail -Fn0 /var/log/auth.log | \
while read line; do
    echo "$line" | grep "Accepted password for" &> /dev/null
    if [ $? = 0 ]; then
        IP=$(echo "$line" | awk '{print $11}')
        USERNAME=$(echo "$line" | awk '{print $9}')
        
        if [[ "$IP" == "$MY_HTB_IP" ]] && [[ "$USERNAME" == "$MY_SSH_USERNAME" ]]; then
            echo "$(date): Connection from myself. No action taken." >> $MAIN_LOG_FILE
        else
            /usr/local/bin/popup.py "$IP" "$USERNAME"
        fi
    fi
done
