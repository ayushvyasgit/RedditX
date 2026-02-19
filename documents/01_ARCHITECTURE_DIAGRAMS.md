# System Architecture Diagrams
## Enterprise Comments SaaS Platform

---

## 1. HIGH-LEVEL SYSTEM ARCHITECTURE

```mermaid
graph TB
    subgraph "Client Layer"
        WEB[Web Application]
        MOBILE[Mobile App]
        API_CLIENT[Third-party API Clients]
    end

    subgraph "Edge Layer"
        CDN[CDN / CloudFlare]
        WAF[Web Application Firewall]
    end

    subgraph "Load Balancer Layer"
        LB[NGINX Load Balancer<br/>Health Checks<br/>SSL Termination<br/>Rate Limiting]
    end

    subgraph "API Gateway Layer"
        AG[API Gateway<br/>Request Routing<br/>Auth Validation<br/>Request Logging]
    end

    subgraph "Application Layer"
        API1[API Server 1<br/>Go Application<br/>Port: 8081]
        API2[API Server 2<br/>Go Application<br/>Port: 8082]
        API3[API Server N<br/>Go Application<br/>Port: 808N]
    end

    subgraph "Cache Layer"
        REDIS1[Redis Master 1<br/>Port: 6379]
        REDIS2[Redis Master 2<br/>Port: 6380]
        REDIS3[Redis Master 3<br/>Port: 6381]
    end

    subgraph "Database Layer"
        PG_PRIMARY[(PostgreSQL Primary<br/>Write Operations<br/>Port: 5432)]
        PG_REPLICA1[(PostgreSQL Replica 1<br/>Read Operations<br/>Port: 5433)]
        PG_REPLICA2[(PostgreSQL Replica 2<br/>Read Operations<br/>Port: 5434)]
    end

    subgraph "Message Queue Layer"
        MQ[RabbitMQ<br/>Event Bus<br/>Port: 5672]
    end

    subgraph "Worker Layer"
        WORKER1[Worker 1<br/>Notifications]
        WORKER2[Worker 2<br/>Analytics]
        WORKER3[Worker 3<br/>Cleanup Jobs]
    end

    subgraph "Monitoring Layer"
        PROM[Prometheus<br/>Metrics Collection]
        GRAFANA[Grafana<br/>Visualization]
        JAEGER[Jaeger<br/>Distributed Tracing]
    end

    WEB --> CDN
    MOBILE --> CDN
    API_CLIENT --> CDN
    
    CDN --> WAF
    WAF --> LB
    
    LB --> AG
    AG --> API1
    AG --> API2
    AG --> API3
    
    API1 --> REDIS1
    API1 --> REDIS2
    API1 --> REDIS3
    API2 --> REDIS1
    API2 --> REDIS2
    API2 --> REDIS3
    API3 --> REDIS1
    API3 --> REDIS2
    API3 --> REDIS3
    
    API1 --> PG_PRIMARY
    API1 --> PG_REPLICA1
    API2 --> PG_PRIMARY
    API2 --> PG_REPLICA2
    API3 --> PG_PRIMARY
    API3 --> PG_REPLICA1
    
    PG_PRIMARY -.Replication.-> PG_REPLICA1
    PG_PRIMARY -.Replication.-> PG_REPLICA2
    
    API1 --> MQ
    API2 --> MQ
    API3 --> MQ
    
    MQ --> WORKER1
    MQ --> WORKER2
    MQ --> WORKER3
    
    WORKER1 --> PG_PRIMARY
    WORKER2 --> PG_PRIMARY
    WORKER3 --> PG_PRIMARY
    
    API1 -.Metrics.-> PROM
    API2 -.Metrics.-> PROM
    API3 -.Metrics.-> PROM
    PROM --> GRAFANA
    
    API1 -.Traces.-> JAEGER
    API2 -.Traces.-> JAEGER
    API3 -.Traces.-> JAEGER

    style CDN fill:#f9f,stroke:#333,stroke-width:2px
    style LB fill:#bbf,stroke:#333,stroke-width:2px
    style API1 fill:#bfb,stroke:#333,stroke-width:2px
    style API2 fill:#bfb,stroke:#333,stroke-width:2px
    style API3 fill:#bfb,stroke:#333,stroke-width:2px
    style PG_PRIMARY fill:#fbb,stroke:#333,stroke-width:4px
    style REDIS1 fill:#ffb,stroke:#333,stroke-width:2px
```

---

## 2. DETAILED COMPONENT ARCHITECTURE

