# Ansible Vault Setup Guide

This guide explains how to use Ansible Vault to securely store Google Drive OAuth credentials instead of copying `rclone.conf` files.

## 📋 Overview

**Why Ansible Vault?**

- ✅ Credentials encrypted at rest
- ✅ Can be committed to version control (encrypted)
- ✅ Standard Ansible workflow
- ✅ No manual file copying needed
- ✅ Better security and auditability

**What you'll do:**

1. Get OAuth credentials from rclone
2. Create encrypted vault file
3. Deploy with vault password

---

## 🔑 Step 1: Extract OAuth Credentials

### Configure rclone (if not already done)

```bash
rclone config

# Follow prompts:
# - New remote → Google Drive
# - Use OAuth (opens browser)
# - Authorize with your Google account
```

### Extract the OAuth token

Your rclone config is at `~/.config/rclone/rclone.conf`. View it:

```bash
cat ~/.config/rclone/rclone.conf
```

You'll see something like:

```ini
[gdrive]
type = drive
scope = drive
token = {"access_token":"ya29.a0AfB_...","token_type":"Bearer","refresh_token":"1//0gL...","expiry":"2024-12-28T12:34:56.789Z"}
```

### Extract the values you need

From the config, identify these values:

1. **Remote name**: The name in brackets (e.g., `gdrive`)
2. **Scope**: Usually `drive` for full access
3. **Token**: The entire JSON object (everything between the quotes)
4. **Client ID/Secret**: (Optional) If you see `client_id` and `client_secret` lines

**Example token structure:**

```json
{
  "access_token": "ya29.a0AfB_byABCDEF...",
  "token_type": "Bearer",
  "refresh_token": "1//0gLXYZ123...",
  "expiry": "2024-12-28T12:34:56.789Z"
}
```

---

## 🔐 Step 2: Create Ansible Vault File

### Method A: Interactive (Recommended)

```bash
# Create encrypted vault file
ansible-vault create group_vars/all/vault.yml

# You'll be prompted for a vault password (remember this!)
# Your editor will open. Add the following:
```

Add this content (replace with your actual values):

```yaml
---
# Google Drive OAuth Credentials
# Extracted from ~/.config/rclone/rclone.conf

# The rclone remote name
vault_rclone_remote_name: gdrive

# OAuth scope (usually 'drive' for full access)
vault_rclone_scope: drive

# The complete OAuth token as a JSON object
vault_rclone_token:
  access_token: "ya29.a0AfB_byYOUR_ACTUAL_ACCESS_TOKEN_HERE"
  token_type: "Bearer"
  refresh_token: "1//0gYOUR_ACTUAL_REFRESH_TOKEN_HERE"
  expiry: "2024-12-28T12:34:56.789123456Z"

# Optional: Client ID and Secret (if using custom OAuth app)
# vault_rclone_client_id: "YOUR_CLIENT_ID.apps.googleusercontent.com"
# vault_rclone_client_secret: "YOUR_CLIENT_SECRET"

# Optional: Team Drive ID (for Google Workspace Shared Drives)
# vault_rclone_team_drive: "0AaBbCcDdEeFfGg"

# Optional: Root folder ID (to restrict to a specific folder)
# vault_rclone_root_folder_id: "1A2B3C4D5E6F7G8H9I"
```

Save and close the editor.

### Method B: From File

If you have your credentials in a plain file:

```bash
# Create plain YAML file first
cat > vault.yml.plain << 'EOF'
---
vault_rclone_remote_name: gdrive
vault_rclone_scope: drive
vault_rclone_token:
  access_token: "ya29.a0AfB_byYOUR_TOKEN"
  token_type: "Bearer"
  refresh_token: "1//0gYOUR_REFRESH"
  expiry: "2024-12-28T12:34:56.789Z"
EOF

# Encrypt it
ansible-vault encrypt vault.yml.plain

# Move to group_vars
mkdir -p group_vars/all
mv vault.yml.plain group_vars/all/vault.yml

# Delete plain file if you made a backup
```

### Method C: Using Python Script

For easier extraction:

