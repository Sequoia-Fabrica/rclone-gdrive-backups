# OAuth Configuration Directory

This directory is used for OAuth-related configuration files when deploying the backup system.

## ⚠️ Important: OAuth Only

**This project uses OAuth authentication, NOT service accounts.**

You do not need to place any credentials files in this directory for the standard VM deployment. OAuth tokens are stored in `rclone.conf` which is managed separately.

## OAuth Setup

### For VM Deployment (Multipass/Vagrant)

1. **Configure rclone on your local machine:**
   ```bash
   rclone config
   # Choose: New remote → Google Drive → OAuth
   ```

2. **Copy the OAuth config to your VM:**
   ```bash
   # For Multipass
   cat ~/.config/rclone/rclone.conf | multipass exec sandbox -- sudo tee /etc/rclone/rclone.conf
   
   # For Vagrant
   vagrant ssh -c "sudo tee /etc/rclone/rclone.conf" < ~/.config/rclone/rclone.conf
   ```

3. **No files needed in this directory!**

### For Docker Deployment

Copy your `rclone.conf` to the appropriate location:

```bash
# Copy to server
scp ~/.config/rclone/rclone.conf user@server:/etc/gdrive-backup/rclone.conf

# Or for local docker-compose
cp ~/.config/rclone/rclone.conf ./rclone.conf
```

## What About credentials.json?

**You don't need it!** 

- `credentials.json` is for service accounts (Google Workspace feature)
- This project uses **OAuth** which stores tokens in `rclone.conf`
- OAuth works with personal Google accounts and Google Workspace
- No service account setup required

## Documentation

- [OAUTH_SETUP_COMPLETE.md](../OAUTH_SETUP_COMPLETE.md) - Complete OAuth guide
- [GOOGLE_DRIVE_SETUP.md](../GOOGLE_DRIVE_SETUP.md) - OAuth vs Service Account comparison
- [QUICKSTART.md](../QUICKSTART.md) - Quick setup with OAuth

## Security Notes

- Never commit `rclone.conf` to version control (it's in .gitignore)
- OAuth tokens auto-refresh, so they last indefinitely
- If you see `invalid_grant` errors, run: `rclone config reconnect remote_name:`
- Store `rclone.conf` securely - it provides access to your Google Drive