# Complete Go Project Structure
## Comments Service - Production-Ready Architecture

---

## Project Directory Structure

```
comments-service/
├── cmd/
│   ├── server/
│   │   └── main.go                    # Main application entry point
│   ├── worker/
│   │   └── main.go                    # Background worker for async jobs
│   └── migrate/
│       └── main.go                    # Database migration tool
│
├── internal/                          # Private application code
│   ├── domain/                        # Domain layer (business logic)
│   │   ├── comment/
│   │   │   ├── aggregate.go           # Comment aggregate root
│   │   │   ├── commands.go            # Command definitions
│   │   │   ├── queries.go             # Query definitions
│   │   │   ├── events.go              # Domain events
│   │   │   ├── errors.go              # Domain-specific errors
│   │   │   └── value_objects.go       # Value objects
│   │   │
│   │   ├── tenant/
│   │   │   ├── aggregate.go
│   │   │   ├── commands.go
│   │   │   ├── queries.go
│   │   │   ├── events.go
│   │   │   └── errors.go
│   │   │
│   │   ├── user/
│   │   │   ├── aggregate.go
│   │   │   ├── commands.go
│   │   │   ├── queries.go
│   │   │   ├── events.go
│   │   │   └── errors.go
│   │   │
│   │   └── like/
│   │       ├── aggregate.go
│   │       ├── commands.go
│   │       ├── events.go
│   │       └── errors.go
│   │
│   ├── application/                   # Application layer (use cases)
│   │   ├── comment/
│   │   │   ├── command_handler.go     # Command handlers
│   │   │   ├── query_handler.go       # Query handlers
│   │   │   ├── read_model.go          # Read model DTOs
│   │   │   ├── projector.go           # Event projector for read model
│   │   │   └── service.go             # Application service
│   │   │
│   │   ├── tenant/
│   │   │   ├── command_handler.go
│   │   │   ├── query_handler.go
│   │   │   ├── read_model.go
│   │   │   └── service.go
│   │   │
│   │   ├── user/
│   │   │   ├── command_handler.go
│   │   │   ├── query_handler.go
│   │   │   ├── read_model.go
│   │   │   └── service.go
│   │   │
│   │   ├── like/
│   │   │   ├── command_handler.go
│   │   │   ├── service.go
│   │   │   └── read_model.go
│   │   │
│   │   └── auth/
│   │       ├── service.go             # Authentication service
│   │       ├── token.go               # JWT token management
│   │       └── authorization.go       # Authorization logic
│   │
│   ├── infrastructure/                # Infrastructure layer
│   │   ├── persistence/
│   │   │   ├── postgres/
│   │   │   │   ├── connection.go      # DB connection pool
│   │   │   │   ├── transaction.go     # Transaction management
│   │   │   │   ├── comment_repository.go
│   │   │   │   ├── tenant_repository.go
│   │   │   │   ├── user_repository.go
│   │   │   │   ├── like_repository.go
│   │   │   │   └── audit_repository.go
│   │   │   │
│   │   │   └── migrations/
│   │   │       ├── 001_create_tenants.sql
│   │   │       ├── 002_create_users.sql
│   │   │       ├── 003_create_comments.sql
│   │   │       ├── 004_create_likes.sql
│   │   │       ├── 005_create_sessions.sql
│   │   │       ├── 006_create_audit_logs.sql
│   │   │       └── 007_create_indexes.sql
│   │   │
│   │   ├── cache/
│   │   │   ├── redis/
│   │   │   │   ├── client.go          # Redis cluster client
│   │   │   │   ├── cache_aside.go     # Cache-aside pattern
│   │   │   │   ├── multi_level.go     # Multi-level cache
│   │   │   │   └── pubsub.go          # Redis pub/sub
│   │   │   │
│   │   │   └── local/
│   │   │       └── in_memory.go       # Local in-memory cache
│   │   │
│   │   ├── messaging/
│   │   │   ├── rabbitmq/
│   │   │   │   ├── client.go          # RabbitMQ connection
│   │   │   │   ├── publisher.go       # Event publisher
│   │   │   │   └── consumer.go        # Event consumer
│   │   │   │
│   │   │   └── events/
│   │   │       ├── bus.go             # Event bus interface
│   │   │       └── handler.go         # Event handler interface
│   │   │
│   │   ├── ratelimit/
│   │   │   ├── token_bucket.go        # Token bucket algorithm
│   │   │   ├── sliding_window.go      # Sliding window algorithm
│   │   │   ├── fixed_window.go        # Fixed window algorithm
│   │   │   └── service.go             # Rate limit service
│   │   │
│   │   ├── locks/
│   │   │   ├── redlock.go             # Redlock implementation
│   │   │   └── manager.go             # Lock manager
│   │   │
│   │   ├── search/
│   │   │   └── postgres_fts.go        # PostgreSQL full-text search
│   │   │
│   │   └── monitoring/
│   │       ├── metrics.go             # Prometheus metrics
│   │       ├── tracing.go             # OpenTelemetry tracing
│   │       └── logging.go             # Structured logging
│   │
│   ├── interfaces/                    # Interface adapters (HTTP, gRPC, etc.)
│   │   ├── http/
│   │   │   ├── server.go              # HTTP server setup
│   │   │   ├── router.go              # Route definitions
│   │   │   │
│   │   │   ├── middleware/
│   │   │   │   ├── logger.go          # Logging middleware
│   │   │   │   ├── recovery.go        # Panic recovery
│   │   │   │   ├── cors.go            # CORS middleware
│   │   │   │   ├── auth.go            # Authentication middleware
│   │   │   │   ├── tenant.go          # Tenant resolution
│   │   │   │   ├── ratelimit.go       # Rate limiting middleware
│   │   │   │   ├── metrics.go         # Metrics middleware
│   │   │   │   └── tracing.go         # Tracing middleware
│   │   │   │
│   │   │   ├── handlers/
│   │   │   │   ├── comment.go         # Comment HTTP handlers
│   │   │   │   ├── tenant.go          # Tenant HTTP handlers
│   │   │   │   ├── user.go            # User HTTP handlers
│   │   │   │   ├── like.go            # Like HTTP handlers
│   │   │   │   ├── auth.go            # Auth HTTP handlers
│   │   │   │   ├── health.go          # Health check handlers
│   │   │   │   └── audit.go           # Audit log handlers
│   │   │   │
│   │   │   └── dto/
│   │   │       ├── request.go         # Request DTOs
│   │   │       ├── response.go        # Response DTOs
│   │   │       └── validators.go      # Input validation
│   │   │
│   │   └── websocket/
│   │       ├── server.go              # WebSocket server
│   │       ├── hub.go                 # Connection hub
│   │       └── client.go              # WebSocket client
│   │
│   └── config/
│       ├── config.go                  # Configuration struct
│       ├── database.go                # Database config
│       ├── redis.go                   # Redis config
│       ├── server.go                  # Server config
│       └── loader.go                  # Config loader (env/file)
│
├── pkg/                               # Public packages (can be imported by other projects)
│   ├── validator/
│   │   ├── validator.go               # Input validation utilities
│   │   └── rules.go                   # Validation rules
│   │
│   ├── crypto/
│   │   ├── hash.go                    # Hashing utilities
│   │   └── jwt.go                     # JWT utilities
│   │
│   ├── errors/
│   │   ├── errors.go                  # Custom error types
│   │   └── codes.go                   # Error codes
│   │
│   └── utils/
│       ├── strings.go                 # String utilities
│       ├── time.go                    # Time utilities
│       └── pagination.go              # Pagination utilities
│
├── migrations/                        # Database migrations (copy from internal)
│   └── ... (same as internal/infrastructure/persistence/migrations)
│
├── scripts/                           # Utility scripts
│   ├── setup.sh                       # Setup development environment
│   ├── build.sh                       # Build application
│   ├── test.sh                        # Run tests
│   ├── migrate.sh                     # Run migrations
│   └── deploy.sh                      # Deployment script
│
├── deployments/                       # Deployment configurations
│   ├── docker/
│   │   ├── Dockerfile                 # Multi-stage Dockerfile
│   │   ├── Dockerfile.worker          # Worker Dockerfile
│   │   └── .dockerignore
│   │
│   ├── kubernetes/
│   │   ├── deployment.yaml            # K8s deployment
│   │   ├── service.yaml               # K8s service
│   │   ├── configmap.yaml             # K8s configmap
│   │   ├── secret.yaml                # K8s secrets
│   │   ├── ingress.yaml               # K8s ingress
│   │   └── hpa.yaml                   # Horizontal Pod Autoscaler
│   │
│   └── terraform/
│       ├── main.tf                    # Infrastructure as code
│       ├── variables.tf
│       └── outputs.tf
│
├── tests/                             # Test files
│   ├── unit/
│   │   ├── domain/
│   │   ├── application/
│   │   └── infrastructure/
│   │
│   ├── integration/
│   │   ├── api_test.go
│   │   ├── database_test.go
│   │   └── cache_test.go
│   │
│   ├── e2e/
│   │   └── scenarios_test.go
│   │
│   └── fixtures/
│       ├── comments.json
│       ├── users.json
│       └── tenants.json
│
├── docs/                              # Documentation
│   ├── api/
│   │   ├── openapi.yaml               # OpenAPI/Swagger spec
│   │   └── postman_collection.json
│   │
│   ├── architecture/
│   │   ├── overview.md
│   │   ├── cqrs.md
│   │   ├── database.md
│   │   └── caching.md
│   │
│   └── deployment/
│       ├── production.md
│       ├── staging.md
│       └── development.md
│
├── monitoring/                        # Monitoring configs
│   ├── prometheus/
│   │   └── prometheus.yml
│   │
│   ├── grafana/
│   │   ├── dashboards/
│   │   │   ├── api_metrics.json
│   │   │   ├── database_metrics.json
│   │   │   └── redis_metrics.json
│   │   └── datasources/
│   │       └── prometheus.yaml
│   │
│   └── alerting/
│       └── rules.yaml
│
├── .github/                           # GitHub specific files
│   ├── workflows/
│   │   ├── ci.yml                     # CI pipeline
│   │   ├── cd.yml                     # CD pipeline
│   │   └── lint.yml                   # Linting pipeline
│   │
│   └── PULL_REQUEST_TEMPLATE.md
│
├── docker-compose.yml                 # Local development stack
├── docker-compose.prod.yml            # Production-like local stack
├── Makefile                           # Build automation
├── go.mod                             # Go module definition
├── go.sum                             # Go module checksums
├── .env.example                       # Example environment variables
├── .gitignore
├── README.md
└── LICENSE
```

