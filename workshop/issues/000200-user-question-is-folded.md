---
id: 000200
status: working
deps: []
github_issue:
created: 2026-08-18
updated: 2026-08-19
estimate_hours:
started: 2026-08-19T11:50:43-07:00
---

# user question is folded

let's do an audit how folding is done. user questions should not be folded. what's folded:

1. tool call
2. tool response
3. summary started with 📝:

only those should be folded and those should always be folded. 

## Problem

Two invariants are violated:

1. A user question (`💬:`) can end up as a fold header, rendered
   `💬: … (N lines)`. Confirmed by the operator and reproduced.
2. Tool calls (`🔧:`), tool results (`📎:`) and summaries (`📝:`) can fail to
   fold, or be swallowed into a neighbouring fold.

The intended policy was already correct — `fold_projection.FOLDABLE` is
`{thinking, summary, tool_use, tool_result}` and excludes questions. The
failures are in how that desired state is *applied* and in how answer sections
are *segmented*, not in the policy.

## Spec

Folding holds these two invariants at all times, not merely on a cold open:

- **A user question is never inside a fold.** Not as a fold header, not
  swallowed by an earlier fold.
- **`🔧:`, `📎:`, `📝:` and `🧠:` blocks are always folded**, each anchored on
  its own marker line.

`🧠:` stays foldable (operator decision, 2026-08-19): it is verbose and
fold-worthy, and it is already legacy — the shipped default prompt dropped the
`🧠:` protocol in #143, so it only appears under custom/back-compat prompts.

Two root causes, both fixed here:

- **`tool_folds.reconcile_exchange` does not reconcile.** It appends folds at
  model-computed rows and never removes one the projection no longer wants, so
  drift from any mutation not wrapped in `with_exchange_update` is permanent
  and survives the whole session (`hydrate_window` latches on
  `initialized[buf][win]`). Drift past EOF additionally throws an uncaught
  `E16: Invalid range`.
- **The fenced-tool-body grammar has three owners.** `tools/serialize.lua`
  implements it correctly (matching pair of the *same* backtick length);
  `answer_structure.lua` closes on any ≥3-backtick run, and `chat_parser.lua`
  does not model fences at all. So a nested ``` block truncates a tool section,
  and a `💬:` line inside tool output forks a spurious exchange (`ARCH-DRY`).

## Done when

- [ ] `reconcile_exchange` verifies each projected range against its anchor
      marker, re-derives the model from the buffer on drift, and clears the
      exchange span before creating folds — no fold can outlive the projection.
- [ ] A stale/drifted model never anchors a fold on a `💬:` line and never
      throws `E16`.
- [ ] One `parley.fence` module owns the fenced-body grammar; `serialize`,
      `answer_structure` and `chat_parser` all derive from it.
- [ ] A nested ``` block inside a tool body no longer truncates its section.
- [ ] A `💬:`/`🤖:`/`📎:` line inside a tool body is content, not a turn.
- [ ] A durable corpus harness asserts both invariants against real transcripts
      plus an adversarial fixture, measured on actual Neovim fold state.
- [ ] `make test` green; atlas + lessons updated.

## Plan

Design: `workshop/plans/000200-fold-reconciliation-plan.md`

- [ ] M1 — fold reconciliation
  - [ ] Anchor verification in `fold_projection` (pure)
  - [ ] `clear_folds_in_span` replaces start-row-only fold deletion
  - [ ] `reconcile_exchange` verifies → re-derives on drift → clears → creates
  - [ ] Corpus regression harness (`tests/integration/fold_invariants_spec.lua`)
- [ ] M2 — one fence grammar
  - [ ] Extract `lua/parley/fence.lua`
  - [ ] `serialize` derives fence selection from it (+ parity test)
  - [ ] `answer_structure` matches fences by length; unterminated fence stops
        at the next boundary instead of swallowing the rest of the answer
  - [ ] `chat_parser` treats markers inside a tool body as content
  - [ ] Adversarial fixture added to the corpus harness

## Log

### 2026-08-19 — fold-surface audit

**The whole fold surface is one producer.** `lua/parley/tool_folds.lua` is the
only module that creates or deletes folds (`grep -rn "fold" lua/` — the only
other hits are `outline.lua`'s `zz` recentering, which is scrolling, not
folding). It runs `foldmethod=manual` and creates every fold explicitly from
`fold_projection.desired_folds`, which folds exactly:

    FOLDABLE = { thinking, summary, tool_use, tool_result }

