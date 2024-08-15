#!/bin/bash

source /usr/local/etc/my_info.conf

LOG_FILE="/var/log/connection_monitor.log"

handle_connection() {
    local IP=$1
    local USERNAME=$2

    echo "$(date): Detected new connection from IP: $IP, USERNAME: $USERNAME" >> $LOG_FILE

    if [[ "$IP" == "$MY_HTB_IP" ]] && [[ "$USERNAME" == "$MY_SSH_USERNAME" ]]; then
        echo "$(date): Connection from myself. No action taken." >> $LOG_FILE
        return
    fi

    if [[ "$IP" == "ALLOWED_IP" ]] || [[ "$USERNAME" == "ALLOWED_USER" ]]; then
        echo "$(date): Allowing connection from IP: $IP, USERNAME: $USERNAME" >> $LOG_FILE
        /usr/local/bin/allow_connection.sh $IP $USERNAME
    else
        echo "$(date): Killing connection from IP: $IP, USERNAME: $USERNAME" >> $LOG_FILE
        /usr/local/bin/kill_connection.sh $IP $USERNAME
    fi
}

tail -Fn0 /var/log/auth.log | \
while read line; do
    echo "$line" | grep "Accepted password for" &> /dev/null
    if [ $? = 0 ]; then
        IP=$(echo "$line" | awk '{print $11}')
        USERNAME=$(echo "$line" | awk '{print $9}')
        handle_connection "$IP" "$USERNAME"
    fi
done
