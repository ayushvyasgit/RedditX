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
