-- Migration: 003_create_users
-- Description: Create users table with role-based access control
-- Author: System
-- Date: 2025-02-16

-- Create ENUM types for users
CREATE TYPE user_role AS ENUM ('GUEST', 'USER', 'MODERATOR', 'ADMIN', 'SUPER_ADMIN');
CREATE TYPE user_status AS ENUM ('ACTIVE', 'SUSPENDED', 'BANNED', 'DELETED');

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    
    -- Authentication
    username VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    email_verified BOOLEAN NOT NULL DEFAULT false,
    password_hash VARCHAR(255), -- bcrypt hash, NULL for OAuth users
    
    -- Profile
    display_name VARCHAR(255),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    avatar_url TEXT,
    bio TEXT,
    website VARCHAR(500),
    location VARCHAR(255),
    
    -- Role & Permissions
    role user_role NOT NULL DEFAULT 'USER',
    custom_permissions TEXT[] DEFAULT ARRAY[]::TEXT[],
    
    -- Status
    status user_status NOT NULL DEFAULT 'ACTIVE',
    
    -- OAuth (for third-party authentication)
    oauth_provider VARCHAR(50), -- 'google', 'github', 'facebook', etc.
    oauth_id VARCHAR(255),
    
    -- Metadata (JSONB for extensibility)
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    
    -- Preferences
    preferences JSONB NOT NULL DEFAULT '{
        "email_notifications": true,
        "push_notifications": false,
        "newsletter": false,
        "language": "en",
        "timezone": "UTC",
        "theme": "light"
    }'::jsonb,
    
    -- Security
    two_factor_enabled BOOLEAN NOT NULL DEFAULT false,
    two_factor_secret VARCHAR(32),
    failed_login_attempts INTEGER NOT NULL DEFAULT 0,
    locked_until TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    last_login_at TIMESTAMPTZ,
    email_verified_at TIMESTAMPTZ,
    
    -- Foreign Keys
    CONSTRAINT fk_users_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants(id)
        ON DELETE CASCADE,
    
    -- Unique Constraints (tenant-scoped)
    CONSTRAINT unique_users_tenant_email UNIQUE (tenant_id, email),
    CONSTRAINT unique_users_tenant_username UNIQUE (tenant_id, username),
    CONSTRAINT unique_users_oauth UNIQUE (tenant_id, oauth_provider, oauth_id),
    
    -- Check Constraints
    CONSTRAINT users_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT users_username_format CHECK (username ~* '^[a-zA-Z0-9_-]+$'),
    CONSTRAINT users_username_length CHECK (char_length(username) >= 3 AND char_length(username) <= 100),
    CONSTRAINT users_password_or_oauth CHECK (
        (password_hash IS NOT NULL AND oauth_provider IS NULL) OR
        (password_hash IS NULL AND oauth_provider IS NOT NULL) OR
        (password_hash IS NOT NULL AND oauth_provider IS NOT NULL)
    )
);

