# Configuration Files Directory

This directory is for deployment-specific configuration files.

## 🔐 OAuth Authentication

**This project uses OAuth authentication exclusively.**

You do not need to place any files in this directory for standard deployments. OAuth tokens are stored in `rclone.conf` which is managed separately and should **never** be committed to version control.

## 📋 Setup Instructions

### For Docker Deployment

1. **Configure rclone on your local machine:**
   ```bash
   rclone config
   # Choose: New remote → Google Drive → OAuth
   # Follow browser prompts to authorize
   ```

2. **Copy the OAuth config to your deployment location:**
   
   **For docker-compose:**
   ```bash
   cp ~/.config/rclone/rclone.conf ./rclone.conf
   chmod 600 ./rclone.conf
   ```
   
   **For Ansible deployment:**
   ```bash
   scp ~/.config/rclone/rclone.conf user@server:/etc/gdrive-backup/rclone.conf
   ```

3. **Deploy your container** - see [DOCKER_QUICK_START.md](../docs/DOCKER_QUICK_START.md)

## ❓ Frequently Asked Questions

### Do I need a credentials.json file?

**No!** This project uses OAuth authentication, not service accounts.

- `credentials.json` is for service accounts (Google Workspace feature)
- This project uses **OAuth** which stores tokens in `rclone.conf`
- OAuth works with personal Google accounts and Google Workspace
- No service account setup required
- No Google Cloud project required

### Where is rclone.conf stored?

OAuth tokens are in `~/.config/rclone/rclone.conf` on your local machine. You copy this file to:

- **docker-compose:** `./rclone.conf` (project root)
- **Ansible/Production:** `/etc/gdrive-backup/rclone.conf` (on server)
- **Manual Docker:** Mount as volume to `/etc/rclone/rclone.conf`

### Can I use this directory for other files?

Yes! You can store deployment-specific files here:

- Custom scripts
- Additional configuration
- Environment-specific settings

Just remember to add them to `.gitignore` if they contain sensitive data.

## 🔒 Security Notes

- Never commit `rclone.conf` to version control (it's in `.gitignore`)
- OAuth tokens auto-refresh indefinitely
- Access tokens expire after ~1 hour, but refresh tokens last months/years
- If you see `invalid_grant` errors, run: `rclone config reconnect remote_name:`
- Store `rclone.conf` securely - it provides access to your Google Drive
- Use `chmod 600` to restrict file permissions

## 📚 Documentation

- [OAUTH_SETUP_COMPLETE.md](../docs/OAUTH_SETUP_COMPLETE.md) - Complete OAuth guide
- [GOOGLE_DRIVE_SETUP.md](../docs/GOOGLE_DRIVE_SETUP.md) - Google Drive setup details
- [DOCKER_QUICK_START.md](../docs/DOCKER_QUICK_START.md) - Quick deployment guide
- [DOCKER_DEPLOYMENT.md](../docs/DOCKER_DEPLOYMENT.md) - Complete deployment guide

## 💡 Example Use Cases

### Multiple Environments

Store environment-specific configs:

```
files/
├── README.md
├── production.env      # Production environment vars
├── staging.env         # Staging environment vars
└── development.env     # Development environment vars
```

Then reference in docker-compose:

```yaml
services:
  backup:
    env_file: files/production.env
```

### Custom Scripts

Add deployment helpers:

```
files/
├── README.md
├── pre-deploy.sh       # Pre-deployment checks
├── post-deploy.sh      # Post-deployment validation
└── monitoring.sh       # Custom monitoring script
```

### Backup Verification

Store verification scripts:

```
files/
├── README.md
└── verify-backup.sh    # Test restore from backup
```

## 🚀 Quick Reference

```bash
# Configure OAuth
rclone config

# Copy config for docker-compose
cp ~/.config/rclone/rclone.conf ./rclone.conf

# Copy config to remote server
scp ~/.config/rclone/rclone.conf user@server:/etc/gdrive-backup/rclone.conf

# Test OAuth connection
rclone lsd gdrive: --config ./rclone.conf

# Reconnect if token expires
rclone config reconnect gdrive:
```

---

**Note:** This directory intentionally left empty - all configuration is OAuth-based using `rclone.conf`.