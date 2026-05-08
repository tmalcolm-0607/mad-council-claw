# Data Model Template: [FEATURE NAME]

**Feature**: [Feature name and spec link]
**Database**: PostgreSQL 16+ with pgvector

## Overview

[Brief description of the data model and its purpose]

## Entity Relationship Diagram

```
[ASCII diagram or link to visual ERD]
```

## Tables

### [table_name]

| Column     | Type        | Constraints                   | Description           |
| ---------- | ----------- | ----------------------------- | --------------------- |
| id         | UUID        | PK, DEFAULT gen_random_uuid() | Primary key           |
| [column]   | [type]      | [constraints]                 | [description]         |
| created_at | TIMESTAMPTZ | DEFAULT now()                 | Creation timestamp    |
| updated_at | TIMESTAMPTZ |                               | Last update timestamp |

**Indexes**:

```sql
CREATE INDEX [index_name] ON [table_name]([columns]);
```

**RLS Policy**:

```sql
ALTER TABLE [table_name] ENABLE ROW LEVEL SECURITY;

CREATE POLICY "[policy_name]" ON [table_name]
  FOR [operation]
  USING ([condition]);
```

---

### [table_name_2]

[Repeat for each table]

---

## Enums

### [enum_name]

```sql
CREATE TYPE [enum_name] AS ENUM (
  'value1',
  'value2',
  'value3'
);
```

## Functions

### [function_name]

```sql
CREATE OR REPLACE FUNCTION [function_name]([params])
RETURNS [return_type]
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Implementation
END;
$$;
```

**Usage**: [When and how to use this function]

## Vector Storage

### [vector_table_name]

| Column      | Type         | Constraints   | Description             |
| ----------- | ------------ | ------------- | ----------------------- |
| id          | UUID         | PK            | Primary key             |
| content     | TEXT         | NOT NULL      | Text for embedding      |
| embedding   | vector(1536) | NULLABLE      | OpenAI/Ollama embedding |
| source_type | TEXT         | NOT NULL      | Source entity type      |
| source_id   | UUID         | NOT NULL      | Source entity ID        |
| created_at  | TIMESTAMPTZ  | DEFAULT now() | Creation time           |

**Index**:

```sql
CREATE INDEX [index_name] ON [table_name]
  USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);
```

## Migration Order

1. `001_extensions.sql` - Enable required extensions (uuid-ossp, pgvector)
2. `002_enums.sql` - Create enum types
3. `003_tables.sql` - Create tables
4. `004_rls.sql` - Enable RLS and create policies
5. `005_functions.sql` - Create helper functions
6. `006_indexes.sql` - Create indexes
7. `007_seed.sql` - Optional seed data

## Zod Schemas

```typescript
import { z } from 'zod';

export const [EntityName]Schema = z.object({
  id: z.string().uuid(),
  [field]: z.[type](),
  createdAt: z.string().datetime(),
});

export type [EntityName] = z.infer<typeof [EntityName]Schema>;
```

## Notes

- [Important considerations]
- [Performance notes]
- [Security considerations]
