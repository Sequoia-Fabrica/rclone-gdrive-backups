# Setup Guide for M3 Mac

Since VirtualBox doesn't support ARM architecture (M3 Macs), we'll use **Multipass** instead of Vagrant. Multipass is a lightweight VM manager from Canonical that works perfectly on Apple Silicon.

## Prerequisites

- **Homebrew** installed (if not: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`)
- **Ansible** installed (`brew install ansible`)
- **Docker Desktop** (optional, but recommended for other projects)

## Step 1: Install Multipass

```bash
brew install multipass
```

## Step 2: Create an Ubuntu VM

```bash
# Create a VM named "sandbox" with Ubuntu 22.04
multipass launch 22.04 --name sandbox --memory 2G --disk 10G --cpus 2

# Wait for it to start (should take 1-2 minutes)
multipass info sandbox
```

## Step 3: Set Up SSH Access

By default, Multipass uses its own connection method, but we need SSH for Ansible. Let's set it up:

### 3.1: Get the VM's IP address

```bash
multipass info sandbox | grep IPv4
```

You'll see something like: `IPv4:           192.168.64.X`

### 3.2: Copy your SSH key to the VM

```bash
# Generate an SSH key if you don't have one
if [ ! -f ~/.ssh/id_rsa ]; then
  ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
fi

# Copy your public key to the VM
multipass exec sandbox -- bash -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
cat ~/.ssh/id_rsa.pub | multipass exec sandbox -- bash -c "cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

### 3.3: Ensure SSH server is running in the VM

```bash
multipass exec sandbox -- sudo apt-get update
multipass exec sandbox -- sudo apt-get install -y openssh-server
multipass exec sandbox -- sudo systemctl enable ssh
multipass exec sandbox -- sudo systemctl start ssh
```

## Step 4: Update inventory.ini

Replace the contents of `inventory.ini` with:

```ini
[sandbox]
<VM_IP_ADDRESS> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa ansible_python_interpreter=/usr/bin/python3

[sandbox:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
```

**Replace `<VM_IP_ADDRESS>`** with the actual IP from step 3.1 (e.g., `192.168.64.2`)

## Step 5: Test Ansible Connection

```bash
ansible -i inventory.ini sandbox -m ping
```

You should see:
```
<IP> | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

## Step 6: Create a Test SQLite Database in the VM

```bash
multipass exec sandbox -- bash -c "sudo mkdir -p /var/lib/myapp && sudo sqlite3 /var/lib/myapp/db.sqlite 'CREATE TABLE test(id INTEGER PRIMARY KEY, name TEXT);' && sudo sqlite3 /var/lib/myapp/db.sqlite \"INSERT INTO test (name) VALUES ('test_data');\""
```

## Step 8: Update the Playbook (Skip Drive Upload for Now)

We need to modify the playbook to skip the Drive connection check since we don't have real credentials yet.

Edit `playbook.yml` and change the "Verify Rclone Connection" task to:

```yaml
- name: Verify Rclone Connection (Dry Run)
  command: rclone lsd gdrive: --config {{ rclone_config_dir }}/rclone.conf
  register: rclone_check
  changed_when: false
  failed_when: false
  ignore_errors: yes  # Add this line
```

## Step 9: Run the Playbook

```bash
ansible-playbook -i inventory.ini playbook.yml
```

The playbook will:
- ✅ Install sqlite3 and rclone
- ✅ Deploy configuration files
- ✅ Deploy the backup script
- ✅ Set up the cron job
- ⚠️  Fail to connect to Google Drive (expected without real credentials)

## Step 10: Test the Backup Script (Without Upload)

Let's test that the backup creation works:

```bash
# SSH into the VM
multipass shell sandbox

# Manually run the backup script (it will fail at the upload step)
sudo /usr/local/bin/backup_sqlite.sh

# Check if the local backup was created before the upload failed
ls -lh /tmp/sqlite_backups/
```

## Useful Multipass Commands

```bash
# Shell into the VM
multipass shell sandbox

# Stop the VM
multipass stop sandbox

# Start the VM
multipass start sandbox

# Delete the VM (WARNING: This deletes everything)
multipass delete sandbox
multipass purge

# View VM info
multipass info sandbox

# View VM list
multipass list
```

## When You Get Real Google Drive Credentials

1. **Download** your service account JSON from Google Cloud Console
2. **Replace** `files/credentials.json` with your real credentials
3. **Share** your Google Drive folder with the service account email (found in the `client_email` field of the JSON)
4. **Re-run** the playbook:
   ```bash
   ansible-playbook -i inventory.ini playbook.yml
   ```
5. **Test** the backup:
   ```bash
   multipass shell sandbox
   sudo /usr/local/bin/backup_sqlite.sh
   ```
6. **Check** your Google Drive folder for the backup file!

## Troubleshooting

### Can't connect via Ansible
- Check the VM is running: `multipass list`
- Verify the IP address: `multipass info sandbox`
- Test SSH manually: `ssh ubuntu@<VM_IP> -i ~/.ssh/id_rsa`

### Playbook fails with permission errors
- Make sure you're using `become: yes` in the playbook (already configured)
- Check the ubuntu user has sudo access: `multipass exec sandbox -- sudo whoami`

### Backup script fails
- Check the database exists: `multipass exec sandbox -- ls -l /var/lib/myapp/db.sqlite`
- Check the log: `multipass exec sandbox -- tail -f /var/log/db_backup.log`
- Run the script manually to see errors: `multipass shell sandbox` then `sudo /usr/local/bin/backup_sqlite.sh`

## Next Steps: Configure OAuth for Google Drive

The playbook is now deployed, but you need to configure OAuth to connect to Google Drive.

### 1. Configure Rclone with OAuth on Your Mac

```bash
# Run rclone config interactively
rclone config

# Follow the prompts:
# - Choose: n (New remote)
# - Name: sequoia_fabrica_google_workspace (or your preferred name)
# - Storage: drive (Google Drive)
# - Client ID/Secret: Press Enter (use defaults)
# - Scope: drive (full access)
# - Root folder: Press Enter
# - Service account file: Press Enter (we're using OAuth, not service accounts!)
# - Edit advanced config: n
# - Use auto config: y (this will open a browser for OAuth)
# - Log in with your Google account and authorize
```

### 2. Copy OAuth Config to the VM

```bash
# Copy your rclone config with OAuth tokens to the VM
cat ~/.config/rclone/rclone.conf | multipass exec sandbox -- sudo tee /etc/rclone/rclone.conf

# Set proper permissions
multipass exec sandbox -- sudo chmod 600 /etc/rclone/rclone.conf
```

### 3. Verify Connection and Test Backup

```bash
# Test that rclone can connect to Google Drive
multipass exec sandbox -- sudo rclone lsd sequoia_fabrica_google_workspace:

# Create the backup folder
multipass exec sandbox -- sudo rclone mkdir sequoia_fabrica_google_workspace:sqlite_backups

# Run a manual backup to test
multipass exec sandbox -- sudo /usr/local/bin/backup_sqlite.sh

# Check your Google Drive - you should see the backup!
```

### 4. Deploy to Production

Once everything is working with Multipass locally, you can:
1. Deploy the same playbook to a real server (cloud or on-premises)
2. Update the `inventory.ini` to point to your production server
3. Copy your rclone OAuth config to the production server
4. Run the same playbook against production

The beauty of this approach is that your development environment (Multipass VM) matches your production environment (Ubuntu server), so what works locally will work in production!

For more details on OAuth setup, see [OAUTH_SETUP_COMPLETE.md](OAUTH_SETUP_COMPLETE.md).