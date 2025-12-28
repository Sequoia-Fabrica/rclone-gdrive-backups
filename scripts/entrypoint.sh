#!/bin/bash
set -e

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log "============================================"
log "Starting SQLite Google Drive Backup Container"
log "============================================"

# Validate required environment variables
if [ -z "$RCLONE_REMOTE_NAME" ]; then
    log "ERROR: RCLONE_REMOTE_NAME environment variable is required"
    exit 1
fi

# Check that at least one database source is specified
if [ -z "$DB_PATH" ] && [ -z "$DB_PATHS" ] && [ -z "$DB_DIRS" ]; then
    log "ERROR: No databases specified"
    log "Set at least one of:"
    log "  DB_PATH  - Single database file"
    log "  DB_PATHS - Colon-separated list of database files"
    log "  DB_DIRS  - Colon-separated list of directories to scan"
    exit 1
fi

# Check if rclone config exists
if [ ! -f "$RCLONE_CONFIG_DIR/rclone.conf" ]; then
    log "ERROR: Rclone config not found at $RCLONE_CONFIG_DIR/rclone.conf"
    log "Please mount your rclone config as a volume:"
    log "  -v /path/to/rclone.conf:$RCLONE_CONFIG_DIR/rclone.conf:ro"
    exit 1
fi

# Verify rclone can connect to remote
log ""
log "Verifying rclone connection to $RCLONE_REMOTE_NAME..."
if rclone lsd "$RCLONE_REMOTE_NAME:" --config "$RCLONE_CONFIG_DIR/rclone.conf" > /dev/null 2>&1; then
    log "✓ Successfully connected to $RCLONE_REMOTE_NAME"
else
    log "WARNING: Could not connect to $RCLONE_REMOTE_NAME"
    log "Please check your rclone config and OAuth token"
fi

# Create backup folder on remote if it doesn't exist
log "Ensuring remote backup folder exists: $RCLONE_REMOTE_NAME:$DRIVE_FOLDER_NAME"
rclone mkdir "$RCLONE_REMOTE_NAME:$DRIVE_FOLDER_NAME" --config "$RCLONE_CONFIG_DIR/rclone.conf" 2>/dev/null || true

# Setup cron job
CRON_SCHEDULE="${BACKUP_SCHEDULE:-30 2 * * *}"
log ""
log "Setting up cron job with schedule: $CRON_SCHEDULE"

# Export environment variables for cron
# Cron runs in a minimal environment, so we need to pass our variables
printenv | grep -E '^(DB_|RCLONE_|DRIVE_|BACKUP_|RETENTION_)' > /etc/environment

# Remove any existing cron jobs for this script
crontab -l 2>/dev/null | grep -v '/scripts/backup_sqlite.sh' | crontab - 2>/dev/null || true

# Add new cron job with environment sourcing
(crontab -l 2>/dev/null; echo "$CRON_SCHEDULE . /etc/environment && /scripts/backup_sqlite.sh >> /var/log/backup.log 2>&1") | crontab -

log "Cron job configured"

# Create log file
touch /var/log/backup.log
chmod 644 /var/log/backup.log

# Display configuration summary
log ""
log "============================================"
log "Configuration Summary"
log "============================================"
log "Remote: $RCLONE_REMOTE_NAME:$DRIVE_FOLDER_NAME"
log "Schedule: $CRON_SCHEDULE"
log "Retention: ${RETENTION_DAYS:-30} days"
log ""
log "Database sources:"
if [ -n "$DB_PATH" ]; then
    log "  DB_PATH: $DB_PATH"
fi
if [ -n "$DB_PATHS" ]; then
    log "  DB_PATHS: $DB_PATHS"
fi
if [ -n "$DB_DIRS" ]; then
    log "  DB_DIRS: $DB_DIRS"
    log "  DB_PATTERN: ${DB_PATTERN:-*.sqlite}"
fi
log ""
log "Logs: /var/log/backup.log"
log "============================================"

# Run backup immediately on startup if requested
if [ "$RUN_ON_STARTUP" = "true" ]; then
    log ""
    log "RUN_ON_STARTUP=true, running initial backup..."
    log ""
    /scripts/backup_sqlite.sh 2>&1 | tee -a /var/log/backup.log || log "Initial backup completed with errors"
fi

log ""
log "Container initialization complete"
log "Waiting for scheduled backups..."
log ""

# Execute the CMD from Dockerfile (usually "cron -f")
exec "$@"
