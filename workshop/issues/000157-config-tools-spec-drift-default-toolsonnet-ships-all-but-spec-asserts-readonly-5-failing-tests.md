---
id: 000157
status: done
deps: []
github_issue:
created: 2026-07-01
updated: 2026-07-01
estimate_hours: 0.3
started: 2026-07-01T08:34:35-07:00
actual_hours: 0.31
---

# config_tools_spec drift: default ToolSonnet ships @all but spec asserts @readonly (5 failing tests)

## Problem

`tests/unit/config_tools_spec.lua` fails **5 tests** deterministically (in
isolation and in the full suite). The shipped default config
(`lua/parley/config.lua:222,246`) sets both `ToolSonnet*` and `ToolSonnet` to
`tools = { "@all" }` with the comment *"Swap @readonly → @all to also allow
edit/write"* — an intentional config change — but `config_tools_spec.lua` was
never refit. It still asserts:

- `get_agent("ToolSonnet").tools == { "@readonly" }` (`:149`, `:198`),
- and, in the full wiring chain, that `edit_file` / `write_file` are **absent**
  (read-only agent) in the resolved payload (`:232`, `:258`).

With the current `@all` default these expectations are wrong, so the suite is red
on a point unrelated to the feature under test. Discovered while landing #155
(verified unrelated to it via `git stash` — #155 touches only message emission).

## Spec

Two coupled decisions:

1. **Product decision (the real question):** should the *default* tool-enabled
   agent ship `@all` (read + edit/write) or `@readonly`? Shipping a default agent
   with write access is a notable permission posture (relates to the
   capability/permission model, #129). The `config.lua` comment says `@all` is
   intentional — if so, confirm; if it was an over-broad default, revert to
   `@readonly`.
2. **Refit the test to match the decision:**
   - If default stays `@all`: update `config_tools_spec.lua` expectations
     (`@readonly` → `@all`; the wiring-chain tests should assert `edit_file` /
     `write_file` are **present**), and refresh any goldens
     (cf. commit `ee7fdec` which last refit these).
   - If reverted to `@readonly`: change `config.lua:228,251` back and the tests
     pass as-is.

Keep a dedicated test that pins whatever the intended default is (so the next
swap can't silently drift the suite again).

## Done when

- `make test` has zero failures from `config_tools_spec.lua`.
- The default `ToolSonnet`/`ToolSonnet*` `tools` value and the spec's assertions
  agree, and a test documents the intended default explicitly.
- If the default is `@all`: a one-line rationale in `config.lua` (or atlas) notes
  why the default tool agent ships write access.

## Decision (product call resolved via git history)

`@all` is **intentional**, not accidental. `git log -S '"@all"'` shows the user's
own deliberate commit `8381829 "chagne tool use to @all"` swapping all four Tool*
agents (`ToolSonnet*`, `ToolOpus*`, `ToolSonnet`, `ToolOpus`) from `@readonly` →
`@all`, alongside model bumps to sonnet-5 / opus-4-8. So the default tool agent is
meant to have edit/write. Direction: **refit the test to `@all`** (option 2a), and
fix the now-misleading `config.lua` comments (they still say "read-only"). No
revert.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
design-buffer: 0.15
item: cross-cutting-refactor design=0.0 impl=0.2
item: milestone-review       design=0.0 impl=0.1
total: 0.3
```

Mechanical test refit (5 assertions + names/comments) + stale-comment cleanup in
`config.lua`; design cost ~nil (decision made via git history). `cross-cutting-refactor`
impl 0.2–1.0 (v2) × 0.4 (v3.1) → ~0.2; single-pass `milestone-review` ~0.1.

> *Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only.*

## Plan

- [x] Refit `config_tools_spec.lua`: the 3 `@readonly`-sentinel assertions →
      `EXPECTED_DEFAULT_TOOLS`; the **3** absence assertions (`edit_file`,
      `write_file` ×2) → assert **present**; update the `@readonly`/"read-only"
      wording in `describe`/`it` names, comments, AND assertion message strings.
- [x] Anti-drift (plan-quality #1): hoist `EXPECTED_DEFAULT_TOOLS = { "@all" }`
      to one local + add a canary that pins **every** tool-enabled default agent
      (discovered dynamically) so a future swap fails in one place.
- [x] Fix the stale `config.lua` comments on the Tool* agents (they said
      "read-only" / mislabeled `@all`) to describe `@all` + edit/write.
- [x] Confirm `config_tools_spec.lua` passes (22/22); full suite has no new
      failures.

## Log

### 2026-07-01
- 2026-07-01: closed — config_tools_spec 22/22 (was 5 failing on @readonly-drift assertions); full `make test` suite green; lint clean. Added EXPECTED_DEFAULT_TOOLS single-source + a dynamic canary pinning every tool-enabled default agent so a future swap fails in one place. --no-atlas: atlas already documents the @all default (agents.md:5 "all 7 builtin tools"); this is a test+comment drift-reconciliation with no new surface.; review verdict: SHIP

Filed from #155's landing (close + plan judges both flagged it as a pre-existing,
out-of-scope failure worth its own issue). Root cause is config↔test drift, not a
#155 regression. Product call resolved above (git history → `@all` intentional).
Golden `parley_harness_golden_spec.lua` is self-contained (passes `READONLY_TOOLS`
explicitly, 7/7 green) — not affected. Only `config_tools_spec.lua` + `config.lua`
comments need touching.

**Implemented.** `config_tools_spec.lua`: added `EXPECTED_DEFAULT_TOOLS = { "@all" }`
single-source local + a dynamic canary (`every tool-enabled default agent pins to
EXPECTED_DEFAULT_TOOLS`) that iterates `parley.agents` so a future swap of the
tool set OR the agent roster fails loudly in one spot. Flipped the 3 sentinel
assertions to `EXPECTED_DEFAULT_TOOLS`, the **3** `is_nil(edit_file/write_file)`
absence checks → `is_true` (present), and refreshed the stale `@readonly`/"read-only"
wording in `it` names, the block comment, AND the assertion message strings
(plan-quality note #2 — all three absence sites + messages). `config.lua`: rewrote
the three Tool* comment blocks (they said "read-only"/mislabeled `@all`) to
describe `@all` = read + edit/write, with a pointer to `@readonly` for a read-only
agent. Result: `config_tools_spec.lua` **22/22** (was 5 failing), lint clean.
