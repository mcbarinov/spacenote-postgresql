# SpaceNote PostgreSQL Experiment

This is an experimental fork of SpaceNote to test the hypothesis: **Would PostgreSQL be a better fit than MongoDB for the SpaceNote project?**

## About SpaceNote

SpaceNote is a flexible note-taking system with customizable spaces. Users can create spaces with custom fields, filters, and structures tailored to their specific needs.

## MongoDB Implementation Issues

The current MongoDB implementation has several pain points that we hope to address with PostgreSQL:

### 1. Dual Identity System

The core module operates with UUID identifiers internally, but the API exposes human-readable identifiers (usernames, space slugs, note numbers). This creates unnecessary complexity and cognitive overhead.

**Current state:**
- Core: `note_id: UUID('550e8400-e29b-41d4-a716-446655440000')`
- API: `GET /spaces/{space_slug}/notes/{note_number}`

**Desired state:** A unified system with human-readable identifiers throughout the stack.

### 2. Opaque Field References

Notes contain fields that reference other entities (users, attachments, etc.), but these are stored as UUIDs. This makes the data incomprehensible to both humans and AI agents.

**Problem:**
- `FieldType.USER` → `"550e8400-e29b-41d4-a716-446655440000"`
- `FieldType.IMAGE` → `"7c9e6679-7425-40de-944b-e07fc1f90ae7"`

This is particularly problematic since AI agents are a core use case for SpaceNote - they need to understand and work with project data effectively.

### 3. No Referential Integrity

MongoDB doesn't enforce referential integrity, so `note.fields` can contain references to non-existent users or deleted attachments. There's no database-level validation preventing invalid references.

**Issues:**
- Can reference a user that doesn't exist
- Can reference a deleted attachment
- No cascading updates or deletes
- Application layer must handle all consistency checks

## Original Implementation