```mermaid
graph TB
    subgraph "API Server Internal Architecture"
        subgraph "HTTP Layer"
            ROUTER[Gin Router<br/>Route Matching]
            MIDDLEWARE[Middleware Chain]
        end

        subgraph "Middleware Stack"
            MW_LOGGER[Logger Middleware]
            MW_RECOVERY[Recovery Middleware]
            MW_CORS[CORS Middleware]
            MW_AUTH[Auth Middleware<br/>JWT Validation]
            MW_TENANT[Tenant Middleware<br/>Tenant Resolution]
            MW_RATE[Rate Limit Middleware]
            MW_METRICS[Metrics Middleware]
            MW_TRACE[Tracing Middleware]
        end

        subgraph "Handler Layer"
            H_TENANT[Tenant Handler]
            H_USER[User Handler]
            H_COMMENT[Comment Handler]
            H_LIKE[Like Handler]
            H_AUDIT[Audit Handler]
        end

        subgraph "Service Layer - Command Side"
            S_TENANT_CMD[Tenant Command Service]
            S_USER_CMD[User Command Service]
            S_COMMENT_CMD[Comment Command Service]
            S_LIKE_CMD[Like Command Service]
        end

        subgraph "Service Layer - Query Side"
            S_TENANT_QUERY[Tenant Query Service]
            S_USER_QUERY[User Query Service]
            S_COMMENT_QUERY[Comment Query Service]
            S_LIKE_QUERY[Like Query Service]
        end

        subgraph "Repository Layer"
            R_TENANT[Tenant Repository]
            R_USER[User Repository]
            R_COMMENT[Comment Repository]
            R_LIKE[Like Repository]
            R_AUDIT[Audit Repository]
        end

        subgraph "Domain Layer"
            D_TENANT[Tenant Aggregate]
            D_USER[User Aggregate]
            D_COMMENT[Comment Aggregate]
            D_LIKE[Like Aggregate]
        end

        subgraph "Infrastructure Layer"
            I_DB[Database Client<br/>PostgreSQL]
            I_CACHE[Cache Client<br/>Redis]
            I_MQ[Message Queue Client<br/>RabbitMQ]
            I_SEARCH[Search Client<br/>Full-text Search]
        end

        subgraph "Cross-Cutting Concerns"
            CC_AUTH[Auth Service<br/>JWT, OAuth]
            CC_CRYPTO[Crypto Service<br/>Hashing, Encryption]
            CC_VALIDATOR[Validator Service<br/>Input Validation]
            CC_EVENT[Event Bus<br/>Domain Events]
        end
    end

    ROUTER --> MIDDLEWARE
    MIDDLEWARE --> MW_LOGGER
    MW_LOGGER --> MW_RECOVERY
    MW_RECOVERY --> MW_CORS
    MW_CORS --> MW_AUTH
    MW_AUTH --> MW_TENANT
    MW_TENANT --> MW_RATE
    MW_RATE --> MW_METRICS
    MW_METRICS --> MW_TRACE
    MW_TRACE --> H_TENANT
    MW_TRACE --> H_USER
    MW_TRACE --> H_COMMENT
    MW_TRACE --> H_LIKE
    MW_TRACE --> H_AUDIT

    H_COMMENT --> S_COMMENT_CMD
    H_COMMENT --> S_COMMENT_QUERY
    
    S_COMMENT_CMD --> D_COMMENT
    S_COMMENT_CMD --> R_COMMENT
    S_COMMENT_CMD --> CC_EVENT
    
    S_COMMENT_QUERY --> R_COMMENT
    S_COMMENT_QUERY --> I_CACHE
    
    R_COMMENT --> I_DB
    R_COMMENT --> I_CACHE
    
    CC_EVENT --> I_MQ
    
    D_COMMENT --> CC_VALIDATOR

    style ROUTER fill:#e1f5ff,stroke:#333,stroke-width:2px
    style S_COMMENT_CMD fill:#fff4e6,stroke:#333,stroke-width:2px
    style S_COMMENT_QUERY fill:#e8f5e9,stroke:#333,stroke-width:2px
    style I_DB fill:#ffebee,stroke:#333,stroke-width:2px
    style I_CACHE fill:#fff9c4,stroke:#333,stroke-width:2px
```

---

## 3. CQRS ARCHITECTURE PATTERN

