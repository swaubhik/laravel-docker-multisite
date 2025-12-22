#!/bin/bash

# ===========================================
# 📋 List All Sites
# ===========================================

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo ""
echo "🌐 Laravel Sites"
echo "================"
echo ""

found=false
for site in "$BASE_DIR/sites"/*/; do
    site_name=$(basename "$site")
    
    # Skip template
    if [ "$site_name" = "template" ]; then
        continue
    fi
    
    found=true
    
    # Check if site has .env
    if [ -f "$site/.env" ]; then
        domain=$(grep SITE_DOMAIN "$site/.env" 2>/dev/null | cut -d '=' -f2)
        
        # Check if containers are running
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${site_name}_app$"; then
            status="🟢 Running"
        else
            status="🔴 Stopped"
        fi
        
        printf "  %-20s %-30s %s\n" "$site_name" "${domain:-N/A}" "$status"
    fi
done

if [ "$found" = false ]; then
    echo "  No sites found. Create one with:"
    echo "  ./scripts/add-site.sh <name> <domain>"
fi

echo ""
