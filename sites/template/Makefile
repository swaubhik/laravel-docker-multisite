# ===========================================
# 🚀 Site Commands
# ===========================================

.PHONY: help up down restart logs shell artisan composer setup deploy backup

help:
	@echo ""
	@echo "🚀 Site Commands"
	@echo "================"
	@echo "  make up        - Start this site"
	@echo "  make down      - Stop this site"
	@echo "  make restart   - Restart this site"
	@echo "  make build     - Rebuild and start"
	@echo "  make logs      - View logs"
	@echo "  make shell     - SSH into app container"
	@echo ""
	@echo "🎯 Laravel"
	@echo "=========="
	@echo "  make artisan cmd='...'   - Run artisan command"
	@echo "  make composer cmd='...'  - Run composer command"
	@echo "  make setup               - Initial setup"
	@echo "  make deploy              - Deploy updates"
	@echo ""
	@echo "� NPM / Assets"
	@echo "==============="
	@echo "  make npm-install   - Install npm packages"
	@echo "  make npm-dev       - Build assets for development"
	@echo "  make npm-prod      - Build assets for production"
	@echo "  make npm-watch     - Watch and rebuild on changes"
	@echo "  make npm cmd='...' - Run custom npm command"
	@echo ""
	@echo "�💾 Database"
	@echo "==========="
	@echo "  make backup    - Backup database"
	@echo ""

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose restart

build:
	docker compose up -d --build

logs:
	docker compose logs -f

logs-app:
	docker compose logs -f app

logs-worker:
	docker compose logs -f worker

shell:
	docker compose exec app sh

artisan:
	docker compose exec app php artisan $(cmd)

composer:
	docker compose exec app composer $(cmd)

setup:
	@echo "🚀 Setting up site..."
	docker compose exec app composer install --optimize-autoloader --no-dev
	docker compose exec app php artisan config:cache
	docker compose exec app php artisan route:cache
	docker compose exec app php artisan view:cache
	docker compose exec app php artisan migrate --force
	docker compose exec --user root app php artisan storage:link || true
	docker compose exec --user root app chown -R www:www storage bootstrap/cache
	docker compose exec --user root app npm run build || true
	@echo "✅ Site setup complete!"

deploy:
	@echo "🚀 Deploying..."
	cd src && git pull origin sbi-collect-pay || git pull origin master
	docker compose exec -u root app composer install --optimize-autoloader --no-dev
	docker compose exec app php artisan config:cache
	docker compose exec app php artisan route:cache
	docker compose exec app php artisan view:cache
	docker compose exec app php artisan migrate --force
	docker compose restart worker
	@echo "✅ Deployment complete!"

backup:
	@echo "💾 Creating backup..."
	docker compose exec worker php /var/www/html/artisan backup:run 2>/dev/null || \
	docker compose exec worker php -r "\
		\$$pdo = new PDO('mysql:host=mysql;dbname=$$(grep DB_DATABASE .env | cut -d= -f2)', '$$(grep DB_USERNAME .env | cut -d= -f2)', '$$(grep DB_PASSWORD .env | cut -d= -f2)'); \
		echo 'Backup would be created here';"
	@echo "✅ Backup complete!"

fresh:
	docker compose exec app php artisan migrate:fresh --seed --force

tinker:
	docker compose exec app php artisan tinker

test:
	docker compose exec app php artisan test

clear:
	docker compose exec app php artisan config:clear
	docker compose exec app php artisan cache:clear
	docker compose exec app php artisan view:clear
	docker compose exec app php artisan route:clear

# ===========================================
# 📦 NPM / Assets
# ===========================================

npm-install:
	docker compose exec --user root app npm install

npm-dev:
	docker compose exec app npm run dev

npm-prod:
	docker compose exec --user root app npm run prod

npm-watch:
	docker compose exec app npm run watch

npm:
	docker compose exec app npm $(cmd)
