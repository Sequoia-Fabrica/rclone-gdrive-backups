#!/bin/bash
set -euo pipefail

# ============================================================================
# SQLite Multi-Database Backup Script
# ============================================================================
# Supports:
#   - Single database: DB_PATH="/data/db.sqlite"
#   - Multiple databases: DB_PATHS="/data/db1.sqlite:/data/db2.sqlite"
#   - Directory scan: DB_DIRS="/data/databases:/var/lib/apps"
#   - Combined: All three can be used together
# ============================================================================

# Configuration from environment variables
DB_PATH="${DB_PATH:-}"
DB_PATHS="${DB_PATHS:-}"
DB_DIRS="${DB_DIRS:-}"
DB_PATTERN="${DB_PATTERN:-*.sqlite}"

BACKUP_DIR="${BACKUP_STAGING_DIR:-/backups}"
REMOTE_NAME="${RCLONE_REMOTE_NAME:-gdrive}"
REMOTE_FOLDER="${DRIVE_FOLDER_NAME:-sqlite_backups}"
RCLONE_CONFIG_DIR="${RCLONE_CONFIG_DIR:-/etc/rclone}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Counters for summary
TOTAL_DBS=0
SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_DBS=()

# ============================================================================
# Logging Functions
# ============================================================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

log_warn() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $*"
}

log_success() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ $*"
}

# ============================================================================
# Validation
# ============================================================================

validate_environment() {
    # Check if rclone config exists
    if [ ! -f "$RCLONE_CONFIG_DIR/rclone.conf" ]; then
        log_error "Rclone config not found at $RCLONE_CONFIG_DIR/rclone.conf"
        exit 1
    fi

    # Ensure backup dir exists
    mkdir -p "$BACKUP_DIR"

    # Check that at least one database source is specified
    if [ -z "$DB_PATH" ] && [ -z "$DB_PATHS" ] && [ -z "$DB_DIRS" ]; then
        log_error "No databases specified. Set DB_PATH, DB_PATHS, or DB_DIRS"
        log_error "  DB_PATH  - Single database file"
        log_error "  DB_PATHS - Colon-separated list of database files"
        log_error "  DB_DIRS  - Colon-separated list of directories to scan for $DB_PATTERN"
        exit 1
    fi
}

# ============================================================================
# Database Discovery
# ============================================================================

# Collect all database paths into an array
declare -a ALL_DATABASES=()

