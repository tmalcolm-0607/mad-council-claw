# Fixture: clean dep-bump PR (synthetic)

PR: chore(deps): bump SharedContracts to 1.11.0
Author: Synthetic Author
Branch: users/synth/bump-shared-1.11.0 → master
Status: active
Files: 1 changed (Directory.Packages.props version line)

## Diff (synthetic)

```
- <PackageVersion Include="Acme.SharedContracts" Version="1.10.0" />
+ <PackageVersion Include="Acme.SharedContracts" Version="1.11.0" />
```

## Description

Picks up new shared types added in 1.11.0. No code changes required; the consumer routes the new types via DI auto-discovery only when the feature flag is on. Build clean, all tests pass.

## Existing threads

(none)

## Author claims

- Build: 0 errors / 0 warnings
- Tests: 4500 passed / 0 failed
