# Google Drive Setup Guide

## 🚨 The Service Account Quota Issue

You encountered this error:
```
ERROR 403: Service Accounts do not have storage quota.
Leverage shared drives or use OAuth delegation instead.
```

**What this means:** Service accounts can authenticate with Google Drive, but they **cannot write to regular "My Drive" folders** in personal Google accounts. This is a Google Drive API limitation.

---

## 🎯 Solutions (Choose One)

### Option 1: OAuth User Authentication (RECOMMENDED for Personal Accounts)

✅ **Best for:** Personal Google accounts  
✅ **Pros:** Simple, works with "My Drive", no quota issues  
❌ **Cons:** Requires one-time interactive setup

### Option 2: Google Shared Drive

✅ **Best for:** Google Workspace accounts  
❌ **Requires:** Paid Google Workspace subscription  
❌ **Not available:** For free personal Gmail accounts

### Option 3: Domain-Wide Delegation

❌ **Complex setup**  
❌ **Requires:** Google Workspace with admin access  
❌ **Not recommended** for simple backup use cases

---

## 🔧 Solution 1: OAuth Setup (Recommended)

This is the easiest solution for personal Google accounts.

### Step 1: Configure Rclone on Your Mac (Interactive)

Run this command **on your Mac** (not in the VM):

```bash
cd ~/Documents/gdrive_backup_test

# Configure rclone with OAuth
rclone config
```

You'll see an interactive menu. Follow these steps:

```
n) New remote
name> gdrive
Storage> drive
client_id> [Press Enter to use default]
client_secret> [Press Enter to use default]
scope> drive
root_folder_id> [Press Enter]
service_account_file> [Press Enter]
Edit advanced config? n
Use auto config? y [This will open a browser]
```

**Browser will open:** Log in with your Google account and authorize rclone.

After authorization:
```
Configure this as a team drive? n
y) Yes this is OK
q) Quit config
```

### Step 2: Copy the OAuth Token to VM

The OAuth configuration is now in `~/.config/rclone/rclone.conf` on your Mac.

```bash
# View the config
cat ~/.config/rclone/rclone.conf

# You'll see something like:
# [gdrive]
# type = drive
# scope = drive
# token = {"access_token":"...", "token_type":"Bearer", ...}
```

Copy this configuration to the VM:

```bash
# Copy the entire [gdrive] section from your Mac's rclone.conf
# Then paste it into the VM:
multipass exec sandbox -- sudo tee /etc/rclone/rclone.conf << 'EOF'
[gdrive]
type = drive
scope = drive
token = {"access_token":"YOUR_TOKEN_HERE","token_type":"Bearer","refresh_token":"YOUR_REFRESH_TOKEN","expiry":"2025-01-28T..."}
EOF
```

**OR** use this helper script:

```bash
# Copy your Mac's rclone config to the VM
cat ~/.config/rclone/rclone.conf | multipass exec sandbox -- sudo tee /etc/rclone/rclone.conf
```

### Step 3: Test the Connection

```bash
# Test rclone can list your Drive
multipass exec sandbox -- sudo rclone lsd gdrive: --config /etc/rclone/rclone.conf

# Should show your Drive folders!
```

### Step 4: Create the Backup Folder

```bash
# Create the backup folder in Drive
multipass exec sandbox -- sudo rclone mkdir gdrive:sqlite_backups --config /etc/rclone/rclone.conf
```

### Step 5: Test the Backup

```bash
./helper.sh test
```

This should now work! Check your Google Drive and you should see the backup file in the `sqlite_backups` folder.

---

## 🔧 Solution 2: Use a Shared Drive (Google Workspace Only)

If you have a Google Workspace account with a Shared Drive:

### Step 1: Create a Shared Drive

