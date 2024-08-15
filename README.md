
# Session Protector Deployment Guide

## Prerequisites

- **Access to the Target Machine:** Ensure you have SSH access to the target machine.
- **Correct Credentials:** Update your scripts with the correct SSH credentials.
- **Local Machine Setup:** Ensure that your local machine has `scp` and `ssh` installed.

## Directory Structure

Your local project should have the following structure:

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
│   ├── main.sh
│   └── monitor_connections.sh
└── deploy.sh
```

## Step 1: Prepare the `deploy.sh` Script

### 1.1 Edit `deploy.sh`

- **Open `deploy.sh`:** Make sure `deploy.sh` is located in the root of the `session_protector` directory.
- **Update the SSH Credentials:**
  Replace the placeholder with your actual SSH credentials for the target machine:
  
  ```bash
  TARGET_MACHINE="username@target_ip_address" # <---- replace with target credentials.
  ```

### 1.2 Review Script Details

- **Encryption:** The `deploy.sh` script will encrypt `scooby_snacks.conf` before transferring files to the target machine.
- **Target Directory:** Files will be transferred to `/var/tmp/.cache` on the target machine.
- **Stealth Execution:** The script runs `main.sh` in the background without generating noticeable logs.

## Step 2: Execute the Deployment Script

### 2.1 Run the Deployment Script

1. **Navigate to `session_protector`:**
   ```bash
   cd /path/to/session_protector
   ```

2. **Make `deploy.sh` Executable:**
   ```bash
   chmod +x deploy.sh
   ```

3. **Run the Script:**
   Execute the script to encrypt your configuration, deploy everything to the target machine, and start the session protection:
   ```bash
   ./deploy.sh
   ```

### 2.2 What Happens Next

- **File Encryption:** The `scooby_snacks.conf` file is encrypted into `scooby_snacks.conf.enc` using AES-256-CBC encryption.
- **File Transfer:** The entire `session_protector` directory, including the encrypted configuration file, is transferred to `/var/tmp/.cache` on the target machine.
- **Dependency Installation:** Necessary packages and libraries are installed quietly on the target machine.
- **Script Execution:** `main.sh` is executed in the background, starting your session protection.

## Step 3: Monitoring and Adjustments

### 3.1 Monitor the Target Machine

After deployment, you may want to check if everything is running smoothly:

1. **SSH into the Target Machine:**
   ```bash
   ssh username@target_ip_address # <---- Replace with actual credentials. Refer to deploy.sh
   ```

2. **Check Processes:**
   Ensure `main.sh` is running in the background:
   ```bash
   ps aux | grep main.sh
   ```

### 3.2 Stopping or Adjusting the Scripts

If needed, you can stop the scripts or make adjustments:

- **To Stop the Script:**
  Kill the process associated with `main.sh`:
  ```bash
  pkill -f main.sh
  ```

- **To Make Adjustments:**
  Edit the necessary files in `/var/tmp/.cache` and restart `main.sh`:
  ```bash
  ./monitor/main.sh &
  ```

## Step 4: Cleanup

If you need to cover your tracks:

1. **Remove All Files:**
   ```bash
   rm -rf /var/tmp/.cache
   ```

2. **Clear Bash History:**
   ```bash
   history -c
   ```