So the *intended* policy already excludes questions — and includes `thinking`
(🧠:), which the issue's list of three does not mention.

**Corpus audit — the static path is clean.** Three scans over all 127 real
transcripts (`workshop/parley/` + the iCloud `chat_dir`):

1. Pure projection (parse → exchange_model → desired_folds): **0 violations**.
   No fold range covers a `💬:` line; every `🔧:`/`📎:`/`📝:` line is covered.
2. Runtime hydration in a real buffer (`tool_folds.hydrate_window` → `zM` →
   `foldclosed()`): **0 violations**. Same two invariants, measured on actual
   Neovim fold state.
3. Ground-truth raw-text scan for structural markers inside a tool block's
   fenced body: **0 hits**.

**Probes that cleared suspected live-path defects:**

- Appending the next `💬:` prompt right after a folded trailing block
  (`chat_respond.lua:1929`) does *not* grow the fold over it — Vim does not
  extend a manual fold at its end boundary.
- `initialized[buf][win]` gating hydration across a buffer switch does not lose
  folds or `foldmethod`; Neovim saves/restores both per buffer per window.

**Two latent structural defects found (both fence-naiveté, neither reproduced
by the current corpus):**

- `chat_parser.lua:549` — the main loop classifies every line with no
  fence-awareness, so a `💬:` line inside a `📎:` tool-result body starts a
  *new exchange*. The spurious question then absorbs the rest of the tool body
  (including the closing fence and any `📝:`), leaving it unfolded.
- `answer_structure.lua:88` — once `fence_open` is true the scanner ignores
  `BOUNDARY` kinds, but `highlight_structure.classify` treats *any* run of ≥3
  backticks as `fence`. A tool result whose body contains a nested ``` block
  (outer fence is longer per `tools/serialize.lua`) closes the section early;
  the tail is then emitted as unfoldable `text`.

Both violate "those should always be folded". Neither folds a user question.

### 2026-08-19 — ROOT CAUSE reproduced

Operator confirmed the symptom shape: the fold's **first line is the `💬:`
line**, rendered `💬: … (N lines)`. That text can only come from `foldtext()`'s
`else` fallback (`tool_folds.lua:154`) — i.e. a fold whose start row is not a
`🔧:`/`📎:`/`🧠:`/`📝:` marker.

**Reproduced** (`scratchpad/drift_probe.lua`): hydrate a chat, mutate the buffer
through a path that does not update the live model, then call
`reconcile_exchange` on the now-stale model. Output:

    23 💬: second question   foldclosed=23 foldend=26
    >>> foldtext: 💬: second question (4 lines)

**Root cause — `reconcile_exchange` does not reconcile; it only adds.**

    for _, range in ipairs(ranges) do
        vim.cmd(string.format("%d,%dfold", range.start_0 + 1, range.end_0 + 1))
    end

It creates folds at model-computed rows and never removes a fold the projection
does not want. The only deletion is `prepare_exchange_update`'s
`delete_projected_folds`, which `zd`s **only at the desired start rows** — so a
fold anywhere else in the exchange survives untouched. Consequences chain:

1. Any buffer mutation not wrapped in `with_exchange_update` drifts the live
   model from the buffer (the model is built once and mutated incrementally,
   never re-derived).
2. The next reconcile creates folds at stale rows, which can land exactly on a
   `💬:` line.
3. Nothing removes it, and `hydrate_window` will not re-run — `initialized[buf]
   [win]` latches after the first hydration — so the bad fold persists for the
   whole session. Reopening the file is the only cure, which is why all 127
   transcripts audit clean from a cold parse.
4. `foldtext()`'s `else` fallback renders the corrupt fold as ordinary text
   instead of failing loudly, masking the defect.

**Second defect, same probe:** when drift runs the range past EOF,
`reconcile_exchange` throws an uncaught `E16: Invalid range: 23,26fold` out of
`vim.cmd`. Stale model ⇒ hard error, not degraded folds.

This is architectural, not a position off-by-one: the projection is a *desired
state*, but the applier treats it as an *append list*. `ARCH-DRY` — the buffer's
fold state has two owners (the live model's incremental mutations and Vim's own
line-shifting) with nothing making them agree.

### 2026-08-18