```mermaid
graph LR
    subgraph "Client Applications"
        CLIENT[Client Application]
    end

    subgraph "API Gateway"
        GATEWAY[API Gateway<br/>Request Router]
    end

    subgraph "Command Side - WRITE PATH"
        CMD_API[Command API<br/>Write Operations]
        CMD_HANDLER[Command Handler<br/>Business Logic]
        CMD_VALIDATOR[Command Validator]
        DOMAIN_MODEL[Domain Model<br/>Aggregates]
        EVENT_STORE[(Event Store<br/>Audit Trail)]
        WRITE_DB[(Write Database<br/>PostgreSQL Primary)]
    end

    subgraph "Event Bus"
        EVENT_BUS[Event Bus<br/>Domain Events]
    end

    subgraph "Query Side - READ PATH"
        PROJECTOR[Event Projector<br/>Read Model Builder]
        READ_MODEL[(Read Model<br/>Denormalized Views)]
        READ_CACHE[(Read Cache<br/>Redis)]
        QUERY_API[Query API<br/>Read Operations]
        QUERY_HANDLER[Query Handler<br/>Data Retrieval]
    end

    CLIENT -->|Write Request<br/>POST, PUT, DELETE| GATEWAY
    CLIENT -->|Read Request<br/>GET| GATEWAY
    
    GATEWAY -->|Commands| CMD_API
    GATEWAY -->|Queries| QUERY_API
    
    CMD_API --> CMD_VALIDATOR
    CMD_VALIDATOR --> CMD_HANDLER
    CMD_HANDLER --> DOMAIN_MODEL
    DOMAIN_MODEL --> WRITE_DB
    DOMAIN_MODEL --> EVENT_STORE
    DOMAIN_MODEL -->|Publish Events| EVENT_BUS
    
    EVENT_BUS -->|Subscribe to Events| PROJECTOR
    PROJECTOR --> READ_MODEL
    PROJECTOR --> READ_CACHE
    
    QUERY_API --> QUERY_HANDLER
    QUERY_HANDLER --> READ_CACHE
    QUERY_HANDLER --> READ_MODEL
    
    READ_CACHE -.Cache Miss.-> READ_MODEL
    READ_MODEL -.Response.-> QUERY_HANDLER
    QUERY_HANDLER --> CLIENT
    
    CMD_HANDLER -->|Success Response| CLIENT

    style CMD_API fill:#ffcdd2,stroke:#333,stroke-width:2px
    style QUERY_API fill:#c8e6c9,stroke:#333,stroke-width:2px
    style EVENT_BUS fill:#fff9c4,stroke:#333,stroke-width:3px
    style WRITE_DB fill:#ffebee,stroke:#333,stroke-width:2px
    style READ_MODEL fill:#e8f5e9,stroke:#333,stroke-width:2px
    style READ_CACHE fill:#fff9c4,stroke:#333,stroke-width:2px
```

---

## 4. REQUEST FLOW SEQUENCE DIAGRAM - CREATE COMMENT

```mermaid
sequenceDiagram
    participant C as Client
    participant LB as Load Balancer
    participant API as API Server
    participant AUTH as Auth Middleware
    participant TENANT as Tenant Middleware
    participant RATE as Rate Limiter
    participant HANDLER as Comment Handler
    participant CMD as Command Service
    participant VALIDATOR as Validator
    participant LOCK as Distributed Lock
    participant DB as PostgreSQL
    participant CACHE as Redis
    participant MQ as Message Queue
    participant AUDIT as Audit Service

    C->>LB: POST /comments<br/>X-API-Key: tenant_xxx<br/>Authorization: Bearer jwt_token
    LB->>API: Forward Request
    
    API->>AUTH: Validate JWT Token
    AUTH->>CACHE: Check Token Blacklist
    CACHE-->>AUTH: Token Valid
    AUTH->>API: ✓ User Authenticated
    
    API->>TENANT: Resolve Tenant
    TENANT->>CACHE: Get Tenant by API Key Hash
    alt Cache Hit
        CACHE-->>TENANT: Tenant Data
    else Cache Miss
        TENANT->>DB: SELECT * FROM tenants WHERE api_key = hash(key)
        DB-->>TENANT: Tenant Data
        TENANT->>CACHE: Cache Tenant Data (TTL: 1h)
    end
    TENANT->>API: ✓ Tenant Resolved
    
    API->>RATE: Check Rate Limit
    RATE->>CACHE: INCR rate_limit:tenant_id:window
    CACHE-->>RATE: Current Count
    alt Rate Limit Exceeded
        RATE-->>C: 429 Too Many Requests
    else Within Limit
        RATE->>API: ✓ Rate Limit OK
    end
    
    API->>HANDLER: Process Request
    HANDLER->>CMD: CreateComment(tenantId, data)
    
    CMD->>VALIDATOR: Validate Command
    VALIDATOR->>VALIDATOR: Check Content Length<br/>Validate Parent ID<br/>Sanitize Input
    VALIDATOR-->>CMD: ✓ Valid
    
    alt Is Reply (has parentId)
        CMD->>LOCK: Acquire Lock("comment:parent_id")
        LOCK->>CACHE: SET NX lock:parent_id uuid EX 5
        CACHE-->>LOCK: Lock Acquired
        
        CMD->>DB: BEGIN TRANSACTION
        CMD->>DB: SELECT * FROM comments<br/>WHERE id = parent_id<br/>FOR UPDATE
        DB-->>CMD: Parent Comment
        CMD->>CMD: Calculate Depth = parent.depth + 1<br/>Calculate Path = parent.path + "." + parent.id
        
        CMD->>DB: UPDATE comments<br/>SET reply_count = reply_count + 1<br/>WHERE id = parent_id
    else Root Comment
        CMD->>DB: BEGIN TRANSACTION
        CMD->>CMD: Set Depth = 0, Path = ""
    end
    
    CMD->>DB: INSERT INTO comments<br/>(id, tenant_id, content, depth, path, ...)
    DB-->>CMD: Comment Created
    
    CMD->>DB: INSERT INTO audit_logs<br/>(action: COMMENT_CREATED, ...)
    DB-->>CMD: Audit Logged
    
    CMD->>DB: COMMIT TRANSACTION
    DB-->>CMD: ✓ Transaction Committed
    
    alt Is Reply
        CMD->>LOCK: Release Lock("comment:parent_id")
        LOCK->>CACHE: DEL lock:parent_id
    end
    
    CMD->>MQ: Publish CommentCreatedEvent
    MQ-->>CMD: Event Published
    
    CMD->>CACHE: DEL comment_tree:tenant_id:entity_id
    CMD->>CACHE: DEL comment:tenant_id:parent_id
    CACHE-->>CMD: Cache Invalidated
    
    CMD-->>HANDLER: Comment Created
    HANDLER-->>API: 201 Created + Comment Data
    API-->>LB: Response
    LB-->>C: 201 Created
    
    Note over MQ: Async Processing
    MQ->>AUDIT: CommentCreatedEvent
    AUDIT->>DB: Update Analytics
    MQ->>WORKER: Send Notification Event
    WORKER->>WORKER: Send Email/Push Notification
```

