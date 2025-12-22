# 🐳 Multi-Site Laravel Docker Infrastructure

Production-ready Docker infrastructure for hosting **multiple Laravel applications** on a single server with shared services.

## ✨ Features

- 🔀 **Traefik** - Reverse proxy with automatic SSL (Let's Encrypt)
- 🗄️ **MySQL 8.0** - Shared database server
- ⚡ **Redis 7** - Shared cache, sessions & queues
- 🐘 **PHP 8.0-FPM** - Per-site PHP processing
- 📦 **Caddy** - Per-site web server
- 👷 **Supervisor** - Queue workers & scheduler per site
- 🔒 **Automatic HTTPS** - SSL certificates via Let's Encrypt

## 📁 Directory Structure

```
├── infrastructure/          # 🏗️ Shared services
│   ├── docker-compose.yml   # Traefik, MySQL, Redis
│   ├── .env                 # Infrastructure config
│   ├── traefik/             # Traefik config
│   └── mysql/               # MySQL config
├── shared/                  # 📦 Shared configs for all sites
│   ├── php/                 # PHP Dockerfile & config
│   ├── caddy/               # Caddyfile template
│   └── supervisor/          # Supervisor configs
├── sites/                   # 🌐 Individual sites
│   ├── template/            # Template for new sites
│   └── site1/               # Your first site
│       ├── docker-compose.yml
│       ├── .env
│       ├── src/             # Laravel code
│       └── backups/         # Database backups
├── scripts/                 # 🛠️ Management scripts
│   ├── add-site.sh
│   ├── remove-site.sh
│   └── list-sites.sh
└── Makefile                 # Main commands
```

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone <repo-url> docker
cd docker
```

### 2. Configure Infrastructure

```bash
# Copy and edit infrastructure config
cp infrastructure/.env.example infrastructure/.env
nano infrastructure/.env
```

Set these values:
```env
TRAEFIK_DOMAIN=yourdomain.com
TRAEFIK_AUTH=admin:$$apr1$$...  # htpasswd hash
ACME_EMAIL=your@email.com
DB_ROOT_PASSWORD=secure_password
REDIS_PASSWORD=secure_password
```

### 3. Start Infrastructure

```bash
make infra-up
```

This starts:
- Traefik (ports 80, 443)
- MySQL 8.0
- Redis 7

### 4. Add Your First Site

```bash
make add-site name=myapp domain=myapp.com
```

This automatically:
- Creates site directory
- Generates secure database credentials
- Creates database & user
- Shows Laravel .env configuration

### 5. Deploy Your Laravel App

```bash
cd sites/myapp
git clone <your-laravel-repo> src

# Update src/.env with database credentials shown above

# Build and start
make build
make setup
```

## 📋 Commands

### Main Commands (from root)

| Command | Description |
|---------|-------------|
| `make infra-up` | Start shared services |
| `make infra-down` | Stop shared services |
| `make infra-logs` | View infrastructure logs |
| `make add-site name=x domain=x.com` | Add new site |
| `make remove-site name=x` | Remove site |
| `make list-sites` | List all sites |
| `make start-all` | Start all sites |
| `make stop-all` | Stop all sites |

### Site Commands (from sites/sitename/)

| Command | Description |
|---------|-------------|
| `make up` | Start site |
| `make down` | Stop site |
| `make build` | Build & start |
| `make logs` | View logs |
| `make shell` | SSH into app container |
| `make artisan cmd='...'` | Run artisan command |
| `make composer cmd='...'` | Run composer |
| `make setup` | Initial Laravel setup |
| `make deploy` | Deploy updates |
| `make backup` | Backup database |

## 🔧 Adding More Sites

```bash
# Add new site
make add-site name=blog domain=blog.mysite.com

# Clone Laravel app
cd sites/blog
git clone <your-blog-repo> src

# Configure and start
nano src/.env  # Add database credentials
make build
make setup
```

Each site gets:
- ✅ Separate PHP-FPM container
- ✅ Separate Caddy container
- ✅ Separate worker container
- ✅ Own database & user
- ✅ Automatic SSL via Traefik

## 🌐 DNS Configuration

Point your domains to your server's IP:

```
myapp.com       A     123.456.789.0
blog.myapp.com  A     123.456.789.0
traefik.myapp.com A   123.456.789.0  (optional, for dashboard)
```

## 🔒 Security

- Change default passwords in `.env` files
- Traefik dashboard protected with HTTP Basic Auth
- Database users isolated per site
- Redis requires password authentication

### Generate Traefik Dashboard Password

```bash
# Install apache2-utils if needed
sudo apt install apache2-utils

# Generate password hash
echo $(htpasswd -nb admin your_secure_password) | sed -e s/\\$/\\$\\$/g
```

## 📊 Monitoring

### Traefik Dashboard

Access at: `https://traefik.yourdomain.com`

### View Logs

```bash
# Infrastructure logs
make infra-logs

# Site logs
cd sites/myapp && make logs
```

## 💾 Backups

### Manual Backup

```bash
cd sites/myapp
make backup
```

### Automatic Backups

Backups run automatically via cron in the worker container. Configure schedule in `shared/supervisor/conf.d/cron.conf`.

### Restore

```bash
./scripts/db-restore.sh sites/myapp/backups/backup-file.sql.gz
```

## 🔄 Deployment

```bash
cd sites/myapp
make deploy
```

This runs:
1. `git pull`
2. `composer install`
3. Laravel cache commands
4. `php artisan migrate`
5. Restart workers

## 🐛 Troubleshooting

### Site Not Loading

```bash
# Check if infrastructure is running
docker ps | grep -E "traefik|mysql|redis"

# Check site containers
cd sites/myapp && docker compose ps

# View logs
make logs
```

### SSL Certificate Issues

```bash
# Check Traefik logs
cd infrastructure && docker compose logs traefik
```

### Database Connection Failed

```bash
# Verify MySQL is running
docker exec mysql mysql -uroot -p -e "SHOW DATABASES;"
```

## 📝 License

MIT License
