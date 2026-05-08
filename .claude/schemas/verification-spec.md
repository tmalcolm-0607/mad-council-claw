# Verification Spec Schema

A verification spec defines **what a feature is supposed to do** and **how to determine if it's working structurally**. It is used by the `feature-verifier` agent to interpret test results in context.

```
+===========================================================================+
|  KEY PRINCIPLE: Verification specs define STRUCTURAL success,             |
|  NOT performance success.                                                 |
|                                                                           |
|  "Does the feature work?" != "Does the feature improve metrics?"          |
+===========================================================================+
```

---

## Where Verification Specs Live

Verification specs can appear in:

1. **Plan files** (`plan.md`) - Verification Spec section during `/mad-plan`
2. **Feature spec files** (`spec.md`) - Optional verification section
3. **Inline in feature-verifier prompts** - When spawning the agent

The plan file is the primary location; spec files may include preliminary verification criteria.

---

## Schema Definition

### JSON Schema (for structured validation)

```json
{
  "verification_spec": {
    "feature_intent": "Brief description of what the feature does",
    "change_type": "filter | gate | threshold | logic | refactor | new_feature",
    "expected_impact": {
      "behavior_change": "none | decrease_minor | decrease_moderate | decrease_significant | increase",
      "behavior_rationale": "Why this behavior change is expected"
    },
    "structural_signals": [
      {
        "signal": "Description of what to check",
        "pass_condition": "What indicates success",
        "fail_condition": "What indicates structural failure"
      }
    ],
    "not_a_failure": [
      "Conditions that look bad but aren't structural failures"
    ]
  }
}
```

### Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| `feature_intent` | Yes | 1-2 sentence description of what the feature does |
| `change_type` | Yes | Category of change (see Change Types below) |
| `expected_impact.behavior_change` | Yes | Expected effect on system behavior/activity |
| `expected_impact.behavior_rationale` | Yes | Why this behavior change is expected |
| `structural_signals` | Yes | List of specific things to verify |
| `not_a_failure` | No | Explicit list of outcomes that are NOT failures |

---

## Change Types

| Type | Description | Typical Behavior Impact |
|------|-------------|------------------------|
| `filter` | Removes cases that don't meet criteria | Decrease (minor to moderate) |
| `gate` | Adds a new condition that must be met | Decrease (minor to moderate) |
| `threshold` | Adjusts an existing numeric parameter | Varies |
| `logic` | Changes decision-making logic | Varies |
| `refactor` | Restructures without changing behavior | None expected |
| `new_feature` | Adds entirely new functionality | Increase or new behavior |

---

## Expected Behavior Impact

| Value | Change Level | When to Use |
|-------|-------------|-------------|
| `none` | 0-5% change | Refactors, bug fixes, cosmetic changes |
| `decrease_minor` | 5-20% decrease | Tight filters, minor threshold adjustments |
| `decrease_moderate` | 20-40% decrease | Meaningful filters, new gates |
| `decrease_significant` | 40-70% decrease | Aggressive filters (requires strong justification) |
| `increase` | Any increase | New features, relaxed conditions |

**Important**: Behavior changes >70% are always flagged as potential structural failures, regardless of what the spec says. The feature-verifier will flag these for investigation.

---

## Structural Signals

Structural signals are specific, testable conditions that indicate the feature is working as designed.

### Good Structural Signals

| Signal | Pass Condition | Fail Condition |
|--------|----------------|----------------|
| "Feature triggers appropriately" | Measurable activity in test period | Near-complete shutdown |
| "Filter logs rejections" | Rejection messages in logs | No rejection messages (filter not running) |
| "New gate activates" | Gate mentioned in logs | Gate never mentioned |
| "State transitions correctly" | No stuck-state errors | State machine errors in logs |
| "API calls execute without errors" | Successful responses received | Error responses in logs |

### Bad Structural Signals (Don't Use These)

| Signal | Why It's Bad |
|--------|--------------|
| "Performance improves" | Metric-based, not structural |
| "Response time < 100ms" | Performance-based, not structural |
| "User satisfaction increases" | Outcome-based, not structural |
| "Fewer errors than before" | Comparative, not structural |

---

## Example Verification Specs

### Example 1: Input Validation Filter

```json
{
  "verification_spec": {
    "feature_intent": "Add input validation to reject malformed requests before processing.",
    "change_type": "filter",
    "expected_impact": {
      "behavior_change": "decrease_minor",
      "behavior_rationale": "Validation filter should reject 5-15% of requests that have missing or malformed fields."
    },
    "structural_signals": [
      {
        "signal": "Valid requests still process normally",
        "pass_condition": "Valid requests processed >= 85% of baseline",
        "fail_condition": "Valid requests processed < 50% of baseline"
      },
      {
        "signal": "Invalid requests are rejected with proper error",
        "pass_condition": "400 errors returned for malformed input",
        "fail_condition": "500 errors or silent failures for malformed input"
      }
    ],
    "not_a_failure": [
      "Overall throughput decreases due to validation overhead",
      "Some edge cases now rejected that previously succeeded"
    ]
  }
}
```

