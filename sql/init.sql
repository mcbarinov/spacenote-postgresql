-- SpaceNote PostgreSQL Schema
-- This schema implements human-readable identifiers as primary keys
-- to solve MongoDB's dual identity system, opaque references, and lack of referential integrity

-- ==============================================================================
-- USERS TABLE
-- ==============================================================================

CREATE TABLE users (
    username VARCHAR(50) PRIMARY KEY CHECK (username ~ '^[a-z0-9_-]+$'),
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE users IS 'User accounts with human-readable usernames as primary keys';
COMMENT ON COLUMN users.username IS 'Lowercase letters, numbers, hyphens, and underscores only';
COMMENT ON COLUMN users.password_hash IS 'bcrypt hash of user password';

-- ==============================================================================
-- SESSIONS TABLE
-- ==============================================================================

CREATE TABLE sessions (
    auth_token VARCHAR(255) PRIMARY KEY,
    username VARCHAR(50) NOT NULL REFERENCES users(username) ON DELETE CASCADE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
    last_active_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sessions_username ON sessions(username);
CREATE INDEX idx_sessions_expires_at ON sessions(expires_at);
CREATE INDEX idx_sessions_last_active ON sessions(last_active_at);

COMMENT ON TABLE sessions IS 'User authentication sessions with 30-day TTL';
COMMENT ON COLUMN sessions.auth_token IS 'Primary key for fast token-based lookups';
COMMENT ON COLUMN sessions.username IS 'Foreign key to users - cascades on delete for referential integrity';
COMMENT ON COLUMN sessions.expires_at IS 'Expiration timestamp - cleanup via periodic background job';
COMMENT ON COLUMN sessions.last_active_at IS 'Updated on each authenticated request for activity tracking';
