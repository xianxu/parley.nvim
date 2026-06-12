---
type: continuation
slug: parley-readonly-harness
agent: claude
session_id: cf6161a1-d526-4ca4-af7b-61b7f3698932
created: 2026-06-11T18:18:56
branch: main
issues: [000115, 000116, 000128, 000129]
---

# Continuation: parley-readonly-harness

## NEXT ACTION
Execute **parley.nvim #116 M1** (discovery-registry core) from a fresh parley.nvim session — plan is written, fresh-reviewed, ready:
```
cd /Users/xianxu/workspace/parley.nvim
sdlc claim --issue 116      # open->working (estimate 20 already set)
sdlc change-code            # branch + plan-quality gate (re-checks the plan)
# then execute workshop/plans/000116-discovery-registry-plan.md via superpowers-executing-plans
#   TDD Tasks 1-8; close with: sdlc milestone-close --issue 116 --milestone M1
```
Start at Task 1 (the `Matcher` pure entity). Per-task test runs use the direct plenary form (`nvim --headless -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/discovery_matcher_spec.lua"`), **not** `make test-spec` (atlas-keyed, inert until Task 8).

## State of play
Arc: turning parley.nvim into a **readonly research harness** (its edge is the chat surface — tree-of-chats, markdown-as-state; cede read/write agentic coding to claude). Five issues are the durable record — read them, don't re-derive:
- **#116** discovery registry — M1 planned+reviewed+ready (the next action); M2 (finders source roots from registry) + M3 (descriptor format + scaffolding) are plan sketches. `deps:[000114]` satisfied. `estimate_hours:20`.
- **#128** skill-system redesign -> agentic harness (**the main event**) — design settled, **no plan doc yet**. `deps:[]` (independent; only its `repo_discovery` task needs #116 M1).
- **#129** capability permission model — settled. `deps:[000128]`.
- **#115** faceted typed finder — reframed from "improve `<C-g>m`". `deps:[000116]`.
- **#106** skill system v1 — superseded by #128; left open for you to dispose.

Sequencing (approved): **#116 M1 -> #128 -> bridge `repo_discovery` -> #129 -> #116 M2/M3.** `sdlc state` in parley.nvim confirms live status.

## Live deliberations
- **#128 needs its own `superpowers-writing-plans` pass** before executing — queued for after M1 closes (you said "ping me and I'll draft it").
- **M3 descriptor format** open: #116's three candidates (embedded fenced block / JSON sidecar / Lua sidecar), leaning (1) embedded structured. Deliberately deferred; M1 doesn't need it.
- **M2 interleave** — fast-follow; could slot right after M1 or wait until after the harness. Not decided, not blocking.

## Decisions & dead ends
**Decisions (why):**
- *Parley = readonly harness, not read/write* — read/write competes with claude and parley's tool loop isn't battle-tested; readonly also makes the security story trivial.
- *Registry is multi-source + base-union-local* — the highest-value nouns (issue/chat/note/vision) are NOT datatype docs (issue->`sdlc`, chat/note/vision->parley-native), so registry = parley-shipped Lua base UNION grep-discovered local `type:`. Audit: parley vendors ariadne's `construct/datatype/` byte-identical.
- *Descriptor format deferred to M3* — base+grep covers discovery; the embedded descriptor is only needed for scaffolding + rich local types.
- *#128 independent of #116* (corrected a mis-sequencing) — only `repo_discovery` bridges them.
- *`<C-g>m` stays the type-blind, registry-INDEPENDENT escape hatch* — type-aware finding goes to the faceted finder (#115); the registry may be partial because the escape hatch backstops it.
- *Permission model = capability-based, chain-scoped, human-gated* — `tools` (active incl. auto) vs `elevated` (manual only); model never self-elevates; grants scoped to the call chain, not the session.
- *M2 scoped to "finders source home root from registry"* — global/repo/super-repo merge reuses parley's existing root union.

**Dead ends:** "`<C-g>m` becomes the typed picker" (rejected — keep escape hatch); a `root_scope` enum (dropped — just expand repo-relative globs across `[repo_root]+members`); a new issue for the faceted finder (instead reframed #115).

## Pointers
Peer repo (pin path — cross-repo): **`/Users/xianxu/workspace/parley.nvim`** (work lives here; this session ran from `/Users/xianxu/workspace/brain`).
Read first (NOT auto-loaded): plan `parley.nvim/workshop/plans/000116-discovery-registry-plan.md`; issues `000116` (esp. `## Revisions`+`## Log`), `000128`, `000129`, `000115`. The source-map audit (5 discriminator kinds; base vs local) is summarized in #116's `## Revisions`.
Code the plan reuses: `lua/parley/tools/builtin/grep.lua` (`detect_grep()`+`vim.fn.system`), `lua/parley/super_repo.lua` (`compute_members`), `lua/parley/tools/types.lua` (validation style), `tests/minimal_init.vim`.
