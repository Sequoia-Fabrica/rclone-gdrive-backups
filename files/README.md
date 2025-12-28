# files/

This directory is intentionally left empty. It can be used for deployment-specific configuration files if needed.

## 🔐 OAuth Configuration

This project uses **OAuth authentication**. OAuth tokens are stored in `rclone.conf` (not in this directory).

### Quick Setup

```bash
# 1. Configure OAuth
rclone config

# 2. Copy for docker-compose
cp ~/.config/rclone/rclone.conf ./rclone.conf

# 3. Or copy to server for Ansible
scp ~/.config/rclone/rclone.conf user@server:/etc/gdrive-backup/rclone.conf
```

## ❓ FAQ

**Q: Do I need a credentials.json file?**  
A: No. This project uses OAuth (stored in `rclone.conf`), not service accounts.

**Q: Can I store files here?**  
A: Yes. Use this directory for custom scripts, environment configs, or deployment helpers. Add sensitive files to `.gitignore`.

## 📚 Documentation

See the main [README.md](../README.md) and [docs/](../docs/) directory for complete documentation.

---

**Note:** `rclone.conf` should never be committed to version control. It's already in `.gitignore`.