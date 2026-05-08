# Cross-Milestone Coordination

Rules for managing shared database schemas, migration numbering, and inter-milestone interfaces in multi-milestone projects.

---

## Migration Numbering

Each milestone owns a dedicated range of migration numbers. Collisions cause deployment failures.

| Rule | Detail |
|------|--------|
| Range assignment | Each milestone gets a 10-number block (e.g., M1: 001-009, M5: 040-049) |
| Naming convention | `{NNN}_m{milestone}_{description}.sql` (e.g., `060_m7_create_veto_decisions.sql`) |
| No cross-range writes | A milestone must NEVER create a migration outside its assigned range |
| Schema ownership | The milestone that CREATEs a table owns it; others ALTER with explicit owner reference |
| ALTER convention | Cross-milestone ALTER columns include comment: `-- Added by M{N}` |

## Schema Ownership

| Rule | Detail |
|------|--------|
| Single owner | Each table has exactly one owner milestone |
| ALTERs reference owner | When M4 alters M3's table: note "Schema owner: M3" in task description |
| No duplicate columns | If two milestones need similar data on the same table, coordinate column names upfront |
| governance_events special | Append-only tables (audit trails) allow NO ALTERs from any milestone |

## Inter-Milestone Interfaces

When milestone A produces data that milestone B consumes:

1. Define the interface (TypeScript type or SQL view) in a shared coordination doc
2. Both milestones reference the same interface definition
3. Producer writes integration tests that emit the interface
4. Consumer writes integration tests that parse the interface
5. Neither milestone can change the interface without updating both sides

## Security-Critical Milestones

Milestones tagged `SECURITY-CRITICAL` require:

1. **Phase 0**: `domain-reviewer` (security) threat assessment before any code
2. **Post-implementation**: `domain-reviewer` (security) code review after implementation
3. **Manual approval**: User sign-off before marking milestone complete

Common security concerns by milestone type:
- **Auth/Identity**: Token validation, role escalation, session hijacking
- **External webhooks**: HMAC signature verification, replay attacks, payload injection
- **Governance/Audit**: Append-only integrity, veto bypass, escalation tampering
- **Eval/Safety**: Adversarial input containment, chaos drill blast radius

## Anti-Patterns

| Anti-Pattern | Correct Approach |
|--------------|------------------|
| Unassigned migration numbers (NNN) | Assign from milestone's range before implementation |
| Two milestones ALTER same column | Coordinate upfront; one adds, other consumes |
| Undefined feedback loop between milestones | Define interface type in coordination doc |
| Security-critical milestone without Phase 0 | Add domain-reviewer assessment as Phase 0 blocker |
| Migration number collision at deploy time | Use assigned ranges with milestone prefix in filename |
