# Changelog

All notable changes to MAD Council Claw. Per the user directive "github early and commit often. we want to see the thought/audit history/chain of thought as you go" — this changelog is the human-readable summary; `git log` is the full chain-of-thought audit trail.

## [Unreleased]

### Wave 1 / Lane Zero (2026-05-06)

- **Repo bootstrap.** `git init` + `.gitignore` + `LICENSE` (MIT) + `.editorconfig`.
- **Wiki skeleton.** 12-directory structure under `docs/` per `foundational-plan.md` "Wiki structure" section. Each directory carries a placeholder `README.md` describing scope + per-file convention + intake protocol.
- **Foundational documents.** `docs/01-requirements/foundational-plan.md` (full plan, verbatim), `docs/01-requirements/session-requests.md` (Messages 1-33, verbatim), `docs/01-requirements/goals.md` (G1-G25 with source-message citations), `docs/01-requirements/glossary.md` (source-tag legend, confidence labels, key abbreviations).
- **Loop state initial files.** `docs/11-loop-state/current-wave.md` (multi-instance pickup table), `docs/11-loop-state/recent-improvements.md`, `docs/11-loop-state/confidence-ledger.md`, `docs/11-loop-state/wave-history/wave-001-lane-zero.md` (this lane's own bootstrap report).
- **Backlog initial files.** `docs/10-backlog/open-questions.md` (with Q-1: gh auth identity blocker), `docs/10-backlog/research-gaps.md`, `docs/10-backlog/design-decisions-pending.md` (D-1..D-8 from plan), `docs/10-backlog/implementation-todo.md`, `docs/10-backlog/feature-promotions.md`, `docs/10-backlog/retire-candidates.md` (12 retire candidates seed from prior per-item-review.md), `docs/10-backlog/dropped-with-rationale.md` (audit trail).
- **Top-level files.** `README.md` (repo navigation), this `CHANGELOG.md`.

### Identity blocker

`gh auth status` shows `tonym_microsoft` (EMU) as the active account. Remote push to `tmalcolm/mad-council-claw` requires switching to `tmalcolm`. User must run one of:

```
gh auth switch -u tmalcolm                          # if tmalcolm already in keyring
gh auth login --hostname github.com --git-protocol https --web   # otherwise
```

Until then: LOCAL-ONLY mode. All commits land in `C:\Users\tonym\Repos\mad-council-claw\`; remote push pending user action.
