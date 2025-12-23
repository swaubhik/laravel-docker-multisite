#!/bin/bash

# ===========================================
# 🗄️ Database Management Script (Multi-Site)
# Usage: ./scripts/db.sh [command] [site_name]
# ===========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
CONTAINER_NAME="mysql"

# Load infrastructure .env for root password
if [ -f "$BASE_DIR/infrastructure/.env" ]; then
    DB_ROOT_PASSWORD=$(grep DB_ROOT_PASSWORD "$BASE_DIR/infrastructure/.env" | cut -d '=' -f2)
fi

show_help() {
    echo -e "${CYAN}🗄️  Database Management Script (Multi-Site)${NC}"
    echo ""
    echo "Usage: $0 <command> [site_name] [options]"
    echo ""
    echo "Commands:"
    echo -e "  ${GREEN}backup${NC} [site]      Create a database backup for a site"
    echo -e "  ${GREEN}restore${NC} [site]     Restore from a backup for a site"
    echo -e "  ${GREEN}list${NC} [site]        List available backups (all sites or specific)"
    echo -e "  ${GREEN}shell${NC} [site]       Open MySQL shell (site db or root)"
    echo -e "  ${GREEN}import${NC} <site> <file>  Import SQL file directly"
    echo -e "  ${GREEN}sites${NC}              List all sites with databases"
    echo ""
    echo "Examples:"
    echo "  $0 backup                    # Select site interactively"
    echo "  $0 backup renewal_addmission # Backup specific site"
    echo "  $0 restore                   # Interactive restore"
    echo "  $0 restore renewal_addmission backup.sql.gz"
    echo "  $0 shell                     # MySQL root shell"
    echo "  $0 shell renewal_addmission  # MySQL shell for site db"
    echo "  $0 sites                     # List all sites"
    echo ""
}

