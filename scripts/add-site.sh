#!/bin/bash

# ===========================================
# 🚀 Add New Laravel Site
# Usage: ./add-site.sh <site_name> <domain> [php_version]
# ===========================================

set -e

SITE_NAME=$1
DOMAIN=$2
PHP_VERSION=${3:-8.2}
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Supported PHP versions
SUPPORTED_PHP="7.4 8.0 8.1 8.2 8.3"

show_help() {
    echo -e "${CYAN}🚀 Add New Laravel Site${NC}"
    echo ""
    echo "Usage: $0 <site_name> <domain> [php_version]"
    echo ""
    echo "Arguments:"
    echo "  site_name     Alphanumeric name (underscores allowed)"
    echo "  domain        Domain name for the site"
    echo "  php_version   PHP version (optional, default: 8.2)"
    echo ""
    echo "Supported PHP versions: $SUPPORTED_PHP"
    echo ""
    echo "Examples:"
    echo "  $0 blog blog.example.com           # Uses PHP 8.2"
    echo "  $0 legacy legacy.example.com 7.4   # Uses PHP 7.4"
    echo "  $0 newapp app.example.com 8.3      # Uses PHP 8.3"
    echo ""
}

if [ -z "$SITE_NAME" ] || [ -z "$DOMAIN" ]; then
    show_help
    exit 1
fi

# Validate PHP version
if ! echo "$SUPPORTED_PHP" | grep -qw "$PHP_VERSION"; then
    echo -e "${RED}❌ Unsupported PHP version: $PHP_VERSION${NC}"
    echo -e "   Supported versions: ${CYAN}$SUPPORTED_PHP${NC}"
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

echo -e "${BLUE}🚀 Creating new site: $SITE_NAME ($DOMAIN) with PHP $PHP_VERSION${NC}"
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

# PHP Version
PHP_VERSION=$PHP_VERSION

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
echo -e "${BLUE}📋 Site Details:${NC}"
echo -e "   Name:        ${CYAN}$SITE_NAME${NC}"
echo -e "   Domain:      ${CYAN}$DOMAIN${NC}"
echo -e "   PHP Version: ${CYAN}$PHP_VERSION${NC}"
echo -e "   Database:    ${CYAN}${SITE_NAME}_db${NC}"
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo ""
echo "   1. Clone your Laravel app:"
echo -e "      ${YELLOW}git clone <your-repo> $BASE_DIR/sites/$SITE_NAME/src${NC}"
echo ""
echo "   2. Create Laravel .env (copy from template):"
echo -e "      ${YELLOW}cp $BASE_DIR/sites/$SITE_NAME/src/.env.example $BASE_DIR/sites/$SITE_NAME/src/.env${NC}"
echo ""
echo "   3. Update Laravel .env (sites/$SITE_NAME/src/.env) with:"
echo -e "      ${YELLOW}APP_URL=https://$DOMAIN${NC}"
echo -e "      ${YELLOW}DB_HOST=mysql${NC}"
echo -e "      ${YELLOW}DB_DATABASE=${SITE_NAME}_db${NC}"
echo -e "      ${YELLOW}DB_USERNAME=${SITE_NAME}_user${NC}"
echo -e "      ${YELLOW}DB_PASSWORD=$DB_PASS${NC}"
echo -e "      ${YELLOW}REDIS_HOST=redis${NC}"
echo -e "      ${YELLOW}REDIS_PASSWORD=$REDIS_PASS${NC}"
echo -e "      ${YELLOW}FORCE_HTTPS=true${NC}"
echo -e "      ${YELLOW}ASSET_URL=https://$DOMAIN${NC}"
echo ""
echo "   4. Generate app key:"
echo -e "      ${YELLOW}cd $BASE_DIR/sites/$SITE_NAME && docker compose exec app php artisan key:generate${NC}"
echo ""
echo "   5. Start and setup the site:"
echo -e "      ${YELLOW}cd $BASE_DIR/sites/$SITE_NAME${NC}"
echo -e "      ${YELLOW}make build${NC}"
echo -e "      ${YELLOW}make setup${NC}"
echo ""
echo "   6. Fix permissions (if needed):"
echo -e "      ${YELLOW}docker run --rm -v $BASE_DIR/sites/$SITE_NAME/src:/app alpine chown -R 1000:1000 /app/storage /app/bootstrap/cache${NC}"
echo ""
echo -e "${GREEN}🌐 Your site will be available at: https://$DOMAIN${NC}"
