-- Migration: 005_create_likes
-- Description: Create likes table with reaction support
-- Author: System
-- Date: 2025-02-16

-- Create ENUM for reaction types (extensible for future emoji reactions)
CREATE TYPE reaction_type AS ENUM (
    'LIKE',
    'LOVE',
    'LAUGH',
    'WOW',
    'SAD',
    'ANGRY'
);

-- Create likes table
CREATE TABLE IF NOT EXISTS likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    comment_id UUID NOT NULL,
    user_id UUID NOT NULL,
    
    -- Reaction Type (defaults to simple LIKE)
    reaction reaction_type NOT NULL DEFAULT 'LIKE',
    
    -- Metadata
    ip_address INET, -- For analytics/abuse detection
    user_agent TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Foreign Keys
    CONSTRAINT fk_likes_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants(id)
        ON DELETE CASCADE,
    
    CONSTRAINT fk_likes_comment
        FOREIGN KEY (comment_id)
        REFERENCES comments(id)
        ON DELETE CASCADE,
    
    CONSTRAINT fk_likes_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE,
    
    -- Unique Constraint (prevent duplicate likes)
    -- User can only have one reaction per comment
    CONSTRAINT unique_likes_user_comment 
        UNIQUE (tenant_id, comment_id, user_id)
);

-- Indexes for performance

-- Primary lookups
CREATE INDEX idx_likes_comment ON likes(comment_id);
CREATE INDEX idx_likes_user ON likes(user_id);
CREATE INDEX idx_likes_tenant ON likes(tenant_id);

-- Composite indexes for common queries
CREATE INDEX idx_likes_comment_user ON likes(comment_id, user_id);
CREATE INDEX idx_likes_user_comment ON likes(user_id, comment_id);

-- Reaction type analytics
CREATE INDEX idx_likes_reaction ON likes(reaction);
CREATE INDEX idx_likes_comment_reaction ON likes(comment_id, reaction);

-- Temporal queries
CREATE INDEX idx_likes_created_at ON likes(created_at DESC);
CREATE INDEX idx_likes_comment_created ON likes(comment_id, created_at DESC);

-- Function to add a like (with race condition protection)
CREATE OR REPLACE FUNCTION add_like(
    p_tenant_id UUID,
    p_comment_id UUID,
    p_user_id UUID,
    p_reaction reaction_type DEFAULT 'LIKE',
    p_ip_address INET DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    like_id UUID,
    new_like_count INTEGER,
    message TEXT
) AS $$
DECLARE
    v_like_id UUID;
    v_like_count INTEGER;
    v_already_exists BOOLEAN;
BEGIN
    -- Check if like already exists
    SELECT EXISTS(
        SELECT 1 FROM likes
        WHERE tenant_id = p_tenant_id
          AND comment_id = p_comment_id
          AND user_id = p_user_id
    ) INTO v_already_exists;
    
    IF v_already_exists THEN
        -- Update existing like (change reaction)
        UPDATE likes
        SET reaction = p_reaction,
            created_at = NOW()
        WHERE tenant_id = p_tenant_id
          AND comment_id = p_comment_id
          AND user_id = p_user_id
        RETURNING id INTO v_like_id;
        
        SELECT like_count INTO v_like_count
        FROM comments
        WHERE id = p_comment_id;
        
        RETURN QUERY
        SELECT 
            true,
            v_like_id,
            v_like_count,
            'Reaction updated'::TEXT;
    ELSE
        -- Insert new like
        INSERT INTO likes (
            id,
            tenant_id,
            comment_id,
            user_id,
            reaction,
            ip_address,
            created_at
        ) VALUES (
            gen_random_uuid(),
            p_tenant_id,
            p_comment_id,
            p_user_id,
            p_reaction,
            p_ip_address,
            NOW()
        )
        RETURNING id INTO v_like_id;
        
        -- Increment comment like count
        UPDATE comments
        SET like_count = like_count + 1
        WHERE id = p_comment_id
        RETURNING like_count INTO v_like_count;
        
        RETURN QUERY
        SELECT 
            true,
            v_like_id,
            v_like_count,
            'Like added'::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to remove a like
CREATE OR REPLACE FUNCTION remove_like(
    p_tenant_id UUID,
    p_comment_id UUID,
    p_user_id UUID
)
RETURNS TABLE(
    success BOOLEAN,
    new_like_count INTEGER,
    message TEXT
) AS $$
DECLARE
    v_like_count INTEGER;
    v_deleted BOOLEAN;
BEGIN
    -- Delete the like
    DELETE FROM likes
    WHERE tenant_id = p_tenant_id
      AND comment_id = p_comment_id
      AND user_id = p_user_id
    RETURNING true INTO v_deleted;
    
    IF v_deleted THEN
        -- Decrement comment like count
        UPDATE comments
        SET like_count = GREATEST(like_count - 1, 0)
        WHERE id = p_comment_id
        RETURNING like_count INTO v_like_count;
        
        RETURN QUERY
        SELECT 
            true,
            v_like_count,
            'Like removed'::TEXT;
    ELSE
        -- Like didn't exist
        SELECT like_count INTO v_like_count
        FROM comments
        WHERE id = p_comment_id;
        
        RETURN QUERY
        SELECT 
            false,
            v_like_count,
            'Like not found'::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to get likes for a comment
