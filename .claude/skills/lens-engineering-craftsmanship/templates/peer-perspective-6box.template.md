# Peer Perspective 6-Box Template (MS Connect form)

Generic shape for one peer's full Perspective. Reads as 6 distinct boxes in the MS Connect form.

## Hard rule: peer-centric subject

Every box has the PEER as the subject. Lead with peer-observable behavior: what they authored, decided, pushed back on, caught, proposed, asked, validated, withdrew, accepted.

```
✅ "You authored the SMS Software Design Document and continuously synchronized it with shipped code."

❌ "I shared the design pattern with you and you absorbed it."
```

The Tony-centric framing (option 2) is **self-Connect material**, not peer feedback.

## 6-box template

### {Peer Name}. {Role / Title}

**Keep doing... Here's something I think you do really well and hope you keep doing:**

{Peer-observable strengths anchored on dated specifics. What they authored, decided, pushed back on, caught. 3-5 anchor moments minimum.}

**Here's a suggestion for how you could leverage this strength further:**

{One concrete, actionable next-step framed as how their existing strength could scale or land earlier in the cycle.}

**Re-think... Here's something you may want to re-think:**

{Optional. Substantive friction worth flagging, OR "No response."}

**Here's an example to consider for doing it another way:**

{Optional. If Re-think is substantive, give a concrete example of when they did the right shape, OR "No response."}

**Additional thoughts... The thing I most value about working with you is:**

{What you most appreciate about the working dynamic, anchored on concrete moments where the dynamic showed up.}

**Here are some other thoughts I have that you may want to consider:**

{Two or three specific moments worth holding up. Each one names a peer-observable contribution, decision, or behavior with the concrete evidence. Quote-friendly fragments are great.}

## Anchor-moment quality bar

Each anchor moment should pass these tests:
- **Subject is the peer**: "you proposed", "you authored", "you withdrew", "your message said". Not "I shared with you".
- **Dated or scoped**: "Apr 11", "the Mar 13 collated email", "the Feb 19 demo discussion".
- **Specific artifact or quote**: filename, PR number genericized, or short verbatim phrase.
- **Decision-shaped**: shows the peer made a judgment call, not just executed a task.

## Anti-patterns (lint will flag)

- "Tony-centric pivot" mid-paragraph (e.g., starts about peer, ends about what Tony did for them).
- Vague compliments without evidence ("you're great at communication" without a quoted exchange or named artifact).
- Missing one of the 6 boxes (set to "No response" if intentional, don't omit).
- Em-dashes, AI-slop phrases, banned vocab from profile.

## Validator

```
pwsh .claude/skills/lens-engineering-craftsmanship/scripts/connect-validate.ps1 -InputFile <draft.md> -Mode peer-feedback
```
