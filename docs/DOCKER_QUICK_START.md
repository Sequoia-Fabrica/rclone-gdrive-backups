# Docker Quick Start Guide

**Deploy SQLite Google Drive backups as a Docker container in 5 minutes.**

## Prerequisites

- Docker installed on your server
- Rclone configured with Google Drive OAuth
- SQLite database to backup

---

## Option 1: Using Ansible (Recommended)

### Step 1: Clone Repository

```bash
git clone https://github.com/yourorg/gdrive-backup.git
cd gdrive-backup
```

### Step 2: Prepare Rclone Config

```bash
# Configure rclone locally
rclone config
# Create a remote named "gdrive" (choose Google Drive, follow OAuth)

# Copy config to your server
scp ~/.config/rclone/rclone.conf user@your-server:/etc/gdrive-backup/rclone.conf
```

### Step 3: Create Inventory

```ini
# production.ini
[production]
your-server ansible_host=192.168.1.100 ansible_user=ubuntu
```

### Step 4: Deploy

```bash
ansible-playbook deploy_docker.yml \
  -i production.ini \
  -e "db_path=/var/lib/myapp/db.sqlite" \
  -e "rclone_remote_name=gdrive" \
  -e "drive_folder_name=backups"
```

**Done!** Container is now running with scheduled backups.

---

## Option 2: Using Docker Compose

### Step 1: Clone and Prepare

```bash
git clone https://github.com/yourorg/gdrive-backup.git
cd gdrive-backup

# Copy your rclone config
cp ~/.config/rclone/rclone.conf ./rclone.conf
chmod 600 ./rclone.conf
```

### Step 2: Edit docker-compose.yml

Update these environment variables:

```yaml
environment:
  - DB_PATH=/data/db.sqlite
  - RCLONE_REMOTE_NAME=gdrive
  - DRIVE_FOLDER_NAME=sqlite_backups
  - BACKUP_SCHEDULE=30 2 * * *  # 2:30 AM daily
```

Update this volume mount:

```yaml
volumes:
  - /var/lib/myapp/db.sqlite:/data/db.sqlite:ro
```

### Step 3: Deploy

```bash
docker-compose up -d
```

### Step 4: Verify

```bash
docker-compose logs -f gdrive_backup
docker-compose exec gdrive_backup /scripts/backup_sqlite.sh
```

**Done!**

---

## Option 3: Manual Docker Commands

### Step 1: Build Image

```bash
git clone https://github.com/yourorg/gdrive-backup.git
cd gdrive-backup
docker build -t sqlite-gdrive-backup:latest .
```

### Step 2: Run Container

```bash
docker run -d \
  --name sqlite_backup \
  --restart unless-stopped \
  -e DB_PATH="/data/db.sqlite" \
  -e RCLONE_REMOTE_NAME="gdrive" \
  -e DRIVE_FOLDER_NAME="sqlite_backups" \
  -e BACKUP_SCHEDULE="30 2 * * *" \
  -v /var/lib/myapp/db.sqlite:/data/db.sqlite:ro \
  -v /etc/gdrive-backup/rclone.conf:/etc/rclone/rclone.conf:ro \
  sqlite-gdrive-backup:latest
```

### Step 3: Verify

```bash
docker logs -f sqlite_backup
docker exec sqlite_backup /scripts/backup_sqlite.sh
```

**Done!**

---

## Verification Checklist

After deployment, verify everything works:

- [ ] Container is running: `docker ps | grep backup`
- [ ] Logs show no errors: `docker logs backup`
- [ ] Manual backup succeeds: `docker exec backup /scripts/backup_sqlite.sh`
- [ ] Backup appears in Google Drive: `rclone ls gdrive:sqlite_backups --config /path/to/rclone.conf`
- [ ] Container survives restart: `docker restart backup && docker logs backup`

---

## Common Commands

```bash
# View logs
docker logs -f sqlite_backup

# Run manual backup
docker exec sqlite_backup /scripts/backup_sqlite.sh

# Check schedule
docker exec sqlite_backup crontab -l

# Enter container
docker exec -it sqlite_backup /bin/bash

# Restart container
docker restart sqlite_backup

# Stop and remove
docker stop sqlite_backup
docker rm sqlite_backup

# View backup log inside container
docker exec sqlite_backup tail -f /var/log/backup.log
```