---

## 5. REQUEST FLOW - LIKE/UNLIKE COMMENT

```mermaid
sequenceDiagram
    participant C as Client
    participant API as API Server
    participant HANDLER as Like Handler
    participant SVC as Like Service
    participant LOCK as Distributed Lock (Redis)
    participant CACHE as Redis Cache
    participant DB as PostgreSQL
    participant MQ as Message Queue

    C->>API: POST /comments/:id/like<br/>{"userId": "user_123"}
    API->>HANDLER: Process Like Request
    HANDLER->>SVC: LikeComment(commentId, userId)
    
    Note over SVC: Prevent Race Conditions
    SVC->>LOCK: Acquire Lock(comment:id:user:id)
    LOCK->>CACHE: SET NX lock:like:comment_id:user_id<br/>uuid EX 5
    
    alt Lock Acquisition Failed
        CACHE-->>LOCK: Lock Already Held
        LOCK-->>SVC: Lock Failed
        SVC-->>HANDLER: 409 Conflict - Try Again
        HANDLER-->>C: 409 Conflict
    else Lock Acquired
        CACHE-->>LOCK: Lock Acquired
        
        SVC->>DB: BEGIN TRANSACTION (SERIALIZABLE)
        
        SVC->>DB: SELECT EXISTS(SELECT 1 FROM likes<br/>WHERE comment_id = $1<br/>AND user_id = $2<br/>FOR UPDATE)
        
        alt Already Liked
            DB-->>SVC: EXISTS = true
            SVC->>DB: ROLLBACK
            SVC->>LOCK: Release Lock
            SVC-->>HANDLER: 409 Already Liked
            HANDLER-->>C: 409 Conflict
        else Not Yet Liked
            DB-->>SVC: EXISTS = false
            
            SVC->>DB: INSERT INTO likes<br/>(id, comment_id, user_id, created_at)<br/>VALUES (uuid, $1, $2, NOW())
            DB-->>SVC: Like Inserted
            
            SVC->>DB: UPDATE comments<br/>SET like_count = like_count + 1<br/>WHERE id = comment_id
            DB-->>SVC: Counter Updated
            
            SVC->>DB: COMMIT TRANSACTION
            DB-->>SVC: ✓ Committed
            
            SVC->>LOCK: Release Lock
            LOCK->>CACHE: DEL lock:like:comment_id:user_id
            
            Note over SVC: Cache Invalidation
            SVC->>CACHE: DEL likes:comment_id
            SVC->>CACHE: DEL comment:comment_id
            SVC->>CACHE: ZINCRBY leaderboard:tenant_id score comment_id
            
            Note over SVC: Publish Event
            SVC->>MQ: Publish CommentLikedEvent
            MQ-->>SVC: Event Published
            
            SVC-->>HANDLER: ✓ Like Success
            HANDLER-->>C: 200 OK {"message": "Liked"}
        end
    end
    
    Note over MQ: Async Event Processing
    MQ->>WORKER: CommentLikedEvent
    WORKER->>DB: Update Analytics
    WORKER->>NOTIFIER: Send Notification to Author
```

---

## 6. READ REQUEST FLOW - GET COMMENT TREE (CQRS Query Side)

