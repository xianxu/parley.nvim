---
type: pensive
status: active
created: 2026-06-15
slug: parley-two-modes-chat-vs-artifact
---

# Parley's two modes: chat-workbench (P1) vs artifact-workbench (P2)

Framing settled in conversation 2026-06-15 while picking up #128. It corrects a
premature unification: #128 originally tried to make *skills* "configure a turn
of the chat loop," conflating two genuinely different modes. They should be
treated as separate projects sharing only a lower layer.

## The unifying lens: parley constructs a per-turn **context**

Whatever mode parley is in, a turn's context is assembled from three sources:

1. **system prompt** — the persona (parley's own).
2. **tool definitions** — some always-on, some contributed by a skill.
3. **skill-contributed prompt portions** — a named body (protocol/instructions).

A *skill* is then just **a named prompt-portion, optionally bundled with
tool-grants and a UI registration for direct invocation.** This is the
generalization that turns parley from a chat bot into an agent harness.

## P1 — parley as an ariadne workbench (read-only investigation)

Ordinary parley **chat**, made repo-aware: ask about chat history, and — in an
ariadne-style repo — local pensives, issues, files. It weaves the parley chat
in as an integral part of ariadne's bench. Characteristics:

- Multi-turn linear chat; the **transcript** is the durable record.
- **Tools only, read-only** — no mutation contemplated in this bucket.
- The win over a coding harness is the durable / accessible / flexible
  transcript format (markdown-as-state), not raw capability.
- **#116's discovery registry feeds this** — as P1 *context/tools* (how the chat
  finds repo nouns), **not** as a "skill."

## P2 — a workbench around one artifact

Parley opens any markdown file; **that file is the subject**. There is no
separate chat — the "chat" is *implicit*, invoked through **skills**. Example,
the review skill: a system_prompt (the review protocol) + the document + tools
(read more files; and crucially **propose changes**). Characteristics:

- Today it's a **single LLM call** expecting one proposal tool-call; conceptually
  extensible to multi-turn recursive.
- Tools include **mutation** (propose/apply edits).
- The "chat" is **multi-headed**: each marker/comment spawns a thread — many
  threads packed into one parent document (cf. drill-in markers, review markers).
- Canonical case: **document review**.

## What follows from the split

| | P1 (chat workbench) | P2 (artifact workbench) |
|---|---|---|
| **tools** | ✅ read-only | ✅ read + **mutate** |
| **skills** | ✗ | ✅ — "skill" lives *only* here |
| **loop** | multi-turn chat | single-shot → maybe recursive |
| **"chat" shape** | linear transcript | multi-headed (markers → threads) |
| **state record** | the chat transcript | the artifact + its markers |

Two corrections to the original #128:

- **`repo_discovery`-as-a-"virtual skill" was a category error.** It is P1
  context/tools, not a P2 skill. (#128 M5 dissolves.)
- **Skills are not "turns of the chat loop."** `read_skill`-in-chat,
  `auto`/`always` activation pulling skills into the *chat* menu — those built P2
  concepts into P1's loop and come out.

## The genuinely-shared core (what's still worth unifying)

The real DRY win — and #128's original *Problem* statement — is that parley has
**two execution engines** (`chat_respond`'s loop and `skill_runner`'s
single-shot) that re-implement the same thing: assemble context → call the LLM →
decode/execute tool calls → maybe recurse.

So the worthwhile unification is **one context-assembler + tool-call loop** that
both modes parameterize:

- **context = system_prompt ⊕ tools ⊕ (skill body, P2 only)** — the 1/2/3 above.
- **P1** drives it with chat history + read-only repo tools, multi-turn.
- **P2** drives it with a skill's system_prompt + the document + the skill's
  tools (incl. the mutation tool), single-shot-or-recursive — so `skill_runner`
  (the parallel engine) **deletes**.

The unification is at the **loop**, not at "skills are chat turns."

## Implications for the issue set

- **#116** (discovery registry) — P1; done; wire as P1 context/tools, not a skill. No rework.
- **#128** — **re-scoped** to "unify the execution loop + context assembly; skill = the P2 artifact-mode descriptor." M1 (manifest + providers + registry) mostly survives as the **P2-skill descriptor**; the chat-flavored fields (`scope`, `activation.auto/always`) trim toward "how a skill is surfaced in the P2 UI." M2–M5 re-planned (drop read_skill-in-chat / chat menu / repo_discovery-as-skill).
- **#129** (capability permission model) — tool permissions; relevant to **both** modes (P2 mutation especially); layers on the shared tool infra.
- **P1 itself** — "parley chat as ariadne workbench: discovery + repo tools in chat context" is a **distinct project** that likely deserves its **own issue** when we tackle it. Not created yet (deferred).

## Open questions (for when we fully tackle this)

- The precise shape of the shared context-assembler + loop API that both
  `chat_respond` (P1) and the P2 skill driver call — the detailed re-plan of
  #128's M2+.
- How far to trim the M1 manifest's chat-flavored fields now that skills are
  P2-only.
- Whether P2's multi-headed (marker → thread) model needs anything from the
  shared loop beyond single-shot/recursive.
