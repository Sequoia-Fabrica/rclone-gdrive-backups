# Docker Deployment Guide

This guide explains how to deploy the Google Drive backup system as a Docker container, either standalone or as part of a larger Ansible infrastructure.

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Integration with Parent Playbook](#integration-with-parent-playbook)
4. [Manual Docker Deployment](#manual-docker-deployment)
5. [Configuration Options](#configuration-options)
6. [Troubleshooting](#troubleshooting)

---

## Overview

The Google Drive backup system can be deployed as a Docker container that:

- Runs scheduled SQLite database backups using cron
- Uploads backups to Google Drive using rclone
- Manages retention policies automatically
- Requires minimal resources and runs in the background
- Can be integrated into existing Ansible playbooks

### Architecture

```
┌─────────────────────────────────────┐
│   Production Server                 │
│                                     │
│  ┌──────────────┐  ┌─────────────┐ │
│  │ Your App     │  │ Backup      │ │
│  │ Container    │  │ Container   │ │
│  │              │  │             │ │
│  │ ┌─────────┐  │  │  ┌───────┐ │ │
│  │ │Database │◄─┼──┼──┤Rclone │ │ │
│  │ │ SQLite  │  │  │  │ +Cron │ │ │
│  │ └─────────┘  │  │  └───┬───┘ │ │
│  └──────────────┘  └──────┼─────┘ │
│                           │       │
└───────────────────────────┼───────┘
                            │
                            ▼
                    ┌───────────────┐
                    │ Google Drive  │
                    │   Backups     │
                    └───────────────┘
```

---

## Quick Start

### Option 1: Using Ansible (Recommended)

1. **Clone this repository on your control machine:**
   ```bash
   git clone https://github.com/yourorg/gdrive-backup.git
   cd gdrive-backup
   ```

2. **Set up your rclone configuration:**
   ```bash
   # On your local machine, configure rclone with OAuth
   rclone config
   
   # Create a remote named "gdrive" (or your preferred name)
   # Choose "Google Drive" and follow the OAuth flow
   
   # Copy the config to a safe location
   cp ~/.config/rclone/rclone.conf ./rclone.conf.production
   ```

3. **Create an inventory file:**
   ```ini
   # production_inventory.ini
   [production_servers]
   prod-server-1 ansible_host=192.168.1.100 ansible_user=ubuntu
   ```

4. **Run the deployment playbook:**
   ```bash
   ansible-playbook deploy_docker.yml \
     -i production_inventory.ini \
     -e rclone_config_path=/etc/gdrive-backup/rclone.conf \
     -e db_path=/var/lib/myapp/db.sqlite \
     -e rclone_remote_name=gdrive
   ```

5. **Copy your rclone config to the server:**
   ```bash
   scp rclone.conf.production ubuntu@prod-server-1:/etc/gdrive-backup/rclone.conf
   ```

### Option 2: Manual Docker Commands

See [Manual Docker Deployment](#manual-docker-deployment) section below.

---

## Integration with Parent Playbook

This is the recommended approach for production deployments where you have an existing Ansible infrastructure.

### Step 1: Structure Your Parent Playbook

```
your-infrastructure/
├── playbooks/
│   └── deploy_production.yml       # Your main playbook
├── files/
│   └── rclone.conf                 # Your rclone config
├── inventory/
│   └── production.ini
└── roles/
    └── ...
```

### Step 2: Add Backup Deployment to Your Playbook

Here's a minimal example of integrating the backup system:

```yaml
---
- name: Deploy Production Application with Backups
  hosts: production
  become: yes
  vars:
    # Your app configuration
    app_name: "myapp"
    app_db_path: "/var/lib/myapp/db.sqlite"
    
    # Backup repository
    backup_repo_url: "https://github.com/yourorg/gdrive-backup.git"
    backup_repo_dest: "/opt/gdrive-backup"
    
    # Backup configuration
    rclone_remote: "gdrive"
    backup_folder: "production_backups"

  tasks:
    # ... your existing tasks for deploying your app ...

    - name: Clone backup repository
      git:
        repo: "{{ backup_repo_url }}"
        dest: "{{ backup_repo_dest }}"
        version: "main"

    - name: Deploy rclone config
      copy:
        src: files/rclone.conf
        dest: /etc/gdrive-backup/rclone.conf
        mode: '0600'

    - name: Deploy backup container
      ansible.builtin.import_playbook: "{{ backup_repo_dest }}/deploy_docker.yml"
      vars:
        db_path: "{{ app_db_path }}"
        rclone_remote_name: "{{ rclone_remote }}"
        drive_folder_name: "{{ backup_folder }}"
        backup_schedule: "0 3 * * *"  # 3 AM daily
```

### Step 3: Alternative - Use include_tasks

If you prefer to keep everything in one playbook:

```yaml
- name: Deploy backup system
  include_tasks:
    file: "{{ backup_repo_dest }}/deploy_docker.yml"
  vars:
    container_name: "myapp_backup"
    db_path: "/var/lib/myapp/db.sqlite"
    rclone_remote_name: "gdrive"
    drive_folder_name: "production_backups"
    backup_schedule: "0 3 * * *"
    rclone_config_path: "/etc/gdrive-backup/rclone.conf"
```

### Step 4: Run Your Playbook

```bash
# Full deployment
ansible-playbook playbooks/deploy_production.yml -i inventory/production.ini

# Deploy only backups (if using tags)
ansible-playbook playbooks/deploy_production.yml -i inventory/production.ini --tags backup
```

---

## Manual Docker Deployment

If you prefer to deploy without Ansible:

### 1. Build the Docker Image

```bash
# Clone the repository
git clone https://github.com/yourorg/gdrive-backup.git
cd gdrive-backup

# Build the image
docker build -t sqlite-gdrive-backup:latest .
```

### 2. Prepare Rclone Configuration

```bash
# Configure rclone locally
rclone config

# Copy the config to your server
mkdir -p /etc/gdrive-backup
cp ~/.config/rclone/rclone.conf /etc/gdrive-backup/rclone.conf
chmod 600 /etc/gdrive-backup/rclone.conf
```

### 3. Run the Container

```bash
docker run -d \
  --name sqlite_gdrive_backup \
  --restart unless-stopped \
  -e DB_PATH="/data/db.sqlite" \
  -e RCLONE_REMOTE_NAME="gdrive" \
  -e DRIVE_FOLDER_NAME="sqlite_backups" \
  -e BACKUP_SCHEDULE="30 2 * * *" \
  -e RUN_ON_STARTUP="false" \
  -v /var/lib/myapp/db.sqlite:/data/db.sqlite:ro \
  -v /etc/gdrive-backup/rclone.conf:/etc/rclone/rclone.conf:ro \
  sqlite-gdrive-backup:latest
```

### 4. Verify the Container

```bash
# Check if container is running
docker ps | grep sqlite_gdrive_backup

# View logs
docker logs -f sqlite_gdrive_backup

# Run a manual backup
docker exec sqlite_gdrive_backup /scripts/backup_sqlite.sh

# Check the backup in Google Drive
rclone ls gdrive:sqlite_backups --config /etc/gdrive-backup/rclone.conf
```

---

## Configuration Options

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `DB_PATH` | Path to the SQLite database file inside the container | `/data/db.sqlite` | Yes |
| `RCLONE_REMOTE_NAME` | Name of the rclone remote (from rclone.conf) | `gdrive` | Yes |
| `DRIVE_FOLDER_NAME` | Folder name in Google Drive for backups | `sqlite_backups` | Yes |
| `BACKUP_SCHEDULE` | Cron schedule for backups | `30 2 * * *` | No |
| `RUN_ON_STARTUP` | Run backup immediately when container starts | `false` | No |
| `RCLONE_CONFIG_DIR` | Directory containing rclone.conf | `/etc/rclone` | No |
| `BACKUP_STAGING_DIR` | Temporary directory for backups | `/backups` | No |

### Ansible Variables (deploy_docker.yml)

| Variable | Description | Default |
|----------|-------------|---------|
| `container_name` | Name for the Docker container | `sqlite_gdrive_backup` |
| `image_name` | Docker image name | `sqlite-gdrive-backup` |
| `image_tag` | Docker image tag | `latest` |
| `db_path` | Host path to the database | `/var/lib/myapp/db.sqlite` |
| `rclone_remote_name` | Rclone remote name | `gdrive` |
| `drive_folder_name` | Google Drive folder name | `sqlite_backups` |
| `backup_schedule` | Cron schedule | `30 2 * * *` |
| `run_on_startup` | Run backup on startup | `false` |
| `rclone_config_path` | Host path to rclone.conf | `/etc/gdrive-backup/rclone.conf` |

### Cron Schedule Examples

```bash
# Every day at 2:30 AM
BACKUP_SCHEDULE="30 2 * * *"

# Every 6 hours
BACKUP_SCHEDULE="0 */6 * * *"

# Every Sunday at 3:00 AM
BACKUP_SCHEDULE="0 3 * * 0"

# Every weekday at 1:00 AM
BACKUP_SCHEDULE="0 1 * * 1-5"

# Twice daily (6 AM and 6 PM)
BACKUP_SCHEDULE="0 6,18 * * *"
```

---

## Volume Mounts

### Required Volumes

1. **Database (Read-Only)**
   ```bash
   -v /path/to/db.sqlite:/data/db.sqlite:ro
   ```
   Mount your SQLite database as read-only. The container only needs read access.

2. **Rclone Configuration (Read-Only)**
   ```bash
   -v /path/to/rclone.conf:/etc/rclone/rclone.conf:ro
   ```
   Mount your rclone configuration file.

### Optional Volumes

3. **Backup Staging Directory**
   ```bash
   -v /path/to/staging:/backups
   ```
   If you want backups to persist temporarily on the host.

4. **Log Persistence**
   ```bash
   -v /path/to/logs:/var/log
   ```
   Persist backup logs outside the container.

---

## Troubleshooting

### Container Starts But Exits Immediately

**Check the logs:**
```bash
docker logs sqlite_gdrive_backup
```

**Common causes:**
- Missing rclone.conf file
- Invalid environment variables
- Database file doesn't exist

### Backup Fails - Cannot Connect to Google Drive

**Verify rclone config:**
```bash
# Test rclone connection on the host
rclone lsd gdrive: --config /etc/gdrive-backup/rclone.conf

# Test inside the container
docker exec sqlite_gdrive_backup rclone lsd gdrive: --config /etc/rclone/rclone.conf
```

**Check token expiration:**
OAuth tokens expire. If you see `invalid_grant` errors, re-authenticate:
```bash
# On your local machine
rclone config reconnect gdrive:

# Copy updated config to server
scp ~/.config/rclone/rclone.conf user@server:/etc/gdrive-backup/rclone.conf

# Restart container
docker restart sqlite_gdrive_backup
```

### Database Locked Error

**Symptom:** `database is locked` error in logs

**Solution:** Ensure no other process is writing to the database during backup, or use WAL mode:
```bash
sqlite3 /path/to/db.sqlite "PRAGMA journal_mode=WAL;"
```

### Backups Not Running on Schedule

**Check cron is running:**
```bash
docker exec sqlite_gdrive_backup pgrep cron
```

**Check crontab:**
```bash
docker exec sqlite_gdrive_backup crontab -l
```

**Check logs:**
```bash
docker exec sqlite_gdrive_backup tail -f /var/log/backup.log
```

### Manual Backup Test

Run a backup manually to test:
```bash
docker exec sqlite_gdrive_backup /scripts/backup_sqlite.sh
```

### Viewing Real-Time Logs

```bash
# Container logs
docker logs -f sqlite_gdrive_backup

# Backup script logs
docker exec sqlite_gdrive_backup tail -f /var/log/backup.log
```

### Check Container Health

```bash
# Container status
docker ps -a | grep sqlite_gdrive_backup

# Health check
docker inspect sqlite_gdrive_backup | jq '.[0].State.Health'

# Resource usage
docker stats sqlite_gdrive_backup
```

---

## Security Best Practices

1. **Read-Only Mounts**
   - Always mount the database as read-only (`:ro`)
   - Mount rclone.conf as read-only

2. **File Permissions**
   ```bash
   chmod 600 /etc/gdrive-backup/rclone.conf
   chown root:root /etc/gdrive-backup/rclone.conf
   ```

3. **Network Isolation**
   - The container doesn't need to expose any ports
   - Consider using a dedicated Docker network

4. **Secrets Management**
   - Don't commit rclone.conf to version control
   - Use Ansible Vault for sensitive data in playbooks
   - Consider Docker secrets or external secret managers

5. **OAuth Token Security**
   - OAuth refresh tokens are stored in rclone.conf
   - Protect this file with appropriate permissions
   - Rotate tokens periodically

---

## Advanced Usage

### Running Multiple Backup Containers

You can run multiple containers for different databases:

```bash
# Backup for app1
docker run -d \
  --name app1_backup \
  -v /var/lib/app1/db.sqlite:/data/db.sqlite:ro \
  -v /etc/gdrive-backup/rclone.conf:/etc/rclone/rclone.conf:ro \
  -e RCLONE_REMOTE_NAME="gdrive" \
  -e DRIVE_FOLDER_NAME="app1_backups" \
  sqlite-gdrive-backup:latest

# Backup for app2
docker run -d \
  --name app2_backup \
  -v /var/lib/app2/db.sqlite:/data/db.sqlite:ro \
  -v /etc/gdrive-backup/rclone.conf:/etc/rclone/rclone.conf:ro \
  -e RCLONE_REMOTE_NAME="gdrive" \
  -e DRIVE_FOLDER_NAME="app2_backups" \
  sqlite-gdrive-backup:latest
```

### Using Docker Compose

Create a `docker-compose.yml`:

```yaml
version: '3.8'

services:
  myapp:
    image: myorg/myapp:latest
    volumes:
      - app_data:/data
    ports:
      - "8080:8080"

  backup:
    image: sqlite-gdrive-backup:latest
    restart: unless-stopped
    environment:
      - DB_PATH=/data/db.sqlite
      - RCLONE_REMOTE_NAME=gdrive
      - DRIVE_FOLDER_NAME=sqlite_backups
      - BACKUP_SCHEDULE=30 2 * * *
    volumes:
      - app_data:/data:ro
      - ./rclone.conf:/etc/rclone/rclone.conf:ro

volumes:
  app_data:
```

Run with:
```bash
docker-compose up -d
```

### Custom Retention Policies

Edit the backup script to change retention:

```bash
# Keep backups for 90 days instead of 30
docker exec sqlite_gdrive_backup sed -i 's/--min-age 30d/--min-age 90d/' /scripts/backup_sqlite.sh
docker restart sqlite_gdrive_backup
```

Or rebuild with a custom script.

---

## Monitoring and Alerts

### Log Monitoring

Use a log aggregator to monitor backup success/failure:

```bash
# Example with promtail/loki
docker run -d \
  --name sqlite_gdrive_backup \
  --log-driver=loki \
  --log-opt loki-url="http://loki:3100/loki/api/v1/push" \
  ...
```

### Health Checks

The container includes a health check that monitors the cron process. You can integrate with monitoring systems:

```bash
# Check health status
docker inspect --format='{{.State.Health.Status}}' sqlite_gdrive_backup
```

### Alerting on Failures

Monitor the logs for errors:

```bash
#!/bin/bash
# check_backup.sh - Run this from your monitoring system

LOGS=$(docker logs --since 24h sqlite_gdrive_backup 2>&1)

if echo "$LOGS" | grep -q "ERROR:"; then
    echo "CRITICAL: Backup errors detected"
    exit 2
elif echo "$LOGS" | grep -q "Backup process completed successfully"; then
    echo "OK: Backup completed successfully"
    exit 0
else
    echo "WARNING: No recent backup completion found"
    exit 1
fi
```

---

## Next Steps

1. Review the [example parent playbook](example_parent_playbook.yml) for integration patterns
2. Set up monitoring for backup success/failure
3. Test your restore process (see RESTORE.md if available)
4. Schedule periodic verification of backups
5. Consider implementing backup encryption with rclone crypt

---

## Support

For issues, questions, or contributions:
- GitHub Issues: [Your repo URL]
- Documentation: Check the other .md files in this repository
- Rclone Docs: https://rclone.org/docs/