```bash
cat > extract_oauth.py << 'EOF'
#!/usr/bin/env python3
import json
import sys
import os
from pathlib import Path

# Read rclone config
rclone_conf = Path.home() / '.config/rclone/rclone.conf'

if not rclone_conf.exists():
    print(f"Error: {rclone_conf} not found", file=sys.stderr)
    sys.exit(1)

print("# Extract values from rclone config and paste into vault.yml")
print("# Run: ansible-vault create group_vars/all/vault.yml")
print()
print("---")

with open(rclone_conf) as f:
    current_remote = None
    for line in f:
        line = line.strip()
        if line.startswith('[') and line.endswith(']'):
            current_remote = line[1:-1]
            print(f"\n# Remote: {current_remote}")
            print(f"vault_rclone_remote_name: {current_remote}")
        elif line.startswith('scope = '):
            scope = line.split('=', 1)[1].strip()
            print(f"vault_rclone_scope: {scope}")
        elif line.startswith('token = '):
            token_str = line.split('=', 1)[1].strip()
            try:
                token = json.loads(token_str)
                print("vault_rclone_token:")
                for key, value in token.items():
                    print(f'  {key}: "{value}"')
            except:
                print(f"# WARNING: Could not parse token")
        elif line.startswith('client_id = '):
            client_id = line.split('=', 1)[1].strip()
            print(f'vault_rclone_client_id: "{client_id}"')
        elif line.startswith('client_secret = '):
            client_secret = line.split('=', 1)[1].strip()
            print(f'vault_rclone_client_secret: "{client_secret}"')
        elif line.startswith('team_drive = '):
            team_drive = line.split('=', 1)[1].strip()
            if team_drive:
                print(f'vault_rclone_team_drive: "{team_drive}"')
EOF

chmod +x extract_oauth.py
./extract_oauth.py > vault_template.yml

# Review the output, then encrypt it
ansible-vault create group_vars/all/vault.yml
# Paste the contents from vault_template.yml
```

---

## 📂 Step 3: Create Group Variables

Create `group_vars/all/vars.yml` (unencrypted, references vault):

```bash
mkdir -p group_vars/all
cat > group_vars/all/vars.yml << 'EOF'
---
# Google Drive OAuth Configuration
# Actual credentials are in vault.yml (encrypted)

rclone_remote_name: "{{ vault_rclone_remote_name }}"
rclone_scope: "{{ vault_rclone_scope }}"
rclone_token: "{{ vault_rclone_token }}"

# Optional: Uncomment if you have these in vault
# rclone_client_id: "{{ vault_rclone_client_id }}"
# rclone_client_secret: "{{ vault_rclone_client_secret }}"
# rclone_team_drive: "{{ vault_rclone_team_drive }}"
# rclone_root_folder_id: "{{ vault_rclone_root_folder_id }}"
EOF
```

---

## 🚀 Step 4: Deploy with Vault

### Run the playbook

```bash
# Deploy with vault password prompt
ansible-playbook deploy_docker.yml -i production.ini --ask-vault-pass

# Or use a password file
echo "your_vault_password" > .vault_pass
chmod 600 .vault_pass
ansible-playbook deploy_docker.yml -i production.ini --vault-password-file .vault_pass
```

### Full example

```bash
# Directory structure
sqlite-gdrive-backup/
├── deploy_docker.yml
├── production.ini
├── group_vars/
│   └── all/
│       ├── vars.yml        # Unencrypted, references vault
│       └── vault.yml       # Encrypted credentials

# Deploy
ansible-playbook deploy_docker.yml -i production.ini --ask-vault-pass
```

---

## 🔧 Managing Vault Files

### View encrypted vault

```bash
ansible-vault view group_vars/all/vault.yml
```

### Edit encrypted vault

```bash
ansible-vault edit group_vars/all/vault.yml
```

### Change vault password

```bash
ansible-vault rekey group_vars/all/vault.yml
```

### Decrypt vault (temporarily)

```bash
# Decrypt to plain file
ansible-vault decrypt group_vars/all/vault.yml

# Edit it
vim group_vars/all/vault.yml

# Re-encrypt
ansible-vault encrypt group_vars/all/vault.yml
```

---

## 📁 Complete Project Structure

```
sqlite-gdrive-backup/
├── deploy_docker.yml                   # Deployment playbook
├── production.ini                      # Inventory
├── templates/
│   └── rclone.conf.j2                  # Rclone config template
├── group_vars/
│   └── all/
│       ├── vars.yml                    # Public variables
│       └── vault.yml                   # Encrypted credentials
└── .vault_pass                         # Vault password (gitignored!)
```

---

## 🔐 Security Best Practices

### 1. Protect vault password file

```bash
# Add to .gitignore
echo ".vault_pass" >> .gitignore

# Restrict permissions
chmod 600 .vault_pass
```

### 2. Use different vaults per environment

```bash
group_vars/
├── production/
│   ├── vars.yml
│   └── vault.yml        # Production credentials
├── staging/
│   ├── vars.yml
│   └── vault.yml        # Staging credentials
└── development/
    ├── vars.yml
    └── vault.yml        # Development credentials
```

### 3. Store vault password securely

**Option A: Password manager**
- Store in 1Password, LastPass, etc.
- Retrieve when needed

**Option B: CI/CD secrets**
- GitLab CI: Use `ANSIBLE_VAULT_PASSWORD` variable
- GitHub Actions: Use secrets
- Jenkins: Use credentials binding

