#!/bin/bash
set -e

# Configuration from environment variables
DB_PATH="${DB_PATH:-/data/db.sqlite}"
BACKUP_DIR="${BACKUP_STAGING_DIR:-/backups}"
REMOTE_NAME="${RCLONE_REMOTE_NAME:-gdrive}"
REMOTE_FOLDER="${DRIVE_FOLDER_NAME:-sqlite_backups}"
RCLONE_CONFIG_DIR="${RCLONE_CONFIG_DIR:-/etc/rclone}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="db_backup_${TIMESTAMP}.sqlite"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
    log "ERROR: Database not found at $DB_PATH"
    exit 1
fi

# Check if rclone config exists
if [ ! -f "$RCLONE_CONFIG_DIR/rclone.conf" ]; then
    log "ERROR: Rclone config not found at $RCLONE_CONFIG_DIR/rclone.conf"
    exit 1
fi

# Ensure backup dir exists
mkdir -p "$BACKUP_DIR"

log "Starting backup of $DB_PATH"

# 1. Safe Hot Backup using SQLite VACUUM INTO
# This creates a transaction-safe copy without locking the DB for long
log "Creating backup file: $BACKUP_NAME"
if ! sqlite3 "$DB_PATH" "VACUUM INTO '$BACKUP_DIR/$BACKUP_NAME'"; then
    log "ERROR: Failed to create backup"
    exit 1
fi

BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_NAME" | cut -f1)
log "Backup created successfully (size: $BACKUP_SIZE)"

# 2. Upload to Google Drive
log "Uploading to $REMOTE_NAME:$REMOTE_FOLDER"
if ! rclone copy "$BACKUP_DIR/$BACKUP_NAME" "$REMOTE_NAME:$REMOTE_FOLDER" \
    --config "$RCLONE_CONFIG_DIR/rclone.conf" \
    --stats-one-line \
    --stats 10s; then
    log "ERROR: Failed to upload backup to Google Drive"
    log "Backup file retained locally at: $BACKUP_DIR/$BACKUP_NAME"
    exit 1
fi

log "Upload completed successfully"

# 3. Cleanup Local File
log "Removing local backup file"
rm "$BACKUP_DIR/$BACKUP_NAME"

# 4. Retention (Optional: Delete cloud backups older than 30 days)
log "Running retention policy (deleting backups older than 30 days)"
if ! rclone delete "$REMOTE_NAME:$REMOTE_FOLDER" --min-age 30d \
    --config "$RCLONE_CONFIG_DIR/rclone.conf"; then
    log "WARNING: Failed to apply retention policy"
fi

log "Backup process completed successfully"