The original MongoDB-based implementation: [spacenote-backend](https://github.com/spacenote-projects/spacenote-backend)

## Status

**Experiment in Progress** - This repository is being used to evaluate PostgreSQL as an alternative database backend.

## Architectural Decisions

This section documents key architectural decisions made in the PostgreSQL implementation.

### 1. Natural Keys with Domain-Specific Names

**Decision:** Use natural keys (username, slug, etc.) as primary keys, and keep their domain-specific names rather than renaming them to generic `id`.

**Rationale:**
- The name `id` semantically implies a surrogate key with no business meaning (e.g., SERIAL, UUID)
- Domain-specific names make it immediately clear what the key represents
- Aligns with PostgreSQL community best practice: "When using natural keys, keep the domain-specific name. Reserve 'id' for surrogate keys only."
- Supports our goal of human and AI readability - data is self-documenting

**Implementation:**
```sql
-- ✅ Natural key with domain-specific name
CREATE TABLE users (
    username VARCHAR(50) PRIMARY KEY,
    password_hash TEXT NOT NULL,
    ...
);

-- ❌ Avoided: Surrogate key approach
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE,
    ...
);
```

**Trade-offs:**
- Natural keys may require cascading updates if the key value changes (acceptable at our scale of 10 users)
- Less familiar to developers accustomed to surrogate key conventions (id SERIAL)
- Benefits: Eliminates dual identity system, data is human-readable throughout the stack

**Why This Works for SpaceNote:**

Natural keys are not unusual - they're a standard PostgreSQL practice when you have stable, meaningful identifiers. Real-world examples include:
- Country/currency codes: `countries(country_code CHAR(2))`, `currencies(currency_code CHAR(3))`
- Product catalogs: `products(sku VARCHAR(50))`
- Multi-tenant systems: `tenants(tenant_slug VARCHAR(100))`

The "unfamiliarity" concern comes from Rails/Django conventions where `id SERIAL` is the default. But PostgreSQL community practice is clear: **use natural keys when you have stable natural identifiers**.

**Why cascading updates aren't a problem:**

Given our scale (10 users, 100 spaces), the performance impact of cascading updates is negligible:
- Username changes are rare (maybe once per year per user)
- Space slug changes are rare (during initial setup only)
- Even if we update a username with 10,000 notes referencing it, PostgreSQL handles this instantly with proper indexes
- Our Scale Considerations (line 151) explicitly accept "temporary freezes during critical identifier changes"

**The surrogate key alternative (id BIGSERIAL + Views):**

We considered using surrogate keys in tables but exposing human-readable identifiers via Views. This approach has fatal flaws:
- **Dual identity problem persists** - just moves from "Core vs API" to "Tables vs Views"
- **Database data remains opaque** - debugging SQL queries shows `user_id=12345` instead of `username='john'`
- **Views don't solve write operations** - INSERT/UPDATE still use numeric IDs
- **Additional complexity** - maintain two parallel systems (tables + views)
- **Contradicts our priorities** - we prioritize "human and AI readability" over marginal performance gains

With natural keys, relationships are immediately visible in query results without additional joins - invaluable for debugging, AI agent comprehension, and database exploration.

**References:**
- PostgreSQL community naming conventions
- Addresses MongoDB Issue #1: Dual Identity System

### 2. Always Use TIMESTAMPTZ for Timestamps

**Decision:** Use `TIMESTAMPTZ` (timestamp with time zone) for all timestamp fields, never `TIMESTAMP` (timestamp without time zone).

**Rationale:**
- PostgreSQL best practice: Official documentation recommends always using `TIMESTAMPTZ`
- **Unambiguous time representation** - always know the exact moment, regardless of timezone
- **Automatic timezone conversion** - PostgreSQL stores everything in UTC internally, converts on read
- **Future-proof** - even if all users are in one timezone today, this prevents issues if that changes
- **No performance penalty** - both types use 8 bytes, no difference in storage or speed

**Implementation:**
```sql
-- ✅ Always use TIMESTAMPTZ
created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

-- ❌ Never use plain TIMESTAMP
created_at TIMESTAMP NOT NULL DEFAULT NOW()  -- Ambiguous! What timezone?
```

**How it works:**
- When inserting: PostgreSQL converts your input time to UTC based on session timezone
- When reading: PostgreSQL converts UTC back to your session timezone
- The database always knows the absolute moment in time

**Example:**
```sql
SET timezone = 'Europe/Moscow';  -- UTC+3
INSERT INTO users VALUES ('john', 'hash', NOW());
-- Stored internally: 2025-01-15 08:00:00 UTC

SET timezone = 'America/New_York';  -- UTC-5
SELECT created_at FROM users WHERE username = 'john';
-- Returns: 2025-01-15 03:00:00 (automatically converted to NYC time)
```

**Trade-offs:**
- None - TIMESTAMPTZ is strictly better than TIMESTAMP
- Only "downside" is needing to type 2 extra characters

**References:**
- [PostgreSQL Documentation on Date/Time Types](https://www.postgresql.org/docs/current/datatype-datetime.html)
- Quote: "For timestamp values, we recommend using `timestamptz`"

---

*This section will grow as we make additional architectural decisions.*

## Goals

- Compare PostgreSQL's relational model vs MongoDB's document model for SpaceNote's use cases
- Evaluate query performance and complexity
- Assess schema flexibility and migration patterns
- Determine which database better suits SpaceNote's architecture

## Scale Considerations

This project operates at a specific scale that informs our design decisions:

**Expected Scale:**
- Up to 10 users
- Up to 100 spaces
- Up to 1,000,000 notes

**Design Priorities:**
1. **Simplicity over performance** - Data structures should be easy to understand and work with
2. **Human and AI readability over performance** - Data should be comprehensible to both humans and AI agents without additional lookups
3. **Acceptable tradeoffs:**
   - Text-based indexing being slower than numeric indexing is acceptable
   - Temporary freezes during critical identifier changes (username, space slug) are acceptable
   - Slightly slower queries are acceptable if they make the data more readable

These constraints allow us to prioritize human-readable identifiers (usernames, space slugs) as primary keys, even though numeric/UUID keys might offer marginal performance benefits at larger scales.
