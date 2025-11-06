# SpaceNote PostgreSQL Project Instructions

## Context

This is an experimental fork of SpaceNote testing PostgreSQL as an alternative to MongoDB. Before making any changes or suggestions, **you MUST read and understand the README.md file** to understand:

- The project's goals and hypothesis
- The problems with the MongoDB implementation we're trying to solve
- The three key issues: dual identity system, opaque field references, and lack of referential integrity
- How PostgreSQL is expected to address these issues

## Key Requirements

1. **Always read README.md first** - The README contains critical context about why this experiment exists and what problems we're solving
2. Maintain awareness of the original MongoDB implementation at [spacenote-backend](https://github.com/spacenote-projects/spacenote-backend)
3. Focus on PostgreSQL's strengths: referential integrity, human-readable identifiers, and transparent data relationships

## SQL Schema Files Structure

When working with `sql/init.sql` or other schema files, **STRICTLY follow this structure**:

### File Organization (top to bottom):

1. **CREATE TABLE statements** - All table definitions first
2. **CREATE INDEX statements** - All indexes after tables
3. **DATABASE METADATA block** - MUST be at the very end of the file

### CRITICAL: DATABASE METADATA block placement

The `DATABASE METADATA` block with all `COMMENT ON` statements **MUST ALWAYS BE AT THE VERY END** of the SQL file, after all CREATE TABLE and CREATE INDEX statements.

**❌ WRONG - Comments scattered throughout:**
```sql
CREATE TABLE users (...);
COMMENT ON TABLE users IS '...';  -- ❌ Too early!

CREATE TABLE sessions (...);
COMMENT ON TABLE sessions IS '...';  -- ❌ Too early!
```

**✅ CORRECT - All comments in one block at the end:**
```sql
-- First: All tables
CREATE TABLE users (...);
CREATE TABLE sessions (...);
CREATE TABLE spaces (...);

-- Second: All indexes
CREATE INDEX idx_sessions_username ON sessions(username);
CREATE INDEX idx_spaces_slug ON spaces(slug);

-- Third: DATABASE METADATA block - MUST BE LAST!
-- ==============================================================================
-- DATABASE METADATA (for psql \d+ command)
-- ==============================================================================

COMMENT ON TABLE users IS '...';
COMMENT ON COLUMN users.username IS '...';
COMMENT ON TABLE sessions IS '...';
COMMENT ON COLUMN sessions.auth_token IS '...';
COMMENT ON TABLE spaces IS '...';
```

**Rationale:**
- Easy navigation - see all schema definitions first, documentation second
- Maintainability - one place for all metadata, never scattered
- Consistency - predictable file structure across all SQL files

**Always use TIMESTAMPTZ:**
- Use `TIMESTAMPTZ` for all timestamp fields, never `TIMESTAMP`
- See README.md "Architectural Decisions #2" for rationale