### Example 2: New Authentication Gate

```json
{
  "verification_spec": {
    "feature_intent": "Add JWT authentication gate requiring valid token before API access.",
    "change_type": "gate",
    "expected_impact": {
      "behavior_change": "decrease_moderate",
      "behavior_rationale": "Gate will block unauthenticated requests. Expect 20-40% of test traffic rejected."
    },
    "structural_signals": [
      {
        "signal": "Authenticated requests succeed",
        "pass_condition": "Requests with valid JWT return 200",
        "fail_condition": "Requests with valid JWT return 401"
      },
      {
        "signal": "Unauthenticated requests are blocked",
        "pass_condition": "Requests without JWT return 401",
        "fail_condition": "Requests without JWT return 200 (gate bypassed)"
      }
    ],
    "not_a_failure": [
      "Overall request count decreases",
      "Test suites without auth setup fail"
    ]
  }
}
```

### Example 3: Threshold Adjustment

```json
{
  "verification_spec": {
    "feature_intent": "Increase request timeout from 5s to 10s to accommodate slow downstream services.",
    "change_type": "threshold",
    "expected_impact": {
      "behavior_change": "none",
      "behavior_rationale": "Timeout change doesn't affect normal requests. Only slow requests benefit."
    },
    "structural_signals": [
      {
        "signal": "Normal requests unaffected",
        "pass_condition": "Request count within +/-5% of baseline",
        "fail_condition": "Request count changes significantly (unintended side effect)"
      },
      {
        "signal": "Timeout is actually increased",
        "pass_condition": "Requests that took 5-10s now succeed (previously timed out)",
        "fail_condition": "5-10s requests still timeout (parameter not applied)"
      }
    ],
    "not_a_failure": [
      "Average response time increases slightly",
      "Resource utilization increases for long-running requests"
    ]
  }
}
```

### Example 4: Refactoring

```json
{
  "verification_spec": {
    "feature_intent": "Refactor UserService to use repository pattern instead of direct DB calls.",
    "change_type": "refactor",
    "expected_impact": {
      "behavior_change": "none",
      "behavior_rationale": "Pure refactor with no behavioral changes. All metrics should match baseline."
    },
    "structural_signals": [
      {
        "signal": "Behavior unchanged",
        "pass_condition": "All existing tests pass",
        "fail_condition": "Any existing test fails"
      },
      {
        "signal": "No new errors",
        "pass_condition": "Zero runtime errors",
        "fail_condition": "Any runtime errors"
      }
    ],
    "not_a_failure": []
  }
}
```

---

## How Feature-Verifier Uses the Spec

1. **Reads the spec** from the plan file or prompt
2. **Compares baseline vs modified** metrics/test results
3. **Checks each structural signal** against the pass/fail conditions
4. **Checks behavior change** against expected impact
5. **Applies the "not a failure" list** to avoid false positives
6. **Determines outcome**: VERIFIED, NEEDS_INVESTIGATION, or STRUCTURAL_FAILURE

### Decision Flow

```
Read verification spec
       |
       v
Check for runtime errors ---- Yes --> MECHANICAL_FAILURE
       |
       No
       v
Check behavior change vs expected
       |
       +-- Within expected range --> Continue to structural signals
       |
       +-- Worse than expected but <70% drop --> NEEDS_INVESTIGATION
       |
       +-- >70% behavior drop --> STRUCTURAL_FAILURE
       |
       v
Check each structural signal
       |
       +-- All pass --> VERIFIED
       |
       +-- Some fail but behavior OK --> VERIFIED_WITH_NOTE
       |
       +-- Critical signal fails --> NEEDS_INVESTIGATION or STRUCTURAL_FAILURE
       |
       v
Apply "not a failure" list
       |
       +-- If outcome was failure but matches "not a failure" --> Downgrade to VERIFIED_WITH_NOTE
```

---

## Verification Outcomes

| Outcome | Meaning | Action |
|---------|---------|--------|
| `VERIFIED` | Feature is structurally sound | Proceed to commit/PR |
| `VERIFIED_WITH_NOTE` | Sound but notable behavior change | Proceed with documentation |
| `NEEDS_INVESTIGATION` | Unclear results | Investigate before proceeding |
| `STRUCTURAL_FAILURE` | Feature broke intended behavior | Do not proceed, fix or revert |
| `MECHANICAL_FAILURE` | Runtime errors | Do not proceed, fix errors |

---

## Integration Points

| Component | How It Uses Verification Spec |
|-----------|------------------------------|
| **mad-plan** | Generates verification spec section in plan.md |
| **mad-implement** | References spec to understand what success looks like |
| **mad-validate** | Validates against verification spec |
| **feature-verifier** | Primary consumer - uses spec to interpret results |

---

## When to Write a Verification Spec

| Situation | Write Spec? |
|-----------|-------------|
| New feature implementation | Yes |
| Bug fix | Optional (often obvious what "fixed" means) |
| Refactoring | Yes (to verify no behavioral change) |
| Configuration change | Yes (to define expected impact) |
| Documentation only | No |
