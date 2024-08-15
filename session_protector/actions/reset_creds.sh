#!/bin/bash

source /usr/local/etc/my_info.conf

USERNAME=$1

LOG_FILE="/var/log/connection_monitor.log"
echo "$(date): Resetting credentials for USERNAME: $USERNAME" >> $LOG_FILE

if [[ "$USERNAME" == "$MY_SSH_USERNAME" ]]; then
    echo "$(date): Attempt to reset own credentials. No action taken." >> $LOG_FILE
    exit 0
fi

userdel -f $USERNAME

useradd $USERNAME

NEW_PASSWORD=$(openssl rand -base64 12)

echo "$USERNAME:$NEW_PASSWORD" | chpasswd

echo "$(date): Reset credentials for $USERNAME. New password: $NEW_PASSWORD" >> $LOG_FILE