**Option C: Encrypted USB drive**
- Store `.vault_pass` on encrypted drive
- Mount only when deploying

### 4. Rotate credentials regularly

```bash
# 1. Reconnect rclone OAuth
rclone config reconnect gdrive:

# 2. Extract new token
cat ~/.config/rclone/rclone.conf

# 3. Update vault
ansible-vault edit group_vars/all/vault.yml

# 4. Redeploy
ansible-playbook deploy_docker.yml -i production.ini --ask-vault-pass
```

---

## 🔄 Token Refresh

OAuth tokens have two parts:

1. **Access token** - Expires after ~1 hour
2. **Refresh token** - Lasts months/years, used to get new access tokens

Rclone automatically refreshes access tokens using the refresh token. You typically don't need to update the vault unless:

- You revoke access in Google Account settings
- You reconnect rclone OAuth
- The refresh token expires (rare)

---

## 🐛 Troubleshooting

### "Vault password incorrect"

```bash
# Make sure you're using the same password
ansible-vault view group_vars/all/vault.yml
# Enter the correct password
```

### "Variable 'rclone_token' is undefined"

```bash
# Check vault.yml exists
ls -la group_vars/all/vault.yml

# Check it contains the variable
ansible-vault view group_vars/all/vault.yml | grep vault_rclone_token

# Check vars.yml references it
cat group_vars/all/vars.yml | grep rclone_token
```

### "Invalid token" error in container

```bash
# Your OAuth token may have expired or been revoked
# Reconnect rclone
rclone config reconnect gdrive:

# Extract new token
cat ~/.config/rclone/rclone.conf

# Update vault
ansible-vault edit group_vars/all/vault.yml

# Redeploy
ansible-playbook deploy_docker.yml -i production.ini --ask-vault-pass
```

### "Template not found"

```bash
# Make sure templates/rclone.conf.j2 exists
ls -la templates/rclone.conf.j2

# Run playbook from project root
cd /path/to/sqlite-gdrive-backup
ansible-playbook deploy_docker.yml -i production.ini --ask-vault-pass
```

---

## 📝 Example Workflow

Complete workflow from scratch:

```bash
# 1. Configure OAuth
rclone config
# Choose: gdrive → Google Drive → OAuth

# 2. Extract credentials
cat ~/.config/rclone/rclone.conf
# Note the token value

# 3. Create vault
ansible-vault create group_vars/all/vault.yml
# Add:
#   vault_rclone_remote_name: gdrive
#   vault_rclone_scope: drive
#   vault_rclone_token: { ... }

# 4. Create vars
mkdir -p group_vars/all
cat > group_vars/all/vars.yml << 'EOF'
rclone_remote_name: "{{ vault_rclone_remote_name }}"
rclone_scope: "{{ vault_rclone_scope }}"
rclone_token: "{{ vault_rclone_token }}"
EOF

# 5. Deploy
ansible-playbook deploy_docker.yml \
  -i production.ini \
  -e "db_path=/var/lib/myapp/db.sqlite" \
  --ask-vault-pass

# 6. Verify
docker logs backup
docker exec backup rclone lsd gdrive:
```

---

## 🆚 Vault vs. File Copy

| Aspect | Ansible Vault | File Copy |
|--------|---------------|-----------|
| **Security** | Encrypted at rest | Plain file on disk |
| **Version Control** | Can commit (encrypted) | Must gitignore |
| **Automation** | Fully automated | Manual copy required |
| **Rotation** | Update vault, redeploy | Copy new file, restart |
| **Audit Trail** | Git history | No tracking |
| **Best For** | Production, CI/CD | Local development |

---

## 📚 See Also

- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- [DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md) - Complete deployment guide
- [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) - Parent playbook integration
- [OAUTH_SETUP_COMPLETE.md](OAUTH_SETUP_COMPLETE.md) - OAuth setup details

---

## 💡 Pro Tips

1. **Use vault ID for multiple passwords**
   ```bash
   ansible-vault create --vault-id prod@prompt group_vars/production/vault.yml
   ansible-vault create --vault-id stage@prompt group_vars/staging/vault.yml
   ansible-playbook deploy.yml --vault-id prod@prompt --vault-id stage@prompt
   ```

2. **Validate vault before deploying**
   ```bash
   ansible-playbook deploy_docker.yml -i production.ini --ask-vault-pass --check
   ```

3. **Test token extraction locally**
   ```bash
   ansible-playbook -i localhost, -c local \
     -e "rclone_token=$(ansible-vault view group_vars/all/vault.yml | grep -A 10 vault_rclone_token)" \
     test_token.yml
   ```

4. **Keep a backup of your vault password**
   - Store in password manager
   - Print and store in safe
   - Share with team securely

---

**Ready to deploy securely!** 🔐