collect_databases() {
    # Add single DB_PATH if specified
    if [ -n "$DB_PATH" ]; then
        if [ -f "$DB_PATH" ]; then
            ALL_DATABASES+=("$DB_PATH")
            log "Found database: $DB_PATH (from DB_PATH)"
        else
            log_warn "Database not found: $DB_PATH (from DB_PATH)"
        fi
    fi

    # Add databases from DB_PATHS (colon or comma separated)
    if [ -n "$DB_PATHS" ]; then
        # Replace commas with colons for unified parsing
        local paths="${DB_PATHS//,/:}"
        IFS=':' read -ra PATH_ARRAY <<< "$paths"
        for db_path in "${PATH_ARRAY[@]}"; do
            # Trim whitespace
            db_path=$(echo "$db_path" | xargs)
            if [ -n "$db_path" ]; then
                if [ -f "$db_path" ]; then
                    ALL_DATABASES+=("$db_path")
                    log "Found database: $db_path (from DB_PATHS)"
                else
                    log_warn "Database not found: $db_path (from DB_PATHS)"
                fi
            fi
        done
    fi

    # Scan directories from DB_DIRS
    if [ -n "$DB_DIRS" ]; then
        # Replace commas with colons for unified parsing
        local dirs="${DB_DIRS//,/:}"
        IFS=':' read -ra DIR_ARRAY <<< "$dirs"
        for dir_path in "${DIR_ARRAY[@]}"; do
            # Trim whitespace
            dir_path=$(echo "$dir_path" | xargs)
            if [ -n "$dir_path" ]; then
                if [ -d "$dir_path" ]; then
                    log "Scanning directory: $dir_path (pattern: $DB_PATTERN)"
                    while IFS= read -r -d '' db_file; do
                        ALL_DATABASES+=("$db_file")
                        log "Found database: $db_file (from DB_DIRS)"
                    done < <(find "$dir_path" -maxdepth 1 -type f -name "$DB_PATTERN" -print0 2>/dev/null)
                else
                    log_warn "Directory not found: $dir_path (from DB_DIRS)"
                fi
            fi
        done
    fi

    # Remove duplicates while preserving order
    local -A seen=()
    local -a unique_dbs=()
    for db in "${ALL_DATABASES[@]}"; do
        if [ -z "${seen[$db]:-}" ]; then
            seen[$db]=1
            unique_dbs+=("$db")
        fi
    done
    ALL_DATABASES=("${unique_dbs[@]}")

    TOTAL_DBS=${#ALL_DATABASES[@]}

    if [ "$TOTAL_DBS" -eq 0 ]; then
        log_error "No valid databases found to backup"
        exit 1
    fi

    log "============================================"
    log "Total databases to backup: $TOTAL_DBS"
    log "============================================"
}

# ============================================================================
# Backup Functions
# ============================================================================

# Generate backup filename from database path
generate_backup_name() {
    local db_path="$1"
    local db_basename=$(basename "$db_path")
    local db_name="${db_basename%.*}"  # Remove extension
    echo "${db_name}_backup_${TIMESTAMP}.sqlite"
}

# Backup a single database
backup_database() {
    local db_path="$1"
    local backup_name=$(generate_backup_name "$db_path")
    local backup_path="$BACKUP_DIR/$backup_name"
    local db_basename=$(basename "$db_path")

    log ""
    log "--- Backing up: $db_basename ---"
    log "Source: $db_path"
    log "Backup: $backup_name"

    # 1. Create backup using VACUUM INTO (safe hot backup)
    log "Creating backup file..."
    if ! sqlite3 "$db_path" "VACUUM INTO '$backup_path'" 2>&1; then
        log_error "Failed to create backup for $db_basename"
        return 1
    fi

    local backup_size=$(du -h "$backup_path" | cut -f1)
    log "Backup created (size: $backup_size)"

    # 2. Upload to Google Drive
    log "Uploading to $REMOTE_NAME:$REMOTE_FOLDER..."
    if ! rclone copy "$backup_path" "$REMOTE_NAME:$REMOTE_FOLDER" \
        --config "$RCLONE_CONFIG_DIR/rclone.conf" \
        --stats-one-line \
        --stats 10s 2>&1; then
        log_error "Failed to upload backup for $db_basename"
        log_error "Backup retained locally at: $backup_path"
        return 1
    fi

    log "Upload completed"

    # 3. Cleanup local backup file
    rm -f "$backup_path"

    log_success "Backup completed for $db_basename"
    return 0
}

# ============================================================================
# Retention Policy
# ============================================================================

apply_retention_policy() {
    if [ "$RETENTION_DAYS" -le 0 ]; then
        log "Retention policy disabled (RETENTION_DAYS=$RETENTION_DAYS)"
        return
    fi

    log ""
    log "============================================"
    log "Applying retention policy (deleting backups older than ${RETENTION_DAYS} days)"
    log "============================================"

    if ! rclone delete "$REMOTE_NAME:$REMOTE_FOLDER" \
        --min-age "${RETENTION_DAYS}d" \
        --config "$RCLONE_CONFIG_DIR/rclone.conf" 2>&1; then
        log_warn "Failed to apply retention policy"
    else
        log "Retention policy applied"
    fi
}

# ============================================================================
# Main
# ============================================================================

main() {
    log "============================================"
    log "SQLite Multi-Database Backup"
    log "============================================"
    log "Timestamp: $TIMESTAMP"
    log "Remote: $REMOTE_NAME:$REMOTE_FOLDER"
    log "Retention: ${RETENTION_DAYS} days"
    log ""

    # Validate environment
    validate_environment

    # Collect all databases to backup
    collect_databases

    # Backup each database
    for db_path in "${ALL_DATABASES[@]}"; do
        if backup_database "$db_path"; then
            ((SUCCESS_COUNT++))
        else
            ((FAIL_COUNT++))
            FAILED_DBS+=("$db_path")
        fi
    done

    # Apply retention policy (once, after all backups)
    apply_retention_policy

    # Summary
    log ""
    log "============================================"
    log "BACKUP SUMMARY"
    log "============================================"
    log "Total databases: $TOTAL_DBS"
    log "Successful: $SUCCESS_COUNT"
    log "Failed: $FAIL_COUNT"

    if [ "$FAIL_COUNT" -gt 0 ]; then
        log ""
        log "Failed databases:"
        for failed_db in "${FAILED_DBS[@]}"; do
            log "  - $failed_db"
        done
        log ""
        log_error "Backup completed with errors"
        exit 1
    else
        log ""
        log_success "All backups completed successfully"
        exit 0
    fi
}

# Run main
main "$@"
