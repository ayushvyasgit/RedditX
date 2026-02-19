-- Migration: 002_create_api_keys
-- Description: Create API keys table for tenant authentication
-- Author: System
-- Date: 2025-02-16

-- Create table for API keys (separate from tenants for security)
CREATE TABLE IF NOT EXISTS api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    
    -- API Key (stored as SHA-256 hash)
    key_hash VARCHAR(64) NOT NULL UNIQUE,
    
    -- Key Metadata
    name VARCHAR(255), -- User-friendly name for the key
    description TEXT,
    
    -- Scopes/Permissions (array of permission strings)
    scopes TEXT[] NOT NULL DEFAULT ARRAY['read', 'write'],
    
    -- Key Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    
    -- Usage Tracking
    last_used_at TIMESTAMPTZ,
    last_used_ip INET,
    total_requests INTEGER NOT NULL DEFAULT 0,
    
    -- Expiration
    expires_at TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    
    -- Foreign Key
    CONSTRAINT fk_api_keys_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants(id)
        ON DELETE CASCADE,
    
    -- Constraints
    CONSTRAINT api_keys_key_hash_length CHECK (char_length(key_hash) = 64),
    CONSTRAINT api_keys_scopes_not_empty CHECK (array_length(scopes, 1) > 0),
    CONSTRAINT api_keys_expiry_future CHECK (
        expires_at IS NULL OR expires_at > created_at
    )
);

-- Indexes for performance
CREATE INDEX idx_api_keys_tenant ON api_keys(tenant_id) WHERE revoked_at IS NULL;
CREATE INDEX idx_api_keys_hash ON api_keys(key_hash) WHERE revoked_at IS NULL AND is_active = true;
CREATE INDEX idx_api_keys_created_at ON api_keys(created_at DESC);
CREATE INDEX idx_api_keys_last_used ON api_keys(last_used_at DESC);
CREATE INDEX idx_api_keys_expires ON api_keys(expires_at) WHERE expires_at IS NOT NULL;

-- GIN index for scopes array
CREATE INDEX idx_api_keys_scopes ON api_keys USING GIN(scopes);

-- Trigger for updated_at
CREATE TRIGGER update_api_keys_updated_at
    BEFORE UPDATE ON api_keys
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to check if API key is valid
CREATE OR REPLACE FUNCTION is_api_key_valid(p_key_hash VARCHAR)
RETURNS TABLE(
    valid BOOLEAN,
    tenant_id UUID,
    scopes TEXT[],
    rate_limit_per_minute INTEGER,
    rate_limit_per_hour INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (ak.is_active 
         AND ak.revoked_at IS NULL 
         AND (ak.expires_at IS NULL OR ak.expires_at > NOW())
         AND t.status = 'ACTIVE'
        )::BOOLEAN as valid,
        t.id as tenant_id,
        ak.scopes,
        t.rate_limit_per_minute,
        t.rate_limit_per_hour
    FROM api_keys ak
    INNER JOIN tenants t ON ak.tenant_id = t.id
    WHERE ak.key_hash = p_key_hash;
END;
$$ LANGUAGE plpgsql;

-- Function to update last_used_at when key is used
CREATE OR REPLACE FUNCTION update_api_key_usage(
    p_key_hash VARCHAR,
    p_ip_address INET
)
RETURNS VOID AS $$
BEGIN
    UPDATE api_keys
    SET 
        last_used_at = NOW(),
        last_used_ip = p_ip_address,
        total_requests = total_requests + 1
    WHERE key_hash = p_key_hash;
END;
$$ LANGUAGE plpgsql;

-- Function to revoke API key
CREATE OR REPLACE FUNCTION revoke_api_key(p_key_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE api_keys
    SET 
        revoked_at = NOW(),
        is_active = false
    WHERE id = p_key_id;
END;
$$ LANGUAGE plpgsql;

-- Function to clean up expired keys (run periodically)
CREATE OR REPLACE FUNCTION cleanup_expired_api_keys()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    WITH deleted AS (
        DELETE FROM api_keys
        WHERE expires_at < NOW() - INTERVAL '90 days'
        AND revoked_at IS NOT NULL
        RETURNING 1
    )
    SELECT COUNT(*) INTO deleted_count FROM deleted;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Comments
COMMENT ON TABLE api_keys IS 'API keys for tenant authentication (keys stored as SHA-256 hashes)';
COMMENT ON COLUMN api_keys.key_hash IS 'SHA-256 hash of the actual API key';
COMMENT ON COLUMN api_keys.scopes IS 'Array of permission scopes (e.g., read, write, admin)';
COMMENT ON COLUMN api_keys.name IS 'User-friendly name to identify the key';
COMMENT ON COLUMN api_keys.last_used_at IS 'Timestamp of last successful authentication';
COMMENT ON COLUMN api_keys.expires_at IS 'Optional expiration date for the key';
COMMENT ON FUNCTION is_api_key_valid IS 'Validates API key and returns tenant info';
COMMENT ON FUNCTION update_api_key_usage IS 'Updates usage tracking when key is used';
COMMENT ON FUNCTION revoke_api_key IS 'Revokes an API key making it unusable';
COMMENT ON FUNCTION cleanup_expired_api_keys IS 'Removes old expired and revoked keys';
