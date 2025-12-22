# ===========================================
# 🐳 Multi-Site Laravel Docker Infrastructure
# ===========================================

.PHONY: help infra-up infra-down infra-logs add-site remove-site list-sites

help:
	@echo ""
	@echo "🐳 Multi-Site Laravel Docker Infrastructure"
	@echo "==========================================="
	@echo ""
	@echo "🏗️  Infrastructure"
	@echo "=================="
	@echo "  make infra-up       - Start shared services (Traefik, MySQL, Redis)"
	@echo "  make infra-down     - Stop shared services"
	@echo "  make infra-logs     - View infrastructure logs"
	@echo "  make infra-restart  - Restart infrastructure"
	@echo ""
	@echo "🌐 Site Management"
	@echo "=================="
	@echo "  make add-site name=mysite domain=mysite.com  - Add new site"
	@echo "  make remove-site name=mysite                 - Remove site"
	@echo "  make list-sites                              - List all sites"
	@echo ""
	@echo "📁 Individual Site Commands"
	@echo "==========================="
	@echo "  cd sites/sitename && make help  - See site-specific commands"
	@echo ""

# Infrastructure commands
infra-up:
	cd infrastructure && docker compose up -d

infra-down:
	cd infrastructure && docker compose down

infra-logs:
	cd infrastructure && docker compose logs -f

infra-restart:
	cd infrastructure && docker compose restart

# Site management
add-site:
	@if [ -z "$(name)" ] || [ -z "$(domain)" ]; then \
		echo "Usage: make add-site name=sitename domain=example.com"; \
		exit 1; \
	fi
	./scripts/add-site.sh $(name) $(domain)

remove-site:
	@if [ -z "$(name)" ]; then \
		echo "Usage: make remove-site name=sitename"; \
		exit 1; \
	fi
	./scripts/remove-site.sh $(name)

list-sites:
	./scripts/list-sites.sh

# Quick start all sites
start-all:
	@echo "🚀 Starting all sites..."
	@for dir in sites/*/; do \
		if [ -f "$$dir/docker-compose.yml" ]; then \
			echo "Starting $$(basename $$dir)..."; \
			cd "$$dir" && docker compose up -d && cd ../..; \
		fi \
	done
	@echo "✅ All sites started!"

stop-all:
	@echo "🛑 Stopping all sites..."
	@for dir in sites/*/; do \
		if [ -f "$$dir/docker-compose.yml" ]; then \
			echo "Stopping $$(basename $$dir)..."; \
			cd "$$dir" && docker compose down && cd ../..; \
		fi \
	done
	@echo "✅ All sites stopped!"
