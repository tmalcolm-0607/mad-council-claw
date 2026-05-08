# Hash Manifest Schema

**Purpose**: Defines the JSON schema for staleness detection baseline files used to track file changes between baseline capture and verification.

## Schema Definition

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://claude.ai/schemas/hash-manifest.json",
  "title": "HashManifest",
  "description": "Baseline snapshot for staleness detection",
  "type": "object",
  "required": ["work_item_id", "captured_at", "files"],
  "properties": {
    "work_item_id": {
      "type": "string",
      "description": "Unique identifier for the work item this manifest belongs to",
      "pattern": "^WI-[0-9]{8}-[0-9]{4}-[a-z0-9-]+$",
      "examples": ["WI-20260121-1430-unified-kit"]
    },
    "captured_at": {
      "type": "string",
      "format": "date-time",
      "description": "ISO 8601 timestamp when baseline was captured",
      "examples": ["2026-01-21T14:30:00Z"]
    },
    "git_commit": {
      "type": "string",
      "pattern": "^[a-f0-9]{40}$",
      "description": "Git commit hash at capture time (optional)",
      "examples": ["abc123def456789012345678901234567890abcd"]
    },
    "include_patterns": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Glob patterns for files to track",
      "default": ["src/**/*", ".claude/**/*.md"],
      "examples": [["src/**/*", ".claude/**/*.md"]]
    },
    "exclude_patterns": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Glob patterns to exclude from tracking",
      "default": ["**/*.test.*", "**/node_modules/**"],
      "examples": [["**/*.test.*", "**/node_modules/**"]]
    },
    "files": {
      "type": "array",
      "description": "List of tracked files with their hashes",
      "items": {
        "$ref": "#/$defs/FileHash"
      }
    }
  },
  "$defs": {
    "FileHash": {
      "type": "object",
      "required": ["path", "hash", "size"],
      "properties": {
        "path": {
          "type": "string",
          "description": "Relative path from repository root",
          "examples": ["src/index.ts", ".claude/rules/orchestration.md"]
        },
        "hash": {
          "type": "string",
          "pattern": "^[a-f0-9]{40,64}$",
          "description": "Git object hash (SHA-1 40 chars or SHA-256 64 chars)",
          "examples": ["e3b0c44298fc1c149afbf4c8996fb92427ae41e4"]
        },
        "size": {
          "type": "integer",
          "minimum": 0,
          "description": "File size in bytes",
          "examples": [1234]
        }
      }
    }
  }
}
```

## Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `work_item_id` | string | Yes | Work item this baseline belongs to |
| `captured_at` | datetime | Yes | When baseline was captured (ISO 8601) |
| `git_commit` | string | No | Git commit hash at capture time |
| `include_patterns` | string[] | No | Glob patterns for files to track |
| `exclude_patterns` | string[] | No | Glob patterns to exclude |
| `files` | FileHash[] | Yes | Array of tracked files |

### FileHash Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | Yes | Relative path from repo root |
| `hash` | string | Yes | Git object hash (SHA-1 or SHA-256) |
| `size` | integer | Yes | File size in bytes |

## Example Manifest

```json
{
  "work_item_id": "WI-20260121-1430-unified-kit",
  "captured_at": "2026-01-21T14:30:00Z",
  "git_commit": "68ed222abc123def456789012345678901234567",
  "include_patterns": ["src/**/*", ".claude/**/*.md"],
  "exclude_patterns": ["**/*.test.*", "**/node_modules/**"],
  "files": [
    {
      "path": "src/index.ts",
      "hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4",
      "size": 1234
    },
    {
      "path": ".claude/skills/mad-c4/SKILL.md",
      "hash": "d7a8fbb307d7809469ca9abcb0082e4f8d5651e4",
      "size": 5678
    }
  ]
}
```

## Storage Location

Hash manifests are stored at:
```
.mad/work-items/<work-item-id>/hash-manifest.json
```

## Validation Rules

1. **work_item_id**: Must match pattern `WI-YYYYMMDD-HHMM-slug`
2. **captured_at**: Must be valid ISO 8601 datetime
3. **git_commit**: If present, must be 40 character hex string
4. **files.path**: Must be relative paths (no leading `/` or drive letters)
5. **files.hash**: Must be 40 or 64 character hex string
6. **files.size**: Must be non-negative integer

## Staleness Detection States

| State | Condition | Action |
|-------|-----------|--------|
| FRESH | All files match baseline hashes | Continue verification silently |
| STALE | One or more files have different hashes | Warn (or fail in strict mode) |
| INCOMPLETE | One or more baselined files are missing | Warn about missing files |

## Related Documents

- [Staleness Detection Contract](../specs/002-unified-ai-development-kit/contracts/staleness.md)
- [Data Model - HashManifest Entity](../specs/002-unified-ai-development-kit/data-model.md)
