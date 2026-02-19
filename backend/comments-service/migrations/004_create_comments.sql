-- Migration: 004_create_comments
-- Description: Create comments table with hierarchical structure
-- Author: System
-- Date: 2025-02-16

-- Create ENUM types for comments
CREATE TYPE comment_status AS ENUM ('ACTIVE', 'DELETED', 'FLAGGED', 'SPAM', 'PENDING');
CREATE TYPE content_format AS ENUM ('plain', 'markdown', 'html');

-- Create comments table
CREATE TABLE IF NOT EXISTS comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    
    -- Hierarchy (Materialized Path Pattern)
    parent_id UUID,
    depth INTEGER NOT NULL DEFAULT 0,
    path TEXT NOT NULL DEFAULT '',
    
    -- Entity Relationship (what is being commented on)
    entity_type VARCHAR(100) NOT NULL, -- 'post', 'product', 'article', etc.
    entity_id VARCHAR(255) NOT NULL,
    
    -- Author Information
    author_id UUID NOT NULL,
    author_name VARCHAR(255) NOT NULL,
    author_email VARCHAR(255),
    author_ip INET, -- For moderation/spam detection
    
    -- Content
    content TEXT NOT NULL,
    content_format content_format NOT NULL DEFAULT 'plain',
    
    -- Status & Moderation
    status comment_status NOT NULL DEFAULT 'ACTIVE',
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    is_edited BOOLEAN NOT NULL DEFAULT false,
    is_verified BOOLEAN NOT NULL DEFAULT false, -- For verified authors
    
    -- Engagement Metrics (denormalized for performance)
    like_count INTEGER NOT NULL DEFAULT 0,
    reply_count INTEGER NOT NULL DEFAULT 0,
    view_count INTEGER NOT NULL DEFAULT 0,
    
    -- Moderation
    flagged_count INTEGER NOT NULL DEFAULT 0,
    spam_score REAL NOT NULL DEFAULT 0.0, -- 0.0 to 1.0
    moderated_by UUID, -- User who moderated this comment
    moderation_note TEXT,
    
    -- Full-Text Search
    search_vector TSVECTOR,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ, -- Soft delete
    edited_at TIMESTAMPTZ,
    published_at TIMESTAMPTZ,
    
    -- Foreign Keys
    CONSTRAINT fk_comments_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants(id)
        ON DELETE CASCADE,
    
    CONSTRAINT fk_comments_parent
        FOREIGN KEY (parent_id)
        REFERENCES comments(id)
        ON DELETE CASCADE,
    
    CONSTRAINT fk_comments_author
        FOREIGN KEY (author_id)
        REFERENCES users(id)
        ON DELETE SET NULL,
    
    CONSTRAINT fk_comments_moderator
        FOREIGN KEY (moderated_by)
        REFERENCES users(id)
        ON DELETE SET NULL,
    
    -- Check Constraints
    CONSTRAINT comments_content_length CHECK (
        char_length(content) >= 1 AND char_length(content) <= 10000
    ),
    CONSTRAINT comments_depth_nonnegative CHECK (depth >= 0),
    CONSTRAINT comments_depth_max CHECK (depth <= 100), -- Prevent infinite nesting
    CONSTRAINT comments_like_count_nonnegative CHECK (like_count >= 0),
    CONSTRAINT comments_reply_count_nonnegative CHECK (reply_count >= 0),
    CONSTRAINT comments_spam_score_range CHECK (spam_score >= 0.0 AND spam_score <= 1.0)
);

-- Indexes for performance

