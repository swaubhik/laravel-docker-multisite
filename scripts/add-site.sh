#!/bin/bash

# ===========================================
# 🚀 Add New Laravel Site
# Usage: ./add-site.sh <site_name> <domain>
# ===========================================

set -e

SITE_NAME=$1
DOMAIN=$2
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ -z "$SITE_NAME" ] || [ -z "$DOMAIN" ]; then
    echo -e "${RED}❌ Usage: ./add-site.sh <site_name> <domain>${NC}"
    echo "   Example: ./add-site.sh blog blog.example.com"
    exit 1
fi

# Validate site name (alphanumeric and underscore only)
if ! [[ "$SITE_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo -e "${RED}❌ Site name must be alphanumeric (underscores allowed)${NC}"
    exit 1
fi

# Check if site already exists
if [ -d "$BASE_DIR/sites/$SITE_NAME" ]; then
    echo -e "${RED}❌ Site '$SITE_NAME' already exists!${NC}"
    exit 1
fi

echo -e "${BLUE}🚀 Creating new site: $SITE_NAME ($DOMAIN)${NC}"
echo ""

# Copy template
echo -e "${YELLOW}📁 Creating site directory...${NC}"
cp -r "$BASE_DIR/sites/template" "$BASE_DIR/sites/$SITE_NAME"

# Generate secure password
DB_PASS=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 16)

# Get passwords from infrastructure .env
if [ -f "$BASE_DIR/infrastructure/.env" ]; then
    REDIS_PASS=$(grep REDIS_PASSWORD "$BASE_DIR/infrastructure/.env" | cut -d '=' -f2)
    DB_ROOT_PASS=$(grep DB_ROOT_PASSWORD "$BASE_DIR/infrastructure/.env" | cut -d '=' -f2)
else
    echo -e "${RED}❌ Infrastructure .env not found! Run infrastructure setup first.${NC}"
    rm -rf "$BASE_DIR/sites/$SITE_NAME"
    exit 1
fi

# Create .env file
echo -e "${YELLOW}📝 Creating .env file...${NC}"
cat > "$BASE_DIR/sites/$SITE_NAME/.env" << EOF
# ===========================================
# 🌐 Site Configuration
# ===========================================

SITE_NAME=$SITE_NAME
SITE_DOMAIN=$DOMAIN

# Database
DB_DATABASE=${SITE_NAME}_db
DB_USERNAME=${SITE_NAME}_user
DB_PASSWORD=$DB_PASS

# Redis
REDIS_PASSWORD=$REDIS_PASS
EOF

# Create database
echo -e "${YELLOW}🗄️ Creating database...${NC}"
docker exec mysql mysql -uroot -p"$DB_ROOT_PASS" -e "
CREATE DATABASE IF NOT EXISTS \`${SITE_NAME}_db\`;
CREATE USER IF NOT EXISTS '${SITE_NAME}_user'@'%' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`${SITE_NAME}_db\`.* TO '${SITE_NAME}_user'@'%';
FLUSH PRIVILEGES;
" 2>/dev/null

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to create database. Is MySQL running?${NC}"
    echo -e "${YELLOW}   Run: cd infrastructure && make up${NC}"
    rm -rf "$BASE_DIR/sites/$SITE_NAME"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Site created successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo ""
echo "   1. Clone your Laravel app:"
echo -e "      ${YELLOW}git clone <your-repo> $BASE_DIR/sites/$SITE_NAME/src${NC}"
echo ""
echo "   2. Update Laravel .env (sites/$SITE_NAME/src/.env) with:"
echo -e "      ${YELLOW}APP_URL=http://$DOMAIN${NC}"
echo -e "      ${YELLOW}DB_HOST=mysql${NC}"
echo -e "      ${YELLOW}DB_DATABASE=${SITE_NAME}_db${NC}"
echo -e "      ${YELLOW}DB_USERNAME=${SITE_NAME}_user${NC}"
echo -e "      ${YELLOW}DB_PASSWORD=$DB_PASS${NC}"
echo -e "      ${YELLOW}REDIS_HOST=redis${NC}"
echo -e "      ${YELLOW}REDIS_PASSWORD=$REDIS_PASS${NC}"
echo ""
echo "   3. Start the site:"
echo -e "      ${YELLOW}cd $BASE_DIR/sites/$SITE_NAME${NC}"
echo -e "      ${YELLOW}make build${NC}"
echo -e "      ${YELLOW}make setup${NC}"
echo ""
echo -e "${GREEN}🌐 Your site will be available at: http://$DOMAIN${NC}"
