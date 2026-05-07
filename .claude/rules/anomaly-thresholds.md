# Anomaly Thresholds

Threshold overrides for `.claude/hooks/detect-anomaly.js` (and `scope-guard.js` for `scope_guard_enabled`).

| Key | Value | Notes |
|---|---:|---|
| spawns_per_hour | 10 | Alert on excessive agent spawning |
| consecutive_failures | 3 | Alert on repeated failures |
| token_multiplier | 2.0 | Alert when token usage > multiplier of average |
| session_duration_hours | 2 | Alert on long-running sessions (was 4; 120+ GB RAM leak risk: #4953) |
| rapid_prompt_seconds | 30 | Window for rapid prompt detection |
| rapid_prompt_count | 5 | Number of rapid prompts before warning |
| planning_turns_without_write | 8 | Alert after N consecutive Read/Grep/Glob without Write/Edit (implementation phases only) |
| detect_overplanning_enabled | true | Set to false to disable planning ratio check |
| scope_guard_enabled | false | Consumed by scope-guard.js (not detect-anomaly.js). scope-guard.js must be registered in settings.json to take effect. |
| anomaly_cooldown_seconds | 300 | Suppress duplicate anomaly fingerprints within cooldown window |
| anomaly_repeat_summary_count | 5 | Emit one repeat-summary after this many suppressed duplicates |
| anomaly_repeat_summary_window_seconds | 900 | Sliding window used for duplicate-repeat summary aggregation |
