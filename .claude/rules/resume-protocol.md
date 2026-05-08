# Resume Protocol

After context compaction or session restart:

1. Check `cat .claude/work-items/ACTIVE`
2. Check for PENDING_HANDOFF -> run `/resume-handoff`
   - PENDING_HANDOFF is at `.claude/work-items/{WI-ID}/PENDING_HANDOFF`, or `.mad/scratch/PENDING_HANDOFF` if no work item was active
3. Read plan.md for last `[x]` checkbox
4. Check `[!]` markers for blocked items
5. Continue from exact point
