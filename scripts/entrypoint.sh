#!/bin/bash
set -e

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log "Starting Google Drive Backup Container"

# Validate required environment variables
if [ -z "$RCLONE_REMOTE_NAME" ]; then
    log "ERROR: RCLONE_REMOTE_NAME environment variable is required"
    exit 1
fi

if [ -z "$DB_PATH" ]; then
    log "ERROR: DB_PATH environment variable is required"
    exit 1
fi

# Check if rclone config exists
if [ ! -f "$RCLONE_CONFIG_DIR/rclone.conf" ]; then
    log "ERROR: Rclone config not found at $RCLONE_CONFIG_DIR/rclone.conf"
    log "Please mount your rclone config as a volume: -v /path/to/rclone.conf:$RCLONE_CONFIG_DIR/rclone.conf:ro"
    exit 1
fi

# Verify rclone can connect to remote
log "Verifying rclone connection to $RCLONE_REMOTE_NAME..."
if rclone lsd "$RCLONE_REMOTE_NAME:" --config "$RCLONE_CONFIG_DIR/rclone.conf" > /dev/null 2>&1; then
    log "✓ Successfully connected to $RCLONE_REMOTE_NAME"
else
    log "WARNING: Could not connect to $RCLONE_REMOTE_NAME. Please check your rclone config."
fi

# Create backup folder on remote if it doesn't exist
log "Ensuring remote backup folder exists: $RCLONE_REMOTE_NAME:$DRIVE_FOLDER_NAME"
rclone mkdir "$RCLONE_REMOTE_NAME:$DRIVE_FOLDER_NAME" --config "$RCLONE_CONFIG_DIR/rclone.conf" 2>/dev/null || true

# Setup cron job
CRON_SCHEDULE="${BACKUP_SCHEDULE:-30 2 * * *}"
log "Setting up cron job with schedule: $CRON_SCHEDULE"

# Remove any existing cron jobs for this script
crontab -l 2>/dev/null | grep -v '/scripts/backup_sqlite.sh' | crontab - 2>/dev/null || true

# Add new cron job
(crontab -l 2>/dev/null; echo "$CRON_SCHEDULE /scripts/backup_sqlite.sh >> /var/log/backup.log 2>&1") | crontab -

log "Cron job configured: $CRON_SCHEDULE"

# Create log file
touch /var/log/backup.log
chmod 644 /var/log/backup.log

# Run backup immediately on startup if requested
if [ "$RUN_ON_STARTUP" = "true" ]; then
    log "RUN_ON_STARTUP=true, running initial backup..."
    /scripts/backup_sqlite.sh 2>&1 | tee -a /var/log/backup.log || log "Initial backup failed"
fi

log "Container initialization complete"
log "Backup schedule: $CRON_SCHEDULE"
log "Database: $DB_PATH"
log "Remote: $RCLONE_REMOTE_NAME:$DRIVE_FOLDER_NAME"
log "Logs available at: /var/log/backup.log"

# Execute the CMD from Dockerfile (usually "cron -f")
exec "$@"