```mermaid
sequenceDiagram
    participant C as Client
    participant API as API Server
    participant HANDLER as Comment Handler
    participant QUERY as Query Service
    participant CACHE as Redis Cache
    participant READ_DB as Read Replica (PostgreSQL)
    participant PRIMARY_DB as Primary DB (Fallback)

    C->>API: GET /comments?entityId=post_123<br/>&page=1&limit=20
    API->>HANDLER: GetComments(entityId, pagination)
    HANDLER->>QUERY: QueryCommentTree(params)
    
    Note over QUERY: Cache-Aside Pattern
    QUERY->>QUERY: Generate Cache Key<br/>comment_tree:tenant:entity:page:limit
    
    QUERY->>CACHE: GET comment_tree:tenant_id:entity_id:1:20
    
    alt Cache Hit
        CACHE-->>QUERY: Cached Comment Tree (JSON)
        Note over QUERY: Deserialize from JSON
        QUERY-->>HANDLER: Comment Tree Data
    else Cache Miss
        CACHE-->>QUERY: nil (Cache Miss)
        
        Note over QUERY: Query Read Model
        QUERY->>READ_DB: SELECT c.*, u.display_name, u.avatar_url,<br/>COUNT(l.id) as like_count,<br/>COUNT(r.id) as reply_count<br/>FROM comments c<br/>JOIN users u ON c.author_id = u.id<br/>LEFT JOIN likes l ON c.id = l.comment_id<br/>LEFT JOIN comments r ON c.id = r.parent_id<br/>WHERE c.tenant_id = $1<br/>AND c.entity_id = $2<br/>AND c.deleted_at IS NULL<br/>GROUP BY c.id, u.id<br/>ORDER BY c.path, c.created_at DESC<br/>LIMIT $3 OFFSET $4
        
        alt Read Replica Available
            READ_DB-->>QUERY: Comment Rows
        else Read Replica Down
            QUERY->>PRIMARY_DB: Fallback to Primary
            PRIMARY_DB-->>QUERY: Comment Rows
        end
        
        Note over QUERY: Build Tree Structure
        QUERY->>QUERY: BuildCommentTree(rows)<br/>- Group by parent<br/>- Nest children<br/>- Sort by depth
        
        Note over QUERY: Update Cache
        QUERY->>QUERY: Serialize to JSON
        QUERY->>CACHE: SET comment_tree:key json<br/>EX 300 (5 minutes)
        CACHE-->>QUERY: ✓ Cached
        
        QUERY-->>HANDLER: Comment Tree Data
    end
    
    HANDLER->>HANDLER: Format Response<br/>- Add pagination metadata<br/>- Add HATEOAS links
    HANDLER-->>API: Response DTO
    API-->>C: 200 OK + Comment Tree JSON
```

---

## 7. DATA FLOW DIAGRAM - MULTI-TENANT ISOLATION

```mermaid
graph TB
    subgraph "Request Entry"
        REQ[Incoming Request<br/>X-API-Key: tenant_abc123]
    end

    subgraph "Tenant Resolution"
        HASH[Hash API Key<br/>SHA-256]
        LOOKUP[Lookup Tenant<br/>Redis/Database]
        VALIDATE[Validate Tenant Status<br/>Check: ACTIVE, rate limits]
    end

    subgraph "Request Context"
        CTX[Request Context<br/>tenant_id: uuid-1234<br/>user_id: uuid-5678<br/>scopes: [read, write]]
    end

    subgraph "Data Access Layer - Automatic Tenant Filtering"
        subgraph "Repository Pattern"
            REPO[Repository Methods]
            FILTER[Auto-inject WHERE tenant_id = $1]
        end
        
        subgraph "Database Queries"
            QUERY1[SELECT * FROM comments<br/>WHERE tenant_id = 'uuid-1234'<br/>AND entity_id = 'post_xyz']
            QUERY2[INSERT INTO comments<br/>VALUES ('uuid-1234', ...)]
            QUERY3[UPDATE comments<br/>SET content = $1<br/>WHERE id = $2<br/>AND tenant_id = 'uuid-1234']
        end
    end

    subgraph "Cache Isolation - Key Namespacing"
        CACHE_KEY[Cache Key Pattern<br/>{tenant_id}:{resource}:{id}]
        EXAMPLES[Examples:<br/>uuid-1234:comment:abc<br/>uuid-1234:likes:abc<br/>uuid-1234:session:xyz]
    end

    subgraph "Security Enforcement"
        CHECK1[Verify tenant ownership<br/>before any operation]
        CHECK2[Return 404 if resource<br/>belongs to different tenant]
        CHECK3[Never expose tenant_id<br/>in error messages]
    end

    REQ --> HASH
    HASH --> LOOKUP
    LOOKUP --> VALIDATE
    VALIDATE --> CTX
    
    CTX --> REPO
    REPO --> FILTER
    FILTER --> QUERY1
    FILTER --> QUERY2
    FILTER --> QUERY3
    
    CTX --> CACHE_KEY
    CACHE_KEY --> EXAMPLES
    
    FILTER --> CHECK1
    CHECK1 --> CHECK2
    CHECK2 --> CHECK3

    style REQ fill:#e3f2fd,stroke:#333,stroke-width:2px
    style CTX fill:#fff9c4,stroke:#333,stroke-width:3px
    style FILTER fill:#ffcdd2,stroke:#333,stroke-width:2px
    style CACHE_KEY fill:#c8e6c9,stroke:#333,stroke-width:2px
```

---

## 8. DATABASE SCHEMA ENTITY RELATIONSHIP DIAGRAM

