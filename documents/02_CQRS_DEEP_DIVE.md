# CQRS Implementation Deep Dive
## Command Query Responsibility Segregation Pattern

---

## Table of Contents
1. [CQRS Fundamentals](#cqrs-fundamentals)
2. [Why CQRS for Comments Service](#why-cqrs)
3. [Command Side Implementation](#command-side)
4. [Query Side Implementation](#query-side)
5. [Event Sourcing Integration](#event-sourcing)
6. [Complete Code Examples](#code-examples)
7. [Performance Optimizations](#optimizations)

---

## 1. CQRS FUNDAMENTALS

### What is CQRS?

**CQRS** separates read and write operations into different models:

- **Command Side (Write)**: Handles state changes, enforces business rules, validates data
- **Query Side (Read)**: Optimized for data retrieval, uses denormalized views

### Core Principles

```
Traditional CRUD:
┌──────────────┐
│  Controller  │
└──────┬───────┘
       │
┌──────▼───────┐
│   Service    │
└──────┬───────┘
       │
┌──────▼───────┐
│  Repository  │
└──────┬───────┘
       │
┌──────▼───────┐
│   Database   │
└──────────────┘

CQRS Pattern:
                    ┌──────────────┐
                    │  Controller  │
                    └───┬──────┬───┘
                        │      │
            Command     │      │     Query
                        │      │
        ┌───────────────▼┐    ┌▼───────────────┐
        │ Command Handler│    │ Query Handler  │
        └───────┬────────┘    └────┬───────────┘
                │                  │
        ┌───────▼────────┐    ┌────▼───────────┐
        │  Write Model   │    │  Read Model    │
        │  (Normalized)  │    │ (Denormalized) │
        └───────┬────────┘    └────┬───────────┘
                │                  │
        ┌───────▼────────┐    ┌────▼───────────┐
        │  Write DB      │    │   Read DB      │
        │  (Primary)     │    │  (Replica +    │
        │                │    │   Cache)       │
        └───────┬────────┘    └────────────────┘
                │
        ┌───────▼────────┐
        │  Event Bus     │ ───────────────┐
        └────────────────┘                 │
                                          │
                                ┌─────────▼──────┐
                                │  Event Handler │
                                │  (Projector)   │
                                └─────────┬──────┘
                                          │
                                    Updates Read Model
```

---

## 2. WHY CQRS FOR COMMENTS SERVICE

### Read/Write Asymmetry

**Our Use Case Statistics:**
- **95% Reads**: Users viewing comments
- **5% Writes**: Creating, updating, liking comments

**Traditional Approach Problems:**
1. Same model for reads and writes
2. Complex joins on every read
3. Counters updated on every write
4. Locking issues during high read traffic

**CQRS Benefits:**
1. ✅ Optimize reads independently (denormalized views)
2. ✅ Scale read and write databases separately
3. ✅ Use caching aggressively on read side
4. ✅ Eventually consistent is acceptable for our domain
5. ✅ Better performance under load

### Trade-offs

| Aspect | Benefit | Cost |
|--------|---------|------|
| **Complexity** | Clearer separation of concerns | More code to maintain |
| **Performance** | Optimized for each operation | Event propagation delay |
| **Scalability** | Independent scaling | Infrastructure overhead |
| **Consistency** | Eventual consistency acceptable | Not suitable for strict consistency |

---

## 3. COMMAND SIDE IMPLEMENTATION

### 3.1 Command Structure

Commands represent **intentions** to change state.

```go
// internal/domain/comment/commands.go

package comment

import (
    "time"
    "github.com/google/uuid"
)

// Base Command Interface
type Command interface {
    CommandType() string
    AggregateID() string
    TenantID() string
    Validate() error
}

// CreateCommentCommand - Intent to create a comment
type CreateCommentCommand struct {
    ID          string    // Pre-generated UUID
    TenantID    string
    EntityType  string    // 'post', 'product', 'article'
    EntityID    string    
    ParentID    *string   // nil for root comments
    AuthorID    string
    AuthorName  string
    AuthorEmail string
    Content     string
    Timestamp   time.Time
}

func (c CreateCommentCommand) CommandType() string { return "CreateComment" }
func (c CreateCommentCommand) AggregateID() string { return c.ID }
func (c CreateCommentCommand) TenantID() string    { return c.TenantID }

func (c CreateCommentCommand) Validate() error {
    if c.TenantID == "" {
        return ErrMissingTenantID
    }
    if c.EntityType == "" || c.EntityID == "" {
        return ErrMissingEntity
    }
    if c.AuthorID == "" {
        return ErrMissingAuthor
    }
    if len(c.Content) < 1 || len(c.Content) > 10000 {
        return ErrInvalidContentLength
    }
    return nil
}

// UpdateCommentCommand
type UpdateCommentCommand struct {
    ID        string
    TenantID  string
    UserID    string // For authorization check
    Content   string
    Timestamp time.Time
}

func (c UpdateCommentCommand) CommandType() string { return "UpdateComment" }
func (c UpdateCommentCommand) AggregateID() string { return c.ID }
func (c UpdateCommentCommand) TenantID() string    { return c.TenantID }

func (c UpdateCommentCommand) Validate() error {
    if c.ID == "" || c.TenantID == "" {
        return ErrInvalidCommand
    }
    if len(c.Content) < 1 || len(c.Content) > 10000 {
        return ErrInvalidContentLength
    }
    return nil
}

// DeleteCommentCommand (Soft Delete)
type DeleteCommentCommand struct {
    ID        string
    TenantID  string
    UserID    string // For authorization
    Reason    string
    Timestamp time.Time
}

func (c DeleteCommentCommand) CommandType() string { return "DeleteComment" }
func (c DeleteCommentCommand) AggregateID() string { return c.ID }
func (c DeleteCommentCommand) TenantID() string    { return c.TenantID }

func (c DeleteCommentCommand) Validate() error {
    if c.ID == "" || c.TenantID == "" {
        return ErrInvalidCommand
    }
    return nil
}

// HardDeleteCommentCommand (Admin Only)
type HardDeleteCommentCommand struct {
    ID        string
    TenantID  string
    AdminID   string
    Reason    string
    Timestamp time.Time
}

func (c HardDeleteCommentCommand) CommandType() string { return "HardDeleteComment" }
func (c HardDeleteCommentCommand) AggregateID() string { return c.ID }
func (c HardDeleteCommentCommand) TenantID() string    { return c.TenantID }

func (c HardDeleteCommentCommand) Validate() error {
    if c.ID == "" || c.TenantID == "" || c.AdminID == "" {
        return ErrInvalidCommand
    }
    return nil
}
```

### 3.2 Command Handler

The command handler orchestrates the command execution.

```go
// internal/application/comment/command_handler.go

package comment

import (
    "context"
    "database/sql"
    "fmt"
    
    "github.com/google/uuid"
    "comment-service/internal/domain/comment"
    "comment-service/internal/infrastructure/events"
    "comment-service/internal/infrastructure/locks"
)

type CommandHandler struct {
    db           *sql.DB
    eventBus     events.EventBus
    lockManager  locks.LockManager
    validator    Validator
    authService  AuthService
}

func NewCommandHandler(
    db *sql.DB,
    eventBus events.EventBus,
    lockManager locks.LockManager,
    validator Validator,
    authService AuthService,
) *CommandHandler {
    return &CommandHandler{
        db:          db,
        eventBus:    eventBus,
        lockManager: lockManager,
        validator:   validator,
        authService: authService,
    }
}

// Handle routes commands to appropriate handlers
func (h *CommandHandler) Handle(ctx context.Context, cmd comment.Command) error {
    // Pre-validation
    if err := cmd.Validate(); err != nil {
        return fmt.Errorf("command validation failed: %w", err)
    }
    
    // Route to specific handler
    switch c := cmd.(type) {
    case comment.CreateCommentCommand:
        return h.handleCreateComment(ctx, c)
    case comment.UpdateCommentCommand:
        return h.handleUpdateComment(ctx, c)
    case comment.DeleteCommentCommand:
        return h.handleDeleteComment(ctx, c)
    case comment.HardDeleteCommentCommand:
        return h.handleHardDeleteComment(ctx, c)
    default:
        return fmt.Errorf("unknown command type: %s", cmd.CommandType())
    }
}

// handleCreateComment - Core business logic for creating comments
func (h *CommandHandler) handleCreateComment(
    ctx context.Context,
    cmd comment.CreateCommentCommand,
) error {
    // Step 1: Acquire distributed lock if this is a reply
    // Prevents race conditions when updating parent reply count
    if cmd.ParentID != nil {
        lockKey := fmt.Sprintf("comment:reply:%s", *cmd.ParentID)
        lock, err := h.lockManager.AcquireLock(ctx, lockKey, 5*time.Second)
        if err != nil {
            return fmt.Errorf("failed to acquire lock: %w", err)
        }
        defer h.lockManager.ReleaseLock(ctx, lock)
    }
    
    // Step 2: Begin database transaction
    tx, err := h.db.BeginTx(ctx, &sql.TxOptions{
        Isolation: sql.LevelSerializable,
    })
    if err != nil {
        return fmt.Errorf("failed to begin transaction: %w", err)
    }
    defer tx.Rollback()
    
    // Step 3: Calculate depth and path for hierarchical structure
    var depth int
    var path string
    
    if cmd.ParentID != nil {
        // This is a reply - get parent details
        var parentDepth int
        var parentPath string
        
        query := `
            SELECT depth, path 
            FROM comments 
            WHERE id = $1 AND tenant_id = $2 AND deleted_at IS NULL
            FOR UPDATE
        `
        err := tx.QueryRowContext(ctx, query, *cmd.ParentID, cmd.TenantID).
            Scan(&parentDepth, &parentPath)
        
        if err == sql.ErrNoRows {
            return ErrParentCommentNotFound
        }
        if err != nil {
            return fmt.Errorf("failed to get parent comment: %w", err)
        }
        
        depth = parentDepth + 1
        if parentPath == "" {
            path = *cmd.ParentID
        } else {
            path = fmt.Sprintf("%s.%s", parentPath, *cmd.ParentID)
        }
        
        // Update parent's reply count
        updateParentQuery := `
            UPDATE comments 
            SET reply_count = reply_count + 1,
                updated_at = NOW()
            WHERE id = $1
        `
        _, err = tx.ExecContext(ctx, updateParentQuery, *cmd.ParentID)
        if err != nil {
            return fmt.Errorf("failed to update parent reply count: %w", err)
        }
    } else {
        // Root comment
        depth = 0
        path = ""
    }
    
    // Step 4: Insert the comment
    insertQuery := `
        INSERT INTO comments (
            id, tenant_id, entity_type, entity_id, parent_id,
            depth, path, author_id, author_name, author_email,
            content, status, like_count, reply_count,
            created_at, updated_at
        ) VALUES (
            $1, $2, $3, $4, $5,
            $6, $7, $8, $9, $10,
            $11, $12, $13, $14,
            $15, $16
        )
    `
    
    _, err = tx.ExecContext(ctx, insertQuery,
        cmd.ID, cmd.TenantID, cmd.EntityType, cmd.EntityID, cmd.ParentID,
        depth, path, cmd.AuthorID, cmd.AuthorName, cmd.AuthorEmail,
        cmd.Content, "ACTIVE", 0, 0,
        cmd.Timestamp, cmd.Timestamp,
    )
    if err != nil {
        return fmt.Errorf("failed to insert comment: %w", err)
    }
    
    // Step 5: Create audit log entry
    auditQuery := `
        INSERT INTO audit_logs (
            id, tenant_id, action, resource, resource_id,
            user_id, user_name, success, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
    `
    
    _, err = tx.ExecContext(ctx, auditQuery,
        uuid.New().String(), cmd.TenantID, "COMMENT_CREATED", "comment", cmd.ID,
        cmd.AuthorID, cmd.AuthorName, true, cmd.Timestamp,
    )
    if err != nil {
        return fmt.Errorf("failed to create audit log: %w", err)
    }
    
    // Step 6: Commit transaction
    if err := tx.Commit(); err != nil {
        return fmt.Errorf("failed to commit transaction: %w", err)
    }
    
    // Step 7: Publish domain event (async)
    // This is done AFTER commit to ensure event is only published on success
    event := events.CommentCreatedEvent{
        EventBase: events.EventBase{
            EventID:   uuid.New().String(),
            EventType: "CommentCreated",
            TenantID:  cmd.TenantID,
            Timestamp: cmd.Timestamp,
        },
        CommentID:  cmd.ID,
        EntityType: cmd.EntityType,
        EntityID:   cmd.EntityID,
        ParentID:   cmd.ParentID,
        AuthorID:   cmd.AuthorID,
        Content:    cmd.Content,
        Depth:      depth,
        Path:       path,
    }
    
    if err := h.eventBus.Publish(ctx, event); err != nil {
        // Log error but don't fail the request
        // Event will be retried or handled by eventual consistency
        log.Error("failed to publish CommentCreatedEvent", "error", err)
    }
    
    return nil
}

// handleUpdateComment
func (h *CommandHandler) handleUpdateComment(
    ctx context.Context,
    cmd comment.UpdateCommentCommand,
) error {
    // Step 1: Authorization - verify user can update this comment
    tx, err := h.db.BeginTx(ctx, nil)
    if err != nil {
        return err
    }
    defer tx.Rollback()
    
    // Get current comment
    var currentAuthorID string
    var currentContent string
    
    query := `
        SELECT author_id, content 
        FROM comments 
        WHERE id = $1 AND tenant_id = $2 AND deleted_at IS NULL
        FOR UPDATE
    `
    
    err = tx.QueryRowContext(ctx, query, cmd.ID, cmd.TenantID).
        Scan(&currentAuthorID, &currentContent)
    
    if err == sql.ErrNoRows {
        return ErrCommentNotFound
    }
    if err != nil {
        return err
    }
    
    // Check authorization
    if !h.authService.CanModifyComment(ctx, cmd.UserID, currentAuthorID) {
        return ErrUnauthorized
    }
    
    // Step 2: Save edit history
    historyQuery := `
        INSERT INTO comment_edits (
            id, tenant_id, comment_id, previous_content, new_content,
            edited_by, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7)
    `
    
    _, err = tx.ExecContext(ctx, historyQuery,
        uuid.New().String(), cmd.TenantID, cmd.ID,
        currentContent, cmd.Content, cmd.UserID, cmd.Timestamp,
    )
    if err != nil {
        return err
    }
    
    // Step 3: Update comment
    updateQuery := `
        UPDATE comments 
        SET content = $1,
            is_edited = TRUE,
            edited_at = $2,
            updated_at = $2
        WHERE id = $3
    `
    
    _, err = tx.ExecContext(ctx, updateQuery, cmd.Content, cmd.Timestamp, cmd.ID)
    if err != nil {
        return err
    }
    
    // Commit
    if err := tx.Commit(); err != nil {
        return err
    }
    
    // Publish event
    event := events.CommentUpdatedEvent{
        EventBase: events.EventBase{
            EventID:   uuid.New().String(),
            EventType: "CommentUpdated",
            TenantID:  cmd.TenantID,
            Timestamp: cmd.Timestamp,
        },
        CommentID:       cmd.ID,
        PreviousContent: currentContent,
        NewContent:      cmd.Content,
        EditedBy:        cmd.UserID,
    }
    
    h.eventBus.Publish(ctx, event)
    
    return nil
}

// handleDeleteComment - Soft delete
func (h *CommandHandler) handleDeleteComment(
    ctx context.Context,
    cmd comment.DeleteCommentCommand,
) error {
    tx, err := h.db.BeginTx(ctx, nil)
    if err != nil {
        return err
    }
    defer tx.Rollback()
    
    // Authorization check
    var authorID string
    query := `
        SELECT author_id 
        FROM comments 
        WHERE id = $1 AND tenant_id = $2 AND deleted_at IS NULL
        FOR UPDATE
    `
    
    err = tx.QueryRowContext(ctx, query, cmd.ID, cmd.TenantID).Scan(&authorID)
    if err == sql.ErrNoRows {
        return ErrCommentNotFound
    }
    if err != nil {
        return err
    }
    
    if !h.authService.CanDeleteComment(ctx, cmd.UserID, authorID) {
        return ErrUnauthorized
    }
    
    // Soft delete - set deleted_at timestamp
    updateQuery := `
        UPDATE comments 
        SET deleted_at = $1,
            status = 'DELETED',
            updated_at = $1
        WHERE id = $2
    `
    
    _, err = tx.ExecContext(ctx, updateQuery, cmd.Timestamp, cmd.ID)
    if err != nil {
        return err
    }
    
    if err := tx.Commit(); err != nil {
        return err
    }
    
    // Publish event
    event := events.CommentDeletedEvent{
        EventBase: events.EventBase{
            EventID:   uuid.New().String(),
            EventType: "CommentDeleted",
            TenantID:  cmd.TenantID,
            Timestamp: cmd.Timestamp,
        },
        CommentID:  cmd.ID,
        DeletedBy:  cmd.UserID,
        DeleteType: "SOFT",
    }
    
    h.eventBus.Publish(ctx, event)
    
    return nil
}

// handleHardDeleteComment - Permanent deletion (Admin only)
func (h *CommandHandler) handleHardDeleteComment(
    ctx context.Context,
    cmd comment.HardDeleteCommentCommand,
) error {
    // Verify admin privileges
    if !h.authService.IsAdmin(ctx, cmd.AdminID) {
        return ErrUnauthorized
    }
    
    tx, err := h.db.BeginTx(ctx, nil)
    if err != nil {
        return err
    }
    defer tx.Rollback()
    
    // Delete likes first (foreign key constraint)
    _, err = tx.ExecContext(ctx, 
        "DELETE FROM likes WHERE comment_id = $1 AND tenant_id = $2",
        cmd.ID, cmd.TenantID,
    )
    if err != nil {
        return err
    }
    
    // Delete edit history
    _, err = tx.ExecContext(ctx,
        "DELETE FROM comment_edits WHERE comment_id = $1 AND tenant_id = $2",
        cmd.ID, cmd.TenantID,
    )
    if err != nil {
        return err
    }
    
    // Delete the comment permanently
    result, err := tx.ExecContext(ctx,
        "DELETE FROM comments WHERE id = $1 AND tenant_id = $2",
        cmd.ID, cmd.TenantID,
    )
    if err != nil {
        return err
    }
    
    rowsAffected, _ := result.RowsAffected()
    if rowsAffected == 0 {
        return ErrCommentNotFound
    }
    
    // Create audit log for compliance
    auditQuery := `
        INSERT INTO audit_logs (
            id, tenant_id, action, resource, resource_id,
            user_id, metadata, success, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
    `
    
    metadata := map[string]interface{}{
        "reason":      cmd.Reason,
        "delete_type": "HARD",
    }
    
    _, err = tx.ExecContext(ctx, auditQuery,
        uuid.New().String(), cmd.TenantID, "COMMENT_HARD_DELETED", "comment", cmd.ID,
        cmd.AdminID, metadata, true, cmd.Timestamp,
    )
    
    if err := tx.Commit(); err != nil {
        return err
    }
    
    // Publish event
    event := events.CommentHardDeletedEvent{
        EventBase: events.EventBase{
            EventID:   uuid.New().String(),
            EventType: "CommentHardDeleted",
            TenantID:  cmd.TenantID,
            Timestamp: cmd.Timestamp,
        },
        CommentID: cmd.ID,
        DeletedBy: cmd.AdminID,
        Reason:    cmd.Reason,
    }
    
    h.eventBus.Publish(ctx, event)
    
    return nil
}
```

---

## 4. QUERY SIDE IMPLEMENTATION

### 4.1 Query Structure

Queries are simple data transfer objects requesting data.

```go
// internal/domain/comment/queries.go

package comment

type Query interface {
    QueryType() string
}

// GetCommentByIDQuery
type GetCommentByIDQuery struct {
    TenantID  string
    CommentID string
}

func (q GetCommentByIDQuery) QueryType() string { return "GetCommentByID" }

// GetCommentTreeQuery - Get hierarchical comment structure
type GetCommentTreeQuery struct {
    TenantID   string
    EntityType string
    EntityID   string
    SortBy     string // "newest", "oldest", "popular"
    Page       int
    Limit      int
}

func (q GetCommentTreeQuery) QueryType() string { return "GetCommentTree" }

// GetCommentRepliesQuery - Get direct replies to a comment
type GetCommentRepliesQuery struct {
    TenantID  string
    CommentID string
    Page      int
    Limit     int
}

func (q GetCommentRepliesQuery) QueryType() string { return "GetCommentReplies" }

// SearchCommentsQuery - Full-text search
type SearchCommentsQuery struct {
    TenantID   string
    SearchTerm string
    EntityType string
    Page       int
    Limit      int
}

func (q SearchCommentsQuery) QueryType() string { return "SearchComments" }
```

### 4.2 Read Model

The read model is denormalized for optimal query performance.

```go
// internal/application/comment/read_model.go

package comment

import "time"

// CommentReadModel - Denormalized view optimized for reads
type CommentReadModel struct {
    // Core Fields
    ID         string    `json:"id"`
    TenantID   string    `json:"-"` // Hidden from API response
    EntityType string    `json:"entity_type"`
    EntityID   string    `json:"entity_id"`
    ParentID   *string   `json:"parent_id,omitempty"`
    
    // Hierarchy
    Depth      int       `json:"depth"`
    Path       string    `json:"-"` // Used for querying, not exposed
    
    // Author (Denormalized - no join needed)
    AuthorID     string  `json:"author_id"`
    AuthorName   string  `json:"author_name"`
    AuthorAvatar string  `json:"author_avatar"`
    AuthorRole   string  `json:"author_role"` // "USER", "MODERATOR", etc.
    
    // Content
    Content       string `json:"content"`
    ContentFormat string `json:"content_format"` // "plain", "markdown"
    
    // Status
    Status   string `json:"status"`
    IsPinned bool   `json:"is_pinned"`
    IsEdited bool   `json:"is_edited"`
    
    // Engagement Metrics (Denormalized)
    LikeCount  int `json:"like_count"`
    ReplyCount int `json:"reply_count"`
    ViewCount  int `json:"view_count"`
    
    // User Context (if authenticated)
    CurrentUserLiked bool `json:"current_user_liked,omitempty"`
    
    // Nested Replies (for tree structure)
    Replies []CommentReadModel `json:"replies,omitempty"`
    
    // Timestamps
    CreatedAt time.Time  `json:"created_at"`
    UpdatedAt time.Time  `json:"updated_at"`
    EditedAt  *time.Time `json:"edited_at,omitempty"`
}

// CommentListResponse - Paginated response
type CommentListResponse struct {
    Data []CommentReadModel `json:"data"`
    Meta PaginationMeta     `json:"meta"`
}

type PaginationMeta struct {
    Page       int `json:"page"`
    Limit      int `json:"limit"`
    Total      int `json:"total"`
    TotalPages int `json:"total_pages"`
}
```

### 4.3 Query Handler

```go
// internal/application/comment/query_handler.go

package comment

import (
    "context"
    "database/sql"
    "encoding/json"
    "fmt"
    "time"
    
    "github.com/go-redis/redis/v8"
    "comment-service/internal/domain/comment"
)

type QueryHandler struct {
    readDB    *sql.DB      // Read replica
    writeDB   *sql.DB      // Fallback to primary if needed
    cache     *redis.Client
    cacheConfig CacheConfig
}

type CacheConfig struct {
    CommentTTL     time.Duration
    TreeTTL        time.Duration
    SearchTTL      time.Duration
    EnableCaching  bool
}

func NewQueryHandler(
    readDB *sql.DB,
    writeDB *sql.DB,
    cache *redis.Client,
    config CacheConfig,
) *QueryHandler {
    return &QueryHandler{
        readDB:      readDB,
        writeDB:     writeDB,
        cache:       cache,
        cacheConfig: config,
    }
}

// Handle routes queries to specific handlers
func (h *QueryHandler) Handle(ctx context.Context, query comment.Query) (interface{}, error) {
    switch q := query.(type) {
    case comment.GetCommentByIDQuery:
        return h.handleGetCommentByID(ctx, q)
    case comment.GetCommentTreeQuery:
        return h.handleGetCommentTree(ctx, q)
    case comment.GetCommentRepliesQuery:
        return h.handleGetCommentReplies(ctx, q)
    case comment.SearchCommentsQuery:
        return h.handleSearchComments(ctx, q)
    default:
        return nil, fmt.Errorf("unknown query type: %s", query.QueryType())
    }
}

// handleGetCommentByID - Single comment retrieval
func (h *QueryHandler) handleGetCommentByID(
    ctx context.Context,
    query comment.GetCommentByIDQuery,
) (*CommentReadModel, error) {
    // Step 1: Try cache first (Cache-Aside Pattern)
    if h.cacheConfig.EnableCaching {
        cacheKey := fmt.Sprintf("comment:%s:%s", query.TenantID, query.CommentID)
        
        cached, err := h.cache.Get(ctx, cacheKey).Bytes()
        if err == nil {
            // Cache hit
            var model CommentReadModel
            if err := json.Unmarshal(cached, &model); err == nil {
                return &model, nil
            }
        }
    }
    
    // Step 2: Cache miss - query database
    dbQuery := `
        SELECT 
            c.id, c.tenant_id, c.entity_type, c.entity_id, c.parent_id,
            c.depth, c.path, c.content, c.content_format,
            c.status, c.is_pinned, c.is_edited,
            c.like_count, c.reply_count,
            c.created_at, c.updated_at, c.edited_at,
            u.id as author_id,
            u.display_name as author_name,
            u.avatar_url as author_avatar,
            u.role as author_role
        FROM comments c
        INNER JOIN users u ON c.author_id = u.id
        WHERE c.id = $1 
          AND c.tenant_id = $2 
          AND c.deleted_at IS NULL
    `
    
    var model CommentReadModel
    var editedAt sql.NullTime
    var parentID sql.NullString
    
    err := h.readDB.QueryRowContext(ctx, dbQuery, query.CommentID, query.TenantID).Scan(
        &model.ID, &model.TenantID, &model.EntityType, &model.EntityID, &parentID,
        &model.Depth, &model.Path, &model.Content, &model.ContentFormat,
        &model.Status, &model.IsPinned, &model.IsEdited,
        &model.LikeCount, &model.ReplyCount,
        &model.CreatedAt, &model.UpdatedAt, &editedAt,
        &model.AuthorID, &model.AuthorName, &model.AuthorAvatar, &model.AuthorRole,
    )
    
    if err == sql.ErrNoRows {
        return nil, ErrCommentNotFound
    }
    if err != nil {
        return nil, fmt.Errorf("database query failed: %w", err)
    }
    
    if parentID.Valid {
        model.ParentID = &parentID.String
    }
    if editedAt.Valid {
        model.EditedAt = &editedAt.Time
    }
    
    // Step 3: Update cache
    if h.cacheConfig.EnableCaching {
        cacheKey := fmt.Sprintf("comment:%s:%s", query.TenantID, query.CommentID)
        modelJSON, _ := json.Marshal(model)
        h.cache.Set(ctx, cacheKey, modelJSON, h.cacheConfig.CommentTTL)
    }
    
    return &model, nil
}

// handleGetCommentTree - Hierarchical comment retrieval
func (h *QueryHandler) handleGetCommentTree(
    ctx context.Context,
    query comment.GetCommentTreeQuery,
) (*CommentListResponse, error) {
    // Step 1: Check cache
    if h.cacheConfig.EnableCaching {
        cacheKey := fmt.Sprintf("comment_tree:%s:%s:%s:%d:%d",
            query.TenantID, query.EntityType, query.EntityID,
            query.Page, query.Limit,
        )
        
        cached, err := h.cache.Get(ctx, cacheKey).Bytes()
        if err == nil {
            var response CommentListResponse
            if err := json.Unmarshal(cached, &response); err == nil {
                return &response, nil
            }
        }
    }
    
    // Step 2: Build optimized query
    offset := (query.Page - 1) * query.Limit
    
    // Determine sort order
    var orderBy string
    switch query.SortBy {
    case "popular":
        orderBy = "c.like_count DESC, c.created_at DESC"
    case "oldest":
        orderBy = "c.created_at ASC"
    default: // "newest"
        orderBy = "c.created_at DESC"
    }
    
    // Single query with JOIN - no N+1 problem
    dbQuery := fmt.Sprintf(`
        WITH RECURSIVE comment_tree AS (
            -- Root comments
            SELECT 
                c.id, c.tenant_id, c.entity_type, c.entity_id, c.parent_id,
                c.depth, c.path, c.content, c.content_format,
                c.status, c.is_pinned, c.is_edited,
                c.like_count, c.reply_count,
                c.created_at, c.updated_at, c.edited_at,
                u.id as author_id,
                u.display_name as author_name,
                u.avatar_url as author_avatar,
                u.role as author_role,
                ARRAY[c.id] as id_path
            FROM comments c
            INNER JOIN users u ON c.author_id = u.id
            WHERE c.tenant_id = $1
              AND c.entity_type = $2
              AND c.entity_id = $3
              AND c.parent_id IS NULL
              AND c.deleted_at IS NULL
            
            UNION ALL
            
            -- Recursive: get all descendants
            SELECT 
                c.id, c.tenant_id, c.entity_type, c.entity_id, c.parent_id,
                c.depth, c.path, c.content, c.content_format,
                c.status, c.is_pinned, c.is_edited,
                c.like_count, c.reply_count,
                c.created_at, c.updated_at, c.edited_at,
                u.id as author_id,
                u.display_name as author_name,
                u.avatar_url as author_avatar,
                u.role as author_role,
                ct.id_path || c.id
            FROM comments c
            INNER JOIN users u ON c.author_id = u.id
            INNER JOIN comment_tree ct ON c.parent_id = ct.id
            WHERE c.deleted_at IS NULL
        )
        SELECT * FROM comment_tree
        ORDER BY %s
        LIMIT $4 OFFSET $5
    `, orderBy)
    
    rows, err := h.readDB.QueryContext(ctx, dbQuery,
        query.TenantID, query.EntityType, query.EntityID,
        query.Limit, offset,
    )
    if err != nil {
        return nil, err
    }
    defer rows.Close()
    
    // Step 3: Parse results
    comments := []CommentReadModel{}
    for rows.Next() {
        var c CommentReadModel
        var editedAt sql.NullTime
        var parentID sql.NullString
        var idPath []string
        
        err := rows.Scan(
            &c.ID, &c.TenantID, &c.EntityType, &c.EntityID, &parentID,
            &c.Depth, &c.Path, &c.Content, &c.ContentFormat,
            &c.Status, &c.IsPinned, &c.IsEdited,
            &c.LikeCount, &c.ReplyCount,
            &c.CreatedAt, &c.UpdatedAt, &editedAt,
            &c.AuthorID, &c.AuthorName, &c.AuthorAvatar, &c.AuthorRole,
            &idPath,
        )
        if err != nil {
            return nil, err
        }
        
        if parentID.Valid {
            c.ParentID = &parentID.String
        }
        if editedAt.Valid {
            c.EditedAt = &editedAt.Time
        }
        
        comments = append(comments, c)
    }
    
    // Step 4: Get total count for pagination
    var total int
    countQuery := `
        SELECT COUNT(*)
        FROM comments
        WHERE tenant_id = $1
          AND entity_type = $2
          AND entity_id = $3
          AND deleted_at IS NULL
    `
    h.readDB.QueryRowContext(ctx, countQuery, 
        query.TenantID, query.EntityType, query.EntityID,
    ).Scan(&total)
    
    // Step 5: Build tree structure
    tree := buildTree(comments)
    
    response := &CommentListResponse{
        Data: tree,
        Meta: PaginationMeta{
            Page:       query.Page,
            Limit:      query.Limit,
            Total:      total,
            TotalPages: (total + query.Limit - 1) / query.Limit,
        },
    }
    
    // Step 6: Cache result
    if h.cacheConfig.EnableCaching {
        cacheKey := fmt.Sprintf("comment_tree:%s:%s:%s:%d:%d",
            query.TenantID, query.EntityType, query.EntityID,
            query.Page, query.Limit,
        )
        responseJSON, _ := json.Marshal(response)
        h.cache.Set(ctx, cacheKey, responseJSON, h.cacheConfig.TreeTTL)
    }
    
    return response, nil
}

// buildTree converts flat list to hierarchical structure
func buildTree(comments []CommentReadModel) []CommentReadModel {
    // Create a map for quick lookups
    commentMap := make(map[string]*CommentReadModel)
    for i := range comments {
        commentMap[comments[i].ID] = &comments[i]
    }
    
    // Build tree
    var roots []CommentReadModel
    for i := range comments {
        if comments[i].ParentID == nil {
            roots = append(roots, comments[i])
        } else {
            parent, exists := commentMap[*comments[i].ParentID]
            if exists {
                parent.Replies = append(parent.Replies, comments[i])
            }
        }
    }
    
    return roots
}

// handleSearchComments - Full-text search with PostgreSQL
func (h *QueryHandler) handleSearchComments(
    ctx context.Context,
    query comment.SearchCommentsQuery,
) (*CommentListResponse, error) {
    offset := (query.Page - 1) * query.Limit
    
    // Use PostgreSQL's full-text search
    dbQuery := `
        SELECT 
            c.id, c.tenant_id, c.entity_type, c.entity_id, c.parent_id,
            c.depth, c.path, c.content, c.content_format,
            c.status, c.is_pinned, c.is_edited,
            c.like_count, c.reply_count,
            c.created_at, c.updated_at, c.edited_at,
            u.id as author_id,
            u.display_name as author_name,
            u.avatar_url as author_avatar,
            u.role as author_role,
            ts_rank(c.search_vector, plainto_tsquery('english', $2)) as rank
        FROM comments c
        INNER JOIN users u ON c.author_id = u.id
        WHERE c.tenant_id = $1
          AND c.entity_type = $3
          AND c.deleted_at IS NULL
          AND c.search_vector @@ plainto_tsquery('english', $2)
        ORDER BY rank DESC, c.created_at DESC
        LIMIT $4 OFFSET $5
    `
    
    rows, err := h.readDB.QueryContext(ctx, dbQuery,
        query.TenantID, query.SearchTerm, query.EntityType,
        query.Limit, offset,
    )
    if err != nil {
        return nil, err
    }
    defer rows.Close()
    
    comments := []CommentReadModel{}
    for rows.Next() {
        var c CommentReadModel
        var editedAt sql.NullTime
        var parentID sql.NullString
        var rank float64
        
        err := rows.Scan(
            &c.ID, &c.TenantID, &c.EntityType, &c.EntityID, &parentID,
            &c.Depth, &c.Path, &c.Content, &c.ContentFormat,
            &c.Status, &c.IsPinned, &c.IsEdited,
            &c.LikeCount, &c.ReplyCount,
            &c.CreatedAt, &c.UpdatedAt, &editedAt,
            &c.AuthorID, &c.AuthorName, &c.AuthorAvatar, &c.AuthorRole,
            &rank,
        )
        if err != nil {
            return nil, err
        }
        
        if parentID.Valid {
            c.ParentID = &parentID.String
        }
        if editedAt.Valid {
            c.EditedAt = &editedAt.Time
        }
        
        comments = append(comments, c)
    }
    
    // Get total count
    var total int
    countQuery := `
        SELECT COUNT(*)
        FROM comments
        WHERE tenant_id = $1
          AND entity_type = $2
          AND deleted_at IS NULL
          AND search_vector @@ plainto_tsquery('english', $3)
    `
    h.readDB.QueryRowContext(ctx, countQuery,
        query.TenantID, query.EntityType, query.SearchTerm,
    ).Scan(&total)
    
    return &CommentListResponse{
        Data: comments,
        Meta: PaginationMeta{
            Page:       query.Page,
            Limit:      query.Limit,
            Total:      total,
            TotalPages: (total + query.Limit - 1) / query.Limit,
        },
    }, nil
}
```

---

## Summary

This CQRS implementation provides:

1. **Clear Separation**: Commands (write) and Queries (read) are completely separate
2. **Optimized Reads**: Denormalized read models with aggressive caching
3. **Scalability**: Read and write databases can scale independently
4. **Event-Driven**: Domain events enable async processing
5. **Performance**: Single-query tree retrieval, GIN indexes for search

**Next**: Redis Patterns Deep Dive