# Fixture: basic input for /council-post (synthetic)

Synthetic input for the council-post skill. The skill posts a message to a thread with monotonic seq + atomic write.

## Synthetic input artifact

Channel: `service-redesign`
Thread: `pivot-rationale` (existing)
From alias: `Skeptic`
Body (≤32 KB): "Latency claim of 'fan-out is faster' needs evidence. Service Bus typical p95 is 12 ms; EventBridge p95 is 45 ms in the docs."

## Skill invocation

```
/council-post service-redesign pivot-rationale "..."
```

## Notes

This fixture exercises the smart-default flow (validate → claim seq → atomic post). For mode-specific fixtures (--new-thread, --type task, --force-raw), add additional fixtures.
