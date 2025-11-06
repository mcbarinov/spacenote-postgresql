-- SpaceNote PostgreSQL Schema
-- This schema implements human-readable identifiers as primary keys
-- to solve MongoDB's dual identity system, opaque references, and lack of referential integrity

-- ==============================================================================
-- USERS TABLE
-- ==============================================================================

CREATE TABLE users (
    username VARCHAR(50) PRIMARY KEY CHECK (username ~ '^[a-z0-9_-]+$'),  -- Human-readable username: a-z, 0-9, -, _
    password_hash TEXT NOT NULL,  -- bcrypt hash
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()  -- Registration timestamp
);

-- ==============================================================================
-- SESSIONS TABLE
-- ==============================================================================

CREATE TABLE sessions (
    auth_token VARCHAR(255) PRIMARY KEY,  -- Auth token for lookups
    username VARCHAR(50) NOT NULL REFERENCES users(username) ON DELETE CASCADE,  -- Owner
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),  -- Session start
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),  -- 30-day TTL
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW()  -- Last activity
);

CREATE INDEX idx_sessions_username ON sessions(username);
CREATE INDEX idx_sessions_expires_at ON sessions(expires_at);
CREATE INDEX idx_sessions_last_active ON sessions(last_active_at);

-- ==============================================================================
-- SPACES TABLE
-- ==============================================================================

CREATE TABLE spaces (
    slug VARCHAR(100) PRIMARY KEY
        CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),  -- Validate slug format: lowercase, numbers, hyphens only

    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL DEFAULT '',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- SPACE_MEMBERS TABLE
-- ==============================================================================

CREATE TABLE space_members (
    space_slug VARCHAR(100) NOT NULL,
    username VARCHAR(50) NOT NULL,

    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (space_slug, username),

    FOREIGN KEY (space_slug) REFERENCES spaces(slug)
        ON UPDATE CASCADE  -- If space slug changes, update all memberships
        ON DELETE CASCADE,  -- If space deleted, remove all memberships

    FOREIGN KEY (username) REFERENCES users(username)
        ON UPDATE CASCADE  -- If username changes, update all memberships
        ON DELETE RESTRICT  -- Prevent deleting user with active space memberships
);

CREATE INDEX idx_space_members_username ON space_members(username);  -- Find all spaces for a user
CREATE INDEX idx_space_members_space ON space_members(space_slug);   -- Find all members of a space

-- ==============================================================================
-- DATABASE METADATA (for psql \d+ command)
-- ==============================================================================

COMMENT ON TABLE users IS 'User accounts with human-readable usernames as primary keys';
COMMENT ON COLUMN users.username IS 'Lowercase letters, numbers, hyphens, and underscores only';
COMMENT ON COLUMN users.password_hash IS 'bcrypt hash of user password';

COMMENT ON TABLE sessions IS 'User authentication sessions with 30-day TTL';
COMMENT ON COLUMN sessions.auth_token IS 'Primary key for fast token-based lookups';
COMMENT ON COLUMN sessions.username IS 'Foreign key to users - cascades on delete for referential integrity';
COMMENT ON COLUMN sessions.expires_at IS 'Expiration timestamp - cleanup via periodic background job';
COMMENT ON COLUMN sessions.last_active_at IS 'Updated on each authenticated request for activity tracking';

COMMENT ON TABLE spaces IS 'Project spaces with human-readable slugs as primary keys';
COMMENT ON COLUMN spaces.slug IS 'Globally unique slug - lowercase letters, numbers, and hyphens only';
COMMENT ON COLUMN spaces.title IS 'Human-readable space name displayed in UI';

COMMENT ON TABLE space_members IS 'Many-to-many relationship between users and spaces they have access to';
COMMENT ON COLUMN space_members.space_slug IS 'Foreign key with CASCADE - slug changes propagate automatically';
COMMENT ON COLUMN space_members.username IS 'Foreign key with RESTRICT - prevents deleting users with active memberships';
