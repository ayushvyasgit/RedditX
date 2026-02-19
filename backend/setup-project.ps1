# ============================================================================
# Comments Service - Project Initialization Script
# Platform: Windows PowerShell
# Description: Creates complete folder structure and initializes Go project
# ============================================================================

Write-Host "`n Comments Service - Project Setup`n" -ForegroundColor Cyan

# Check prerequisites
Write-Host " Checking prerequisites..." -ForegroundColor Yellow

# Check Go installation
try {
    $goVersion = go version
    Write-Host "[OK] Go is installed: $goVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Go is not installed. Please install Go 1.21+ from https://golang.org/dl/" -ForegroundColor Red
    exit 1
}

# Check Docker installation
try {
    $dockerVersion = docker --version
    Write-Host "[OK] Docker is installed: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Docker is not installed. Please install Docker Desktop from https://www.docker.com/products/docker-desktop/" -ForegroundColor Red
    exit 1
}

# Check Docker Compose
try {
    $composeVersion = docker compose version
    Write-Host "[OK] Docker Compose is available: $composeVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Docker Compose is not available" -ForegroundColor Red
    exit 1
}

Write-Host "`n Creating project structure..." -ForegroundColor Yellow

# Create root directory
$projectRoot = "comments-service"
if (Test-Path $projectRoot) {
    Write-Host "[WARN]  Directory '$projectRoot' already exists. Remove it? (y/n)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -eq 'y') {
        Remove-Item -Path $projectRoot -Recurse -Force
        Write-Host "[OK] Removed existing directory" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Aborted" -ForegroundColor Red
        exit 1
    }
}

New-Item -ItemType Directory -Path $projectRoot | Out-Null
Set-Location $projectRoot

# Create directory structure
$directories = @(
    "cmd/server",
    "cmd/worker",
    "cmd/migrate",
    "internal/domain/comment",
    "internal/domain/tenant",
    "internal/domain/user",
    "internal/domain/like",
    "internal/application/comment",
    "internal/application/tenant",
    "internal/application/user",
    "internal/application/like",
    "internal/application/auth",
    "internal/infrastructure/persistence/postgres",
    "internal/infrastructure/cache/redis",
    "internal/infrastructure/messaging/rabbitmq",
    "internal/infrastructure/ratelimit",
    "internal/infrastructure/locks",
    "internal/infrastructure/monitoring",
    "internal/interfaces/http/handlers",
    "internal/interfaces/http/middleware",
    "internal/interfaces/http/dto",
    "internal/config",
    "pkg/validator",
    "pkg/crypto",
    "pkg/errors",
    "pkg/utils",
    "migrations",
    "scripts",
    "deployments/docker",
    "deployments/kubernetes",
    "tests/unit",
    "tests/integration",
    "tests/e2e",
    "tests/fixtures",
    "docs/api",
    "docs/architecture",
    "monitoring/prometheus",
    "monitoring/grafana/dashboards",
    "monitoring/grafana/datasources"
)

Write-Host "`nCreating directories..." -ForegroundColor Cyan
foreach ($dir in $directories) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Write-Host "  [OK] $dir" -ForegroundColor Gray
}

Write-Host "`n[OK] Directory structure created!" -ForegroundColor Green

# Initialize Go module
Write-Host "`n Initializing Go module..." -ForegroundColor Yellow
go mod init github.com/ayushvyasgit/comments-service
Write-Host "[OK] Go module initialized" -ForegroundColor Green

# Create go.mod with dependencies
$goModContent = @'
module github.com/ayushvyasgit/comments-service

go 1.21

require (
	github.com/gin-gonic/gin v1.10.0
	github.com/google/uuid v1.6.0
	github.com/lib/pq v1.10.9
	github.com/redis/go-redis/v9 v9.4.0
	github.com/golang-jwt/jwt/v5 v5.2.0
	github.com/joho/godotenv v1.5.1
	golang.org/x/crypto v0.18.0
)
'@

Set-Content -Path "go.mod" -Value $goModContent
Write-Host "[OK] go.mod configured with dependencies" -ForegroundColor Green

# Create .gitignore
$gitignoreContent = @'
# Binaries
*.exe
*.exe~
*.dll
*.so
*.dylib
/bin/
/dist/

# Test binary
*.test

# Output of the go coverage tool
*.out

# Dependency directories
/vendor/

# Go workspace file
go.work

# Environment variables
.env
.env.local
.env.*.local

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# Database
*.db
*.sqlite

# Docker
docker-compose.override.yml

# Temporary files
tmp/
temp/
'@

Set-Content -Path ".gitignore" -Value $gitignoreContent
Write-Host "[OK] .gitignore created" -ForegroundColor Green

# Create .env.example
$envExampleContent = @'
# Application
APP_NAME=comments-service
APP_ENV=development
PORT=8080

# Database
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=comments_service
DB_SSLMODE=disable
DB_MAX_CONNECTIONS=100
DB_MAX_IDLE_CONNECTIONS=10

