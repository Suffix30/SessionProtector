#!/bin/bash

source /usr/local/etc/my_info.conf

LOG_FILE="/var/log/connection_monitor.log"
ALLOWED_IPS=("/path/to/allowed_ips.txt")
ALLOWED_USERS=("/path/to/allowed_users.txt")

handle_connection() {
    local IP=$1
    local USERNAME=$2

    echo "$(date): Detected new connection from IP: $IP, USERNAME: $USERNAME" >> $LOG_FILE

    if [[ "$IP" == "$MY_HTB_IP" ]] && [[ "$USERNAME" == "$MY_SSH_USERNAME" ]]; then
        echo "$(date): Connection from myself. No action taken." >> $LOG_FILE
        return
    fi

    if grep -Fxq "$IP" "$ALLOWED_IPS" || grep -Fxq "$USERNAME" "$ALLOWED_USERS"; then
        echo "$(date): Allowing connection from IP: $IP, USERNAME: $USERNAME" >> $LOG_FILE
        /usr/local/bin/allow_connection.sh "$IP" "$USERNAME"
    else
        echo "$(date): Killing connection from IP: $IP, USERNAME: $USERNAME" >> $LOG_FILE
        /usr/local/bin/kill_connection.sh "$IP" "$USERNAME"
    fi
}

validate_environment() {
    if [[ -z "$MY_HTB_IP" || -z "$MY_SSH_USERNAME" ]]; then
        echo "$(date): Error - Required environment variables MY_HTB_IP or MY_SSH_USERNAME are not set." >> $LOG_FILE
        exit 1
    fi

    if [[ ! -f "$ALLOWED_IPS" || ! -f "$ALLOWED_USERS" ]]; then
        echo "$(date): Error - Allowed IPs or users file is missing." >> $LOG_FILE
        exit 1
    fi
}

validate_environment

tail -Fn0 /var/log/auth.log | while read -r line; do
    if echo "$line" | grep -q "Accepted password for"; then
        IP=$(echo "$line" | awk '{print $11}')
        USERNAME=$(echo "$line" | awk '{print $9}')
        handle_connection "$IP" "$USERNAME"
    fi
done
