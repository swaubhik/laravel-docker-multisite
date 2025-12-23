#!/bin/sh

# Database Backup Script for Cron (runs inside container)
# This script is called by cron automatically

set -e

# Logging
LOG_FILE="/var/log/supervisor/db-backup.log"
exec >> "$LOG_FILE" 2>&1

echo "=========================================="
echo "Backup started at $(date)"
echo "=========================================="

# Backup directory (mounted volume)
BACKUP_DIR="/var/www/backups"
mkdir -p "$BACKUP_DIR"

# Backup filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DAY_OF_WEEK=$(date +"%A")
BACKUP_FILE="$BACKUP_DIR/backup_${TIMESTAMP}.sql"
BACKUP_FILE_GZ="$BACKUP_FILE.gz"
DAILY_BACKUP="$BACKUP_DIR/daily_${DAY_OF_WEEK}.sql.gz"

# Run PHP backup script
php /usr/local/bin/db-backup.php "$BACKUP_FILE"

# Compress backup
gzip -f "$BACKUP_FILE"

# Copy as daily backup (overwrites previous same-day backup)
cp "$BACKUP_FILE_GZ" "$DAILY_BACKUP"

echo "Daily backup: $(basename "$DAILY_BACKUP")"

# Cleanup: Keep only last 7 timestamped backups
echo "Cleaning up old backups..."
cd "$BACKUP_DIR"
ls -1t backup_*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm -f

# Count remaining backups
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/backup_*.sql.gz 2>/dev/null | wc -l)
echo "Total timestamped backups: $BACKUP_COUNT"

echo "Backup finished at $(date)"
echo ""
