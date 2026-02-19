-- Migration: 006_create_sessions_and_audit
-- Description: Create sessions and audit_logs tables
-- Author: System
-- Date: 2025-02-16

-- ============================================================================
-- SESSIONS TABLE (for JWT refresh tokens)
-- ============================================================================

CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    user_id UUID NOT NULL,
    
    -- Token Information
    refresh_token_hash VARCHAR(64) NOT NULL UNIQUE, -- SHA-256 hash
    access_token_jti VARCHAR(64), -- JWT ID for revocation
    
    -- Session Metadata
    ip_address INET,
    user_agent TEXT,
    device_info JSONB DEFAULT '{}'::jsonb,
    
    -- Geolocation (optional, from IP)
    country VARCHAR(2),
    city VARCHAR(100),
    
    -- Lifecycle
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_accessed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    
    -- Foreign Keys
    CONSTRAINT fk_sessions_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants(id)
        ON DELETE CASCADE,
    
    CONSTRAINT fk_sessions_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE,
    
    -- Check Constraints
    CONSTRAINT sessions_expires_future CHECK (expires_at > created_at)
);

-- Indexes
CREATE INDEX idx_sessions_user ON sessions(user_id) WHERE revoked_at IS NULL;
CREATE INDEX idx_sessions_tenant ON sessions(tenant_id) WHERE revoked_at IS NULL;
CREATE INDEX idx_sessions_token ON sessions(refresh_token_hash) WHERE revoked_at IS NULL;
CREATE INDEX idx_sessions_jti ON sessions(access_token_jti) WHERE revoked_at IS NULL;
CREATE INDEX idx_sessions_expires ON sessions(expires_at) WHERE expires_at > NOW();
CREATE INDEX idx_sessions_last_accessed ON sessions(last_accessed_at DESC);

-- GIN index for device_info
CREATE INDEX idx_sessions_device ON sessions USING GIN(device_info);

-- Function to create new session
CREATE OR REPLACE FUNCTION create_session(
    p_tenant_id UUID,
    p_user_id UUID,
    p_refresh_token_hash VARCHAR,
    p_access_token_jti VARCHAR,
    p_ip_address INET,
    p_user_agent TEXT,
    p_expires_at TIMESTAMPTZ
)
RETURNS UUID AS $$
DECLARE
    v_session_id UUID;
BEGIN
    INSERT INTO sessions (
        tenant_id,
        user_id,
        refresh_token_hash,
        access_token_jti,
        ip_address,
        user_agent,
        expires_at
    ) VALUES (
        p_tenant_id,
        p_user_id,
        p_refresh_token_hash,
        p_access_token_jti,
        p_ip_address,
        p_user_agent,
        p_expires_at
    )
    RETURNING id INTO v_session_id;
    
    RETURN v_session_id;
END;
$$ LANGUAGE plpgsql;

