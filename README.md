# SQLite Google Drive Backup

Automated SQLite database backup system that safely backs up databases to Google Drive using Docker, rclone, and OAuth authentication.

## 🚀 Quick Start

### Prerequisites

- Docker installed on your server
- SQLite database to backup
- Google account for Drive storage

### 1. Clone Repository

```bash
git clone https://github.com/yourorg/sqlite-gdrive-backup.git
cd sqlite-gdrive-backup
```

### 2. Configure OAuth

```bash
# Configure rclone with Google Drive OAuth
rclone config

# Follow prompts:
# - New remote → Google Drive
# - Use OAuth (opens browser)
# - Authorize with your Google account

# Copy config for deployment
cp ~/.config/rclone/rclone.conf ./rclone.conf
chmod 600 ./rclone.conf
```

### 3. Deploy with Docker Compose

```bash
# Edit docker-compose.yml to set your database path
# Update: /var/lib/myapp/db.sqlite to your actual database location

docker-compose up -d
```

### 4. Verify

```bash
# Check logs
docker-compose logs -f gdrive_backup

# Run manual backup
docker-compose exec gdrive_backup /scripts/backup_sqlite.sh

# Verify in Google Drive
rclone ls gdrive:sqlite_backups --config ./rclone.conf
```

**Done!** Backups run automatically on schedule (default: 2:30 AM daily).

---

## 📦 Features

- ✅ **Safe hot backups** using SQLite's `VACUUM INTO` (no long locks)
- ✅ **Automatic uploads** to Google Drive using rclone OAuth
- ✅ **Scheduled backups** via cron inside container
- ✅ **Automatic retention** (deletes backups older than 30 days)
- ✅ **Docker containerized** - runs anywhere Docker runs
- ✅ **Production ready** - health checks, logging, restart policies
- ✅ **Easy integration** - works with existing Ansible playbooks

---

## 🐳 Deployment Options

### Option 1: Docker Compose (Recommended)

Best for: Simple deployments, single server

```bash
cp ~/.config/rclone/rclone.conf ./rclone.conf
docker-compose up -d
```

**See:** [DOCKER_QUICK_START.md](docs/DOCKER_QUICK_START.md)

### Option 2: Ansible Deployment

Best for: Production, multiple servers, infrastructure as code

```bash
ansible-playbook deploy_docker.yml -i production.ini \
  -e "db_path=/var/lib/myapp/db.sqlite"
```

**See:** [DOCKER_DEPLOYMENT.md](docs/DOCKER_DEPLOYMENT.md)

### Option 3: Manual Docker

Best for: Custom deployments, testing

```bash
docker build -t sqlite-gdrive-backup .

docker run -d \
  --name backup \
  -v /path/to/db.sqlite:/data/db.sqlite:ro \
  -v ./rclone.conf:/etc/rclone/rclone.conf:ro \
  -e RCLONE_REMOTE_NAME=gdrive \
  -e DRIVE_FOLDER_NAME=backups \
  sqlite-gdrive-backup:latest
```

