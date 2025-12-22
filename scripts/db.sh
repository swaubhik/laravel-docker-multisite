#!/bin/bash

# Database Management Script for Laravel Docker Environment
# Usage: ./scripts/db.sh [command]
#
# Commands:
#   backup [name]     Create a database backup
#   restore [file]    Restore from a backup
#   list              List available backups
#   shell             Open MySQL shell
#   import <file>     Import SQL file directly (no confirmation)
#   export            Quick export to stdout

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
DB_DATABASE="${DB_DATABASE:-laravel}"
DB_USERNAME="${DB_USERNAME:-laravel}"
DB_PASSWORD="${DB_PASSWORD:-secret}"
CONTAINER_NAME="${MYSQL_CONTAINER:-laravel_mysql}"
BACKUP_DIR="$PROJECT_DIR/backups"

show_help() {
    echo -e "${CYAN}Database Management Script${NC}"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo -e "  ${GREEN}backup${NC} [name]     Create a database backup (default: timestamped)"
    echo -e "  ${GREEN}restore${NC} [file]    Restore from a backup (interactive if no file)"
    echo -e "  ${GREEN}list${NC}              List available backups"
    echo -e "  ${GREEN}shell${NC}             Open MySQL shell"
    echo -e "  ${GREEN}import${NC} <file>     Import SQL file directly (no confirmation)"
    echo -e "  ${GREEN}export${NC}            Quick export to stdout (pipe to file)"
    echo ""
    echo "Examples:"
    echo "  $0 backup                    # Create timestamped backup"
    echo "  $0 backup before_migration   # Create named backup"
    echo "  $0 restore                   # Interactive restore"
    echo "  $0 restore backup.sql.gz     # Restore specific file"
    echo "  $0 import /path/to/dump.sql  # Import SQL file"
    echo "  $0 shell                     # Open MySQL CLI"
    echo ""
}

check_container() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${RED}Error: MySQL container '$CONTAINER_NAME' is not running${NC}"
        echo -e "Start it with: ${CYAN}docker compose up -d mysql${NC}"
        exit 1
    fi
}

cmd_backup() {
    "$SCRIPT_DIR/db-backup.sh" "$@"
}

cmd_restore() {
    "$SCRIPT_DIR/db-restore.sh" "$@"
}

cmd_list() {
    echo -e "${YELLOW}Available backups in $BACKUP_DIR:${NC}"
    if [ -d "$BACKUP_DIR" ] && ls "$BACKUP_DIR"/*.sql* &>/dev/null; then
        ls -lht "$BACKUP_DIR"/*.sql* 2>/dev/null
    else
        echo -e "${RED}No backups found${NC}"
    fi
}

cmd_shell() {
    check_container
    echo -e "${YELLOW}Opening MySQL shell...${NC}"
    echo -e "Database: ${GREEN}$DB_DATABASE${NC}"
    echo -e "Type 'exit' or press Ctrl+D to quit\n"
    docker exec -it "$CONTAINER_NAME" mysql -u"$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE"
}

cmd_import() {
    check_container
    
    if [ -z "$1" ]; then
        echo -e "${RED}Error: Please specify a SQL file to import${NC}"
        echo "Usage: $0 import <file.sql|file.sql.gz>"
        exit 1
    fi
    
    local file="$1"
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}Error: File not found: $file${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Importing $file into $DB_DATABASE...${NC}"
    
    if [[ "$file" == *.gz ]]; then
        gunzip -c "$file" | docker exec -i "$CONTAINER_NAME" mysql \
            -u"$DB_USERNAME" \
            -p"$DB_PASSWORD" \
            "$DB_DATABASE"
    else
        docker exec -i "$CONTAINER_NAME" mysql \
            -u"$DB_USERNAME" \
            -p"$DB_PASSWORD" \
            "$DB_DATABASE" < "$file"
    fi
    
    echo -e "${GREEN}✓ Import completed!${NC}"
}

cmd_export() {
    check_container
    docker exec "$CONTAINER_NAME" mysqldump \
        -u"$DB_USERNAME" \
        -p"$DB_PASSWORD" \
        --single-transaction \
        --routines \
        --triggers \
        "$DB_DATABASE"
}

# Main command handler
case "${1:-help}" in
    backup)
        shift
        cmd_backup "$@"
        ;;
    restore)
        shift
        cmd_restore "$@"
        ;;
    list)
        cmd_list
        ;;
    shell)
        cmd_shell
        ;;
    import)
        shift
        cmd_import "$@"
        ;;
    export)
        cmd_export
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac
