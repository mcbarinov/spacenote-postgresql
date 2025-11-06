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