-- Indexes for performance
CREATE INDEX idx_users_tenant ON users(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_email ON users(tenant_id, email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_username ON users(tenant_id, username) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_status ON users(status) WHERE status = 'ACTIVE';
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_created_at ON users(created_at DESC);
CREATE INDEX idx_users_last_login ON users(last_login_at DESC);
CREATE INDEX idx_users_oauth ON users(oauth_provider, oauth_id) WHERE oauth_provider IS NOT NULL;

-- GIN indexes for JSONB
CREATE INDEX idx_users_metadata ON users USING GIN(metadata);
CREATE INDEX idx_users_preferences ON users USING GIN(preferences);
CREATE INDEX idx_users_permissions ON users USING GIN(custom_permissions);

-- Full-text search index on user profile
CREATE INDEX idx_users_search ON users USING GIN(
    to_tsvector('english', 
        COALESCE(display_name, '') || ' ' || 
        COALESCE(first_name, '') || ' ' || 
        COALESCE(last_name, '') || ' ' || 
        COALESCE(bio, '')
    )
);

-- Trigger for updated_at
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to verify email
CREATE OR REPLACE FUNCTION verify_user_email(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE users
    SET 
        email_verified = true,
        email_verified_at = NOW()
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- Function to increment failed login attempts
CREATE OR REPLACE FUNCTION increment_failed_login(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    new_attempts INTEGER;
BEGIN
    UPDATE users
    SET failed_login_attempts = failed_login_attempts + 1
    WHERE id = p_user_id
    RETURNING failed_login_attempts INTO new_attempts;
    
    -- Lock account after 5 failed attempts for 30 minutes
    IF new_attempts >= 5 THEN
        UPDATE users
        SET locked_until = NOW() + INTERVAL '30 minutes'
        WHERE id = p_user_id;
    END IF;
    
    RETURN new_attempts;
END;
$$ LANGUAGE plpgsql;

-- Function to reset failed login attempts on successful login
CREATE OR REPLACE FUNCTION reset_failed_login(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE users
    SET 
        failed_login_attempts = 0,
        locked_until = NULL,
        last_login_at = NOW()
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- Function to check if user has permission
CREATE OR REPLACE FUNCTION user_has_permission(
    p_user_id UUID,
    p_permission TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    user_role_value user_role;
    user_permissions TEXT[];
BEGIN
    SELECT role, custom_permissions INTO user_role_value, user_permissions
    FROM users
    WHERE id = p_user_id AND deleted_at IS NULL;
    
    -- Super admin has all permissions
    IF user_role_value = 'SUPER_ADMIN' THEN
        RETURN true;
    END IF;
    
    -- Check custom permissions
    IF p_permission = ANY(user_permissions) THEN
        RETURN true;
    END IF;
    
    -- Check role-based permissions
    RETURN CASE user_role_value
        WHEN 'ADMIN' THEN p_permission IN (
            'comment:create', 'comment:read', 'comment:update', 'comment:delete',
            'comment:hard_delete', 'user:manage'
        )
        WHEN 'MODERATOR' THEN p_permission IN (
            'comment:create', 'comment:read', 'comment:update', 'comment:delete'
        )
        WHEN 'USER' THEN p_permission IN (
            'comment:create', 'comment:read', 'comment:update_own', 'comment:delete_own'
        )
        WHEN 'GUEST' THEN p_permission IN (
            'comment:read'
        )
        ELSE false
    END;
END;
$$ LANGUAGE plpgsql;

-- Function to get users by role
CREATE OR REPLACE FUNCTION get_users_by_role(
    p_tenant_id UUID,
    p_role user_role
)
RETURNS TABLE(
    user_id UUID,
    username VARCHAR,
    email VARCHAR,
    display_name VARCHAR,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        id,
        username,
        email,
        display_name,
        created_at
    FROM users
    WHERE tenant_id = p_tenant_id
      AND role = p_role
      AND deleted_at IS NULL
    ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Trigger to increment tenant user count
CREATE OR REPLACE FUNCTION update_tenant_user_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE tenants
        SET total_users = total_users + 1
        WHERE id = NEW.tenant_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE tenants
        SET total_users = total_users - 1
        WHERE id = OLD.tenant_id;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_tenant_users_count
    AFTER INSERT OR DELETE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_tenant_user_count();

-- Comments
COMMENT ON TABLE users IS 'User accounts with role-based access control';
COMMENT ON COLUMN users.role IS 'User role determining base permissions';
COMMENT ON COLUMN users.custom_permissions IS 'Additional permissions beyond role defaults';
COMMENT ON COLUMN users.password_hash IS 'Bcrypt hash of password (NULL for OAuth-only users)';
COMMENT ON COLUMN users.oauth_provider IS 'OAuth provider if using third-party auth';
COMMENT ON COLUMN users.two_factor_enabled IS 'Whether 2FA is enabled for this user';
COMMENT ON COLUMN users.failed_login_attempts IS 'Counter for failed login attempts (resets on success)';
COMMENT ON COLUMN users.locked_until IS 'Account locked until this timestamp after too many failed logins';
COMMENT ON FUNCTION user_has_permission IS 'Checks if user has specific permission based on role and custom permissions';
COMMENT ON FUNCTION increment_failed_login IS 'Increments failed login counter and locks account if threshold exceeded';
COMMENT ON FUNCTION reset_failed_login IS 'Resets failed login counter on successful authentication';

-- Create default admin user for system tenant
INSERT INTO users (
    id,
    tenant_id,
    username,
    email,
    email_verified,
    display_name,
    role,
    status
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    'system_admin',
    'admin@system.local',
    true,
    'System Administrator',
    'SUPER_ADMIN',
    'ACTIVE'
) ON CONFLICT (id) DO NOTHING;