# List available sites
list_sites() {
    local sites=()
    for site_dir in "$BASE_DIR/sites"/*/; do
        site_name=$(basename "$site_dir")
        if [ "$site_name" != "template" ] && [ -f "$site_dir/.env" ]; then
            sites+=("$site_name")
        fi
    done
    echo "${sites[@]}"
}

# Interactive site selection
select_site() {
    local prompt="${1:-Select a site}"
    local sites=($(list_sites))
    
    if [ ${#sites[@]} -eq 0 ]; then
        echo -e "${RED}No sites found!${NC}" >&2
        exit 1
    fi
    
    if [ ${#sites[@]} -eq 1 ]; then
        echo "${sites[0]}"
        return
    fi
    
    echo -e "${YELLOW}$prompt:${NC}" >&2
    local i=1
    for site in "${sites[@]}"; do
        local domain=$(grep SITE_DOMAIN "$BASE_DIR/sites/$site/.env" 2>/dev/null | cut -d '=' -f2)
        echo -e "  ${CYAN}[$i]${NC} $site ${BLUE}($domain)${NC}" >&2
        ((i++))
    done
    echo "" >&2
    read -p "Enter number or site name: " selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#sites[@]} ]; then
        echo "${sites[$((selection-1))]}"
    else
        # Check if it's a valid site name
        for site in "${sites[@]}"; do
            if [ "$site" = "$selection" ]; then
                echo "$site"
                return
            fi
        done
        echo -e "${RED}Invalid selection${NC}" >&2
        exit 1
    fi
}

# Load site configuration
load_site_config() {
    local site_name="$1"
    local site_env="$BASE_DIR/sites/$site_name/.env"
    
    if [ ! -f "$site_env" ]; then
        echo -e "${RED}Site '$site_name' not found or missing .env${NC}"
        exit 1
    fi
    
    DB_DATABASE=$(grep DB_DATABASE "$site_env" | cut -d '=' -f2)
    DB_USERNAME=$(grep DB_USERNAME "$site_env" | cut -d '=' -f2)
    DB_PASSWORD=$(grep DB_PASSWORD "$site_env" | cut -d '=' -f2)
    BACKUP_DIR="$BASE_DIR/sites/$site_name/backups"
    
    mkdir -p "$BACKUP_DIR"
}

check_container() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${RED}Error: MySQL container '$CONTAINER_NAME' is not running${NC}"
        echo -e "Start it with: ${CYAN}cd infrastructure && docker compose up -d${NC}"
        exit 1
    fi
}

cmd_sites() {
    echo -e "${CYAN}🌐 Sites with Databases${NC}"
    echo ""
    
    for site_dir in "$BASE_DIR/sites"/*/; do
        site_name=$(basename "$site_dir")
        if [ "$site_name" != "template" ] && [ -f "$site_dir/.env" ]; then
            local domain=$(grep SITE_DOMAIN "$site_dir/.env" 2>/dev/null | cut -d '=' -f2)
            local db_name=$(grep DB_DATABASE "$site_dir/.env" 2>/dev/null | cut -d '=' -f2)
            local backup_count=$(ls -1 "$site_dir/backups"/*.sql* 2>/dev/null | wc -l || echo "0")
            
            echo -e "  ${GREEN}$site_name${NC}"
            echo -e "    Domain:   $domain"
            echo -e "    Database: $db_name"
            echo -e "    Backups:  $backup_count"
            echo ""
        fi
    done
}

cmd_backup() {
    check_container
    
    local site_name="$1"
    local backup_name="$2"
    
    if [ -z "$site_name" ]; then
        site_name=$(select_site "Select site to backup")
    fi
    
    load_site_config "$site_name"
    
    # Backup filename
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    backup_name="${backup_name:-backup_${timestamp}}"
    local backup_file="$BACKUP_DIR/${backup_name}.sql"
    local backup_file_gz="$backup_file.gz"
    
    echo -e "${YELLOW}📦 Creating backup for ${GREEN}$site_name${NC}"
    echo -e "   Database: ${CYAN}$DB_DATABASE${NC}"
    
    # Create backup
    docker exec "$CONTAINER_NAME" mysqldump \
        -u"$DB_USERNAME" \
        -p"$DB_PASSWORD" \
        --single-transaction \
        --routines \
        --triggers \
        --add-drop-table \
        "$DB_DATABASE" > "$backup_file" 2>/dev/null
    
    # Compress
    gzip -f "$backup_file"
    
    local filesize=$(du -h "$backup_file_gz" | cut -f1)
    
    echo -e "${GREEN}✅ Backup completed!${NC}"
    echo -e "   File: ${CYAN}$backup_file_gz${NC}"
    echo -e "   Size: ${CYAN}$filesize${NC}"
    
    # Cleanup old backups (keep last 10)
    local backup_count=$(ls -1 "$BACKUP_DIR"/*.sql.gz 2>/dev/null | wc -l)
    if [ "$backup_count" -gt 10 ]; then
        echo -e "\n${YELLOW}Cleaning up old backups (keeping last 10)...${NC}"
        ls -1t "$BACKUP_DIR"/*.sql.gz | tail -n +11 | xargs rm -f
    fi
}

cmd_restore() {
    check_container
    
    local site_name="$1"
    local backup_file="$2"
    
    if [ -z "$site_name" ]; then
        site_name=$(select_site "Select site to restore")
    fi
    
    load_site_config "$site_name"
    
    # List backups if no file specified
    if [ -z "$backup_file" ]; then
        echo -e "${YELLOW}Available backups for ${GREEN}$site_name${NC}:"
        
        if [ -d "$BACKUP_DIR" ] && ls "$BACKUP_DIR"/*.sql* &>/dev/null; then
            local i=1
            local backups=()
            for file in $(ls -1t "$BACKUP_DIR"/*.sql* 2>/dev/null); do
                backups+=("$file")
                local size=$(du -h "$file" | cut -f1)
                echo -e "  ${CYAN}[$i]${NC} $(basename "$file") (${size})"
                ((i++))
            done
            
            echo ""
            read -p "Enter backup number or path (q to quit): " selection
            
            if [ "$selection" = "q" ] || [ "$selection" = "Q" ]; then
                echo "Cancelled."
                exit 0
            fi
            
            if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#backups[@]} ]; then
                backup_file="${backups[$((selection-1))]}"
            elif [ -f "$selection" ]; then
                backup_file="$selection"
            else
                echo -e "${RED}Invalid selection${NC}"
                exit 1
            fi
        else
            echo -e "${RED}No backups found${NC}"
            exit 1
        fi
    fi
    
    # Resolve backup file path
    if [ ! -f "$backup_file" ]; then
        if [ -f "$BACKUP_DIR/$backup_file" ]; then
            backup_file="$BACKUP_DIR/$backup_file"
        else
            echo -e "${RED}Backup file not found: $backup_file${NC}"
            exit 1
        fi
    fi
    
    echo -e "\n${YELLOW}⚠️  Restore Details:${NC}"
    echo -e "   Site:     ${GREEN}$site_name${NC}"
    echo -e "   Database: ${CYAN}$DB_DATABASE${NC}"
    echo -e "   File:     ${CYAN}$(basename "$backup_file")${NC}"
    echo ""
    read -p "This will OVERWRITE the database. Continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Cancelled."
        exit 0
    fi
    
    echo -e "${YELLOW}Restoring...${NC}"
    
    # Decompress if needed and import
    if [[ "$backup_file" == *.gz ]]; then
        gunzip -c "$backup_file" | docker exec -i "$CONTAINER_NAME" mysql \
            -u"$DB_USERNAME" \
            -p"$DB_PASSWORD" \
            "$DB_DATABASE" 2>/dev/null
    else
        docker exec -i "$CONTAINER_NAME" mysql \
            -u"$DB_USERNAME" \
            -p"$DB_PASSWORD" \
            "$DB_DATABASE" < "$backup_file" 2>/dev/null
    fi
    
    echo -e "${GREEN}✅ Database restored successfully!${NC}"
}

cmd_list() {
    local site_name="$1"
    
    if [ -z "$site_name" ]; then
        # List all sites' backups
        echo -e "${CYAN}📦 All Backups${NC}"
        echo ""
        
        for site_dir in "$BASE_DIR/sites"/*/; do
            local name=$(basename "$site_dir")
            if [ "$name" != "template" ] && [ -d "$site_dir/backups" ]; then
                local backup_count=$(ls -1 "$site_dir/backups"/*.sql* 2>/dev/null | wc -l || echo "0")
                if [ "$backup_count" -gt 0 ]; then
                    echo -e "${GREEN}$name${NC} ($backup_count backups):"
                    ls -lht "$site_dir/backups"/*.sql* 2>/dev/null | head -3 | while read line; do
                        echo "  $line"
                    done
                    echo ""
                fi
            fi
        done
    else
        load_site_config "$site_name"
        echo -e "${YELLOW}Backups for ${GREEN}$site_name${NC}:"
        if [ -d "$BACKUP_DIR" ] && ls "$BACKUP_DIR"/*.sql* &>/dev/null; then
            ls -lht "$BACKUP_DIR"/*.sql* 2>/dev/null
        else
            echo -e "${RED}No backups found${NC}"
        fi
    fi
}

cmd_shell() {
    check_container
    
    local site_name="$1"
    
    if [ -z "$site_name" ]; then
        echo -e "${YELLOW}Opening MySQL root shell...${NC}"
        docker exec -it "$CONTAINER_NAME" mysql -uroot -p"$DB_ROOT_PASSWORD"
    else
        load_site_config "$site_name"
        echo -e "${YELLOW}Opening MySQL shell for ${GREEN}$site_name${NC}..."
        echo -e "Database: ${CYAN}$DB_DATABASE${NC}"
        docker exec -it "$CONTAINER_NAME" mysql -u"$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE"
    fi
}

cmd_import() {
    check_container
    
    local site_name="$1"
    local import_file="$2"
    
    if [ -z "$site_name" ] || [ -z "$import_file" ]; then
        echo -e "${RED}Usage: $0 import <site_name> <sql_file>${NC}"
        exit 1
    fi
    
    if [ ! -f "$import_file" ]; then
        echo -e "${RED}File not found: $import_file${NC}"
        exit 1
    fi
    
    load_site_config "$site_name"
    
    echo -e "${YELLOW}Importing to ${GREEN}$site_name${NC} (${CYAN}$DB_DATABASE${NC})..."
    
    if [[ "$import_file" == *.gz ]]; then
        gunzip -c "$import_file" | docker exec -i "$CONTAINER_NAME" mysql \
            -u"$DB_USERNAME" \
            -p"$DB_PASSWORD" \
            "$DB_DATABASE" 2>/dev/null
    else
        docker exec -i "$CONTAINER_NAME" mysql \
            -u"$DB_USERNAME" \
            -p"$DB_PASSWORD" \
            "$DB_DATABASE" < "$import_file" 2>/dev/null
    fi
    
    echo -e "${GREEN}✅ Import completed!${NC}"
}

# Main
case "${1:-help}" in
    backup)
        cmd_backup "$2" "$3"
        ;;
    restore)
        cmd_restore "$2" "$3"
        ;;
    list)
        cmd_list "$2"
        ;;
    shell)
        cmd_shell "$2"
        ;;
    import)
        cmd_import "$2" "$3"
        ;;
    sites)
        cmd_sites
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