-- Function to validate session
CREATE OR REPLACE FUNCTION validate_session(p_refresh_token_hash VARCHAR)
RETURNS TABLE(
    valid BOOLEAN,
    user_id UUID,
    tenant_id UUID,
    expires_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (s.revoked_at IS NULL AND s.expires_at > NOW())::BOOLEAN,
        s.user_id,
        s.tenant_id,
        s.expires_at
    FROM sessions s
    WHERE s.refresh_token_hash = p_refresh_token_hash;
END;
$$ LANGUAGE plpgsql;

-- Function to revoke session
CREATE OR REPLACE FUNCTION revoke_session(p_session_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE sessions
    SET revoked_at = NOW()
    WHERE id = p_session_id;
END;
$$ LANGUAGE plpgsql;

-- Function to cleanup expired sessions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    WITH deleted AS (
        DELETE FROM sessions
        WHERE expires_at < NOW() - INTERVAL '30 days'
        OR revoked_at < NOW() - INTERVAL '30 days'
        RETURNING 1
    )
    SELECT COUNT(*) INTO deleted_count FROM deleted;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- AUDIT LOGS TABLE
-- ============================================================================

CREATE TYPE audit_action AS ENUM (
    'COMMENT_CREATED',
    'COMMENT_UPDATED',
    'COMMENT_DELETED',
    'COMMENT_HARD_DELETED',
    'COMMENT_VIEWED',
    'COMMENT_LIKED',
    'COMMENT_UNLIKED',
    'COMMENT_FLAGGED',
    'USER_CREATED',
    'USER_UPDATED',
    'USER_DELETED',
    'USER_LOGIN',
    'USER_LOGOUT',
    'TENANT_CREATED',
    'TENANT_UPDATED',
    'RATE_LIMIT_EXCEEDED',
    'API_KEY_CREATED',
    'API_KEY_REVOKED',
    'SESSION_CREATED',
    'SESSION_REVOKED'
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    
    -- Action Details
    action audit_action NOT NULL,
    resource VARCHAR(100) NOT NULL, -- 'comment', 'user', 'tenant', etc.
    resource_id UUID,
    
    -- Actor (who performed the action)
    user_id UUID,
    user_name VARCHAR(255),
    user_role VARCHAR(50),
    
    -- Request Context
    method VARCHAR(10), -- HTTP method
    path TEXT, -- Request path
    ip_address INET,
    user_agent TEXT,
    
    -- Result
    success BOOLEAN NOT NULL DEFAULT true,
    error_message TEXT,
    http_status_code INTEGER,
    
    -- Additional Data (flexible JSON)
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    
    -- Changes (before/after for updates)
    changes JSONB,
    
    -- Timestamp
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Foreign Keys
    CONSTRAINT fk_audit_logs_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants(id)
        ON DELETE CASCADE,
    
    CONSTRAINT fk_audit_logs_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE SET NULL
);

-- Partition by month for performance (declarative partitioning)
-- Create partitions programmatically

-- Indexes
CREATE INDEX idx_audit_logs_tenant ON audit_logs(tenant_id, created_at DESC);
CREATE INDEX idx_audit_logs_action ON audit_logs(action, created_at DESC);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id, created_at DESC);
CREATE INDEX idx_audit_logs_resource ON audit_logs(resource, resource_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_logs_success ON audit_logs(success) WHERE success = false;
CREATE INDEX idx_audit_logs_ip ON audit_logs(ip_address);

-- GIN indexes for JSON
CREATE INDEX idx_audit_logs_metadata ON audit_logs USING GIN(metadata);
CREATE INDEX idx_audit_logs_changes ON audit_logs USING GIN(changes);

-- Function to log action
CREATE OR REPLACE FUNCTION log_audit(
    p_tenant_id UUID,
    p_action audit_action,
    p_resource VARCHAR,
    p_resource_id UUID DEFAULT NULL,
    p_user_id UUID DEFAULT NULL,
    p_user_name VARCHAR DEFAULT NULL,
    p_method VARCHAR DEFAULT NULL,
    p_path TEXT DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_success BOOLEAN DEFAULT true,
    p_error_message TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO audit_logs (
        tenant_id,
        action,
        resource,
        resource_id,
        user_id,
        user_name,
        method,
        path,
        ip_address,
        success,
        error_message,
        metadata,
        created_at
    ) VALUES (
        p_tenant_id,
        p_action,
        p_resource,
        p_resource_id,
        p_user_id,
        p_user_name,
        p_method,
        p_path,
        p_ip_address,
        p_success,
        p_error_message,
        p_metadata,
        NOW()
    )
    RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get audit trail for resource
CREATE OR REPLACE FUNCTION get_audit_trail(
    p_resource VARCHAR,
    p_resource_id UUID,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE(
    action audit_action,
    user_name VARCHAR,
    success BOOLEAN,
    created_at TIMESTAMPTZ,
    metadata JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.action,
        a.user_name,
        a.success,
        a.created_at,
        a.metadata
    FROM audit_logs a
    WHERE a.resource = p_resource
      AND a.resource_id = p_resource_id
    ORDER BY a.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMMENT EDITS TABLE (edit history)
-- ============================================================================

CREATE TABLE IF NOT EXISTS comment_edits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    comment_id UUID NOT NULL,
    
    -- Edit Details
    previous_content TEXT NOT NULL,
    new_content TEXT NOT NULL,
    
    -- Editor
    edited_by UUID NOT NULL,
    reason TEXT, -- Optional reason for edit
    
    -- Diff (optional, can be computed)
    content_diff TEXT,
    
    -- Timestamp
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Foreign Keys
    CONSTRAINT fk_comment_edits_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants(id)
        ON DELETE CASCADE,
    
    CONSTRAINT fk_comment_edits_comment
        FOREIGN KEY (comment_id)
        REFERENCES comments(id)
        ON DELETE CASCADE,
    
    CONSTRAINT fk_comment_edits_user
        FOREIGN KEY (edited_by)
        REFERENCES users(id)
        ON DELETE SET NULL
);

-- Indexes
CREATE INDEX idx_comment_edits_comment ON comment_edits(comment_id, created_at DESC);
CREATE INDEX idx_comment_edits_user ON comment_edits(edited_by);
CREATE INDEX idx_comment_edits_tenant ON comment_edits(tenant_id);

-- Function to get edit history
CREATE OR REPLACE FUNCTION get_edit_history(p_comment_id UUID)
RETURNS TABLE(
    edit_id UUID,
    previous_content TEXT,
    new_content TEXT,
    edited_by_name VARCHAR,
    reason TEXT,
    edited_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ce.id,
        ce.previous_content,
        ce.new_content,
        u.display_name,
        ce.reason,
        ce.created_at
    FROM comment_edits ce
    LEFT JOIN users u ON ce.edited_by = u.id
    WHERE ce.comment_id = p_comment_id
    ORDER BY ce.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Comments
COMMENT ON TABLE sessions IS 'User sessions for JWT refresh token management';
COMMENT ON TABLE audit_logs IS 'Comprehensive audit trail of all system actions';
COMMENT ON TABLE comment_edits IS 'Edit history for comments showing all revisions';
COMMENT ON COLUMN sessions.refresh_token_hash IS 'SHA-256 hash of refresh token';
COMMENT ON COLUMN sessions.access_token_jti IS 'JWT ID for access token revocation';
COMMENT ON COLUMN audit_logs.metadata IS 'Flexible JSONB field for additional context';
COMMENT ON COLUMN audit_logs.changes IS 'Before/after state for update actions';
COMMENT ON FUNCTION log_audit IS 'Creates audit log entry for any action';
COMMENT ON FUNCTION get_audit_trail IS 'Returns complete audit history for a resource';
COMMENT ON FUNCTION get_edit_history IS 'Returns full edit history for a comment';
