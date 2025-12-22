#!/bin/bash

# Database Restore Script for Laravel Docker Environment
# Usage: ./scripts/db-restore.sh [backup_file.sql.gz]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
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

# Function to list available backups
list_backups() {
    echo -e "${YELLOW}Available backups:${NC}"
    if [ -d "$BACKUP_DIR" ] && ls "$BACKUP_DIR"/*.sql.gz &>/dev/null; then
        local i=1
        for file in $(ls -1t "$BACKUP_DIR"/*.sql.gz 2>/dev/null); do
            local size=$(du -h "$file" | cut -f1)
            local date=$(stat -c %y "$file" 2>/dev/null | cut -d'.' -f1 || stat -f %Sm "$file" 2>/dev/null)
            echo -e "  ${CYAN}[$i]${NC} $(basename "$file") (${size}, ${date})"
            ((i++))
        done
    else
        echo -e "${RED}No backups found in $BACKUP_DIR${NC}"
        exit 1
    fi
}

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}Error: MySQL container '$CONTAINER_NAME' is not running${NC}"
    exit 1
fi

# Determine backup file
BACKUP_FILE=""

if [ -n "$1" ]; then
    # File provided as argument
    if [ -f "$1" ]; then
        BACKUP_FILE="$1"
    elif [ -f "$BACKUP_DIR/$1" ]; then
        BACKUP_FILE="$BACKUP_DIR/$1"
    else
        echo -e "${RED}Error: Backup file not found: $1${NC}"
        list_backups
        exit 1
    fi
else
    # Interactive selection
    list_backups
    echo ""
    read -p "Enter backup number or filename to restore (or 'q' to quit): " selection
    
    if [ "$selection" = "q" ] || [ "$selection" = "Q" ]; then
        echo -e "${YELLOW}Restore cancelled${NC}"
        exit 0
    fi
    
    if [[ "$selection" =~ ^[0-9]+$ ]]; then
        # Number selected
        BACKUP_FILE=$(ls -1t "$BACKUP_DIR"/*.sql.gz 2>/dev/null | sed -n "${selection}p")
    else
        # Filename provided
        if [ -f "$selection" ]; then
            BACKUP_FILE="$selection"
        elif [ -f "$BACKUP_DIR/$selection" ]; then
            BACKUP_FILE="$BACKUP_DIR/$selection"
        fi
    fi
    
    if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
        echo -e "${RED}Error: Invalid selection${NC}"
        exit 1
    fi
fi

echo -e "\n${YELLOW}Restore Details:${NC}"
echo -e "File: ${GREEN}$(basename "$BACKUP_FILE")${NC}"
echo -e "Database: ${GREEN}$DB_DATABASE${NC}"
echo -e "Container: ${GREEN}$CONTAINER_NAME${NC}"

# Confirmation
echo -e "\n${RED}⚠ WARNING: This will OVERWRITE all data in '$DB_DATABASE' database!${NC}"
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${YELLOW}Restore cancelled${NC}"
    exit 0
fi

echo -e "\n${YELLOW}Restoring database...${NC}"

# Check file type and restore
if [[ "$BACKUP_FILE" == *.gz ]]; then
    # Compressed file
    gunzip -c "$BACKUP_FILE" | docker exec -i "$CONTAINER_NAME" mysql \
        -u"$DB_USERNAME" \
        -p"$DB_PASSWORD" \
        "$DB_DATABASE"
elif [[ "$BACKUP_FILE" == *.sql ]]; then
    # Uncompressed SQL file
    docker exec -i "$CONTAINER_NAME" mysql \
        -u"$DB_USERNAME" \
        -p"$DB_PASSWORD" \
        "$DB_DATABASE" < "$BACKUP_FILE"
else
    echo -e "${RED}Error: Unsupported file format. Use .sql or .sql.gz${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Database restored successfully!${NC}"

# Clear Laravel cache after restore
echo -e "${YELLOW}Clearing Laravel cache...${NC}"
docker exec laravel_app php artisan cache:clear 2>/dev/null || true
docker exec laravel_app php artisan config:clear 2>/dev/null || true

echo -e "${GREEN}✓ All done!${NC}"
