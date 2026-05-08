# Example: Peer Perspective 6-Box (peer-centric, anchored on dated specifics)

Sanitized example showing the peer-centric framing pattern. Every box leads with peer-observable behavior.

## Good example

### Peer A. Senior Software Engineer, Service-X

**Keep doing... Here's something I think you do really well and hope you keep doing:**

You authored and continuously synchronized the Service-X Software Design Document with shipped code this cycle. The decisions you made show a consistent posture. you removed the `/provision` endpoint in favor of implicit container creation on the first `/sas` call to reduce orchestration complexity. trimmed the SAS response surface so only `sasUri` is returned. simplified region codes (e.g., `na1` instead of `na1p/na1s`) and let Azure Storage GRS handle the redundancy. moved storage-account naming to a programmatic resolution from CMS routing dimensions. chose User-Delegation SAS scoped per job and directory rather than account-level access. and explicitly deferred encryption scopes post-MVP0 in alignment with HLD conclusions to unblock delivery without violating SFI guidance. That's six load-bearing decisions made the same way: simpler APIs, stricter contracts, defer when risk > reward.

**Here's a suggestion for how you could leverage this strength further:**

The end-to-end Service-X playbook you've built (Bicep, NSP, 1P apps, security review, SDL, PIA) is a complete onboarding sequence for any new service in the org. A short "how I stood up Service-X infra and security from zero" runbook from you would save the next service team weeks of re-derivation.

**Re-think... Here's something you may want to re-think:**

When an issue is outside of your direct domain, your engagement noticeably drops. The pattern-recognition you bring inside your domain would help adjacent domains too, but only if you treat those conversations as adjacent rather than someone else's.

**Here's an example to consider for doing it another way:**

The Apr cross-service alignment week is the closer-to-home example: in five days you aligned Service-X with two adjacent services on blast-radius, state-ownership, and an enum extension. that kind of compressed convergence works in adjacent-domain design conversations too.

**Additional thoughts... The thing I most value about working with you is:**

You're one of the most thoughtful cross-service reviewers on the team. On the shared contract package you wrote *"This is great. we've been maintaining local copies of these enums and it's been a source of pain... we'll align to these ordinals when we adopt the Common package"*. That single comment captures it. naming the local divergence honestly, committing to align with the canonical contract, treating the seam as ours-not-mine.

**Here are some other thoughts I have that you may want to consider:**

The sub-type extraction architectural argument you made on the contracts review stuck with me: *"the approach is proven. Not asking for it in this PR. that'd blow up scope. But I think a follow-up to extract the lifecycle phases would go a long way"*. That's exactly the right balance of architect-grade vision and PR-boundary discipline. The new error code you introduced in Service-X distinguishing "the request is invalid" from "external service responded but data is incomplete" is the kind of contract-level honesty that makes ecosystems debuggable.

## Bad example (what to avoid)

### Peer A. Senior Software Engineer, Service-X

**Keep doing:**

I shared a lot of architectural patterns with you this cycle and you absorbed them well. I helped you with the SAS token design, the region simplification, the NSP work. I appreciate that you took my framework and ran with it.

**Most value:**

I value our partnership. I helped you through the Apr 11 RBAC-4k crisis, I uploaded the cert when you couldn't, I covered for you during your OOO. We work well together.

## What's wrong with the bad example

| Issue | Fix |
|---|---|
| Subject is "I" or "Tony" instead of the peer | Lead every sentence with what THE PEER did, decided, said |
| "I shared with you... you absorbed" | Reframe to "You authored / decided / chose" |
| "I helped you" framing | Reframe to "you noticed / you root-caused / you proposed" |
| Self-Connect material in peer feedback | What Tony did belongs in self-Connect Part 1, not here |
| No quoted artifacts or dated moments | Anchor every box on quoted phrase or named artifact |

## Quick reframe checklist

For each sentence in a peer 6-box, ask:
1. **Subject test**: is the peer the grammatical subject? If not, rewrite.
2. **Authorship test**: does it name what the peer authored, decided, said, withdrew? If not, find the peer-side action.
3. **Evidence test**: is there a date, quote, or named artifact? If not, add one or drop the sentence.
