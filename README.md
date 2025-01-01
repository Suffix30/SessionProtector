# Session Protector Deployment Guide ( KOTH ) == EPO

## Prerequisites

- **Access to Target Machines**: Ensure you have SSH access to the target machines.
- **Correct Credentials**: Update your scripts with the correct SSH credentials for each target machine.
- **Local Machine Setup**: Ensure that your local machine has the following tools installed:
  - `scp`
  - `ssh`
  - `openssl`
  - Python 3 with `pip3`

## Directory Structure

Ensure your project follows this structure:

```
session_protector/
│
├── actions/
│   ├── allow_connection.sh
│   ├── kill_connection.sh
│   └── reset_creds.sh
├── garbage/
│   ├── scooby_snacks.conf
│   └── scooby_snacks.conf.enc
├── gui/
│   └── popup.py
├── monitor/
│   ├── LICENSE
│   ├── README.md
├── deploy.sh
├── requirements.txt
```

## Step 1: Preparation

### 1.1 Encrypt Configuration File

Encrypt the `scooby_snacks.conf` file before deployment:

```bash
openssl enc -aes-256-cbc -salt -in garbage/scooby_snacks.conf -out garbage/scooby_snacks.conf.enc -k "your_password"
```

This ensures sensitive information like `MY_HTB_IP` and `MY_SSH_USERNAME` remains secure.

### 1.2 Edit `deploy.sh`

Update the `TARGET_MACHINES` array in `deploy.sh` with the target machine details:

```bash
TARGET_MACHINES=("username1@target_ip_1" "username2@target_ip_2")
```

Review the other variables in `deploy.sh`, such as:
- `TARGET_DIR` (default: `/var/tmp/.cache`)
- `PASSWORD` (used for encryption)

### 1.3 Install Dependencies Locally

Install the required Python dependencies from `requirements.txt`:

```bash
pip3 install -r requirements.txt
```

Ensure `deploy.sh` and all scripts in `actions` and `monitor` directories are executable:

```bash
chmod +x deploy.sh
chmod +x actions/*.sh
chmod +x gui/popup.py
```

---

## Step 2: Deployment

### 2.1 Deploy to Target Machines

Run the deployment script to set up the system on all specified target machines:

```bash
./deploy.sh
```

This script will:
- Encrypt `scooby_snacks.conf`.
- Transfer the `session_protector` directory to `/var/tmp/.cache` on each target machine.
- Install all dependencies silently on the target machines.
- Start the monitoring script (`popup.py`) and `main.sh` in the background.

---

## Step 3: Monitoring and Management

### 3.1 Check Running Processes

To verify the scripts are running, SSH into a target machine and check for the processes:

```bash
ssh username@target_ip_1
ps aux | grep -E "popup.py|main.sh"
```

### 3.2 Retrieve Logs

Logs from the monitoring script (`popup.py`) are stored at `/var/log/connection_popup.log`. Retrieve them using `scp`:

```bash
scp username@target_ip_1:/var/log/connection_popup.log ./logs/target_ip_1.log
```

### 3.3 Adjust or Restart Scripts

If you need to make adjustments:

1. SSH into the target machine.
2. Navigate to the deployed directory:
   ```bash
   cd /var/tmp/.cache
   ```
3. Edit the required files, then restart the script:
   ```bash
   ./monitor/main.sh &
   ```

---

## Step 4: Automated Monitoring

### 4.1 Enable Persistent Monitoring

Set up `popup.py` as a systemd service to restart automatically on failure:

```bash
sudo nano /etc/systemd/system/popup.service
```

Add the following:

```ini
[Unit]
Description=Covert Monitoring Script
After=network.target

[Service]
ExecStart=/usr/bin/python3 /var/tmp/.cache/gui/popup.py
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start the service:

```bash
sudo systemctl enable popup.service
sudo systemctl start popup.service
```

### 4.2 Automate Log Retrieval

Schedule a cron job to pull logs periodically to your local machine:

```bash
crontab -e
```

Add:

```bash
0 * * * * scp username@target_ip_1:/var/log/connection_popup.log /path/to/local/logs/
```

---

## Step 5: Cleanup and Stealth

### 5.1 Remove Files from Target Machines

To clean up all traces of the deployment on the target machine:

```bash
ssh username@target_ip_1
rm -rf /var/tmp/.cache
```

### 5.2 Clear Bash History

Clear the bash history on the target machine to remove traces of your commands:

```bash
history -c
```

---

## Step 6: Logging and Review

### 6.1 Local Log Review

Consolidate all logs from the target machines into a local directory for review:

```bash
mkdir -p logs
scp username@target_ip_1:/var/log/connection_popup.log logs/target_ip_1.log
scp username@target_ip_2:/var/log/connection_popup.log logs/target_ip_2.log
```

### 6.2 Analyze Logs

Analyze the retrieved logs to understand connection activities and actions taken.

---


