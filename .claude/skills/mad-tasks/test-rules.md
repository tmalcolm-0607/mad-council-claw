# Test Generation Rules Reference

Reference data for mad-tasks test task generation. Technology-specific implementation details belong in project CLAUDE.md files.

## What Tests MUST Verify

| Test Type | MUST Verify | MUST NOT Just Check |
|-----------|-------------|---------------------|
| **E2E** | Data appears correctly, forms submit to correct APIs, real-time events update UI | "Page loads without error" |
| **Integration** | Real route → controller → service → database flow | Mocked responses pass through |
| **Component** | Loading/error/success states, user interactions, accessibility | Component renders without crashing |
| **API** | Correct URLs, CORS headers, validation, error responses | Status code 200 only |

## E2E Test Task Format

```markdown
- [ ] T0XX [US1] E2E: [Feature] flow in [test-file-path]
  - **Functionality**: Test complete user journey for [feature]
  - **Test cases** (REQUIRED):
    - Form fields are accessible (semantic queries)
    - Form submits to correct API endpoint (intercept and verify)
    - Success shows actual data from API response
    - Error displays user-friendly message
    - Data persists (verify via API or database)
  - **Verification requirements**:
    - Verify specific data appears (not just "page has content")
    - Intercept API calls and verify URL + payload
    - Test error states explicitly (mock API failures)
    - Test multi-user scenarios where applicable
  - **Anti-patterns**: Arbitrary timeouts, content substring checks, swallowing errors, happy path only
```

## Integration Test Task Format

```markdown
- [ ] T0XX [US1] Integration: [Resource] API routes in [test-file-path]
  - **Functionality**: Test real API routes with database
  - **Test cases** (REQUIRED):
    - Create operation persists to database
    - Read operation returns correct data
    - Invalid input returns validation errors
    - Unauthorized request returns 401
    - CORS headers correct for allowed origins
  - **Verification requirements**:
    - Use real application instance (not mocked)
    - Verify response body content (not just status)
    - Query database to verify mutations
    - Test with real or containerized database
  - **Anti-patterns**: Mocking entire service layer, only checking status codes, skipping DB verification
```

## Component Test Task Format

```markdown
- [ ] T0XX [US1] Component: [Component] tests in [test-file-path]
  - **Functionality**: Test component behavior and API integration
  - **Test cases** (REQUIRED):
    - Loading state displays while fetching
    - Success state shows correct data
    - Error state shows user-friendly message
    - Form validation prevents invalid submission
    - Submit calls correct API endpoint
  - **Verification requirements**:
    - Use accessibility-first queries (role, label, text)
    - Mock at network level (not module level)
    - Test all three states: loading, success, error
    - Verify user-visible behavior, not implementation
  - **Anti-patterns**: Testing "component renders" without assertions, testing internal state, over-reliance on test IDs
```

## Real-Time/WebSocket Test Task Format

```markdown
- [ ] T0XX [US1] Real-time: [Handler] tests in [test-file-path]
  - **Functionality**: Test real-time event handling
  - **Test cases** (REQUIRED):
    - Event broadcasts to correct subscribers/rooms
    - Payload structure matches contract
    - Multiple clients receive updates simultaneously
    - Error events handled gracefully
  - **Verification requirements**:
    - Test with real client connections (not mocked)
    - Test multi-client scenarios
    - Verify broadcast targeting (room isolation)
```

## Test Anti-Patterns (REJECT IF FOUND)

| Anti-Pattern | Why It's Bad | Correct Approach |
|--------------|--------------|------------------|
| "Page loads successfully" | Catches nothing except crashes | Verify specific data appears |
| Status code only | URL could be wrong, response empty | Verify response body content |
| Mock everything | Tests mock, not real code | Mock only external services |
| Arbitrary timeouts | Flaky, hides async issues | Use framework auto-wait mechanisms |
| Generic content checks | Tests nothing specific | Use semantic queries for specific elements |
| Happy path only | Errors happen in production | Test error states explicitly |
| No database verification | Mutations might not persist | Query DB after write operations |

## Test Infrastructure Tasks (Phase 2)

Every project with tests MUST include:

```markdown
- [ ] T0XX [P] Setup: Configure test utilities
  - Create test wrappers for framework providers
  - Create application factory for API testing
  - Configure network-level mocking
  - Add containerized database for integration tests

- [ ] T0XX [P] Setup: Configure test commands
  - Unit/component test command
  - Integration test command (separate from unit)
  - E2E test command
  - Coverage report command
```

## Phase Verification Must Include Test Mechanics

After each user story phase, verification MUST include:

```markdown
### Phase X Test Verification

- [ ] E2E tests verify user-visible outcomes (not just page loads)
- [ ] Integration tests use real database (not mocked)
- [ ] Component tests cover loading/error/success states
- [ ] API tests verify response bodies (not just status codes)
- [ ] All tests run and pass (see project CLAUDE.md for commands)
```