1. Go to [Google Drive](https://drive.google.com)
2. Click "Shared drives" in the left sidebar
3. Click "+ New" to create a new shared drive
4. Name it (e.g., "Backups")

### Step 2: Add Service Account as Member

1. Open the Shared Drive
2. Click the gear icon → "Manage members"
3. Add: `651658280725-compute@developer.gserviceaccount.com`
4. Give it **Content Manager** or **Manager** role

### Step 3: Get the Shared Drive ID

1. Open the Shared Drive in your browser
2. Copy the ID from the URL: `https://drive.google.com/drive/folders/SHARED_DRIVE_ID_HERE`

### Step 4: Update Rclone Config

Edit the rclone config template to include the shared drive:

```bash
# Edit the template
nano templates/rclone.conf.j2
```

Change to:
```ini
[gdrive]
type = drive
scope = drive
service_account_file = {{ rclone_config_dir }}/service_account.json
team_drive = YOUR_SHARED_DRIVE_ID_HERE
```

### Step 5: Redeploy and Test

```bash
ansible-playbook -i inventory.ini playbook.yml
./helper.sh test
```

---

## 🎯 Quick Decision Guide

**Do you have:**
- ❌ Free Gmail account → Use **Option 1 (OAuth)**
- ✅ Google Workspace → Use **Option 2 (Shared Drive)**
- 🤷 Not sure → Use **Option 1 (OAuth)** (works for everyone)

---

## 📝 Step-by-Step: Complete OAuth Setup

Here's the complete process start to finish:

```bash
# 1. On your Mac: Configure rclone with OAuth
cd ~/Documents/gdrive_backup_test
rclone config
# Follow the interactive prompts, choose 'drive', authorize in browser

# 2. Verify it works on your Mac
rclone lsd gdrive:
# Should list your Drive folders

# 3. Copy the config to the VM
cat ~/.config/rclone/rclone.conf | multipass exec sandbox -- sudo tee /etc/rclone/rclone.conf > /dev/null

# 4. Set correct permissions
multipass exec sandbox -- sudo chmod 600 /etc/rclone/rclone.conf

# 5. Test in VM
multipass exec sandbox -- sudo rclone lsd gdrive: --config /etc/rclone/rclone.conf

# 6. Create backup folder
multipass exec sandbox -- sudo rclone mkdir gdrive:sqlite_backups --config /etc/rclone/rclone.conf

# 7. Test backup
./helper.sh test

# 8. Check Google Drive in your browser - you should see the backup!
```

---

## ✅ Verification

After setup, verify everything works:

```bash
# List files in your Drive
multipass exec sandbox -- sudo rclone ls gdrive:sqlite_backups --config /etc/rclone/rclone.conf

# Manual backup test
./helper.sh test

# Check Google Drive in browser
open https://drive.google.com
# Navigate to sqlite_backups folder
# You should see: db_backup_YYYYMMDD_HHMMSS.sqlite
```

---

## 🐛 Troubleshooting

### "Token expired" error

OAuth tokens expire. To refresh:

```bash
# On your Mac
rclone config reconnect gdrive:
# Opens browser for re-authorization

# Copy updated config to VM
cat ~/.config/rclone/rclone.conf | multipass exec sandbox -- sudo tee /etc/rclone/rclone.conf > /dev/null
```

### "Access denied" with service account

- Verify you shared the folder with the correct email
- Use OAuth instead (easier for personal accounts)

### Rclone can't find the folder

```bash
# List all folders to find the exact name
multipass exec sandbox -- sudo rclone lsd gdrive: --config /etc/rclone/rclone.conf

# Make sure folder name in playbook.yml matches exactly
```

---

## 📚 Additional Resources

- [Rclone Google Drive Documentation](https://rclone.org/drive/)
- [Google Drive API Quotas](https://developers.google.com/drive/api/guides/limits)
- [Service Account Limitations](https://developers.google.com/workspace/guides/create-credentials#service-account)

---

**Recommendation:** Use **OAuth authentication (Option 1)** for personal use. It's simpler and works reliably with regular Google accounts.