---

## Detailed Component Explanations

### 1. CMD Layer (Application Entry Points)

#### `cmd/server/main.go`
**Purpose**: Main HTTP API server entry point
**Responsibilities**:
- Initialize configuration
- Set up database connections
- Initialize Redis cluster
- Configure middleware stack
- Start HTTP server
- Handle graceful shutdown

```go
package main

import (
    "context"
    "os"
    "os/signal"
    "syscall"
    "time"
    
    "comment-service/internal/config"
    "comment-service/internal/infrastructure/persistence/postgres"
    "comment-service/internal/infrastructure/cache/redis"
    "comment-service/internal/interfaces/http"
)

func main() {
    // Load configuration
    cfg := config.Load()
    
    // Initialize logger
    logger := initLogger(cfg)
    
    // Initialize database
    db, err := postgres.NewConnection(cfg.Database)
    if err != nil {
        logger.Fatal("failed to connect to database", "error", err)
    }
    defer db.Close()
    
    // Initialize Redis cluster
    redisClient := redis.NewProductionClusterClient()
    defer redisClient.Close()
    
    // Health check
    if err := redisClient.HealthCheck(context.Background()); err != nil {
        logger.Fatal("redis cluster unhealthy", "error", err)
    }
    
    // Initialize HTTP server
    server := http.NewServer(cfg, db, redisClient, logger)
    
    // Start server in goroutine
    go func() {
        if err := server.Start(); err != nil {
            logger.Fatal("server failed to start", "error", err)
        }
    }()
    
    // Wait for interrupt signal
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit
    
    // Graceful shutdown
    logger.Info("shutting down server...")
    
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()
    
    if err := server.Shutdown(ctx); err != nil {
        logger.Error("server forced to shutdown", "error", err)
    }
    
    logger.Info("server exited")
}
```