```mermaid
erDiagram
    TENANTS ||--o{ API_KEYS : has
    TENANTS ||--o{ USERS : contains
    TENANTS ||--o{ COMMENTS : owns
    TENANTS ||--o{ LIKES : owns
    TENANTS ||--o{ AUDIT_LOGS : tracks
    TENANTS ||--o{ SESSIONS : manages
    
    USERS ||--o{ COMMENTS : authors
    USERS ||--o{ LIKES : performs
    USERS ||--o{ COMMENT_EDITS : edits
    USERS ||--o{ SESSIONS : has
    USERS ||--o{ AUDIT_LOGS : performs
    
    COMMENTS ||--o{ COMMENTS : parent_of
    COMMENTS ||--o{ LIKES : receives
    COMMENTS ||--o{ COMMENT_EDITS : has_history
    
    TENANTS {
        uuid id PK
        varchar name
        varchar subdomain UK
        varchar plan
        varchar status
        int rate_limit_per_minute
        int rate_limit_per_hour
        jsonb features
        jsonb settings
        timestamptz created_at
        timestamptz updated_at
        timestamptz deleted_at
    }
    
    API_KEYS {
        uuid id PK
        uuid tenant_id FK
        varchar key_hash UK
        varchar name
        text[] scopes
        timestamptz last_used_at
        timestamptz expires_at
        timestamptz created_at
        timestamptz revoked_at
    }
    
    USERS {
        uuid id PK
        uuid tenant_id FK
        varchar username
        varchar email
        boolean email_verified
        varchar password_hash
        varchar display_name
        text avatar_url
        text bio
        varchar role
        varchar status
        jsonb metadata
        timestamptz created_at
        timestamptz updated_at
        timestamptz deleted_at
        timestamptz last_login_at
    }
    
    COMMENTS {
        uuid id PK
        uuid tenant_id FK
        uuid parent_id FK
        varchar entity_type
        varchar entity_id
        text path
        int depth
        uuid author_id FK
        varchar author_name
        varchar author_email
        text content
        varchar content_format
        varchar status
        boolean is_pinned
        boolean is_edited
        int like_count
        int reply_count
        tsvector search_vector
        timestamptz created_at
        timestamptz updated_at
        timestamptz deleted_at
        timestamptz edited_at
    }
    
    LIKES {
        uuid id PK
        uuid tenant_id FK
        uuid comment_id FK
        uuid user_id FK
        varchar reaction_type
        timestamptz created_at
    }
    
    COMMENT_EDITS {
        uuid id PK
        uuid tenant_id FK
        uuid comment_id FK
        text previous_content
        text new_content
        uuid edited_by FK
        text reason
        timestamptz created_at
    }
    
    SESSIONS {
        uuid id PK
        uuid tenant_id FK
        uuid user_id FK
        varchar refresh_token_hash UK
        varchar access_token_jti
        inet ip_address
        text user_agent
        timestamptz created_at
        timestamptz last_accessed_at
        timestamptz expires_at
        timestamptz revoked_at
    }
    
    AUDIT_LOGS {
        uuid id PK
        uuid tenant_id FK
        varchar action
        varchar resource
        uuid resource_id
        uuid user_id FK
        varchar user_name
        varchar method
        text path
        inet ip_address
        text user_agent
        boolean success
        text error_message
        jsonb metadata
        timestamptz created_at
    }
```

---

## 9. REDIS DATA STRUCTURE ARCHITECTURE

