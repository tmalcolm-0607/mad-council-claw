# Expected output: auth policy PR

## Smart-default flow

| Step | Result |
|------|--------|
| Step 1.6 risk score | content-grep matches `Authoriz`, `MISE`, `AllowlistedCallers` (+3) + new public DTO/contract surface (+1) + description has auth keywords (+1). Score: **5** → extended security pass tier. |
| Auto-promote | NOT to council (score < 6); manual `--council` recommended given the security touch |

## Findings (post-threshold gate)

```
[SHOULD-FIX, conf 70] AuthorizationPolicies.cs — Verify AllowlistedCallers backing config is non-empty in PRD/PPE

Evidence: New policy constants added but PR doesn't show the corresponding appsettings.<env>.json updates that populate AnyOfAuthorizedClients for AllowlistedCallers. If empty in PRD, the policy fails open per S2 (Authorization fail-open).

Rule: S2 from references/security-checklist.md.

Suggested fix: Add appsettings.npe.json + .ppe.json + .prd.json updates with explicit AppId+OID lists for AllowlistedCallers OR reference the existing config that populates it.
```

```
[CONSIDER, conf 60 mention only] Recommend --council mode

This PR scored 5 on the risk heuristic (just below auto-promote threshold of 6). Given the auth-policy surface change and S2 LATENT considerations, manual --council invocation would surface architectural concerns the standard pass may miss.
```

```
[PRAISE, conf 85] Author added 45 lines of auth-specific tests in CasesControllerTests covering the policy attribute on GetCase
```

## Verdict

ACCEPT_WITH_CAVEATS — `wait-for-author` until S2 LATENT concern is resolved (config verification).

## Skill features exercised

- Content-grep heuristic correctly elevated risk score from 0 (path-only) to 5 (content-aware) ✓
- S1-S15 walk explicitly checked S2 (auth fail-open) ✓
- Output Contract format on all 3 findings ✓
- Confidence floor: SHOULD-FIX at 70 (≥60 floor → posts), PRAISE at 85 (≥70 floor → posts), CONSIDER at 60 (mention only) ✓
