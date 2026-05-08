---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
---

# Code Review Criteria (TypeScript/JavaScript)

Any of these issues = automatic rejection.

## Code Quality

- Functions exceeding 300 lines
- Nesting deeper than 3 levels
- Unhandled Promise rejections
- Missing error handling on database calls
- `any` type without `@ts-expect-error` + justification
- Unbounded queries (missing `.limit()`)
- `// @ts-ignore` (must use `@ts-expect-error`)
- ESLint disable without explanatory comment
- Mock/hardcoded data in non-test files
- `// TODO: use real API` comments

## Test Quality

- `vi.mock('../services/...')` in integration test files
- `vi.mock('../../db/...')` in integration test files
- `page.route('**/api/...')` in E2E test files
- Missing Docker smoke test for new API endpoints

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| "Tests are optional" | Quality gaps | Tests are default |
| `npm run build` = verified | False confidence | Only `npm test` = verified |
| Defer testing to "later" | Bugs compound | Test inline |
| Mock data in production | False functionality | API hooks only |
| Unit tests only | URL/CORS bugs missed | Add integration tests |
