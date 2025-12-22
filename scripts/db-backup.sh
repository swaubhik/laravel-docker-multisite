#!/bin/bash

# Database Backup Script for Laravel Docker Environment
# Usage: ./scripts/db-backup.sh [backup_name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
fi

# Database credentials (from .env or defaults)
DB_HOST="${DB_HOST:-mysql}"
DB_DATABASE="${DB_DATABASE:-laravel}"
DB_USERNAME="${DB_USERNAME:-laravel}"
DB_PASSWORD="${DB_PASSWORD:-secret}"
CONTAINER_NAME="${MYSQL_CONTAINER:-laravel_mysql}"

# Backup directory
BACKUP_DIR="$PROJECT_DIR/backups"
mkdir -p "$BACKUP_DIR"

# Backup filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="${1:-backup_${TIMESTAMP}}"
BACKUP_FILE="$BACKUP_DIR/${BACKUP_NAME}.sql"
BACKUP_FILE_GZ="$BACKUP_FILE.gz"

echo -e "${YELLOW}Starting database backup...${NC}"
echo -e "Database: ${GREEN}$DB_DATABASE${NC}"
echo -e "Container: ${GREEN}$CONTAINER_NAME${NC}"

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}Error: MySQL container '$CONTAINER_NAME' is not running${NC}"
    exit 1
fi

# Create backup
echo -e "${YELLOW}Creating backup...${NC}"
docker exec "$CONTAINER_NAME" mysqldump \
    -u"$DB_USERNAME" \
    -p"$DB_PASSWORD" \
    --single-transaction \
    --routines \
    --triggers \
    --add-drop-table \
    "$DB_DATABASE" > "$BACKUP_FILE"

# Compress backup
echo -e "${YELLOW}Compressing backup...${NC}"
gzip -f "$BACKUP_FILE"

# Get file size
FILESIZE=$(du -h "$BACKUP_FILE_GZ" | cut -f1)

echo -e "${GREEN}✓ Backup completed successfully!${NC}"
echo -e "File: ${GREEN}$BACKUP_FILE_GZ${NC}"
echo -e "Size: ${GREEN}$FILESIZE${NC}"

# List recent backups
echo -e "\n${YELLOW}Recent backups:${NC}"
ls -lht "$BACKUP_DIR"/*.sql.gz 2>/dev/null | head -5 || echo "No backups found"

# Cleanup old backups (keep last 10)
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/*.sql.gz 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt 10 ]; then
    echo -e "\n${YELLOW}Cleaning up old backups (keeping last 10)...${NC}"
    ls -1t "$BACKUP_DIR"/*.sql.gz | tail -n +11 | xargs rm -f
    echo -e "${GREEN}✓ Old backups removed${NC}"
fi