---

## Configuration Quick Reference

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DB_PATH` | Path to database in container | `/data/db.sqlite` |
| `RCLONE_REMOTE_NAME` | Name from rclone.conf | `gdrive` |
| `DRIVE_FOLDER_NAME` | Folder in Google Drive | `sqlite_backups` |
| `BACKUP_SCHEDULE` | Cron schedule | `30 2 * * *` |
| `RUN_ON_STARTUP` | Run backup on start | `true` or `false` |

### Cron Schedule Examples

```bash
# Every day at 2:30 AM
BACKUP_SCHEDULE="30 2 * * *"

# Every 6 hours
BACKUP_SCHEDULE="0 */6 * * *"

# Every Sunday at 3 AM
BACKUP_SCHEDULE="0 3 * * 0"

# Twice daily (6 AM and 6 PM)
BACKUP_SCHEDULE="0 6,18 * * *"
```

---

## Troubleshooting

### Container Exits Immediately

**Check logs:**
```bash
docker logs sqlite_backup
```

**Common causes:**
- Missing rclone.conf: Verify file exists and is mounted
- Invalid environment variables: Check all required vars are set
- Database not found: Verify database path and mount

### Can't Connect to Google Drive

**Test rclone:**
```bash
# Outside container
rclone lsd gdrive: --config /etc/gdrive-backup/rclone.conf

# Inside container
docker exec sqlite_backup rclone lsd gdrive: --config /etc/rclone/rclone.conf
```

**If OAuth token expired:**
```bash
# On your local machine
rclone config reconnect gdrive:

# Copy updated config to server
scp ~/.config/rclone/rclone.conf user@server:/etc/gdrive-backup/rclone.conf

# Restart container
docker restart sqlite_backup
```

### Backup Not Running

**Check cron:**
```bash
docker exec sqlite_backup pgrep cron
docker exec sqlite_backup crontab -l
```

**Check logs:**
```bash
docker exec sqlite_backup tail -f /var/log/backup.log
```

### Database Locked

**Solution: Enable WAL mode**
```bash
sqlite3 /path/to/db.sqlite "PRAGMA journal_mode=WAL;"
```

---

## Integration with Existing Applications

If your application is already running in Docker:

### Using Docker Compose

```yaml
version: '3.8'

services:
  myapp:
    image: myapp:latest
    volumes:
      - app_data:/data

  backup:
    image: sqlite-gdrive-backup:latest
    environment:
      - DB_PATH=/data/db.sqlite
      - RCLONE_REMOTE_NAME=gdrive
      - DRIVE_FOLDER_NAME=sqlite_backups
    volumes:
      - app_data:/data:ro
      - ./rclone.conf:/etc/rclone/rclone.conf:ro

volumes:
  app_data:
```

### Using Docker Networks

```bash
# Create shared volume
docker volume create app_data

# Run your app
docker run -d --name myapp -v app_data:/data myapp:latest

# Run backup
docker run -d --name backup \
  -v app_data:/data:ro \
  -v /etc/gdrive-backup/rclone.conf:/etc/rclone/rclone.conf:ro \
  -e DB_PATH=/data/db.sqlite \
  -e RCLONE_REMOTE_NAME=gdrive \
  sqlite-gdrive-backup:latest
```

---

## Next Steps

- [ ] Test restore procedure
- [ ] Set up monitoring/alerting
- [ ] Document your specific configuration
- [ ] Schedule periodic backup verification
- [ ] Consider encryption with rclone crypt

---

## Full Documentation

- **[DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md)** - Complete guide with advanced topics
- **[INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)** - Integrate into Ansible playbooks
- **[example_parent_playbook.yml](example_parent_playbook.yml)** - Full integration example
- **[README.md](README.md)** - Project overview

---

## Need Help?

1. Check [DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md) troubleshooting section
2. Review container logs: `docker logs sqlite_backup`
3. Test manual backup: `docker exec sqlite_backup /scripts/backup_sqlite.sh`
4. Verify rclone config: `docker exec sqlite_backup rclone lsd gdrive:`
