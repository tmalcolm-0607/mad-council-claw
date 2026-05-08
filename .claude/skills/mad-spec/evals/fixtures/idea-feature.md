# Fixture: feature idea (synthetic) — input to /mad-spec

## Idea

Add a `lookup-by-tag` endpoint that returns documents whose tags match a query string. Should be paginated, cacheable, and respect existing tenant-scoping rules.

## Context

- Consumers want to filter document collections by tag without scanning the full DB.
- Tags are already indexed but not exposed via a dedicated endpoint.
- 3 internal teams (LRMS, LEEDS, downstream X) have asked for it.

## Constraints

- Must use ServiceAuthorizationPolicies.DocumentRead (consumer-app placeholder; substitute the real policy name).
- Must respect tenant isolation per the existing DocumentRepository.
- Pagination: ≤50 items per page, cursor-based.
- Cache: 5-minute TTL keyed on (tenant, tag-query, cursor).

## What WAS NOT decided

- Whether to expose this on the existing /api/v1/documents endpoint with a query param OR a new /api/v1/documents/by-tag route.
- Whether to support multi-tag AND/OR queries in v1, or only single-tag.
- Whether to emit a TagLookupRequested event for downstream consumers.

## Estimated impact

Medium. New endpoint, new handler, new repository method. Existing infrastructure (auth, tenant isolation, pagination cursor scheme) reusable.
