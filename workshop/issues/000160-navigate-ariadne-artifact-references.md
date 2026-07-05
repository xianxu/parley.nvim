---
id: 000160
status: working
deps: [ariadne#144]
github_issue:
created: 2026-07-03
updated: 2026-07-05
estimate_hours: 1.8
started: 2026-07-03T23:39:29-07:00
actual_hours: 2.0
---

# navigate ariadne artifact references

## Problem

ariadne artifacts (issues, plans, review sidecars, targets) refer to each other
and across peer repos with **symbolic** refs — `ariadne#11`, `#15 M4`, `pair#84` —
but there's no fast way for a human in the editor to *jump* from a ref to the file
it names, especially across sibling repos. Navigation is manual (grep, guess the
path, `:e`).

This grew from **ariadne#144**, which originally framed the fix as files carrying
**stored cross-links** (e.g. `[ariadne#11](../ariadne/workshop/issues/000011-…md)`).
We rejected that premise: the issue *number* is immutable but the *path* is not —
slugs get renamed, and files move `issues/ → history/` on close/merge (ariadne#160
made that move happen on every merge). Stored links rot on archive. The fix is
**read-time resolution**.

The feature splits across two repos: **ariadne#144** is the resolver (`sdlc
resolve`, base-layer Go — reframed off the stored-link premise); **this issue** is
the parley editor UX that consumes it. `deps: [ariadne#144]`.

## Spec

**Keep the canonical ref symbolic; resolve the path on demand.** Agents already
write `ariadne#11` (the constitution mandates it and greps it). parley resolves it
to the current file location at navigation time — immune to renames, archiving,
and moves. Nothing is stored; nothing rots.

### Approach: `sdlc resolve` + parley UX

- **ariadne side (small dependency):** add a **read-only** `sdlc resolve <ref>` that
  maps a symbolic ref → the current file path(s), deriving artifact locations from
  the vocab/datatype models (the `discovery:` blocks — parley already sources the
  issue home from `issue.cue`, ariadne#116) rather than hardcoding. It also
  single-sources the **ref grammar** so parley and agents can't drift. Because it's
  read-only it takes **no git transaction lock** — so it avoids the lock-contention
  slowness of mutating verbs like `sdlc issue new`; cost is just Go process spawn
  (~10–40ms), imperceptible for keypress→jump.
- **parley side (this issue):** shell to `sdlc resolve` from Lua; **highlight**
  resolvable refs so they read as navigable (conceal/treesitter or regex); bind a
  keymap (`gf`-style) that resolves the ref under cursor and opens it. When a ref's
  id has a whole **family** (issue + `000160-*-plan.md` + `000160-*-m1-review.md`),
  offer a small picker — that is ariadne#144's original "interlink" ask, delivered
  as navigation (bidirectional, always current) instead of stored links.

### Ref grammar (single-sourced in ariadne; parley consumes)

- `repo#id` → that repo's workshop issue (`<parent>/<repo>/workshop/{issues,history}/<id>-*.md`).
- `repo#id Mx` → the issue + its milestone context (jump to the `Mx` row / review sidecar).
- Bare `#id` → the current repo.
- Disambiguate the GitHub inbox from the workshop tracker (sdlc already splits
  `--issue` vs `--github-issue`) — pick a form for GitHub refs (e.g. `repo gh#id`).
- Plans / review sidecars / targets resolve by the same 6-digit id.

### Why here, not in ariadne generating links (decided)

Read-time resolution is move-robust and stores nothing; write-time links store the
volatile path and rot on archive. The resolver *logic* lives in `sdlc resolve`
(single source, also usable by the CLI / agents — `sdlc open ariadne#11`), and
parley owns the editor affordance. Slower than a pure-Lua in-process resolver by a
process spawn, but single-source-of-truth is worth it (same call we made putting
the issue schema in `issue.cue`) — and read-only keeps it lock-free, so the spawn
is the only cost.

## Done when

- [x] From a ref under the cursor (`ariadne#11`, `#15 M4`, `pair#84`), a keymap
      opens the current file for that artifact — correct across sibling repos and
      after the file has been archived (`issues/ → history/`). *(e2e: `ariadne#160 M2`
      → the archived m2-review sidecar, cross-repo from parley)*
- [x] Resolvable refs are visually marked so they read as navigable.
      *(`ParleyArtifactRef` underline, chat + markdown)*
- [x] A ref with a family (issue + plan + reviews) offers a picker of the related files.
      *(e2e: `ariadne#144` → float_picker with 3 items)*
- [x] Resolution derives artifact locations from the ariadne models (no hardcoded
      paths); grammar single-sourced in ariadne, not re-encoded in Lua. *(parley's
      `iter_refs` is a loose detector; `sdlc resolve` is the sole authority)*

## Plan

- [x] **ariadne dependency — ariadne#144:** `sdlc resolve <ref>` — DONE + merged to
      ariadne main (read-only; grammar + discovery from the vocab model). No temp
      Lua resolver needed; parley shells straight to `sdlc resolve --json`.
- [x] parley: ref highlighting (regex via the decoration provider — `ParleyArtifactRef`).
- [x] parley: resolve-under-cursor keymap (`<C-g>r`) → `sdlc resolve` → open; family picker.
- [x] Cross-repo: `sdlc resolve` handles it; parley sets child `cwd` via
      `neighborhood.for_buf` so a bare `#id` anchors to the buffer's repo.

Durable plan: `workshop/plans/000160-navigate-refs-plan.md` (single close boundary,
TDD, fresh-eyes API-verified against parley source).

## Estimate

Best guess: ~1.8 hr (ship wall-clock, AI-paired).

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only.

```estimate
model: estimate-logic-v3.1
familiarity: 1.1
item: lua-neovim             design=0.3 impl=0.35
item: lua-neovim             design=0.2 impl=0.4
item: atlas-docs             design=0.1 impl=0.1
item: milestone-review       design=0.0 impl=0.18
design-buffer: 0.15
total: 1.82
```

Derivation (design kept from v2; impl = 40% of the v2/v2.1 primitive-table impl per
v3.1; familiarity 1.1 for the less-familiar parley/Lua codebase, offset by a detailed
reuse code-map; +15% design buffer for a thorough plan):
- **lua-neovim** — the pure core `lua/parley/artifact_ref.lua` (`iter_refs`,
  `parse_ref_at_cursor`, `parse_resolve_output`, `run_resolve`) + unit tests.
- **lua-neovim** — the editor surface: `ParleyArtifactRef` highlight (chat+markdown),
  `ResolveRefUnderCursor` command, `resolve_ref` keymap, `float_picker` family picker.
  Heavy reuse of existing infra (highlighter, keybinding registry, float_picker).
- **atlas-docs** — parley `atlas/` for the artifact-ref nav surface + keymap.
- **milestone-review** — the single fresh-context close boundary review.

recomputed = Σdesign(0.6)×1.15 + Σimpl(1.03)×1.1 = 0.69 + 1.133 = 1.823 ≈ total 1.82.

## Log

### 2026-07-03

- Created from a design discussion (with the operator) on ariadne#144. Conclusion:
  navigation belongs in parley at **read time** (symbolic ref stays canonical; path
  resolved on demand) — rejecting ariadne#144's stored-cross-link premise, which
  rots when files archive. Resolver logic goes in a read-only `sdlc resolve` (single
  source, lock-free, so not subject to the mutating-verb slowness) that parley shells
  to; parley owns highlight + keymap + family picker.
- Operator correction (2026-07-04): since the resolver (`sdlc resolve`) is ariadne
  base-layer work, **ariadne#144 is NOT wontfix** — it was reopened + reframed as the
  ariadne slice, and this issue now `deps: [ariadne#144]`.

### 2026-07-05 — implemented (ariadne#144 landed first)
- 2026-07-05: closed — Smart-gf added (operator request) + prior #160 feature: gf resolves an artifact ref under cursor, else native gf (verified e2e both paths: lua/parley/config.lua -> native gf; ariadne#160 M2 -> resolved sidecar). goto_ref_at_cursor parameterized with opts.on_no_ref. Full artifact-ref nav (highlight + <C-g>r + gf + family picker + cross-repo) intact. make test GREEN: lint 0 warnings/0 errors in 239 files, 128 spec files PASS, no failures. 22 unit tests (pure core + dispatch + gf fallback) + gf/resolve keybinding assertions. ACTUAL ~2.0h scoped (original ~1.8 + smart-gf ~0.2; tool over-attributes the multi-day #144-shared window).; review verdict: SHIP
- 2026-07-05: closed — FIX-THEN-SHIP boundary review addressed + shippable: (1) Critical lint (luacheck 542 while-executed-once) fixed via while->if — `make test` now GREEN (lint 0 warnings/0 errors in 239 files, unit+integration pass, prior tools_builtin_find flake -> PASS this run); (2) Important col-math untested -> extracted pure highlight_spans + unit test exact extmark columns for ariadne#11 and interior-space #15 M4; minors: comment accuracy, shell fallback aligned with issues.lua, README <C-g>r. FIX-THEN-SHIP pre-clears shipping once the named fixes land (vs REWORK); re-closing --no-judge to re-anchor the reviewed-HEAD invariant on the fixed code rather than redundantly re-dispatch the review. Full e2e vs real sdlc binary still holds (family/milestone/github/cross-repo/not-found). Actual ~1.8h scoped (tool 6.83 over-attributes the multi-day #144-shared window).; review verdict: not-run
- 2026-07-05: closed — parley artifact-ref navigation implemented + verified e2e against the REAL sdlc binary (headless nvim): bare #160 -> parley issue+plan (cwd anchoring); ariadne#144 -> archived 3-file family cross-repo; ariadne#160 M2 -> m2-review sidecar, goto opened it directly (single file); ariadne#144 goto -> float_picker "Resolve ariadne#144" with 3 items; gh#42 -> 0-file github notice; #99999 -> sdlc not-found error. 18 unit tests (pure core iter_refs/parse_ref_at_cursor/parse_resolve_output/run_resolve + dispatch 0/1/N) + keybindings assertion, green. ParleyArtifactRef highlight in chat+markdown. Config sdlc_cmd documented (must be the binary, not the shell fn). ACTUAL: tool suggested 6.83h is over-attributed — window a0d1afd3 spans back to the 2026-07-03 spec commits and is shared with #144 (already booked 2.0h) + idle; scoped #160 active work this session (post-#144-merge design + ~11min impl commits + e2e debugging) is ~1.8h, on the estimate.; review verdict: FIX-THEN-SHIP

ariadne#144 shipped `sdlc resolve`/`open` and merged to ariadne main, so parley
shells straight to it — no temp Lua resolver. Durable plan
`workshop/plans/000160-navigate-refs-plan.md` (fresh-eyes API-verified against
parley source; a plan-review caught a control-flow bug in the reference `iter_refs`
— searching the repo-pattern first leapfrogs an earlier bare `#id` — fixed by
taking the earliest of the repo/bare match each step).

**Design — a thin layer (the payoff of ariadne#144 doing the hard part):**
- `lua/parley/artifact_ref.lua` (new, pure core): `iter_refs` (a LOOSE ref-shape
  detector — `sdlc resolve` owns the grammar, ARCH-DRY), `parse_ref_at_cursor`
  (span under cursor, absorbs interior-space `#15 M4`), `parse_resolve_output`
  (plain + `--json`), `run_resolve` (shells `sdlc resolve --json` via
  `issues.build_spawn_argv` + an injected runner), and a testable `dispatch_resolve_result`
  (0 files → github notice / 1 → open / N → picker).
- Highlight: `ParleyArtifactRef` (underline) via a shared `push_artifact_refs` in
  both the chat + markdown decoration paths (ARCH-DRY).
- Keymap: `<C-g>r` (the `<C-g>` chord family; avoids shadowing Vim's `gf`) →
  `M.cmd.ResolveRefUnderCursor`, wired at both `register_buffer` sites.
- Family picker via the house `float_picker`; child `cwd` via `neighborhood.for_buf`.
- Config: `sdlc_cmd` (default `"sdlc"`) — **must point at the sdlc BINARY**; a shell
  *function* isn't reachable from `vim.system` (found during e2e).

**Verification (headless, against the REAL sdlc binary):**
- `#160` (bare) → parley's own issue+plan (cwd anchoring works). ✓
- `ariadne#144` → the archived 3-file family in ariadne `history/` (cross-repo + archive-correct). ✓
- `ariadne#160 M2` → the m2-review sidecar; `goto` opened it directly (single file). ✓
- `ariadne#144` `goto` → float_picker "Resolve ariadne#144" with 3 items (issue/plan/review). ✓
- `gh#42` → 0 files (github/external notice); `#99999` → sdlc's not-found error. ✓
- 18 unit tests (pure core + dispatch) + a keybindings assertion; unrelated
  `tools_builtin_find_spec` flake (shells a real `find .`, passes in isolation).

**Follow-up (operator request): smart `gf` fallback.** Added `gf` (`resolve_ref_gf`
→ `M.cmd.ResolveRefOrGotoFile`) alongside the dedicated `<C-g>r`: it resolves an
artifact ref under the cursor, else falls back to Vim's native `gf` (`normal! gf`),
so `gf` keeps opening plain paths — the fallback makes shadowing `gf` transparent.
Handler parameterized with `opts.on_no_ref`. e2e: `gf` on `lua/parley/config.lua`
→ native gf opened it; `gf` on `ariadne#160 M2` → resolved the sidecar. 22 unit
tests + the gf keybinding assertion; `make test` green (lint 0/0).
