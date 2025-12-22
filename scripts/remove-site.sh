#!/bin/bash

# ===========================================
# 🗑️ Remove Laravel Site
# Usage: ./remove-site.sh <site_name>
# ===========================================

set -e

SITE_NAME=$1
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -z "$SITE_NAME" ]; then
    echo -e "${RED}❌ Usage: ./remove-site.sh <site_name>${NC}"
    exit 1
fi

if [ ! -d "$BASE_DIR/sites/$SITE_NAME" ]; then
    echo -e "${RED}❌ Site '$SITE_NAME' not found!${NC}"
    exit 1
fi

if [ "$SITE_NAME" = "template" ]; then
    echo -e "${RED}❌ Cannot remove template!${NC}"
    exit 1
fi

echo -e "${YELLOW}⚠️  This will permanently delete:${NC}"
echo "   - Site containers (${SITE_NAME}_app, ${SITE_NAME}_caddy, ${SITE_NAME}_worker)"
echo "   - Site files in sites/$SITE_NAME"
echo "   - Database ${SITE_NAME}_db"
echo "   - Database user ${SITE_NAME}_user"
echo ""
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

# Stop containers
echo -e "${YELLOW}🛑 Stopping containers...${NC}"
cd "$BASE_DIR/sites/$SITE_NAME"
docker compose down -v 2>/dev/null || true

# Remove database
echo -e "${YELLOW}🗄️ Removing database...${NC}"
if [ -f "$BASE_DIR/infrastructure/.env" ]; then
    DB_ROOT_PASS=$(grep DB_ROOT_PASSWORD "$BASE_DIR/infrastructure/.env" | cut -d '=' -f2)
    docker exec mysql mysql -uroot -p"$DB_ROOT_PASS" -e "
    DROP DATABASE IF EXISTS \`${SITE_NAME}_db\`;
    DROP USER IF EXISTS '${SITE_NAME}_user'@'%';
    FLUSH PRIVILEGES;
    " 2>/dev/null || true
fi

# Remove files
echo -e "${YELLOW}📁 Removing site files...${NC}"
rm -rf "$BASE_DIR/sites/$SITE_NAME"

echo ""
echo -e "${GREEN}✅ Site '$SITE_NAME' removed successfully!${NC}"
