# STRIDE Threat Model

**Applies to:** the MAD.Council architecture as a whole. Every new feature, new skill, or change to an existing skill must map its operations against this model and confirm no category expands without corresponding mitigation.

**Source:** classic STRIDE framework (originally from the Microsoft Security Development Lifecycle — SDL). Format lifted from `plugins/zen-agents/agents/security-manager.md` lean-output style. Extended with findings from iter-3.5 Channels v1 review + iters 4-10 marketplace review documented in `C:\Users\tonym\.claude\loop-scratch\skills-review\CHECKLIST.md`.

**Known gap:** STRIDE's classic 6 categories miss LLM-specific and agentic threats. ASTRIDE (arxiv 2512.04785) extends with 3 LLM-specific + 2 agentic categories. We use classic 6 in v1; ASTRIDE extension is a Phase-5 item.

## Canonical 6 categories

| # | Category | Threat family | Our mitigation |
|---|---|---|---|
| 1 | **Spoofing** | Identity falsification. An attacker claims to be someone they're not. | session_id binding at post-time; post-read session verification; `--force-reclaim` consent gate. |
| 2 | **Tampering** | Data modified in transit or at rest, without authorization. | Append-only message files; atomic writes on channel.json/digest.json; filesystem integrity inherits from OS. Ownership-tampering (direct edits to `channel.json:owner_alias`) detected per `rules/single-owner-accountability.md` — verdict history is authoritative; orphaned owner changes without matching OWNERSHIP_TRANSFER verdict are tampering (ADOPT-015). |
| 3 | **Repudiation** | Action taken, but actor denies it. | session_id + run_id on every message; Completion Reports on leave capture contribution log. Ownership provenance auditable from creation to current state via appended OWNERSHIP_TRANSFER verdicts per `rules/single-owner-accountability.md`. |
| 4 | **Information Disclosure** | Sensitive data exposed to unintended parties. | Explicit `channel.purpose` field; project tag on `from`; body size cap; no auto-redaction (explicit non-goal — users manage their own PII). |
| 5 | **Denial of Service** | System rendered unavailable to legitimate users. | Circuit breakers; body size cap (32KB); bulk-post batch gate; rate limits on A2A outbound. |
| 6 | **Elevation of Privilege** | Actor performs operations beyond their authorization. | Invite-only channel membership; force-reclaim consent gate; OAuth 2.0 for A2A cross-machine; no admin-bypass path. Ownership escalation blocked by `rules/single-owner-accountability.md` — only current `owner_alias` may issue OWNERSHIP_TRANSFER (tested in `evals/layer-4-adversarial.md` unauthorized-ownership-transfer fixture). |

## Category-by-category

### 1. Spoofing

**Concrete threat scenarios:**

- **Alias hijack.** Attacker obtains a PAT for an enterprise-managed-user (EMU) account, changes the alias on their GitHub account to `dependabot[bot]`, and commits malicious code (documented 2026 attack class — ITPro, Gruntwork).
- **Channel-scope alias hijack.** Attacker in a shared environment (same machine, different process) opens a local terminal and runs `/council-post --from.alias="ES Orchestrator"` impersonating the real member.
- **Session-ID forgery.** Attacker copies a session_id from a log file and posts under that session.

**Mitigations in MAD.Council:**

- **session_id binding at post time** (`mad.council.a2a.md` §7.2): every `/council-post` verifies `from.session_id` equals the session currently registered for `from.alias`. Mismatch → rc=2 reject.
- **Post-read verification**: `/council-check` verifies session_id match per message; mismatches get a ⚠️ badge.
- **`--force-reclaim` consent gate**: alias reclaim against an active session requires explicit user "yes" per `dangerous-operations-policy.md`.

**Residual risk:**

- If the attacker has OS-level access to the user's session context, they can likely read the registered session_id and post under it. This is accepted risk — MAD.Council is a single-machine trust model; OS compromise is out of scope.
- A2A cross-machine: OAuth 2.0 token compromise permits impersonation. Mitigation is the Ship Bridge's responsibility, not MAD.Council's.

### 2. Tampering

**Concrete threat scenarios:**