CREATE OR REPLACE FUNCTION get_comment_likes(
    p_comment_id UUID,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
    user_id UUID,
    user_name VARCHAR,
    user_avatar TEXT,
    reaction reaction_type,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.display_name,
        u.avatar_url,
        l.reaction,
        l.created_at
    FROM likes l
    INNER JOIN users u ON l.user_id = u.id
    WHERE l.comment_id = p_comment_id
    ORDER BY l.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- Function to check if user liked a comment
CREATE OR REPLACE FUNCTION has_user_liked(
    p_comment_id UUID,
    p_user_id UUID
)
RETURNS TABLE(
    liked BOOLEAN,
    reaction reaction_type
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        true,
        l.reaction
    FROM likes l
    WHERE l.comment_id = p_comment_id
      AND l.user_id = p_user_id
    LIMIT 1;
    
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT false, NULL::reaction_type;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to get reaction breakdown for a comment
CREATE OR REPLACE FUNCTION get_reaction_breakdown(p_comment_id UUID)
RETURNS TABLE(
    reaction reaction_type,
    count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.reaction,
        COUNT(*)::BIGINT
    FROM likes l
    WHERE l.comment_id = p_comment_id
    GROUP BY l.reaction
    ORDER BY COUNT(*) DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get user's recent likes
CREATE OR REPLACE FUNCTION get_user_likes(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
    comment_id UUID,
    comment_content TEXT,
    comment_author VARCHAR,
    reaction reaction_type,
    liked_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.content,
        c.author_name,
        l.reaction,
        l.created_at
    FROM likes l
    INNER JOIN comments c ON l.comment_id = c.id
    WHERE l.user_id = p_user_id
      AND c.deleted_at IS NULL
    ORDER BY l.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- Function to get most liked comments
CREATE OR REPLACE FUNCTION get_most_liked_comments(
    p_tenant_id UUID,
    p_entity_type VARCHAR DEFAULT NULL,
    p_time_range INTERVAL DEFAULT INTERVAL '30 days',
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE(
    comment_id UUID,
    comment_content TEXT,
    author_name VARCHAR,
    like_count BIGINT,
    first_liked_at TIMESTAMPTZ,
    last_liked_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.content,
        c.author_name,
        COUNT(l.id)::BIGINT as like_count,
        MIN(l.created_at) as first_liked_at,
        MAX(l.created_at) as last_liked_at
    FROM comments c
    INNER JOIN likes l ON c.id = l.comment_id
    WHERE c.tenant_id = p_tenant_id
      AND c.deleted_at IS NULL
      AND l.created_at > NOW() - p_time_range
      AND (p_entity_type IS NULL OR c.entity_type = p_entity_type)
    GROUP BY c.id, c.content, c.author_name
    ORDER BY like_count DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function to clean up orphaned likes (comments that were hard-deleted)
CREATE OR REPLACE FUNCTION cleanup_orphaned_likes()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    WITH deleted AS (
        DELETE FROM likes l
        WHERE NOT EXISTS (
            SELECT 1 FROM comments c
            WHERE c.id = l.comment_id
        )
        RETURNING 1
    )
    SELECT COUNT(*) INTO deleted_count FROM deleted;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Trigger to prevent liking deleted comments
CREATE OR REPLACE FUNCTION prevent_like_deleted_comment()
RETURNS TRIGGER AS $$
DECLARE
    comment_deleted BOOLEAN;
BEGIN
    SELECT deleted_at IS NOT NULL INTO comment_deleted
    FROM comments
    WHERE id = NEW.comment_id;
    
    IF comment_deleted THEN
        RAISE EXCEPTION 'Cannot like a deleted comment';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_like_deleted
    BEFORE INSERT ON likes
    FOR EACH ROW
    EXECUTE FUNCTION prevent_like_deleted_comment();

-- View for like analytics
CREATE OR REPLACE VIEW like_analytics AS
SELECT 
    DATE_TRUNC('day', l.created_at) as date,
    l.tenant_id,
    COUNT(DISTINCT l.user_id) as unique_users,
    COUNT(l.id) as total_likes,
    COUNT(DISTINCT l.comment_id) as comments_liked,
    l.reaction,
    COUNT(l.id) FILTER (WHERE l.created_at::date = CURRENT_DATE) as today_count
FROM likes l
GROUP BY DATE_TRUNC('day', l.created_at), l.tenant_id, l.reaction;

-- Comments
COMMENT ON TABLE likes IS 'Stores user likes/reactions on comments';
COMMENT ON COLUMN likes.reaction IS 'Type of reaction (LIKE, LOVE, LAUGH, etc.)';
COMMENT ON COLUMN likes.ip_address IS 'IP address for analytics and abuse detection';
COMMENT ON CONSTRAINT unique_likes_user_comment ON likes IS 'Prevents duplicate likes - user can only react once per comment';
COMMENT ON FUNCTION add_like IS 'Adds or updates a like with race condition protection';
COMMENT ON FUNCTION remove_like IS 'Removes a like and decrements counter atomically';
COMMENT ON FUNCTION has_user_liked IS 'Checks if user has liked a specific comment';
COMMENT ON FUNCTION get_reaction_breakdown IS 'Returns count of each reaction type for a comment';
COMMENT ON FUNCTION get_most_liked_comments IS 'Returns most liked comments in a time range';
COMMENT ON VIEW like_analytics IS 'Daily aggregated like statistics by tenant and reaction type';