**See:** [DOCKER_DEPLOYMENT.md](docs/DOCKER_DEPLOYMENT.md#manual-docker-deployment)

---

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `DB_PATH` | Path to database in container | `/data/db.sqlite` | Yes |
| `RCLONE_REMOTE_NAME` | Name from rclone.conf | `gdrive` | Yes |
| `DRIVE_FOLDER_NAME` | Folder in Google Drive | `sqlite_backups` | Yes |
| `BACKUP_SCHEDULE` | Cron schedule | `30 2 * * *` | No |
| `RUN_ON_STARTUP` | Run backup on start | `false` | No |

### Backup Schedule Examples

```bash
# Daily at 2:30 AM (default)
BACKUP_SCHEDULE="30 2 * * *"

# Every 6 hours
BACKUP_SCHEDULE="0 */6 * * *"

# Every Sunday at 3 AM
BACKUP_SCHEDULE="0 3 * * 0"

# Twice daily (6 AM and 6 PM)
BACKUP_SCHEDULE="0 6,18 * * *"
```

---

## 🔐 OAuth Authentication

This project uses **OAuth authentication** (not service accounts).

### Why OAuth?

- ✅ Works with personal Google accounts
- ✅ Works with Google Workspace accounts
- ✅ No Google Cloud project setup required
- ✅ No service account configuration
- ✅ Tokens auto-refresh indefinitely
- ✅ Simpler setup process

### Setup OAuth

**Option 1: Ansible Vault (Recommended for Production)**

```bash
# 1. Configure rclone
rclone config

# 2. Extract OAuth credentials
cat ~/.config/rclone/rclone.conf
# Note: remote name, scope, and token values

# 3. Create encrypted vault
ansible-vault create group_vars/all/vault.yml
# Add: vault_rclone_remote_name, vault_rclone_scope, vault_rclone_token

# 4. Deploy with vault
ansible-playbook deploy_docker.yml -i production.ini --ask-vault-pass
```

**Option 2: File Copy (Quick Testing)**

```bash
# 1. Configure rclone
rclone config

# 2. Copy config for docker-compose
cp ~/.config/rclone/rclone.conf ./rclone.conf
```

**See:** 
- [ANSIBLE_VAULT_SETUP.md](docs/ANSIBLE_VAULT_SETUP.md) - Extract OAuth values and use vault
- [OAUTH_SETUP_COMPLETE.md](docs/OAUTH_SETUP_COMPLETE.md) - OAuth setup details

---

## 🔗 Integration with Ansible

Easily integrate into existing infrastructure using **Ansible Vault** for secure credential management:

```yaml
---
- name: Deploy Application with Backups
  hosts: production
  become: yes
  
  tasks:
    # Deploy your application
    - name: Deploy app
      # ... your tasks ...
    
    # Clone backup repository
    - name: Clone backup system
      git:
        repo: https://github.com/yourorg/sqlite-gdrive-backup.git
        dest: /opt/backup-system
    
    # OAuth credentials are in Ansible Vault (encrypted)
    # No manual file copying needed!
    
    # Deploy backup container
    - import_playbook: /opt/backup-system/deploy_docker.yml
      vars:
        db_path: /var/lib/myapp/db.sqlite
        rclone_remote_name: "{{ vault_rclone_remote_name }}"
        drive_folder_name: production_backups
        # OAuth token from vault
        rclone_token: "{{ vault_rclone_token }}"
        rclone_scope: "{{ vault_rclone_scope }}"
```

**Deploy with vault:**
```bash
ansible-playbook deploy.yml -i production.ini --ask-vault-pass
```

**See:** 
- [ANSIBLE_VAULT_SETUP.md](docs/ANSIBLE_VAULT_SETUP.md) - Secure credential management
- [INTEGRATION_GUIDE.md](docs/INTEGRATION_GUIDE.md) - Complete integration patterns

---

## 🛠️ Common Commands

```bash
# View logs
docker logs -f backup

# Run manual backup
docker exec backup /scripts/backup_sqlite.sh

# Check backup schedule
docker exec backup crontab -l

# Enter container shell
docker exec -it backup /bin/bash

# Restart container
docker restart backup

# View backup log inside container
docker exec backup tail -f /var/log/backup.log

# List backups in Google Drive
rclone ls gdrive:sqlite_backups --config ./rclone.conf

# Check container health
docker ps | grep backup
docker inspect backup | jq '.[0].State.Health'
```

---

## 🔍 Troubleshooting

### Container exits immediately

**Check logs:**
```bash
docker logs backup
```

**Common causes:**
- Missing rclone.conf - verify file exists and is mounted
- Invalid environment variables - check all required vars
- Database not found - verify path and volume mount

### Can't connect to Google Drive

**Test connection:**
```bash
# Outside container
rclone lsd gdrive: --config ./rclone.conf

# Inside container
docker exec backup rclone lsd gdrive: --config /etc/rclone/rclone.conf
```

**If OAuth token expired:**
```bash
rclone config reconnect gdrive:
cp ~/.config/rclone/rclone.conf ./rclone.conf
docker restart backup
```

### Backup not running on schedule

**Check cron:**
```bash
docker exec backup pgrep cron
docker exec backup crontab -l
```

**Check logs:**
```bash
docker exec backup tail -f /var/log/backup.log
```

### Database locked error

**Enable WAL mode:**
```bash
sqlite3 /path/to/db.sqlite "PRAGMA journal_mode=WAL;"
```

**See:** [DOCKER_DEPLOYMENT.md](docs/DOCKER_DEPLOYMENT.md#troubleshooting) for more troubleshooting.

---

## 📊 Multiple Applications

Deploy separate backup containers for multiple databases:

```yaml
# docker-compose.yml
version: '3.8'

services:
  webapp_backup:
    image: sqlite-gdrive-backup
    environment:
      - DB_PATH=/data/db.sqlite
      - DRIVE_FOLDER_NAME=webapp_backups
    volumes:
      - /var/lib/webapp/db.sqlite:/data/db.sqlite:ro
      - ./rclone.conf:/etc/rclone/rclone.conf:ro

  api_backup:
    image: sqlite-gdrive-backup
    environment:
      - DB_PATH=/data/db.sqlite
      - DRIVE_FOLDER_NAME=api_backups
    volumes:
      - /var/lib/api/db.sqlite:/data/db.sqlite:ro
      - ./rclone.conf:/etc/rclone/rclone.conf:ro
```

---

## 📚 Documentation

### Quick Start
- **[DOCKER_QUICK_START.md](docs/DOCKER_QUICK_START.md)** - 5-minute deployment guide

### Deployment
- **[DOCKER_DEPLOYMENT.md](docs/DOCKER_DEPLOYMENT.md)** - Complete deployment guide
- **[docker-compose.yml](docker-compose.yml)** - Docker Compose example
- **[deploy_docker.yml](deploy_docker.yml)** - Ansible deployment

### Integration
- **[INTEGRATION_GUIDE.md](docs/INTEGRATION_GUIDE.md)** - Parent playbook patterns
- **[example_parent_playbook.yml](example_parent_playbook.yml)** - Working example

### Configuration
- **[ANSIBLE_VAULT_SETUP.md](docs/ANSIBLE_VAULT_SETUP.md)** - Secure credential management
- **[OAUTH_SETUP_COMPLETE.md](docs/OAUTH_SETUP_COMPLETE.md)** - OAuth setup guide
- **[GOOGLE_DRIVE_SETUP.md](docs/GOOGLE_DRIVE_SETUP.md)** - Google Drive setup
- **[rclone.conf.example](rclone.conf.example)** - Configuration template

### Technical
- **[DEPLOYMENT_SUMMARY.md](docs/DEPLOYMENT_SUMMARY.md)** - Architecture and design

---

## 🔒 Security Best Practices

1. **Read-only mounts** - Always mount databases as `:ro`
2. **Protect rclone.conf** - Use `chmod 600`, never commit to git
3. **Use secrets** - Consider Docker secrets or Ansible Vault
4. **Isolate containers** - Use Docker networks
5. **Rotate tokens** - Periodically reconnect OAuth

---

## 📈 Monitoring

### Health Checks

Built-in health check monitors cron process:

```bash
docker inspect backup | jq '.[0].State.Health'
```

### Log Monitoring

Monitor backup success/failure:

```bash
# Real-time logs
docker logs -f backup

# Check for errors
docker logs backup 2>&1 | grep ERROR

# Successful backups
docker logs backup 2>&1 | grep "completed successfully"
```

### Alerting

Integrate with monitoring systems:

```bash
#!/bin/bash
# Simple monitoring script
LOGS=$(docker logs --since 24h backup 2>&1)

if echo "$LOGS" | grep -q "ERROR:"; then
    echo "CRITICAL: Backup errors detected"
    exit 2
elif echo "$LOGS" | grep -q "completed successfully"; then
    echo "OK: Backup completed successfully"
    exit 0
else
    echo "WARNING: No recent backup completion"
    exit 1
fi
```

---

## 🚀 Production Checklist

Before deploying to production:

- [ ] OAuth configured and tested
- [ ] Database path verified
- [ ] Backup schedule configured
- [ ] Manual backup tested successfully
- [ ] Backup appears in Google Drive
- [ ] Container restarts automatically
- [ ] Logs are being captured
- [ ] Monitoring/alerting configured
- [ ] Restore procedure documented and tested
- [ ] rclone.conf backed up securely

---

## 🤝 Contributing

This is a production-focused backup tool. Contributions welcome:

1. Fork the repository
2. Create a feature branch
3. Test thoroughly
4. Submit pull request

---

## 📝 License

MIT License - use freely in personal and commercial projects.

---

## ❓ Support

- **Documentation:** Check the docs/ directory
- **Issues:** GitHub Issues
- **Examples:** See example_parent_playbook.yml

---

## 🎯 Use Cases

- **Web applications** - Backup application databases
- **API services** - Protect transactional data
- **IoT devices** - Backup sensor/device data
- **Development** - Automated dev environment backups
- **Personal projects** - Backup hobby project databases
- **Multi-tenant** - Separate backups per tenant/customer

---

**Built with:** Docker, Rclone, SQLite, Bash, Ansible
