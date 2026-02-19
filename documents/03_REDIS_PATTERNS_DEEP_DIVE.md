# Redis Patterns Deep Dive
## Advanced Caching, Rate Limiting, and Distributed Systems Patterns

---

## Table of Contents
1. [Redis Cluster Architecture](#redis-cluster)
2. [Caching Patterns](#caching-patterns)
3. [Rate Limiting Patterns](#rate-limiting)
4. [Distributed Locking](#distributed-locking)
5. [Pub/Sub for Real-time Features](#pubsub)
6. [Session Management](#session-management)
7. [Leaderboards and Ranking](#leaderboards)
8. [Cache Invalidation Strategies](#cache-invalidation)

---

## 1. REDIS CLUSTER ARCHITECTURE

### 1.1 Cluster Setup

Redis Cluster provides:
- **Automatic Sharding**: Data distributed across nodes
- **High Availability**: Automatic failover
- **Horizontal Scaling**: Add nodes dynamically

```yaml
# docker-compose.yml - Redis Cluster Setup

version: '3.9'

services:
  redis-node-1:
    image: redis:7-alpine
    command: redis-server /etc/redis/redis.conf
    volumes:
      - ./redis/node-1.conf:/etc/redis/redis.conf
      - redis-node-1-data:/data
    ports:
      - "7000:7000"
      - "17000:17000"
    networks:
      - redis-cluster

  redis-node-2:
    image: redis:7-alpine
    command: redis-server /etc/redis/redis.conf
    volumes:
      - ./redis/node-2.conf:/etc/redis/redis.conf
      - redis-node-2-data:/data
    ports:
      - "7001:7001"
      - "17001:17001"
    networks:
      - redis-cluster

  redis-node-3:
    image: redis:7-alpine
    command: redis-server /etc/redis/redis.conf
    volumes:
      - ./redis/node-3.conf:/etc/redis/redis.conf
      - redis-node-3-data:/data
    ports:
      - "7002:7002"
      - "17002:17002"
    networks:
      - redis-cluster

  # Replica nodes
  redis-node-4:
    image: redis:7-alpine
    command: redis-server /etc/redis/redis.conf
    volumes:
      - ./redis/node-4.conf:/etc/redis/redis.conf
      - redis-node-4-data:/data
    ports:
      - "7003:7003"
      - "17003:17003"
    networks:
      - redis-cluster

  redis-node-5:
    image: redis:7-alpine
    command: redis-server /etc/redis/redis.conf
    volumes:
      - ./redis/node-5.conf:/etc/redis/redis.conf
      - redis-node-5-data:/data
    ports:
      - "7004:7004"
      - "17004:17004"
    networks:
      - redis-cluster

  redis-node-6:
    image: redis:7-alpine
    command: redis-server /etc/redis/redis.conf
    volumes:
      - ./redis/node-6.conf:/etc/redis/redis.conf
      - redis-node-6-data:/data
    ports:
      - "7005:7005"
      - "17005:17005"
    networks:
      - redis-cluster

  # Cluster creator
  redis-cluster-creator:
    image: redis:7-alpine
    command: >
      sh -c "
        sleep 10 &&
        redis-cli --cluster create
          redis-node-1:7000
          redis-node-2:7001
          redis-node-3:7002
          redis-node-4:7003
          redis-node-5:7004
          redis-node-6:7005
          --cluster-replicas 1
          --cluster-yes
      "
    networks:
      - redis-cluster
    depends_on:
      - redis-node-1
      - redis-node-2
      - redis-node-3
      - redis-node-4
      - redis-node-5
      - redis-node-6

networks:
  redis-cluster:
    driver: bridge

volumes:
  redis-node-1-data:
  redis-node-2-data:
  redis-node-3-data:
  redis-node-4-data:
  redis-node-5-data:
  redis-node-6-data:
```

### 1.2 Node Configuration

```conf
# redis/node-1.conf

# Cluster Configuration
port 7000
cluster-enabled yes
cluster-config-file nodes-7000.conf
cluster-node-timeout 5000

# Persistence
appendonly yes
appendfilename "appendonly-7000.aof"
dir /data

# Memory Management
maxmemory 512mb
maxmemory-policy allkeys-lru

# Security
requirepass your_redis_password
masterauth your_redis_password

# Performance
tcp-backlog 511
timeout 0
tcp-keepalive 300

# Logging
loglevel notice
logfile ""
```

### 1.3 Go Client Setup

```go
// internal/infrastructure/redis/client.go

package redis

import (
    "context"
    "crypto/tls"
    "time"
    
    "github.com/go-redis/redis/v8"
)

type ClusterConfig struct {
    Addrs              []string
    Password           string
    PoolSize           int
    MinIdleConns       int
    MaxRetries         int
    DialTimeout        time.Duration
    ReadTimeout        time.Duration
    WriteTimeout       time.Duration
    PoolTimeout        time.Duration
    IdleTimeout        time.Duration
    IdleCheckFrequency time.Duration
    TLSConfig          *tls.Config
}

func NewClusterClient(config ClusterConfig) *redis.ClusterClient {
    client := redis.NewClusterClient(&redis.ClusterOptions{
        Addrs:    config.Addrs,
        Password: config.Password,
        
        // Connection Pool Settings
        PoolSize:     config.PoolSize,           // Default: 10 per node
        MinIdleConns: config.MinIdleConns,       // Default: 0
        PoolTimeout:  config.PoolTimeout,        // Default: ReadTimeout + 1 second
        
        // Timeouts
        DialTimeout:  config.DialTimeout,  // Default: 5 seconds
        ReadTimeout:  config.ReadTimeout,  // Default: 3 seconds
        WriteTimeout: config.WriteTimeout, // Default: ReadTimeout
        
        // Connection Management
        IdleTimeout:        config.IdleTimeout,        // Default: 5 minutes
        IdleCheckFrequency: config.IdleCheckFrequency, // Default: 1 minute
        
        // Retry Settings
        MaxRetries:      config.MaxRetries, // Default: 3
        MinRetryBackoff: 8 * time.Millisecond,
        MaxRetryBackoff: 512 * time.Millisecond,
        
        // TLS
        TLSConfig: config.TLSConfig,
        
        // Route Commands
        RouteByLatency: true,  // Use node with lowest latency
        RouteRandomly:  false, // Don't route randomly
    })
    
    return client
}

// Production Configuration
func NewProductionClusterClient() *redis.ClusterClient {
    return NewClusterClient(ClusterConfig{
        Addrs: []string{
            "redis-node-1:7000",
            "redis-node-2:7001",
            "redis-node-3:7002",
            "redis-node-4:7003",
            "redis-node-5:7004",
            "redis-node-6:7005",
        },
        Password:           "your_redis_password",
        PoolSize:           100,  // 100 connections per node
        MinIdleConns:       10,   // Keep 10 idle connections ready
        MaxRetries:         3,
        DialTimeout:        5 * time.Second,
        ReadTimeout:        3 * time.Second,
        WriteTimeout:       3 * time.Second,
        PoolTimeout:        4 * time.Second,
        IdleTimeout:        5 * time.Minute,
        IdleCheckFrequency: 1 * time.Minute,
    })
}

// Health Check
func (c *redis.ClusterClient) HealthCheck(ctx context.Context) error {
    // Check each node
    err := c.ForEachMaster(ctx, func(ctx context.Context, client *redis.Client) error {
        return client.Ping(ctx).Err()
    })
    
    if err != nil {
        return fmt.Errorf("cluster health check failed: %w", err)
    }
    
    return nil
}

// Get Cluster Info
func (c *redis.ClusterClient) GetClusterInfo(ctx context.Context) (map[string]interface{}, error) {
    info := make(map[string]interface{})
    
    // Get cluster nodes
    nodes, err := c.ClusterNodes(ctx).Result()
    if err != nil {
        return nil, err
    }
    info["nodes"] = nodes
    
    // Get cluster info
    clusterInfo, err := c.ClusterInfo(ctx).Result()
    if err != nil {
        return nil, err
    }
    info["cluster_info"] = clusterInfo
    
    // Get cluster slots
    slots, err := c.ClusterSlots(ctx).Result()
    if err != nil {
        return nil, err
    }
    info["slots"] = slots
    
    return info, nil
}
```

---

## 2. CACHING PATTERNS

### 2.1 Cache-Aside Pattern (Lazy Loading)

**Most common pattern**: Application reads from cache, falls back to database on miss.

```go
// internal/infrastructure/cache/cache_aside.go

package cache

import (
    "context"
    "encoding/json"
    "fmt"
    "time"
    
    "github.com/go-redis/redis/v8"
)

type CacheAsideService struct {
    redis *redis.ClusterClient
    ttl   time.Duration
}

func NewCacheAsideService(redis *redis.ClusterClient, ttl time.Duration) *CacheAsideService {
    return &CacheAsideService{
        redis: redis,
        ttl:   ttl,
    }
}

// Get retrieves data from cache or executes fallback function
func (s *CacheAsideService) Get(
    ctx context.Context,
    key string,
    dest interface{},
    fallback func(ctx context.Context) (interface{}, error),
) error {
    // Step 1: Try to get from cache
    cached, err := s.redis.Get(ctx, key).Bytes()
    
    if err == nil {
        // Cache hit - unmarshal and return
        return json.Unmarshal(cached, dest)
    }
    
    if err != redis.Nil {
        // Redis error (not a miss) - log and continue to fallback
        log.Warn("Redis error, falling back to database", "error", err)
    }
    
    // Step 2: Cache miss - execute fallback
    data, err := fallback(ctx)
    if err != nil {
        return fmt.Errorf("fallback failed: %w", err)
    }
    
    // Step 3: Store in cache (fire and forget - don't block on cache write)
    go func() {
        cacheCtx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
        defer cancel()
        
        dataJSON, err := json.Marshal(data)
        if err != nil {
            log.Error("failed to marshal data for cache", "error", err)
            return
        }
        
        err = s.redis.Set(cacheCtx, key, dataJSON, s.ttl).Err()
        if err != nil {
            log.Error("failed to set cache", "error", err)
        }
    }()
    
    // Step 4: Return data immediately (don't wait for cache write)
    // Use reflection to copy data to dest
    destJSON, _ := json.Marshal(data)
    return json.Unmarshal(destJSON, dest)
}

// Example Usage: Get Comment with Cache-Aside
func (r *CommentRepository) GetCommentByID(
    ctx context.Context,
    tenantID, commentID string,
) (*Comment, error) {
    cacheKey := fmt.Sprintf("comment:%s:%s", tenantID, commentID)
    
    var comment Comment
    
    err := r.cache.Get(
        ctx,
        cacheKey,
        &comment,
        func(ctx context.Context) (interface{}, error) {
            // Fallback: Query database
            return r.getCommentFromDB(ctx, tenantID, commentID)
        },
    )
    
    return &comment, err
}

func (r *CommentRepository) getCommentFromDB(
    ctx context.Context,
    tenantID, commentID string,
) (*Comment, error) {
    query := `
        SELECT id, tenant_id, content, author_id, created_at
        FROM comments
        WHERE id = $1 AND tenant_id = $2 AND deleted_at IS NULL
    `
    
    var comment Comment
    err := r.db.QueryRowContext(ctx, query, commentID, tenantID).Scan(
        &comment.ID,
        &comment.TenantID,
        &comment.Content,
        &comment.AuthorID,
        &comment.CreatedAt,
    )
    
    return &comment, err
}
```

### 2.2 Write-Through Cache

**Pattern**: Write to cache and database simultaneously.

```go
// Write-Through Pattern
func (r *CommentRepository) CreateComment(
    ctx context.Context,
    comment *Comment,
) error {
    // Step 1: Write to database first (source of truth)
    err := r.insertCommentToDB(ctx, comment)
    if err != nil {
        return err
    }
    
    // Step 2: Write to cache immediately
    cacheKey := fmt.Sprintf("comment:%s:%s", comment.TenantID, comment.ID)
    commentJSON, _ := json.Marshal(comment)
    
    // Use pipeline for atomic operations
    pipe := r.redis.Pipeline()
    pipe.Set(ctx, cacheKey, commentJSON, 1*time.Hour)
    
    // Also update comment tree cache
    treeKey := fmt.Sprintf("comment_tree:%s:%s", comment.TenantID, comment.EntityID)
    pipe.Del(ctx, treeKey) // Invalidate tree cache
    
    _, err = pipe.Exec(ctx)
    if err != nil {
        // Log but don't fail - cache is not critical
        log.Error("failed to update cache", "error", err)
    }
    
    return nil
}
```

### 2.3 Write-Behind (Write-Back) Cache

**Pattern**: Write to cache first, async write to database.

```go
// Write-Behind Pattern (Advanced - for high write throughput)
type WriteBehindCache struct {
    redis      *redis.ClusterClient
    db         *sql.DB
    writeQueue chan WriteOperation
    batchSize  int
    flushInterval time.Duration
}

type WriteOperation struct {
    Key   string
    Value interface{}
}

func NewWriteBehindCache(redis *redis.ClusterClient, db *sql.DB) *WriteBehindCache {
    wbc := &WriteBehindCache{
        redis:         redis,
        db:            db,
        writeQueue:    make(chan WriteOperation, 10000),
        batchSize:     100,
        flushInterval: 1 * time.Second,
    }
    
    // Start background worker
    go wbc.flushWorker()
    
    return wbc
}

func (wbc *WriteBehindCache) Write(ctx context.Context, key string, value interface{}) error {
    // Write to cache immediately
    valueJSON, err := json.Marshal(value)
    if err != nil {
        return err
    }
    
    err = wbc.redis.Set(ctx, key, valueJSON, 0).Err() // No expiry
    if err != nil {
        return err
    }
    
    // Queue for async DB write
    select {
    case wbc.writeQueue <- WriteOperation{Key: key, Value: value}:
        return nil
    default:
        return fmt.Errorf("write queue full")
    }
}

func (wbc *WriteBehindCache) flushWorker() {
    ticker := time.NewTicker(wbc.flushInterval)
    defer ticker.Stop()
    
    batch := make([]WriteOperation, 0, wbc.batchSize)
    
    for {
        select {
        case op := <-wbc.writeQueue:
            batch = append(batch, op)
            
            if len(batch) >= wbc.batchSize {
                wbc.flushBatch(batch)
                batch = batch[:0]
            }
            
        case <-ticker.C:
            if len(batch) > 0 {
                wbc.flushBatch(batch)
                batch = batch[:0]
            }
        }
    }
}

func (wbc *WriteBehindCache) flushBatch(batch []WriteOperation) {
    ctx := context.Background()
    tx, err := wbc.db.BeginTx(ctx, nil)
    if err != nil {
        log.Error("failed to begin transaction", "error", err)
        return
    }
    defer tx.Rollback()
    
    // Batch insert
    for _, op := range batch {
        // Insert into database
        // ... implementation
    }
    
    if err := tx.Commit(); err != nil {
        log.Error("failed to commit batch", "error", err)
    }
}
```

### 2.4 Multi-Level Caching

**Pattern**: L1 (in-memory) + L2 (Redis) cache layers.

```go
// Multi-Level Cache
type MultiLevelCache struct {
    l1    *sync.Map              // In-memory cache
    l2    *redis.ClusterClient   // Redis cache
    l1TTL time.Duration
    l2TTL time.Duration
}

func NewMultiLevelCache(redis *redis.ClusterClient) *MultiLevelCache {
    mlc := &MultiLevelCache{
        l1:    &sync.Map{},
        l2:    redis,
        l1TTL: 5 * time.Minute,
        l2TTL: 1 * time.Hour,
    }
    
    // Periodic L1 cache cleanup
    go mlc.cleanupL1()
    
    return mlc
}

type cacheEntry struct {
    Data      []byte
    ExpiresAt time.Time
}

func (mlc *MultiLevelCache) Get(
    ctx context.Context,
    key string,
    dest interface{},
) error {
    // Try L1 cache first
    if entry, ok := mlc.l1.Load(key); ok {
        ce := entry.(*cacheEntry)
        if time.Now().Before(ce.ExpiresAt) {
            return json.Unmarshal(ce.Data, dest)
        }
        // Expired - remove from L1
        mlc.l1.Delete(key)
    }
    
    // Try L2 cache (Redis)
    data, err := mlc.l2.Get(ctx, key).Bytes()
    if err == nil {
        // L2 hit - store in L1
        mlc.l1.Store(key, &cacheEntry{
            Data:      data,
            ExpiresAt: time.Now().Add(mlc.l1TTL),
        })
        return json.Unmarshal(data, dest)
    }
    
    return redis.Nil
}

func (mlc *MultiLevelCache) Set(
    ctx context.Context,
    key string,
    value interface{},
) error {
    dataJSON, err := json.Marshal(value)
    if err != nil {
        return err
    }
    
    // Set in L1
    mlc.l1.Store(key, &cacheEntry{
        Data:      dataJSON,
        ExpiresAt: time.Now().Add(mlc.l1TTL),
    })
    
    // Set in L2
    return mlc.l2.Set(ctx, key, dataJSON, mlc.l2TTL).Err()
}

func (mlc *MultiLevelCache) cleanupL1() {
    ticker := time.NewTicker(1 * time.Minute)
    defer ticker.Stop()
    
    for range ticker.C {
        now := time.Now()
        mlc.l1.Range(func(key, value interface{}) bool {
            entry := value.(*cacheEntry)
            if now.After(entry.ExpiresAt) {
                mlc.l1.Delete(key)
            }
            return true
        })
    }
}
```

---

## 3. RATE LIMITING PATTERNS

### 3.1 Token Bucket Algorithm

**Best for**: Handling bursts while maintaining average rate.

```go
// internal/infrastructure/ratelimit/token_bucket.go

package ratelimit

import (
    "context"
    "fmt"
    "time"
    
    "github.com/go-redis/redis/v8"
)

type TokenBucketLimiter struct {
    redis    *redis.ClusterClient
    capacity int64         // Maximum tokens
    refillRate int64       // Tokens added per second
}

func NewTokenBucketLimiter(redis *redis.ClusterClient, capacity, refillRate int64) *TokenBucketLimiter {
    return &TokenBucketLimiter{
        redis:      redis,
        capacity:   capacity,
        refillRate: refillRate,
    }
}

// AllowRequest checks if request is allowed under rate limit
func (tbl *TokenBucketLimiter) AllowRequest(ctx context.Context, key string) (bool, *RateLimitInfo, error) {
    now := time.Now().Unix()
    
    // Lua script for atomic token bucket operations
    script := `
        local key = KEYS[1]
        local capacity = tonumber(ARGV[1])
        local refill_rate = tonumber(ARGV[2])
        local now = tonumber(ARGV[3])
        local requested = tonumber(ARGV[4])
        
        -- Get current bucket state
        local bucket = redis.call('HMGET', key, 'tokens', 'last_refill')
        local tokens = tonumber(bucket[1]) or capacity
        local last_refill = tonumber(bucket[2]) or now
        
        -- Calculate tokens to add based on time elapsed
        local time_elapsed = now - last_refill
        local tokens_to_add = time_elapsed * refill_rate
        
        -- Refill bucket (capped at capacity)
        tokens = math.min(capacity, tokens + tokens_to_add)
        
        -- Check if request can be allowed
        local allowed = 0
        local remaining = tokens
        
        if tokens >= requested then
            tokens = tokens - requested
            allowed = 1
            remaining = tokens
        end
        
        -- Update bucket state
        redis.call('HMSET', key, 
            'tokens', tokens,
            'last_refill', now
        )
        redis.call('EXPIRE', key, 120) -- 2 minute TTL
        
        return {allowed, math.floor(remaining), capacity}
    `
    
    result, err := tbl.redis.Eval(ctx, script,
        []string{fmt.Sprintf("rate_limit:token_bucket:%s", key)},
        tbl.capacity,
        tbl.refillRate,
        now,
        1, // Request 1 token
    ).Result()
    
    if err != nil {
        return false, nil, err
    }
    
    values := result.([]interface{})
    allowed := values[0].(int64) == 1
    remaining := values[1].(int64)
    limit := values[2].(int64)
    
    info := &RateLimitInfo{
        Limit:     limit,
        Remaining: remaining,
        RetryAfter: 0,
    }
    
    if !allowed {
        // Calculate retry after
        info.RetryAfter = int64(1.0 / float64(tbl.refillRate))
    }
    
    return allowed, info, nil
}

type RateLimitInfo struct {
    Limit      int64
    Remaining  int64
    RetryAfter int64 // Seconds to wait
}
```

### 3.2 Fixed Window Counter

**Simplest pattern**: Count requests per time window.

```go
// Fixed Window Counter
func (fwc *FixedWindowCounter) AllowRequest(
    ctx context.Context,
    key string,
    limit int64,
    window time.Duration,
) (bool, error) {
    // Generate window key based on current time
    windowStart := time.Now().Unix() / int64(window.Seconds())
    windowKey := fmt.Sprintf("rate_limit:fixed:%s:%d", key, windowStart)
    
    // Atomic increment
    pipe := fwc.redis.Pipeline()
    incr := pipe.Incr(ctx, windowKey)
    pipe.Expire(ctx, windowKey, window)
    
    _, err := pipe.Exec(ctx)
    if err != nil {
        return false, err
    }
    
    count := incr.Val()
    return count <= limit, nil
}
```

### 3.3 Sliding Window Log

**Most accurate**: Tracks individual request timestamps.

```go
// Sliding Window Log
func (swl *SlidingWindowLog) AllowRequest(
    ctx context.Context,
    key string,
    limit int64,
    window time.Duration,
) (bool, error) {
    now := time.Now().Unix()
    windowStart := now - int64(window.Seconds())
    
    logKey := fmt.Sprintf("rate_limit:sliding:%s", key)
    
    // Lua script for atomic operations
    script := `
        local key = KEYS[1]
        local window_start = tonumber(ARGV[1])
        local now = tonumber(ARGV[2])
        local limit = tonumber(ARGV[3])
        local window_seconds = tonumber(ARGV[4])
        
        -- Remove old entries
        redis.call('ZREMRANGEBYSCORE', key, '-inf', window_start)
        
        -- Count current requests
        local count = redis.call('ZCARD', key)
        
        if count < limit then
            -- Add new request
            redis.call('ZADD', key, now, now)
            redis.call('EXPIRE', key, window_seconds)
            return {1, limit - count - 1}
        else
            return {0, 0}
        end
    `
    
    result, err := swl.redis.Eval(ctx, script,
        []string{logKey},
        windowStart,
        now,
        limit,
        int64(window.Seconds()),
    ).Result()
    
    if err != nil {
        return false, err
    }
    
    values := result.([]interface{})
    allowed := values[0].(int64) == 1
    
    return allowed, nil
}
```

### 3.4 Sliding Window Counter (Hybrid)

**Best balance**: Combines fixed window efficiency with sliding window accuracy.

```go
// Sliding Window Counter
func (swc *SlidingWindowCounter) AllowRequest(
    ctx context.Context,
    key string,
    limit int64,
    window time.Duration,
) (bool, error) {
    now := time.Now()
    currentWindow := now.Unix() / int64(window.Seconds())
    previousWindow := currentWindow - 1
    
    currentKey := fmt.Sprintf("rate_limit:sliding_counter:%s:%d", key, currentWindow)
    previousKey := fmt.Sprintf("rate_limit:sliding_counter:%s:%d", key, previousWindow)
    
    // Get current and previous window counts
    pipe := swc.redis.Pipeline()
    currentCount := pipe.Get(ctx, currentKey)
    previousCount := pipe.Get(ctx, previousKey)
    _, _ = pipe.Exec(ctx)
    
    current, _ := currentCount.Int64()
    previous, _ := previousCount.Int64()
    
    // Calculate weighted count
    windowProgress := float64(now.Unix()%int64(window.Seconds())) / float64(window.Seconds())
    estimatedCount := int64(float64(previous)*(1-windowProgress) + float64(current))
    
    if estimatedCount >= limit {
        return false, nil
    }
    
    // Increment current window
    pipe2 := swc.redis.Pipeline()
    pipe2.Incr(ctx, currentKey)
    pipe2.Expire(ctx, currentKey, window*2) // Keep for 2 windows
    _, err := pipe2.Exec(ctx)
    
    return err == nil, err
}
```

### 3.5 Distributed Rate Limiting with Tenant Isolation

```go
// internal/application/ratelimit/service.go

package ratelimit

import (
    "context"
    "fmt"
    
    "github.com/go-redis/redis/v8"
)

type Service struct {
    redis        *redis.ClusterClient
    tokenBucket  *TokenBucketLimiter
    slidingWindow *SlidingWindowCounter
}

func NewService(redis *redis.ClusterClient) *Service {
    return &Service{
        redis:         redis,
        tokenBucket:   NewTokenBucketLimiter(redis, 100, 100), // 100 tokens, refill 100/sec
        slidingWindow: NewSlidingWindowCounter(redis),
    }
}

// CheckTenantRateLimit checks multiple rate limits for a tenant
func (s *Service) CheckTenantRateLimit(
    ctx context.Context,
    tenantID string,
    limits map[string]RateLimit,
) (bool, *RateLimitInfo, error) {
    // Check each configured limit
    for window, limit := range limits {
        var allowed bool
        var info *RateLimitInfo
        var err error
        
        key := fmt.Sprintf("tenant:%s:%s", tenantID, window)
        
        switch window {
        case "per_second":
            allowed, info, err = s.tokenBucket.AllowRequest(ctx, key)
        case "per_minute":
            allowed, err = s.slidingWindow.AllowRequest(ctx, key, limit.Limit, limit.Window)
            info = &RateLimitInfo{Limit: limit.Limit}
        case "per_hour":
            allowed, err = s.slidingWindow.AllowRequest(ctx, key, limit.Limit, limit.Window)
            info = &RateLimitInfo{Limit: limit.Limit}
        case "per_day":
            allowed, err = s.slidingWindow.AllowRequest(ctx, key, limit.Limit, limit.Window)
            info = &RateLimitInfo{Limit: limit.Limit}
        }
        
        if err != nil {
            return false, nil, err
        }
        
        if !allowed {
            return false, info, nil
        }
    }
    
    return true, nil, nil
}

type RateLimit struct {
    Limit  int64
    Window time.Duration
}

// Example: Configure rate limits based on tenant plan
func GetTenantRateLimits(plan string) map[string]RateLimit {
    limits := map[string]map[string]RateLimit{
        "FREE": {
            "per_minute": {Limit: 10, Window: 1 * time.Minute},
            "per_hour":   {Limit: 100, Window: 1 * time.Hour},
            "per_day":    {Limit: 1000, Window: 24 * time.Hour},
        },
        "STARTER": {
            "per_minute": {Limit: 100, Window: 1 * time.Minute},
            "per_hour":   {Limit: 5000, Window: 1 * time.Hour},
            "per_day":    {Limit: 50000, Window: 24 * time.Hour},
        },
        "BUSINESS": {
            "per_minute": {Limit: 1000, Window: 1 * time.Minute},
            "per_hour":   {Limit: 50000, Window: 1 * time.Hour},
            "per_day":    {Limit: 500000, Window: 24 * time.Hour},
        },
        "ENTERPRISE": {
            "per_minute": {Limit: 10000, Window: 1 * time.Minute},
            "per_hour":   {Limit: 500000, Window: 1 * time.Hour},
            "per_day":    {Limit: 5000000, Window: 24 * time.Hour},
        },
    }
    
    return limits[plan]
}
```

---

## 4. DISTRIBUTED LOCKING

### 4.1 Redlock Algorithm Implementation

**Industry standard** for distributed locks.

```go
// internal/infrastructure/locks/redlock.go

package locks

import (
    "context"
    "crypto/rand"
    "encoding/hex"
    "fmt"
    "time"
    
    "github.com/go-redis/redis/v8"
)

type RedLock struct {
    clients []*redis.Client
    retries int
    delay   time.Duration
}

func NewRedLock(clients []*redis.Client) *RedLock {
    return &RedLock{
        clients: clients,
        retries: 3,
        delay:   100 * time.Millisecond,
    }
}

type Lock struct {
    Resource string
    Value    string
    Expiry   time.Duration
}

// AcquireLock implements Redlock algorithm
func (rl *RedLock) AcquireLock(
    ctx context.Context,
    resource string,
    ttl time.Duration,
) (*Lock, error) {
    value := generateLockValue()
    
    for i := 0; i < rl.retries; i++ {
        lock := &Lock{
            Resource: resource,
            Value:    value,
            Expiry:   ttl,
        }
        
        if rl.tryAcquire(ctx, lock) {
            return lock, nil
        }
        
        // Wait before retry
        time.Sleep(rl.delay)
    }
    
    return nil, fmt.Errorf("failed to acquire lock after %d retries", rl.retries)
}

func (rl *RedLock) tryAcquire(ctx context.Context, lock *Lock) bool {
    quorum := len(rl.clients)/2 + 1
    acquired := 0
    
    // Try to acquire lock on majority of nodes
    for _, client := range rl.clients {
        ok, err := rl.acquireOnNode(ctx, client, lock)
        if err == nil && ok {
            acquired++
        }
    }
    
    if acquired >= quorum {
        return true
    }
    
    // Failed to acquire quorum - release locks
    rl.ReleaseLock(ctx, lock)
    return false
}

func (rl *RedLock) acquireOnNode(
    ctx context.Context,
    client *redis.Client,
    lock *Lock,
) (bool, error) {
    // Use SET with NX (only if not exists) and PX (expiry in milliseconds)
    result, err := client.SetNX(ctx,
        fmt.Sprintf("lock:%s", lock.Resource),
        lock.Value,
        lock.Expiry,
    ).Result()
    
    return result, err
}

// ReleaseLock releases the lock using Lua script for atomicity
func (rl *RedLock) ReleaseLock(ctx context.Context, lock *Lock) error {
    script := `
        if redis.call("GET", KEYS[1]) == ARGV[1] then
            return redis.call("DEL", KEYS[1])
        else
            return 0
        end
    `
    
    for _, client := range rl.clients {
        client.Eval(ctx, script,
            []string{fmt.Sprintf("lock:%s", lock.Resource)},
            lock.Value,
        )
    }
    
    return nil
}

func generateLockValue() string {
    bytes := make([]byte, 16)
    rand.Read(bytes)
    return hex.EncodeToString(bytes)
}

// ExtendLock extends lock TTL if still owned
func (rl *RedLock) ExtendLock(
    ctx context.Context,
    lock *Lock,
    additionalTTL time.Duration,
) error {
    script := `
        if redis.call("GET", KEYS[1]) == ARGV[1] then
            return redis.call("PEXPIRE", KEYS[1], ARGV[2])
        else
            return 0
        end
    `
    
    for _, client := range rl.clients {
        client.Eval(ctx, script,
            []string{fmt.Sprintf("lock:%s", lock.Resource)},
            lock.Value,
            int64(additionalTTL.Milliseconds()),
        )
    }
    
    return nil
}
```

### 4.2 Practical Lock Usage Example

```go
// Example: Like comment with distributed lock to prevent race conditions

func (s *LikeService) LikeComment(
    ctx context.Context,
    tenantID, commentID, userID string,
) error {
    // Acquire lock
    lockKey := fmt.Sprintf("comment:like:%s:%s", commentID, userID)
    lock, err := s.lockManager.AcquireLock(ctx, lockKey, 5*time.Second)
    if err != nil {
        return fmt.Errorf("failed to acquire lock: %w", err)
    }
    defer s.lockManager.ReleaseLock(ctx, lock)
    
    // Critical section - check and insert like
    exists, err := s.checkLikeExists(ctx, commentID, userID)
    if err != nil {
        return err
    }
    
    if exists {
        return ErrAlreadyLiked
    }
    
    // Insert like and update counter atomically
    return s.insertLike(ctx, tenantID, commentID, userID)
}
```

---

## Summary

This deep dive covered:

1. **Redis Cluster**: Production setup with 6 nodes (3 master + 3 replica)
2. **Caching Patterns**: Cache-aside, write-through, write-behind, multi-level
3. **Rate Limiting**: Token bucket, fixed window, sliding window, sliding window counter
4. **Distributed Locking**: Redlock algorithm for preventing race conditions

**Next**: Complete Go Project Structure with all components integrated