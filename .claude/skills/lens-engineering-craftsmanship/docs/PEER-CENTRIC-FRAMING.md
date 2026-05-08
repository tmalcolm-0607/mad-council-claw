# Peer-Centric Framing (the rule you'll forget if you don't read this)

When authoring peer Perspective feedback in MS Connect, the **subject of every sentence is the peer**. Not the user. Self-Connect harvests look the same on the surface but they are not the same artifact.

## The mistake

When WorkIQ surfaces a moment like "Tony shared work-item-templates.zip with Joel after Ben recommended Tony as the work-item-hygiene authority," the synthesis pattern wants to write:

> *"You absorbed my work-item-hygiene patterns after Ben pointed you my way. I shared the templates and you ran with them."*

That's a self-Connect sentence wearing peer-feedback clothing. The subject pivots between "you" and "I"; the credit centers Tony's giving rather than Joel's asking and adopting.

## The rule

Lead every sentence with what the **peer** did, decided, said, withdrew, asked, validated, accepted. Tony only appears as background context, never as the actor.

```
✅ "You came in with a precise question about work-item hygiene after Ben's pointer, named exactly which patterns you wanted to see, and ran with the artifacts on your own from there. low overhead, high mutual trust, knowledge moves cleanly."

❌ "Ben pointed you my way, I shared work-item-templates.zip + DataCollector.Design.md + the LENS-SMS/CMS ADO links, you took it from there."
```

## How to tell which artifact you're authoring

| Question | Self-Connect | Peer Perspective |
|---|---|---|
| Whose impact is being measured? | Tony's | The peer's |
| Who is the grammatical subject? | "I" or implied | "You" or peer's name |
| Where do peer names appear? | "Collaboration:" line at end | Throughout, as actors |
| Where does Tony appear? | As actor everywhere | Background context only |
| Outcome framing | "Did X, resulting in Y" (Tony's Y) | "You did X, which means Y" (peer's contribution) |

## Reframe checklist (apply per-sentence)

For each sentence in a peer 6-box, run:

1. **Subject test**. Is the peer the grammatical subject? If you find "I shared", "I helped", "I unblocked", "I covered" — rewrite.
2. **Verb test**. Is the verb peer-authoritative (authored, decided, proposed, withdrew, caught, root-caused)? If the verb is passive ("absorbed", "received", "was given") — find the active peer-side verb.
3. **Pivot test**. Does the sentence start with the peer and end with Tony's action? If yes, split or rewrite.
4. **Anchor test**. Is there a quoted phrase, named artifact, or specific date? If not, the box is too vague.

## When Tony has to appear

Sometimes Tony's role is structurally relevant (cross-team review, paired debugging, mutual feedback). Even then, frame it as the peer's behavior:

```
✅ "On the contracts review you wrote *"This is great. we've been maintaining local copies of these enums in SMS"* — that single comment captures the seam-as-ours posture."

❌ "I left feedback on your contract PR and you adopted it cleanly."
```

The first sentence makes Angelo the subject; Tony is implicit (the comment was on Tony's PR). The second makes Tony the subject; Angelo is the recipient of Tony's feedback.

## Why this matters

- The peer reads the Perspective and should feel **seen**, not credited.
- The manager handles outside-perspective citations of Tony via the Feedback section. Self-praising in peer feedback is a category error.
- The peer's actual decisions are the most teachable artifact for them — that's the thing they can repeat or scale.
- Self-Connect already has a section for "what Tony did with peers." It's called Part 1 Results. Don't duplicate.

## When you spot the mistake

- If you're synthesizing a 6-box and find yourself writing "I + verb + you", stop.
- Re-read the harvest file for that peer.
- Find the sentence that names what THE PEER did — that's your replacement.
- If the harvest doesn't have peer-side material, run a peer-only WorkIQ query (see `templates/workiq-peer-decisions-prompt.template.md`).

## Reference

- `templates/peer-perspective-6box.template.md` — the generic 6-box shape with the subject-test rule.
- `evals/peer-centric-vs-self-centric.md` — fixtures the linter uses to detect the drift.
- `examples/example-peer-6box.md` — good vs bad side-by-side.