```mermaid
graph TB
    subgraph "Redis Cluster Architecture"
        subgraph "Master Nodes"
            M1[Master 1<br/>Slots: 0-5460<br/>Port: 6379]
            M2[Master 2<br/>Slots: 5461-10922<br/>Port: 6380]
            M3[Master 3<br/>Slots: 10923-16383<br/>Port: 6381]
        end
        
        subgraph "Replica Nodes"
            R1[Replica 1<br/>→ Master 1<br/>Port: 6382]
            R2[Replica 2<br/>→ Master 2<br/>Port: 6383]
            R3[Replica 3<br/>→ Master 3<br/>Port: 6384]
        end
    end
    
    M1 -.Replicate.-> R1
    M2 -.Replicate.-> R2
    M3 -.Replicate.-> R3
    
    subgraph "Data Structures by Use Case"
        subgraph "Session Management"
            S1[Key: session:{session_id}<br/>Type: Hash<br/>Fields: user_id, tenant_id,<br/>created_at, expires_at<br/>TTL: 24 hours]
        end
        
        subgraph "Rate Limiting"
            S2[Key: rate_limit:{tenant}:{window}<br/>Type: String<br/>Value: Counter<br/>TTL: Window duration<br/>Operations: INCR, EXPIRE]
        end
        
        subgraph "Caching - Comments"
            S3[Key: comment:{tenant}:{id}<br/>Type: String JSON<br/>Value: Comment object<br/>TTL: 1 hour]
            S4[Key: comment_tree:{tenant}:{entity}<br/>Type: String JSON<br/>Value: Tree structure<br/>TTL: 5 minutes]
        end
        
        subgraph "Caching - Counts"
            S5[Key: likes:{comment_id}<br/>Type: String<br/>Value: Like count<br/>TTL: 5 minutes]
        end
        
        subgraph "Distributed Locks"
            S6[Key: lock:{resource}<br/>Type: String<br/>Value: Lock UUID<br/>TTL: 5 seconds<br/>Operation: SET NX EX]
        end
        
        subgraph "Leaderboards"
            S7[Key: leaderboard:{tenant}:{type}<br/>Type: Sorted Set<br/>Score: engagement_score<br/>Member: comment_id<br/>Operations: ZADD, ZRANGE]
        end
        
        subgraph "Pub/Sub - Real-time"
            S8[Channel: notifications:{tenant}:{user}<br/>Type: Pub/Sub<br/>Payload: JSON events<br/>Operations: PUBLISH, SUBSCRIBE]
        end
        
        subgraph "Token Blacklist"
            S9[Key: revoked:{jti}<br/>Type: String<br/>Value: 1<br/>TTL: Token expiry duration]
        end
        
        subgraph "Tenant Cache"
            S10[Key: tenant:{api_key_hash}<br/>Type: Hash<br/>Fields: id, name, plan,<br/>rate_limits<br/>TTL: 1 hour]
        end
    end
    
    M1 --> S1
    M1 --> S2
    M2 --> S3
    M2 --> S4
    M3 --> S5
    M3 --> S6
    M1 --> S7
    M2 --> S8
    M3 --> S9
    M1 --> S10

    style M1 fill:#ffcdd2,stroke:#333,stroke-width:2px
    style M2 fill:#ffcdd2,stroke:#333,stroke-width:2px
    style M3 fill:#ffcdd2,stroke:#333,stroke-width:2px
    style R1 fill:#e1f5fe,stroke:#333,stroke-width:1px
    style R2 fill:#e1f5fe,stroke:#333,stroke-width:1px
    style R3 fill:#e1f5fe,stroke:#333,stroke-width:1px
```

---

## 10. DEPLOYMENT ARCHITECTURE - PRODUCTION

```mermaid
graph TB
    subgraph "Internet"
        INTERNET[Users / API Clients]
    end
    
    subgraph "DNS Layer"
        DNS[DNS / Route53<br/>comments-api.example.com]
    end
    
    subgraph "CDN / Edge"
        CDN[CloudFlare CDN<br/>- DDoS Protection<br/>- Rate Limiting<br/>- TLS Termination]
    end
    
    subgraph "AWS Region: us-east-1"
        subgraph "Availability Zone A"
            subgraph "Public Subnet A"
                LB_A[Load Balancer A<br/>NGINX]
            end
            
            subgraph "Private Subnet A"
                API_A1[API Server A1]
                API_A2[API Server A2]
                WORKER_A[Worker A]
            end
            
            subgraph "Data Subnet A"
                PG_PRIMARY_A[(PostgreSQL<br/>Primary)]
                REDIS_A[Redis Master A]
            end
        end
        
        subgraph "Availability Zone B"
            subgraph "Public Subnet B"
                LB_B[Load Balancer B<br/>NGINX]
            end
            
            subgraph "Private Subnet B"
                API_B1[API Server B1]
                API_B2[API Server B2]
                WORKER_B[Worker B]
            end
            
            subgraph "Data Subnet B"
                PG_REPLICA_B[(PostgreSQL<br/>Replica)]
                REDIS_B[Redis Master B]
            end
        end
        
        subgraph "Availability Zone C"
            subgraph "Private Subnet C"
                API_C1[API Server C1]
                WORKER_C[Worker C]
            end
            
            subgraph "Data Subnet C"
                PG_REPLICA_C[(PostgreSQL<br/>Replica)]
                REDIS_C[Redis Master C]
            end
        end
        
        subgraph "Shared Services"
            MQ[RabbitMQ Cluster<br/>Multi-AZ]
            BASTION[Bastion Host<br/>SSH Access]
        end
        
        subgraph "Monitoring - Separate VPC"
            PROMETHEUS[Prometheus]
            GRAFANA[Grafana]
            JAEGER[Jaeger]
            ELK[ELK Stack]
        end
    end
    
    subgraph "Backup & DR"
        S3[S3 Bucket<br/>Database Backups]
        BACKUP[Automated Backups<br/>Daily + WAL Archiving]
    end
    
    INTERNET --> DNS
    DNS --> CDN
    CDN --> LB_A
    CDN --> LB_B
    
    LB_A --> API_A1
    LB_A --> API_A2
    LB_A --> API_B1
    LB_A --> API_B2
    LB_A --> API_C1
    
    LB_B --> API_A1
    LB_B --> API_A2
    LB_B --> API_B1
    LB_B --> API_B2
    LB_B --> API_C1
    
    API_A1 --> PG_PRIMARY_A
    API_A1 --> PG_REPLICA_B
    API_A1 --> REDIS_A
    API_A1 --> REDIS_B
    API_A1 --> MQ
    
    API_B1 --> PG_PRIMARY_A
    API_B1 --> PG_REPLICA_B
    API_B1 --> REDIS_B
    API_B1 --> MQ
    
    PG_PRIMARY_A -.Streaming<br/>Replication.-> PG_REPLICA_B
    PG_PRIMARY_A -.Streaming<br/>Replication.-> PG_REPLICA_C
    
    REDIS_A -.Cluster<br/>Replication.-> REDIS_B
    REDIS_B -.Cluster<br/>Replication.-> REDIS_C
    
    PG_PRIMARY_A --> BACKUP
    BACKUP --> S3
    
    API_A1 -.Metrics.-> PROMETHEUS
    API_B1 -.Metrics.-> PROMETHEUS
    API_C1 -.Metrics.-> PROMETHEUS
    PROMETHEUS --> GRAFANA
    
    API_A1 -.Logs.-> ELK
    API_B1 -.Logs.-> ELK

    style CDN fill:#f9f,stroke:#333,stroke-width:3px
    style PG_PRIMARY_A fill:#f44,stroke:#333,stroke-width:3px
    style LB_A fill:#4af,stroke:#333,stroke-width:2px
    style LB_B fill:#4af,stroke:#333,stroke-width:2px
```