-- Primary lookups
CREATE INDEX idx_comments_tenant ON comments(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_comments_id_tenant ON comments(id, tenant_id) WHERE deleted_at IS NULL;

-- Entity lookups (most common query pattern)
CREATE INDEX idx_comments_entity ON comments(tenant_id, entity_type, entity_id, created_at DESC) 
    WHERE deleted_at IS NULL;

-- Hierarchy lookups
CREATE INDEX idx_comments_parent ON comments(parent_id) WHERE parent_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_comments_path ON comments USING btree(path text_pattern_ops) WHERE deleted_at IS NULL;

-- Author lookups
CREATE INDEX idx_comments_author ON comments(author_id, created_at DESC) WHERE deleted_at IS NULL;

-- Status and moderation
CREATE INDEX idx_comments_status ON comments(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_comments_flagged ON comments(flagged_count DESC) WHERE flagged_count > 0 AND deleted_at IS NULL;
CREATE INDEX idx_comments_spam ON comments(spam_score DESC) WHERE spam_score > 0.5 AND deleted_at IS NULL;

-- Sorting and pagination
CREATE INDEX idx_comments_created_at ON comments(created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_comments_updated_at ON comments(updated_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_comments_popular ON comments(like_count DESC, reply_count DESC) WHERE deleted_at IS NULL;

-- Full-text search
CREATE INDEX idx_comments_search ON comments USING GIN(search_vector);

-- Composite index for common query pattern (entity + status + sort)
CREATE INDEX idx_comments_entity_active_created ON comments(
    tenant_id, entity_type, entity_id, created_at DESC
) WHERE deleted_at IS NULL AND status = 'ACTIVE';

-- Partial index for soft-deleted comments
CREATE INDEX idx_comments_deleted ON comments(deleted_at) WHERE deleted_at IS NOT NULL;

-- Trigger for updated_at
CREATE TRIGGER update_comments_updated_at
    BEFORE UPDATE ON comments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger to update search_vector
CREATE OR REPLACE FUNCTION update_comment_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := to_tsvector('english',
        COALESCE(NEW.content, '') || ' ' ||
        COALESCE(NEW.author_name, '')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_comments_search_vector
    BEFORE INSERT OR UPDATE OF content, author_name ON comments
    FOR EACH ROW
    EXECUTE FUNCTION update_comment_search_vector();

-- Trigger to update tenant comment count
CREATE OR REPLACE FUNCTION update_tenant_comment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE tenants
        SET total_comments = total_comments + 1
        WHERE id = NEW.tenant_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE tenants
        SET total_comments = total_comments - 1
        WHERE id = OLD.tenant_id;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_tenant_comments_count
    AFTER INSERT OR DELETE ON comments
    FOR EACH ROW
    EXECUTE FUNCTION update_tenant_comment_count();

-- Function to get comment tree (all descendants)
CREATE OR REPLACE FUNCTION get_comment_tree(p_comment_id UUID)
RETURNS TABLE(
    id UUID,
    parent_id UUID,
    depth INTEGER,
    content TEXT,
    author_name VARCHAR,
    like_count INTEGER,
    reply_count INTEGER,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.parent_id,
        c.depth,
        c.content,
        c.author_name,
        c.like_count,
        c.reply_count,
        c.created_at
    FROM comments c
    WHERE c.path LIKE (
        SELECT path || '.' || p_comment_id || '%'
        FROM comments
        WHERE id = p_comment_id
    )
    OR c.id = p_comment_id
    ORDER BY c.path, c.created_at;
END;
$$ LANGUAGE plpgsql;

-- Function to get direct replies
CREATE OR REPLACE FUNCTION get_comment_replies(
    p_comment_id UUID,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
    id UUID,
    content TEXT,
    author_name VARCHAR,
    author_avatar TEXT,
    like_count INTEGER,
    reply_count INTEGER,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.content,
        c.author_name,
        u.avatar_url,
        c.like_count,
        c.reply_count,
        c.created_at
    FROM comments c
    LEFT JOIN users u ON c.author_id = u.id
    WHERE c.parent_id = p_comment_id
      AND c.deleted_at IS NULL
    ORDER BY c.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- Function to increment like count atomically
CREATE OR REPLACE FUNCTION increment_comment_likes(p_comment_id UUID)
RETURNS INTEGER AS $$
DECLARE
    new_count INTEGER;
BEGIN
    UPDATE comments
    SET like_count = like_count + 1
    WHERE id = p_comment_id
    RETURNING like_count INTO new_count;
    
    RETURN new_count;
END;
$$ LANGUAGE plpgsql;

-- Function to decrement like count atomically
CREATE OR REPLACE FUNCTION decrement_comment_likes(p_comment_id UUID)
RETURNS INTEGER AS $$
DECLARE
    new_count INTEGER;
BEGIN
    UPDATE comments
    SET like_count = GREATEST(like_count - 1, 0)
    WHERE id = p_comment_id
    RETURNING like_count INTO new_count;
    
    RETURN new_count;
END;
$$ LANGUAGE plpgsql;

-- Function to soft delete comment and all descendants
CREATE OR REPLACE FUNCTION soft_delete_comment_tree(p_comment_id UUID)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    WITH deleted AS (
        UPDATE comments
        SET 
            deleted_at = NOW(),
            status = 'DELETED',
            updated_at = NOW()
        WHERE id = p_comment_id
           OR path LIKE (
               SELECT path || '.' || p_comment_id || '%'
               FROM comments
               WHERE id = p_comment_id
           )
        RETURNING 1
    )
    SELECT COUNT(*) INTO deleted_count FROM deleted;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function to hard delete comment (admin only)
CREATE OR REPLACE FUNCTION hard_delete_comment(p_comment_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    -- First delete all likes
    DELETE FROM likes WHERE comment_id = p_comment_id;
    
    -- Delete edit history
    DELETE FROM comment_edits WHERE comment_id = p_comment_id;
    
    -- Delete the comment
    DELETE FROM comments WHERE id = p_comment_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to search comments by full-text
CREATE OR REPLACE FUNCTION search_comments(
    p_tenant_id UUID,
    p_search_term TEXT,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
    id UUID,
    content TEXT,
    author_name VARCHAR,
    entity_type VARCHAR,
    entity_id VARCHAR,
    like_count INTEGER,
    created_at TIMESTAMPTZ,
    rank REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.content,
        c.author_name,
        c.entity_type,
        c.entity_id,
        c.like_count,
        c.created_at,
        ts_rank(c.search_vector, plainto_tsquery('english', p_search_term)) as rank
    FROM comments c
    WHERE c.tenant_id = p_tenant_id
      AND c.deleted_at IS NULL
      AND c.search_vector @@ plainto_tsquery('english', p_search_term)
    ORDER BY rank DESC, c.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- Function to get popular comments for leaderboard
CREATE OR REPLACE FUNCTION get_popular_comments(
    p_tenant_id UUID,
    p_entity_type VARCHAR DEFAULT NULL,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE(
    id UUID,
    content TEXT,
    author_name VARCHAR,
    entity_type VARCHAR,
    entity_id VARCHAR,
    like_count INTEGER,
    reply_count INTEGER,
    engagement_score REAL,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.content,
        c.author_name,
        c.entity_type,
        c.entity_id,
        c.like_count,
        c.reply_count,
        (c.like_count * 2.0 + c.reply_count)::REAL as engagement_score,
        c.created_at
    FROM comments c
    WHERE c.tenant_id = p_tenant_id
      AND c.deleted_at IS NULL
      AND c.status = 'ACTIVE'
      AND (p_entity_type IS NULL OR c.entity_type = p_entity_type)
    ORDER BY engagement_score DESC, c.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Comments
COMMENT ON TABLE comments IS 'Hierarchical comments with materialized path for efficient tree queries';
COMMENT ON COLUMN comments.path IS 'Materialized path for hierarchy (e.g., "parent_id.grandparent_id")';
COMMENT ON COLUMN comments.depth IS 'Nesting level (0 for root comments)';
COMMENT ON COLUMN comments.entity_type IS 'Type of entity being commented on (e.g., "post", "product")';
COMMENT ON COLUMN comments.entity_id IS 'ID of the entity being commented on';
COMMENT ON COLUMN comments.search_vector IS 'Full-text search vector for content and author name';
COMMENT ON COLUMN comments.spam_score IS 'Spam probability score (0.0-1.0) from ML model';
COMMENT ON FUNCTION get_comment_tree IS 'Returns entire comment subtree starting from given comment';
COMMENT ON FUNCTION get_comment_replies IS 'Returns direct replies to a comment with pagination';
COMMENT ON FUNCTION soft_delete_comment_tree IS 'Soft deletes comment and all its descendants';
COMMENT ON FUNCTION hard_delete_comment IS 'Permanently deletes comment (admin only)';
COMMENT ON FUNCTION search_comments IS 'Full-text search across comments with ranking';
COMMENT ON FUNCTION get_popular_comments IS 'Returns most popular comments by engagement score';