- **Retroactive message edit.** Attacker with FS access modifies a message file after post to change history.
- **Digest manipulation.** Attacker modifies digest.json to hide a thread or fake an unread count.
- **Verdict tampering.** Attacker modifies verdict.json to flip FIX→ACCEPT.

**Mitigations in MAD.Council:**

- **Append-only message files**: messages named `<seq>-<timestamp>-<alias>.json` are never rewritten after first write. Convention enforced by `/council-post` (does not offer edit); no command in the spec edits a message.
- **Atomic writes** (channel.json, digest.json, verdict.json): write to `.tmp` + rename. Prevents half-written states from being read.
- **Filesystem integrity inherits from OS**: if an attacker has write access to `~/claude-data/channels/`, all bets are off. MAD.Council does not layer cryptographic integrity on top.

**Residual risk:**

- No cryptographic signing of messages in v1. A motivated attacker with FS write can modify messages silently. Signed messages (GPG-style) are considered a Phase-5 enhancement.
- Archive files are mutable in the archive directory. Archive integrity is an audit-trail gap; consider immutable archive storage (WORM) for regulated environments.

### 3. Repudiation

**Concrete threat scenarios:**

- "I didn't post that" — a member denies authorship of a controversial message.
- "I didn't leave" — a member claims they didn't call `/council-leave` when their Completion Report shows they did.
- "The verdict wasn't me" — the channel's ACCEPT verdict is disputed by a member claiming they didn't vote.

**Mitigations in MAD.Council:**

- **session_id + run_id on every message**: two independent correlations tie the action to a session.
- **Completion Reports on leave** (`mad.council.a2a.md` §9.2): structured log of what the departing member contributed. Stored at `<channel>/leave-reports/`.
- **Consent audit trail** (`dangerous-operations-policy.md` §Enforcement): `<channel>/consent-log.jsonl` logs every gate emission + user decision.

**Residual risk:**

- Members can claim "the session_id was stolen" to evade the binding. This is a conflict between repudiation-mitigation and spoofing-residual-risk: if you accept that session_id is forgeable, repudiation is weakened.
- No third-party timestamping. A member could claim "the clock was wrong." Clock-skew checks in preflight help but aren't conclusive.

### 4. Information Disclosure

**Concrete threat scenarios:**

- **Cross-project leak.** A member posts from `project: market-analysis` into a channel whose other members work on `ml-training` — sensitive market data visible to unrelated members.
- **PII in message bodies.** A member pastes a support ticket into a thread, including customer PII.
- **A2A cross-org broadcast.** A message tagged `transport: a2a-http` is delivered to an agent-card endpoint outside the current org — potentially a competitor's infrastructure.

**Mitigations in MAD.Council:**

- **Explicit `channel.purpose`** (required at `/council-open`): sets expectations about topicality. Members can see purpose drift in the digest.
- **Project tag on `from`**: every message carries `from.project`. Readers can tell when a message originates from a different project.
- **Body size cap (32KB)**: limits accidental bulk paste. Encourages file-path references over embedded content.
- **Cross-org A2A consent gate** (`dangerous-operations-policy.md` §Category table): first message to an OIDC-discovered endpoint requires explicit "yes/no" confirmation.

**Residual risk:**

- **PII handling is explicitly out of scope** (`mad.council.a2a.md` §2). No auto-redaction. Members are responsible for their own data hygiene.
- **Filesystem trust** — if another OS user can read `~/claude-data/`, they see every message. Use OS permissions + encrypted home if this matters.

### 5. Denial of Service

**Concrete threat scenarios:**

- **Poll storm.** A bug causes CronCreate to fire every second instead of every 2 minutes; digest.json is hammered.
- **Message flood.** A runaway agent posts 10,000 messages in a thread.
- **Large-body DoS.** A single message posts 100MB of data, filling the disk.
- **Thread explosion.** An agent creates 1,000 threads in minutes.

**Mitigations in MAD.Council:**

- **Circuit breakers** (`mad.council.a2a.md` §10.1): 3 consecutive polling failures → member disconnected, CronCreate deleted. Also: 5 consecutive post-time validation failures → force-interactive pause.
- **Body size cap 32KB** (§8.5): per-message limit prevents large-body DoS.
- **Bulk-post batch gate** (§10.4): >10 mentions or >10 new threads in one operation → consent prompt.
- **A2A rate limit**: max 20 outgoing messages per minute per session per endpoint (§10.5).
- **Max-100-messages-per-thread nudge** (§7.4): not enforcement, but a visible prompt to split.

