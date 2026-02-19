-- Migration: 001_create_tenants
-- Description: Create tenants table for multi-tenancy support
-- Author: System
-- Date: 2025-02-16

-- Create ENUM types for tenant
CREATE TYPE tenant_status AS ENUM ('ACTIVE', 'SUSPENDED', 'INACTIVE', 'DELETED');
CREATE TYPE tenant_plan AS ENUM ('FREE', 'STARTER', 'BUSINESS', 'ENTERPRISE');

-- Create tenants table
CREATE TABLE IF NOT EXISTS tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Basic Information
    name VARCHAR(255) NOT NULL,
    subdomain VARCHAR(100) NOT NULL UNIQUE,
    
    -- Plan & Status
    plan tenant_plan NOT NULL DEFAULT 'FREE',
    status tenant_status NOT NULL DEFAULT 'ACTIVE',
    
    -- Rate Limiting Configuration
    rate_limit_per_minute INTEGER NOT NULL DEFAULT 100,
    rate_limit_per_hour INTEGER NOT NULL DEFAULT 5000,
    rate_limit_per_day INTEGER NOT NULL DEFAULT 50000,
    
    -- Feature Flags (JSONB for flexibility)
    features JSONB NOT NULL DEFAULT '{
        "comments_enabled": true,
        "likes_enabled": true,
        "real_time_enabled": false,
        "advanced_moderation": false,
        "custom_branding": false,
        "api_access": true,
        "webhooks_enabled": false,
        "analytics_enabled": false
    }'::jsonb,
    
    -- Settings (JSONB for flexibility)
    settings JSONB NOT NULL DEFAULT '{
        "moderation_mode": "auto",
        "spam_filter_enabled": true,
        "profanity_filter_enabled": true,
        "max_comment_length": 10000,
        "max_nesting_depth": 10,
        "allow_anonymous": false,
        "require_email_verification": true
    }'::jsonb,
    
    -- Contact & Billing
    contact_email VARCHAR(255),
    contact_name VARCHAR(255),
    billing_email VARCHAR(255),
    
    -- Usage Metrics (updated by triggers/jobs)
    total_comments INTEGER NOT NULL DEFAULT 0,
    total_users INTEGER NOT NULL DEFAULT 0,
    total_api_calls INTEGER NOT NULL DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    last_active_at TIMESTAMPTZ,
    
    -- Constraints
    CONSTRAINT tenants_subdomain_length CHECK (char_length(subdomain) >= 3),
    CONSTRAINT tenants_subdomain_format CHECK (subdomain ~* '^[a-z0-9-]+$'),
    CONSTRAINT tenants_name_not_empty CHECK (char_length(name) > 0),
    CONSTRAINT tenants_rate_limits_positive CHECK (
        rate_limit_per_minute > 0 AND
        rate_limit_per_hour > 0 AND
        rate_limit_per_day > 0
    )
);

-- Create indexes for performance
CREATE INDEX idx_tenants_subdomain ON tenants(subdomain) WHERE deleted_at IS NULL;
CREATE INDEX idx_tenants_status ON tenants(status) WHERE status = 'ACTIVE';
CREATE INDEX idx_tenants_plan ON tenants(plan);
CREATE INDEX idx_tenants_created_at ON tenants(created_at DESC);
CREATE INDEX idx_tenants_deleted_at ON tenants(deleted_at) WHERE deleted_at IS NOT NULL;

-- GIN index for JSONB fields (for efficient JSON queries)
CREATE INDEX idx_tenants_features ON tenants USING GIN(features);
CREATE INDEX idx_tenants_settings ON tenants USING GIN(settings);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to tenants table
CREATE TRIGGER update_tenants_updated_at
    BEFORE UPDATE ON tenants
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create function to validate tenant before operations
CREATE OR REPLACE FUNCTION validate_tenant_active()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Cannot modify deleted tenant';
    END IF;
    
    IF NEW.status = 'DELETED' THEN
        NEW.deleted_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_tenant_before_update
    BEFORE UPDATE ON tenants
    FOR EACH ROW
    EXECUTE FUNCTION validate_tenant_active();

-- Comments for documentation
COMMENT ON TABLE tenants IS 'Stores tenant/customer information for multi-tenancy';
COMMENT ON COLUMN tenants.subdomain IS 'Unique subdomain identifier (e.g., "acme" for acme.comments-api.com)';
COMMENT ON COLUMN tenants.plan IS 'Subscription plan level determining features and rate limits';
COMMENT ON COLUMN tenants.features IS 'Feature flags in JSON format for easy enablement/disablement';
COMMENT ON COLUMN tenants.settings IS 'Tenant-specific configuration settings';
COMMENT ON COLUMN tenants.rate_limit_per_minute IS 'Maximum API requests allowed per minute';
COMMENT ON COLUMN tenants.rate_limit_per_hour IS 'Maximum API requests allowed per hour';
COMMENT ON COLUMN tenants.rate_limit_per_day IS 'Maximum API requests allowed per day';

-- Insert default system tenant for testing
INSERT INTO tenants (
    id,
    name,
    subdomain,
    plan,
    status,
    rate_limit_per_minute,
    rate_limit_per_hour,
    rate_limit_per_day,
    contact_email
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    'System',
    'system',
    'ENTERPRISE',
    'ACTIVE',
    10000,
    500000,
    5000000,
    'admin@system.local'
) ON CONFLICT (id) DO NOTHING;
