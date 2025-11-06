# MongoDB Alternative Implementation

This document describes an **alternative MongoDB-based implementation** that addresses the core issues identified in the original [spacenote-backend](https://github.com/spacenote-projects/spacenote-backend) while staying within MongoDB's capabilities.

## Core Principle

**All collections have `_id: ObjectId` (MongoDB standard), but we NEVER use `_id` in application code.**

Instead, we always use human-readable, meaningful identifiers:
- Users identified by `username`
- Spaces identified by `slug`
- Notes identified by `(space_slug, number)` composite
- Attachments identified by `(space_slug, number)` composite
- Sessions identified by `auth_token`

This creates a **unified identifier system** throughout the entire stack (database, core, API) while maintaining MongoDB's internal `_id` requirement.

## Collections Schema

### Users Collection

```javascript
{
    _id: ObjectId("..."),        // MongoDB internal ID (never used in code)
    username: "john",             // PRIMARY IDENTIFIER - used everywhere
    password_hash: "bcrypt...",
    created_at: ISODate("2025-01-15T10:00:00Z")
}
```

**Indexes:**
- `username` - unique index (used for all queries)

**Code usage:**
```python
# ✅ Always use username
user = await user_service.get_user(username="john")

# ❌ Never use _id
user = await user_service.get_user(user_id=ObjectId("..."))  # DON'T DO THIS
```

---

### Spaces Collection

```javascript
{
    _id: ObjectId("..."),        // MongoDB internal ID (never used in code)
    slug: "my-tasks",            // PRIMARY IDENTIFIER - used everywhere
    title: "My Tasks",
    description: "Personal task tracker",
    members: ["john", "alice"],  // ✅ Usernames, NOT ObjectIds
    fields: [
        {
            id: "assigned_to",
            name: "Assigned To",
            type: "USER",
            required: false
        },
        {
            id: "thumbnail",
            name: "Thumbnail",
            type: "IMAGE",
            required: false
        }
    ],
    created_at: ISODate("2025-01-15T10:00:00Z"),
    updated_at: ISODate("2025-01-15T10:00:00Z")
}
```

**Indexes:**
- `slug` - unique index (used for all queries)
- `members` - multikey index (for filtering spaces by member)

**Code usage:**
```python
# ✅ Always use slug
space = await space_service.get_space(slug="my-tasks")

# ❌ Never use _id
space = await space_service.get_space(space_id=ObjectId("..."))  # DON'T DO THIS
```

---

### Notes Collection

```javascript
{
    _id: ObjectId("..."),             // MongoDB internal ID (never used in code)
    space_slug: "my-tasks",           // Part of composite identifier
    number: 42,                       // Part of composite identifier (unique per space)
    created_by: "john",               // ✅ Username, NOT ObjectId
    created_at: ISODate("2025-01-15T10:00:00Z"),
    edited_at: ISODate("2025-01-15T11:00:00Z"),
    activity_at: ISODate("2025-01-15T11:00:00Z"),
    fields: {
        "title": "Implement user authentication",
        "status": "in_progress",
        "assigned_to": "alice",       // ✅ Username (FieldType.USER)
        "thumbnail": 15,              // ✅ Attachment number (FieldType.IMAGE)
        "priority": 3
    }
}
```

**Indexes:**
- `(space_slug, number)` - compound unique index (composite primary key)
- `space_slug` - for listing all notes in a space
- `created_by` - for filtering by creator

**Code usage:**
```python
# ✅ Always use (space_slug, number) composite
note = await note_service.get_note(space_slug="my-tasks", number=42)

# ❌ Never use _id
note = await note_service.get_note(note_id=ObjectId("..."))  # DON'T DO THIS
```

---

### Attachments Collection

```javascript
{
    _id: ObjectId("..."),        // MongoDB internal ID (never used in code)
    space_slug: "my-tasks",      // Part of composite identifier
    number: 15,                  // Part of composite identifier (unique per space)
    note_number: 42,             // Optional - which note it's attached to
    uploaded_by: "john",         // ✅ Username, NOT ObjectId
    filename: "screenshot.png",
    size: 1024000,
    mime_type: "image/png",
    created_at: ISODate("2025-01-15T10:00:00Z")
}
```

**Indexes:**
- `(space_slug, number)` - compound unique index (composite primary key)
- `space_slug` - for listing all attachments in a space
- `(space_slug, note_number)` - for getting all attachments for a note

**Code usage:**
```python
# ✅ Always use (space_slug, number) composite
attachment = await attachment_service.get_attachment(
    space_slug="my-tasks",
    number=15
)

# ❌ Never use _id
attachment = await attachment_service.get_attachment(
    attachment_id=ObjectId("...")
)  # DON'T DO THIS
```

---

### Sessions Collection

```javascript
{
    _id: ObjectId("..."),                    // MongoDB internal ID (never used in code)
    auth_token: "a1b2c3d4e5f6...",          // PRIMARY IDENTIFIER (64-char hex)
    username: "john",                        // ✅ Username, NOT ObjectId
    created_at: ISODate("2025-01-15T10:00:00Z"),
    expires_at: ISODate("2025-02-14T10:00:00Z"),
    last_active_at: ISODate("2025-01-15T12:00:00Z")
}
```

**Indexes:**
- `auth_token` - unique index (used for all authentication)
- `username` - for listing user's sessions
- `expires_at` - for TTL cleanup

**Code usage:**
```python
# ✅ Always use auth_token
session = await session_service.get_session(auth_token="a1b2c3d4e5f6...")

# ❌ Never use _id
session = await session_service.get_session(session_id=ObjectId("..."))  # DON'T DO THIS
```

---

## Key Differences from Original Implementation

### 1. No Dual Identity System

**Original (spacenote-backend):**
- Core layer: Everything uses UUID (`user_id`, `space_id`, `note_id`)
- API layer: Uses human-readable identifiers (`username`, `slug`, `number`)
- Constant translation between the two systems

**Alternative:**
- **Unified system**: Human-readable identifiers everywhere (database, core, API)
- No translation layer needed
- Code is simpler and more intuitive

### 2. Transparent Field References

**Original (spacenote-backend):**
```javascript
// ❌ Opaque - who is this? what is this?
{
    "assigned_to": UUID("7b8c9d0e-1f2g-3h4i-5j6k-7l8m9n0o1p2q"),
    "thumbnail": UUID("550e8400-e29b-41d4-a716-446655440000")
}
```

**Alternative:**
```javascript
// ✅ Transparent - immediately comprehensible
{
    "assigned_to": "alice",    // Clearly a user named Alice
    "thumbnail": 15            // Attachment #15 in this space
}
```

**Benefits:**
- **Humans can read the data** - No need to look up UUIDs
- **AI agents can understand the data** - Critical for SpaceNote's core use case
- **Database queries are self-documenting** - Query results show meaningful values

### 3. API Methods Use Human-Readable Identifiers

**Service layer examples:**

```python
# User service
class UserService:
    async def get_user(self, username: str) -> User:
        """Get user by username (NOT by _id)"""
        return await self.db.users.find_one({"username": username})

    async def create_user(self, username: str, password: str) -> User:
        """Create user - MongoDB generates _id, but we ignore it"""
        user = {
            "username": username,
            "password_hash": bcrypt.hash(password),
            "created_at": datetime.now()
        }
        await self.db.users.insert_one(user)
        return user

# Space service
class SpaceService:
    async def get_space(self, slug: str) -> Space:
        """Get space by slug (NOT by _id)"""
        return await self.db.spaces.find_one({"slug": slug})

# Note service
class NoteService:
    async def get_note(self, space_slug: str, number: int) -> Note:
        """Get note by composite key (NOT by _id)"""
        return await self.db.notes.find_one({
            "space_slug": space_slug,
            "number": number
        })

# Attachment service
class AttachmentService:
    async def get_attachment(self, space_slug: str, number: int) -> Attachment:
        """Get attachment by composite key (NOT by _id)"""
        return await self.db.attachments.find_one({
            "space_slug": space_slug,
            "number": number
        })
```

**API endpoints:**
```python
# ✅ All endpoints use human-readable identifiers
GET    /spaces/{space_slug}/notes/{note_number}
PATCH  /spaces/{space_slug}/notes/{note_number}
DELETE /spaces/{space_slug}/notes/{note_number}

# No UUID-based endpoints needed
```

---

## Data Examples

### Example 1: Note with User Reference

**MongoDB document:**
```javascript
{
    _id: ObjectId("67890..."),     // Ignored in code
    space_slug: "project-alpha",
    number: 123,
    created_by: "john",
    created_at: ISODate("2025-01-15T10:00:00Z"),
    fields: {
        "title": "Design database schema",
        "assigned_to": "alice",    // ✅ Human-readable username
        "reviewer": "bob",          // ✅ Human-readable username
        "status": "in_review"
    }
}
```

**What this looks like when queried:**
```python
note = await note_service.get_note(space_slug="project-alpha", number=123)

print(note.fields["assigned_to"])  # Prints: "alice"
print(note.fields["reviewer"])     # Prints: "bob"
# No UUID lookups needed - data is immediately comprehensible
```

---

### Example 2: Note with Attachment Reference

**MongoDB documents:**

**Attachment:**
```javascript
{
    _id: ObjectId("abc123..."),      // Ignored in code
    space_slug: "project-alpha",
    number: 47,                      // Unique within space
    uploaded_by: "john",
    filename: "wireframe.png",
    mime_type: "image/png",
    size: 2048000,
    created_at: ISODate("2025-01-15T10:00:00Z")
}
```

**Note referencing the attachment:**
```javascript
{
    _id: ObjectId("def456..."),      // Ignored in code
    space_slug: "project-alpha",
    number: 124,
    created_by: "john",
    fields: {
        "title": "Review wireframe",
        "thumbnail": 47,             // ✅ References attachment by number
        "assigned_to": "alice"
    }
}
```

**Code to resolve the reference:**
```python
note = await note_service.get_note(space_slug="project-alpha", number=124)

# Get the attachment referenced in the thumbnail field
attachment_number = note.fields["thumbnail"]  # 47
attachment = await attachment_service.get_attachment(
    space_slug="project-alpha",
    number=attachment_number
)

print(attachment.filename)  # Prints: "wireframe.png"
```

---

### Example 3: Comparison with Original Implementation

**Original spacenote-backend (opaque):**
```javascript
{
    "_id": UUID("550e8400-e29b-41d4-a716-446655440000"),
    "space_id": UUID("abc12345-..."),
    "number": 42,
    "user_id": UUID("def67890-..."),
    "fields": {
        "assigned_to": UUID("7b8c9d0e-1f2g-3h4i-5j6k-7l8m9n0o1p2q"),  // ❌ Who?
        "thumbnail": UUID("550e8400-e29b-41d4-a716-446655440000")     // ❌ What?
    }
}
```

**Alternative implementation (transparent):**
```javascript
{
    "_id": ObjectId("67890..."),     // Present but ignored
    "space_slug": "my-tasks",        // ✅ Readable
    "number": 42,                    // ✅ Readable
    "created_by": "john",            // ✅ Readable
    "fields": {
        "assigned_to": "alice",      // ✅ Clear - it's user Alice
        "thumbnail": 15              // ✅ Clear - it's attachment #15
    }
}
```

---

## Advantages and Disadvantages

### ✅ Advantages

1. **Unified Identifier System**
   - No translation between Core and API layers
   - Human-readable identifiers throughout the entire stack
   - Reduces cognitive overhead for developers

2. **Data Transparency**
   - **Humans can read the data** - Query results show `assigned_to: "alice"` not `assigned_to: UUID("...")`
   - **AI agents can understand the data** - Critical for SpaceNote's AI integration goals
   - **Self-documenting** - No need for additional lookups to understand relationships

3. **Simpler Codebase**
   - No dual lookup methods (`get_user(uuid)` AND `get_user_by_username(str)`)
   - Single source of truth for identifiers
   - Less cache complexity - no need to maintain UUID→username mappings

4. **Better Developer Experience**
   - Database debugging shows meaningful values
   - Logs show readable identifiers
   - API responses are immediately comprehensible

### ❌ Disadvantages

1. **No Referential Integrity (MongoDB Limitation)**
   - MongoDB doesn't support foreign key constraints
   - Application must validate all references manually
   - **Issues:**
     - Can reference a user that doesn't exist: `"assigned_to": "nonexistent_user"`
     - Can reference a deleted attachment: `"thumbnail": 9999`
     - No cascade deletes when removing entities
     - No database-level guarantee of data consistency

2. **Cascading Updates When Renaming Identifiers**
   - If a username changes from "john" → "jane":
     - Must update all notes where `created_by: "john"`
     - Must update all space memberships
     - Must update all note fields where `assigned_to: "john"`
     - Must update all sessions
   - This requires application-level cascade logic
   - **Performance impact:** At SpaceNote's scale (10 users, 100 spaces, 1M notes), this is acceptable but requires careful transaction handling

3. **No Database-Level Validation**
   - MongoDB won't prevent invalid data:
     - Username with invalid characters
     - Duplicate space slugs (unless we add unique indexes)
     - Invalid attachment numbers
   - Application must implement all validation logic

4. **Compound Keys for Notes/Attachments**
   - Need to pass both `space_slug` and `number` for lookups
   - Slightly more complex than single-field primary keys
   - Must ensure both values are always available in context

---

## Implementation Considerations

### Handling Username/Slug Changes

When a username or space slug changes, we need cascading updates:

```python
async def rename_user(old_username: str, new_username: str):
    """Rename user across all collections"""
    async with await db.client.start_session() as session:
        async with session.start_transaction():
            # Update user document
            await db.users.update_one(
                {"username": old_username},
                {"$set": {"username": new_username}},
                session=session
            )

            # Update space memberships
            await db.spaces.update_many(
                {"members": old_username},
                {"$set": {"members.$": new_username}},
                session=session
            )

            # Update notes created_by
            await db.notes.update_many(
                {"created_by": old_username},
                {"$set": {"created_by": new_username}},
                session=session
            )

            # Update note fields (FieldType.USER)
            # This is more complex - need to iterate and update field values
            notes_with_user_fields = await db.notes.find(
                {f"fields.{field_id}": old_username},
                session=session
            ).to_list(length=None)

            for note in notes_with_user_fields:
                for field_id, value in note["fields"].items():
                    if value == old_username:
                        await db.notes.update_one(
                            {"_id": note["_id"]},
                            {"$set": {f"fields.{field_id}": new_username}},
                            session=session
                        )

            # Update sessions
            await db.sessions.update_many(
                {"username": old_username},
                {"$set": {"username": new_username}},
                session=session
            )
```

**Note:** MongoDB transactions work across collections in a replica set. For single-node deployments, this would need careful handling.

### Validating References

Since MongoDB doesn't enforce foreign keys, we must validate in application code:

```python
async def validate_note_fields(space: Space, fields: dict):
    """Validate all field references exist"""
    for field_def in space.fields:
        if field_def.id not in fields:
            continue

        value = fields[field_def.id]

        # Validate USER field
        if field_def.type == FieldType.USER:
            user = await user_service.get_user(username=value)
            if not user:
                raise ValueError(f"User '{value}' does not exist")

        # Validate IMAGE field
        elif field_def.type == FieldType.IMAGE:
            attachment = await attachment_service.get_attachment(
                space_slug=space.slug,
                number=value
            )
            if not attachment:
                raise ValueError(f"Attachment #{value} does not exist in space '{space.slug}'")
```

---

## Scale Considerations

This implementation aligns with SpaceNote's scale assumptions:

**Expected Scale:**
- Up to 10 users
- Up to 100 spaces
- Up to 1,000,000 notes

**Why This Works:**
- **Username changes are rare** - Maybe once per year per user (10 cascading updates/year)
- **Slug changes are rare** - Usually only during initial space setup
- **Text indexing performance** - At 1M notes, indexed text lookups (username, slug) are still fast
- **Validation overhead** - Checking references exists is acceptable with proper caching

**Acceptable Tradeoffs:**
- Slower cascading updates when renaming (vs numeric keys) - acceptable at this scale
- Manual reference validation - acceptable with proper caching (10 users, 100 spaces in memory)
- Slightly larger index size for text vs numbers - acceptable for readability benefits

---

## Summary

This alternative MongoDB implementation addresses the **dual identity system** and **opaque field references** problems from the original implementation while staying within MongoDB's capabilities.

**What it solves:**
- ✅ Unified identifier system (no UUID/username split)
- ✅ Human and AI-readable data
- ✅ Simpler codebase

**What it doesn't solve:**
- ❌ Referential integrity (MongoDB limitation)
- ❌ Cascading updates complexity (requires application logic)

This document provides a foundation for comparing this approach with the PostgreSQL implementation being developed in this repository.
