# Feature Map: [Feature Name]

**Feature ID**: [ID]
**Created**: [DATE]
**Last Updated**: [DATE]
**Status**: [In Progress / Complete]

---

## Overview

This feature map provides end-to-end traceability from user stories through implementation to test coverage. It serves as a single source of truth for tracking feature completeness and test validation.

---

## User Journey → E2E Test Mapping

Complete traceability from user stories to E2E tests for UI features.

| Journey ID | User Story | Journey Description | Priority | E2E Test File | Status | Last Run | Pass Rate |
|------------|------------|---------------------|----------|---------------|--------|----------|-----------|
| J-001 | US-001 | [Complete user flow] | P0 (Smoke) | `e2e/auth/login.spec.ts` | ✅ Pass | 2026-02-16 | 100% |
| J-002 | US-002 | [Another complete flow] | P1 (Critical) | `e2e/campaigns/create.spec.ts` | ✅ Pass | 2026-02-16 | 100% |

**Legend**:
- **P0 (Smoke)**: Critical paths, run on every deployment, 100% pass required
- **P1 (Critical Path)**: Primary features, run pre-merge, ≥95% pass required
- **P2 (Regression)**: Secondary features, run nightly
- **P3 (Optional)**: Nice-to-have, run manually

---

## UI Component → Page Object Mapping

Maps React components to Playwright Page Objects for E2E testing.

| Component | File Path | Page Object | E2E Coverage | Accessibility | Notes |
|-----------|-----------|-------------|--------------|---------------|-------|
| `CampaignForm` | `src/components/CampaignForm.tsx` | `CampaignPage.createCampaign()` | ✅ Covered | ✅ WCAG 2.1 AA | Form validation, keyboard navigation |
| `PlayerInviteModal` | `src/components/PlayerInviteModal.tsx` | `InviteModal.sendInvite()` | ✅ Covered | ✅ WCAG 2.1 AA | Focus trap, ESC key handler |

**Accessibility Compliance**:
- All components must meet WCAG 2.1 Level AA standards
- Keyboard navigation required for all interactive elements
- Screen reader labels required for all form inputs
- Focus management for modals and overlays

---

## Critical Paths → Smoke Tests

Smoke tests are the highest priority E2E tests that MUST pass 100% on every deployment.

| Critical Path | User Journey | Smoke Test | Pass Rate | Execution Time | Last Failure |
|---------------|--------------|------------|-----------|----------------|--------------|
| Auth Flow | Login → Dashboard | `e2e/auth/login.spec.ts @p0` | 100% | 5s | Never |
| Campaign Creation | New Campaign → Save | `e2e/campaigns/create.spec.ts @p0` | 100% | 8s | Never |
| Core Navigation | App Shell → Main Pages | `e2e/navigation/app-shell.spec.ts @p0` | 100% | 3s | Never |

**Smoke Test Criteria**:
- Execution time: < 1 minute total for all smoke tests
- Pass rate: 100% required (blocking)
- Run frequency: Every deployment + every phase gate during implementation
- Flakiness: 0% tolerance - flaky smoke tests must be fixed immediately

---

## Success Criteria → Test Assertions

Maps success criteria from spec.md to specific test assertions.

| Success Criterion | Test File | Assertion | Status |
|-------------------|-----------|-----------|--------|
| SC-001: Users can create campaign in < 2 minutes | `e2e/campaigns/create.spec.ts` | `expect(duration).toBeLessThan(120000)` | ✅ Pass |
| SC-002: Campaign appears in dashboard immediately | `e2e/campaigns/create.spec.ts` | `expect(campaignList).toContainText(campaignName)` | ✅ Pass |
| SC-003: System handles 1000 concurrent users | `load-tests/campaign-creation.js` | `http_req_duration p95 < 500ms` | ⚠️ 650ms |

**Note**: Performance success criteria (SC-003) may use different test frameworks (k6, Artillery) and are not part of E2E test suite.

---

## Test Coverage Summary

### By Priority

| Priority | Journeys | Tests Implemented | Tests Passing | Coverage % |
|----------|----------|-------------------|---------------|------------|
| P0 (Smoke) | 3 | 3 | 3 | 100% |
| P1 (Critical) | 5 | 5 | 5 | 100% |
| P2 (Regression) | 8 | 6 | 6 | 75% |
| P3 (Optional) | 4 | 0 | 0 | 0% |
| **Total** | **20** | **14** | **14** | **70%** |

### By Test Type

| Test Type | Count | Pass Rate | Avg Execution Time |
|-----------|-------|-----------|-------------------|
| Smoke (@p0) | 3 | 100% | 16s total |
| Critical Path (@p1) | 5 | 100% | 45s total |
| Regression (@p2) | 6 | 100% | 2m 30s total |
| **Total** | **14** | **100%** | **3m 31s** |

### Flakiness Report

| Status | Count | Percentage |
|--------|-------|------------|
| Stable (0 retries) | 14 | 100% |
| Flaky (1-2 retries) | 0 | 0% |
| Very Flaky (3+ retries) | 0 | 0% |
| Quarantined (`test.fixme()`) | 0 | 0% |

**Flaky Rate Target**: < 5% (current: 0% ✅)

---

## Gaps and TODOs

### Missing E2E Tests

| Journey ID | User Story | Priority | Reason Not Implemented | ETA |
|------------|------------|----------|------------------------|-----|
| J-015 | US-008: Character portrait upload | P2 | Feature not yet implemented | Sprint 3 |
| J-016 | US-009: Player invite via email | P2 | External email service dependency | Sprint 4 |

### Missing Accessibility Validation

| Component | Current Status | Required Action | Owner |
|-----------|----------------|-----------------|-------|
| `CharacterSheet` | No a11y tests | Add axe-playwright assertions | Frontend Team |
| `DiceRoller` | Keyboard nav incomplete | Add keyboard event handlers | Frontend Team |

### Performance Gaps

| Success Criterion | Current | Target | Gap | Mitigation |
|-------------------|---------|--------|-----|------------|
| SC-003: Concurrent users | 650ms p95 | < 500ms p95 | +150ms | Database query optimization Sprint 3 |

---

## Maintenance Notes

### Recent Changes

| Date | Change | Impact | Updated By |
|------|--------|--------|------------|
| 2026-02-16 | Fixed auth race condition in smoke tests | Smoke pass rate: 50% → 100% | Claude |
| 2026-02-16 | Disabled parallel execution for auth tests | Flaky rate: 50% → 0% | Claude |

### Known Issues

None currently.

### Future Improvements

1. **Accessibility**: Add automated a11y testing using `@axe-core/playwright` for all components
2. **Visual Regression**: Add Percy or Playwright snapshots for critical UI components
3. **Performance**: Add performance budgets to E2E tests using Lighthouse CI
4. **Mobile**: Add mobile viewport testing for responsive design validation

---

## References

- **Spec**: `specs/[feature-dir]/spec.md` - E2E Test Coverage section
- **Validation Report**: `frontend/e2e/VALIDATION-REPORT.md` - Latest test run results
- **E2E Pattern Rule**: `.claude/rules/e2e-testing-patterns.md` - E2E best practices
- **Playwright Config**: `frontend/playwright.config.ts` - Test configuration
- **Page Objects**: `frontend/e2e/pages/` - Page Object Model implementations
