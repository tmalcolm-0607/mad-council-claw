# 09 — Examples & proof

Per-feature physical evidence. Per Goal G22 (Message 27): "small micro sessions targets features with full behavior tests and physical proof."

## Convention

```
docs/09-examples-proof/F-NNN/
  red-test-output.txt        pasted vitest/jest output showing the test fails (RED state)
  green-test-output.txt      pasted output after impl (GREEN state)
  locked-review.md           council review verdict for the LOCKED transition
  status-table-screenshot.md CI eval-runner output showing F-NNN GREEN in the status table
```

## Why

- **Physical proof** beats claimed status. Per Goal G27 / kit's `verification-protocol.md` Rule 4 (ACTUAL BEFORE PRESENT): never claim "tests pass" without running them and pasting output.
- **Validatable scopes** per Goal G23: outcomes the user can verify by reading test output, not by trusting a status table.
- **Audit chain**: the proof files are the evidence; the status table aggregates them; the wiki ties them to features.