#### `cmd/worker/main.go`
**Purpose**: Background worker for async event processing
**Responsibilities**:
- Consume events from RabbitMQ
- Process notifications
- Run scheduled cleanup jobs
- Update analytics

```go
package main

import (
    "context"
    "os"
    "os/signal"
    "syscall"
    
    "comment-service/internal/config"
    "comment-service/internal/infrastructure/messaging/rabbitmq"
    "comment-service/internal/application/comment"
)

func main() {
    cfg := config.Load()
    logger := initLogger(cfg)
    
    // Initialize message queue
    mq, err := rabbitmq.NewClient(cfg.RabbitMQ)
    if err != nil {
        logger.Fatal("failed to connect to RabbitMQ", "error", err)
    }
    defer mq.Close()
    
    // Initialize event handlers
    commentProjector := comment.NewProjector(db, cache)
    
    // Register event handlers
    mq.Subscribe("comment.created", commentProjector.OnCommentCreated)
    mq.Subscribe("comment.updated", commentProjector.OnCommentUpdated)
    mq.Subscribe("comment.deleted", commentProjector.OnCommentDeleted)
    
    // Start consuming
    go mq.StartConsuming()
    
    logger.Info("worker started")
    
    // Wait for signal
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit
    
    logger.Info("worker shutting down")
}
```

