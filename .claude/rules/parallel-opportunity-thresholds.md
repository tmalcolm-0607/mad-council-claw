# Parallel Opportunity Thresholds

Config for the parallel-opportunity-detector hook.

## Thresholds

| Key | Value |
|-----|-------|
| min_parallel_tasks | 3 |
| min_time_savings_minutes | 15 |
| cooldown_seconds | 300 |
| max_teammates_per_wave | 6 |

## Detection Logic

Triggers when: >=3 independent wave-1 tasks, no team exists, savings >=15min, outside cooldown. Suppressed if file ownership conflicts detected.
