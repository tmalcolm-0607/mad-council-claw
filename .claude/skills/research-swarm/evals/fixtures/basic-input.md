# Fixture: basic input for /research-swarm (synthetic)

Synthetic input for the research-swarm skill. The skill orchestrates multiple parallel-researcher agents on disjoint topics, then synthesizes.

## Synthetic input artifact

Topics:
1. Rate-limiting strategies for serverless APIs
2. Async/await pitfalls in .NET 10
3. EventBridge vs Service Bus tradeoffs

Expected: 3 parallel researchers; synthesis at end.

## Skill invocation

```
/research-swarm "rate limiting; async pitfalls; eventbridge vs service bus"
```

## Notes

This fixture exercises the smart-default flow (parse topics → spawn parallel → synthesize).