---

### 2. Domain Layer (Business Logic)

#### `internal/domain/comment/aggregate.go`
**Purpose**: Comment aggregate root - encapsulates business rules
**Key Concepts**:
- Aggregate is the consistency boundary
- All state changes go through the aggregate
- Emits domain events

```go
package comment

import (
    "errors"
    "time"
)

// Comment is the aggregate root
type Comment struct {
    // Identity
    id       string
    tenantID string
    
    // Hierarchy
    parentID *string
    depth    int
    path     string
    
    // Entity relation
    entityType string
    entityID   string
    
    // Author
    authorID    string
    authorName  string
    authorEmail string
    
    // Content
    content       string
    contentFormat string
    
    // State
    status    CommentStatus
    isPinned  bool
    isEdited  bool
    
    // Metrics
    likeCount  int
    replyCount int
    
    // Timestamps
    createdAt time.Time
    updatedAt time.Time
    editedAt  *time.Time
    deletedAt *time.Time
    
    // Domain events (to be published)
    events []DomainEvent
}

type CommentStatus string

const (
    StatusActive  CommentStatus = "ACTIVE"
    StatusDeleted CommentStatus = "DELETED"
    StatusFlagged CommentStatus = "FLAGGED"
    StatusSpam    CommentStatus = "SPAM"
)

// NewComment creates a new comment (factory method)
func NewComment(
    id, tenantID, entityType, entityID string,
    parentID *string,
    authorID, authorName, authorEmail string,
    content string,
) (*Comment, error) {
    // Business rule: content must be between 1 and 10,000 characters
    if len(content) < 1 || len(content) > 10000 {
        return nil, errors.New("content length must be between 1 and 10,000 characters")
    }
    
    // Business rule: tenant ID is required
    if tenantID == "" {
        return nil, errors.New("tenant ID is required")
    }
    
    comment := &Comment{
        id:            id,
        tenantID:      tenantID,
        parentID:      parentID,
        depth:         0,
        path:          "",
        entityType:    entityType,
        entityID:      entityID,
        authorID:      authorID,
        authorName:    authorName,
        authorEmail:   authorEmail,
        content:       content,
        contentFormat: "plain",
        status:        StatusActive,
        isPinned:      false,
        isEdited:      false,
        likeCount:     0,
        replyCount:    0,
        createdAt:     time.Now(),
        updatedAt:     time.Now(),
        events:        []DomainEvent{},
    }
    
    // Record domain event
    comment.recordEvent(CommentCreatedEvent{
        CommentID: id,
        TenantID:  tenantID,
        Timestamp: time.Now(),
    })
    
    return comment, nil
}

// UpdateContent updates the comment content
func (c *Comment) UpdateContent(newContent string) error {
    // Business rule: cannot update deleted comments
    if c.status == StatusDeleted {
        return errors.New("cannot update deleted comment")
    }
    
    // Business rule: content must be between 1 and 10,000 characters
    if len(newContent) < 1 || len(newContent) > 10000 {
        return errors.New("content length must be between 1 and 10,000 characters")
    }
    
    previousContent := c.content
    c.content = newContent
    c.isEdited = true
    now := time.Now()
    c.editedAt = &now
    c.updatedAt = now
    
    // Record event
    c.recordEvent(CommentUpdatedEvent{
        CommentID:       c.id,
        PreviousContent: previousContent,
        NewContent:      newContent,
        Timestamp:       now,
    })
    
    return nil
}

// Delete soft-deletes the comment
func (c *Comment) Delete() error {
    // Business rule: already deleted
    if c.status == StatusDeleted {
        return errors.New("comment already deleted")
    }
    
    now := time.Now()
    c.status = StatusDeleted
    c.deletedAt = &now
    c.updatedAt = now
    
    c.recordEvent(CommentDeletedEvent{
        CommentID: c.id,
        Timestamp: now,
    })
    
    return nil
}

// IncrementLikeCount increments the like counter
func (c *Comment) IncrementLikeCount() {
    c.likeCount++
    c.updatedAt = time.Now()
}

// DecrementLikeCount decrements the like counter
func (c *Comment) DecrementLikeCount() {
    if c.likeCount > 0 {
        c.likeCount--
        c.updatedAt = time.Now()
    }
}

// IncrementReplyCount increments the reply counter
func (c *Comment) IncrementReplyCount() {
    c.replyCount++
    c.updatedAt = time.Now()
}

// recordEvent adds a domain event to the aggregate
func (c *Comment) recordEvent(event DomainEvent) {
    c.events = append(c.events, event)
}

// GetEvents returns all recorded domain events
func (c *Comment) GetEvents() []DomainEvent {
    return c.events
}

// ClearEvents clears all recorded domain events (after publishing)
func (c *Comment) ClearEvents() {
    c.events = []DomainEvent{}
}

// Getters (no setters - state changes through methods)
func (c *Comment) ID() string       { return c.id }
func (c *Comment) TenantID() string { return c.tenantID }
func (c *Comment) Content() string  { return c.content }
func (c *Comment) Status() CommentStatus { return c.status }
// ... more getters
```

