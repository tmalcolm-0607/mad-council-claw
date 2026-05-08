# Fixture: copilot-canary-tiny (synthetic thread context)

Thread: `fix-payment-retry-loop`
Channel: `synth-channel`
Status: active
Messages: 5

## Messages

1. (status, from synthetic-author-a) "Reported: PaymentService retries indefinitely on 4xx. Need bounded retry."
2. (file-ref, from synthetic-author-a) "src/services/PaymentService.cs:142 — `while (true) { try { ... } catch { } }` — no break, no max-attempt, no backoff."
3. (proposal, from synthetic-author-b) "Propose: cap at 3 attempts, exponential backoff, dead-letter on exhaustion."
4. (verdict-claim, from synthetic-author-b) "FIX issued — committed in branch users/synth/payment-retry-fix, sha 0000000."
5. (review-request, from synthetic-author-a) "Ready for council review of the FIX verdict."

## Underlying file evidence (synthetic)

`src/services/PaymentService.cs:142` (current HEAD on the cited branch):

```csharp
public async Task ProcessAsync(Payment p) {
    while (true) {
        try {
            await _gateway.ChargeAsync(p);
            return;
        } catch {
            // SYNTHETIC FIXTURE — do not deploy.
            // No break, no attempt counter, no backoff. Loop is unbounded.
        }
    }
}
```

Branch `users/synth/payment-retry-fix` contains zero commits modifying `PaymentService.cs`.
The FIX verdict claim in message 4 is therefore stale — evidence does not back it.

## Skill invocation

```
/council-review fix-payment-retry-loop --copilot --roles advocate,skeptic,architect
```

## Brief shape note

Synthesis lens: thread vs. 3-role council; binding-verdict cross-check.
The stale-verdict-with-no-supporting-commit is the canonical cross-model agreement target —
both Opus and GPT should flag this as a CRITICAL repudiation/integrity finding.