# Database Read Replica (optional)
DB_READ_HOST=localhost
DB_READ_PORT=5433

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0
REDIS_CLUSTER_ENABLED=false
REDIS_CLUSTER_ADDRS=redis-1:6379,redis-2:6379,redis-3:6379

# JWT
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production
JWT_EXPIRY=15m
JWT_REFRESH_EXPIRY=7d

# Rate Limiting
RATE_LIMIT_ENABLED=true
DEFAULT_RATE_LIMIT_PER_MINUTE=100
DEFAULT_RATE_LIMIT_PER_HOUR=5000

# Logging
LOG_LEVEL=debug
LOG_FORMAT=json

# CORS
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080
CORS_ALLOWED_METHODS=GET,POST,PUT,PATCH,DELETE,OPTIONS
CORS_ALLOWED_HEADERS=Content-Type,Authorization,X-API-Key

# Monitoring
METRICS_ENABLED=true
METRICS_PORT=9090
TRACING_ENABLED=false
JAEGER_ENDPOINT=http://localhost:14268/api/traces
'@

Set-Content -Path ".env.example" -Value $envExampleContent
Copy-Item ".env.example" ".env"
Write-Host "[OK] .env files created" -ForegroundColor Green

# Create README.md
$readmeContent = @'
# Comments Service - Enterprise SaaS Platform

A production-ready, horizontally-scalable, multi-tenant comments system built with Go.

## Architecture

- **Language**: Go 1.21+
- **Database**: PostgreSQL 16 with read replicas
- **Cache**: Redis 7 (cluster mode)
- **Message Queue**: RabbitMQ (optional)
- **API**: RESTful with JWT authentication
- **Pattern**: CQRS, Event Sourcing, DDD

## Quick Start

### Prerequisites
- Go 1.21+
- Docker Desktop

### 1. Start Infrastructure
```powershell
docker compose up -d
```

### 2. Run Migrations
```powershell
go run cmd/migrate/main.go up
```

### 3. Start Server
```powershell
go run cmd/server/main.go
```

API will be available at: http://localhost:8080

## Testing
```powershell
go test ./...
go test -cover ./...
go test ./tests/integration/...
```

## License
MIT
'@

Set-Content -Path "README.md" -Value $readmeContent
Write-Host "[OK] README.md created" -ForegroundColor Green

# Create Makefile
$makefileContent = @'
.PHONY: help build test run docker-up docker-down migrate-up migrate-down

help:
	@echo "Available commands:"
	@echo "  make build        - Build the application"
	@echo "  make test         - Run tests"
	@echo "  make run          - Run the server"
	@echo "  make docker-up    - Start Docker services"
	@echo "  make docker-down  - Stop Docker services"
	@echo "  make migrate-up   - Run database migrations"
	@echo "  make migrate-down - Rollback migrations"

build:
	go build -o bin/server cmd/server/main.go
	go build -o bin/worker cmd/worker/main.go
	go build -o bin/migrate cmd/migrate/main.go

test:
	go test -v ./...

test-coverage:
	go test -cover -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out

run:
	go run cmd/server/main.go

docker-up:
	docker compose up -d

docker-down:
	docker compose down

docker-logs:
	docker compose logs -f

migrate-up:
	go run cmd/migrate/main.go up

migrate-down:
	go run cmd/migrate/main.go down

clean:
	rm -rf bin/
	rm -f coverage.out

deps:
	go mod download
	go mod tidy

fmt:
	go fmt ./...

lint:
	golangci-lint run
'@

Set-Content -Path "Makefile" -Value $makefileContent
Write-Host "[OK] Makefile created" -ForegroundColor Green

# Summary
Write-Host "`n Project initialization complete!" -ForegroundColor Green
Write-Host "`n Summary:" -ForegroundColor Cyan
Write-Host "  - Project root: " -NoNewline
Write-Host "$projectRoot" -ForegroundColor Yellow
Write-Host "  - Go module: " -NoNewline
Write-Host "github.com/ayushvyasgit/comments-service" -ForegroundColor Yellow
Write-Host "  - Directories created: " -NoNewline
Write-Host "$($directories.Count)" -ForegroundColor Yellow

Write-Host "`n Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Review .env file and update configuration"
Write-Host "  2. Run: " -NoNewline -ForegroundColor White
Write-Host "docker compose up -d" -ForegroundColor Yellow -NoNewline
Write-Host " (start infrastructure)" -ForegroundColor White
Write-Host "  3. Run: " -NoNewline -ForegroundColor White
Write-Host "go mod download" -ForegroundColor Yellow -NoNewline
Write-Host " (download dependencies)" -ForegroundColor White
Write-Host "  4. Copy migration files to ./migrations folder"
Write-Host "  5. Run migrations and start building!"

Write-Host "`n Ready to code! Happy building! `n" -ForegroundColor Green