---

### 3. Application Layer (Use Cases)

#### `internal/application/comment/service.go`
**Purpose**: Orchestrates use cases, coordinates between domain and infrastructure
**Responsibilities**:
- Handles application-level transactions
- Coordinates between aggregates
- Publishes events
- Does NOT contain business logic (that's in domain layer)

```go
package comment

import (
    "context"
    "database/sql"
    
    domainComment "comment-service/internal/domain/comment"
    "comment-service/internal/infrastructure/events"
)

type Service struct {
    db          *sql.DB
    eventBus    events.EventBus
    cache       CacheService
    validator   Validator
    authService AuthService
}

func NewService(
    db *sql.DB,
    eventBus events.EventBus,
    cache CacheService,
    validator Validator,
    authService AuthService,
) *Service {
    return &Service{
        db:          db,
        eventBus:    eventBus,
        cache:       cache,
        validator:   validator,
        authService: authService,
    }
}

// CreateComment is a use case
func (s *Service) CreateComment(
    ctx context.Context,
    cmd domainComment.CreateCommentCommand,
) (*domainComment.Comment, error) {
    // Validate command
    if err := s.validator.Validate(cmd); err != nil {
        return nil, err
    }
    
    // Create domain aggregate
    comment, err := domainComment.NewComment(
        cmd.ID,
        cmd.TenantID,
        cmd.EntityType,
        cmd.EntityID,
        cmd.ParentID,
        cmd.AuthorID,
        cmd.AuthorName,
        cmd.AuthorEmail,
        cmd.Content,
    )
    if err != nil {
        return nil, err
    }
    
    // Begin transaction
    tx, err := s.db.BeginTx(ctx, nil)
    if err != nil {
        return nil, err
    }
    defer tx.Rollback()
    
    // Persist to repository
    if err := s.saveComment(ctx, tx, comment); err != nil {
        return nil, err
    }
    
    // Commit transaction
    if err := tx.Commit(); err != nil {
        return nil, err
    }
    
    // Publish domain events (after commit)
    for _, event := range comment.GetEvents() {
        if err := s.eventBus.Publish(ctx, event); err != nil {
            // Log error but don't fail - eventual consistency
            log.Error("failed to publish event", "error", err)
        }
    }
    
    return comment, nil
}
```

---

### 4. Infrastructure Layer

#### `internal/infrastructure/persistence/postgres/comment_repository.go`
**Purpose**: Implements persistence for comment aggregate
**Pattern**: Repository pattern - abstracts database operations

```go
package postgres

import (
    "context"
    "database/sql"
    
    "comment-service/internal/domain/comment"
)

type CommentRepository struct {
    db *sql.DB
}

func NewCommentRepository(db *sql.DB) *CommentRepository {
    return &CommentRepository{db: db}
}

// Save persists a comment
func (r *CommentRepository) Save(ctx context.Context, c *comment.Comment) error {
    query := `
        INSERT INTO comments (
            id, tenant_id, parent_id, entity_type, entity_id,
            depth, path, author_id, author_name, author_email,
            content, content_format, status, is_pinned, is_edited,
            like_count, reply_count, created_at, updated_at
        ) VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
            $11, $12, $13, $14, $15, $16, $17, $18, $19
        )
    `
    
    _, err := r.db.ExecContext(ctx, query,
        c.ID(), c.TenantID(), c.ParentID(), c.EntityType(), c.EntityID(),
        c.Depth(), c.Path(), c.AuthorID(), c.AuthorName(), c.AuthorEmail(),
        c.Content(), c.ContentFormat(), c.Status(), c.IsPinned(), c.IsEdited(),
        c.LikeCount(), c.ReplyCount(), c.CreatedAt(), c.UpdatedAt(),
    )
    
    return err
}

// FindByID retrieves a comment by ID
func (r *CommentRepository) FindByID(
    ctx context.Context,
    tenantID, commentID string,
) (*comment.Comment, error) {
    query := `
        SELECT id, tenant_id, parent_id, entity_type, entity_id,
               depth, path, author_id, author_name, author_email,
               content, content_format, status, is_pinned, is_edited,
               like_count, reply_count, created_at, updated_at, edited_at, deleted_at
        FROM comments
        WHERE id = $1 AND tenant_id = $2
    `
    
    // ... scan and reconstruct aggregate
}
```

---

## Request Flow Through Layers

### Example: Create Comment Request

```
1. HTTP Request arrives at interface layer
   ↓
2. Middleware stack processes (auth, tenant, rate limit)
   ↓
3. Handler validates input and creates command
   ↓
4. Application service receives command
   ↓
5. Service creates domain aggregate (business rules enforced)
   ↓
6. Repository persists aggregate to database
   ↓
7. Event bus publishes domain events
   ↓
8. Response sent back to client
   ↓
9. Worker consumes events (async)
   ↓
10. Projector updates read model
```

**Next file**: Complete code for each component with full implementation