# ===========================================
# 🐳 Infrastructure Commands
# ===========================================

.PHONY: help up down restart logs build

help:
	@echo ""
	@echo "🐳 Infrastructure Commands"
	@echo "=========================="
	@echo "  make up        - Start shared services"
	@echo "  make down      - Stop shared services"
	@echo "  make restart   - Restart shared services"
	@echo "  make logs      - View logs"
	@echo "  make build     - Rebuild and start"
	@echo ""
	@echo "💾 Database"
	@echo "==========="
	@echo "  make db-shell  - Open MySQL shell"
	@echo "  make db-list   - List all databases"
	@echo ""

up:
	docker compose up -d
	@echo ""
	@echo "✅ Infrastructure started!"
	@echo "   - Traefik: Running on ports 80/443"
	@echo "   - MySQL:   Running on backend network"
	@echo "   - Redis:   Running on backend network"

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f

build:
	docker compose up -d --build

db-shell:
	@docker exec -it mysql mysql -uroot -p$$(grep DB_ROOT_PASSWORD .env | cut -d '=' -f2)

db-list:
	@docker exec mysql mysql -uroot -p$$(grep DB_ROOT_PASSWORD .env | cut -d '=' -f2) -e "SHOW DATABASES;" 2>/dev/null
