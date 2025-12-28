FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && \
    apt-get install -y \
    sqlite3 \
    rclone \
    cron \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /etc/rclone /backups /data /scripts

# Copy backup script
COPY scripts/backup_sqlite.sh /scripts/backup_sqlite.sh
RUN chmod +x /scripts/backup_sqlite.sh

# Copy entrypoint script
COPY scripts/entrypoint.sh /scripts/entrypoint.sh
RUN chmod +x /scripts/entrypoint.sh

# Default environment variables (can be overridden)
# Database sources (use one or more):
ENV DB_PATH=""
ENV DB_PATHS=""
ENV DB_DIRS="/data"
ENV DB_PATTERN="*.sqlite"

# Backup configuration
ENV BACKUP_STAGING_DIR="/backups"
ENV RCLONE_REMOTE_NAME="gdrive"
ENV DRIVE_FOLDER_NAME="sqlite_backups"
ENV RCLONE_CONFIG_DIR="/etc/rclone"
ENV BACKUP_SCHEDULE="30 2 * * *"
ENV RUN_ON_STARTUP="false"
ENV RETENTION_DAYS="30"

# Health check to verify cron is running
HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep cron || exit 1

ENTRYPOINT ["/scripts/entrypoint.sh"]
CMD ["cron", "-f"]