---

## 11. EVENT-DRIVEN ARCHITECTURE FLOW

```mermaid
graph TB
    subgraph "Event Publishers - Domain Services"
        TENANT_SVC[Tenant Service]
        USER_SVC[User Service]
        COMMENT_SVC[Comment Service]
        LIKE_SVC[Like Service]
    end
    
    subgraph "Event Bus - RabbitMQ"
        EXCHANGE[Topic Exchange<br/>'domain.events']
        
        subgraph "Queues"
            Q_AUDIT[audit.queue]
            Q_NOTIFICATION[notification.queue]
            Q_ANALYTICS[analytics.queue]
            Q_CACHE[cache.invalidation.queue]
            Q_SEARCH[search.indexing.queue]
        end
    end
    
    subgraph "Event Consumers - Workers"
        AUDIT_WORKER[Audit Worker<br/>Writes to audit_logs]
        NOTIF_WORKER[Notification Worker<br/>Sends emails/push]
        ANALYTICS_WORKER[Analytics Worker<br/>Updates metrics]
        CACHE_WORKER[Cache Worker<br/>Invalidates Redis]
        SEARCH_WORKER[Search Worker<br/>Updates search index]
    end
    
    subgraph "Event Types"
        E1[TenantCreated]
        E2[UserRegistered]
        E3[CommentCreated]
        E4[CommentUpdated]
        E5[CommentDeleted]
        E6[CommentLiked]
        E7[CommentUnliked]
    end
    
    COMMENT_SVC -->|Publish| EXCHANGE
    LIKE_SVC -->|Publish| EXCHANGE
    USER_SVC -->|Publish| EXCHANGE
    TENANT_SVC -->|Publish| EXCHANGE
    
    EXCHANGE -->|Route by<br/>routing key| Q_AUDIT
    EXCHANGE -->|Route by<br/>routing key| Q_NOTIFICATION
    EXCHANGE -->|Route by<br/>routing key| Q_ANALYTICS
    EXCHANGE -->|Route by<br/>routing key| Q_CACHE
    EXCHANGE -->|Route by<br/>routing key| Q_SEARCH
    
    Q_AUDIT --> AUDIT_WORKER
    Q_NOTIFICATION --> NOTIF_WORKER
    Q_ANALYTICS --> ANALYTICS_WORKER
    Q_CACHE --> CACHE_WORKER
    Q_SEARCH --> SEARCH_WORKER
    
    COMMENT_SVC -.Publishes.-> E3
    COMMENT_SVC -.Publishes.-> E4
    COMMENT_SVC -.Publishes.-> E5
    LIKE_SVC -.Publishes.-> E6
    LIKE_SVC -.Publishes.-> E7

    style EXCHANGE fill:#fff9c4,stroke:#333,stroke-width:3px
    style COMMENT_SVC fill:#c8e6c9,stroke:#333,stroke-width:2px
    style LIKE_SVC fill:#c8e6c9,stroke:#333,stroke-width:2px
```

---

## Summary

These diagrams cover:

1. **High-Level System Architecture** - Complete infrastructure view
2. **Component Architecture** - Internal API server structure
3. **CQRS Pattern** - Separation of read/write concerns
4. **Create Comment Sequence** - Detailed step-by-step flow
5. **Like/Unlike Flow** - Race condition prevention
6. **Query Flow (CQRS)** - Cache-aside pattern
7. **Multi-Tenant Isolation** - Security enforcement
8. **Database ERD** - Complete schema relationships
9. **Redis Architecture** - Cluster setup and data structures
10. **Production Deployment** - Multi-AZ, high availability
11. **Event-Driven Flow** - Async processing architecture

Each diagram shows different aspects of the system at various levels of detail, from high-level architecture down to specific request flows.