**Residual risk:**

- **Disk fill by sheer message count** (not size): even at 1KB per message, a member could post hundreds of thousands of valid small messages. No hard cap on message count per channel. Consider a channel-level message-count budget in a future version.
- **CronCreate abuse**: a member could /council-join N channels to N different machines to fan out polls. Rate-limits are per-session; cross-session floods aren't controlled.

### 6. Elevation of Privilege

**Concrete threat scenarios:**

- **Uninvited agent joins.** An attacker discovers a channel name and joins without invitation.
- **Admin-bypass.** A member attempts to issue a verdict or archive a channel they shouldn't have authority over.
- **Transport upgrade.** A local-only member manipulates their agent card to claim an A2A endpoint and drains cross-org traffic.

**Mitigations in MAD.Council:**

- **Invite-only discovery**: channel names are not enumerable. `/council-list` only shows channels the current session is a member of. Joining requires an explicit `/council-join <name>` with a name the user already knows.
- **Force-reclaim consent gate**: alias reclaim is not automatic — user must explicitly confirm with preview.
- **Verdict authorship verification**: verdicts carry the session_id of the issuer; post-read verification applies to verdicts too (future enhancement — spec v1 doesn't explicitly specify, but it's a natural extension).
- **OAuth 2.0 for A2A cross-machine**: agent cards with `auth_schemes` declared are subject to the Ship Bridge's token exchange, not MAD.Council's internal trust.

**Residual risk:**

- Channel names are secrets. If a name leaks (e.g., in a screenshot), anyone who knows the name can attempt to `/council-join`. Mitigation: explicit `--as "<alias>"` is required and alias reuse is detected, but a fresh alias will be accepted by default.
- No explicit admin role in v1. Anyone in the channel can archive it (if last member) or resolve threads. Admin-tier authorization is a Phase-5 item.

## ASTRIDE extensions (deferred to Phase 5)

ASTRIDE (arxiv 2512.04785) adds:

- **LLM-specific threats:**
  - Prompt injection via message body (partially covered by `prompt-injection-policy.md`, but ASTRIDE formalizes it as a STRIDE-adjacent category).
  - Jailbreak via ingested artifact content.
  - Hallucinated tool invocation.

- **Agentic threats:**
  - Goal corruption (an agent's objective is subtly redirected across a long interaction).
  - Tool-abuse chaining (agent chains low-risk tools to achieve high-risk outcome).

Tracked in `_review-checklist.md` (ASTRIDE adoption is a Phase-5 consideration, not a v1 blocker).

## Per-feature threat-model requirement

When any skill is added or modified, its SKILL.md must include a STRIDE Delta section:

```markdown
## STRIDE Delta
| Category | Does this change expand the attack surface? | If yes, mitigation |
|---|---|---|
| Spoofing | No change | — |
| Tampering | No change | — |
| Repudiation | Expands (new write action) | Logs to <channel>/consent-log.jsonl |
| Info Disclosure | No change | — |
| DoS | No change | — |
| Elevation | No change | — |
```

A row with "Yes" and no mitigation is a blocking review issue per the Council layer's severity rubric.

## References

- Microsoft SDL STRIDE — https://learn.microsoft.com/en-us/previous-versions/commerce-server/ee823878(v=cs.20)
- `plugins/zen-agents/agents/security-manager.md` — lean-output format + litmus tests.
- ASTRIDE extension — arxiv 2512.04785 — https://arxiv.org/html/2512.04785
- `mad.council.a2a.md` §8.4 — the spec section this expands.
- Dependabot-spoofing attack class — https://www.itpro.com/security/cyber-attacks/hackers-are-spoofing-themselves-as-githubs-dependabot
- GitHub spoofing-and-prevention guide — https://blog.gruntwork.io/how-to-spoof-any-user-on-github-and-what-to-do-to-prevent-it
- `C:\Users\tonym\.claude\loop-scratch\skills-review\CHECKLIST.md` — iter-3.5 Channels v1 analysis that surfaced the initial threat list.
