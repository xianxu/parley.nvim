# Boundary Review — parley.nvim#160 (whole-issue close)

| field | value |
|-------|-------|
| issue | 160 — navigate ariadne artifact references |
| repo | parley.nvim |
| issue file | workshop/issues/000160-navigate-ariadne-artifact-references.md |
| boundary | whole-issue close |
| milestone | — |
| window | f9cbc2ed547d65ae44a32b78a1212be76faef2eb..HEAD |
| command | sdlc close --issue 160 |
| reviewer | claude |
| timestamp | 2026-07-05T14:08:00-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

This is a clean, well-architected boundary: a genuinely thin editor layer over `sdlc resolve`, with the pure core (`iter_refs`, `parse_ref_at_cursor`, `parse_resolve_output`, `dispatch_resolve_result`, `family_picker_items`) unit-tested by 18 passing specs and the IO seam (`run_resolve`) behind an injected runner. I verified the integration contract against the **real** `sdlc` binary — the `--json` shape (`.files[]` with `kind`/`path`/`milestone`, `github:true` → empty files, exit-1 stderr on not-found) matches parley's parser exactly across family, milestone, github, and not-found cases, so all four Done-when e2e claims hold. The one thing blocking a clean SHIP is that the new file trips a luacheck warning that makes `make test`'s `lint` target exit non-zero — so the suite is **not** green as the Log claims. That plus a missing highlighter test are the only real gaps; everything else is solid. Fix the lint one-liner, re-run `make test`, ship.

### 1. Strengths
- **ARCH-DRY done right.** `iter_refs` is the single ref-shape source, consumed by both `parse_ref_at_cursor` and the highlighter's `push_artifact_refs` (`highlighter.lua:27`), which is itself shared across the chat (`:293`) and markdown (`:460`) compute paths. `build_spawn_argv` is reused verbatim (`issues.lua:369`), not re-implemented.
- **ARCH-PURPOSE / shadow-sweep passes.** The grammar is genuinely single-sourced in `sdlc` — parley's detector is deliberately loose and delegates all *acceptance* to the binary. No hand-maintained restatement of the grammar exists; the loose→over-match→sdlc-rejects flow is the correct derivation.
- **ARCH-PURE.** Business logic (span-finding, output parse, 0/1/N dispatch) is pure and injected into the thin `goto_ref_at_cursor` shell; `run_resolve`'s runner seam keeps it spawn-free in tests.
- The earliest-of-repo/bare control flow (`artifact_ref.lua:34`) correctly fixes the leapfrog bug the plan-review caught (`#15` before `ariadne#11`), and it's pinned by a test.
- Config default (`sdlc_cmd = "sdlc"`) carries an accurate, hard-won comment about the shell-function-vs-binary gotcha.

### 2. Critical findings
- **`lua/parley/artifact_ref.lua:30` — new lint warning fails `make test`.** luacheck flags `while pos <= #line do` as *"loop is executed at most once"* (code 542): every path through the body returns, so the `while` is semantically an `if`. `luacheck lua tests` therefore exits 1, and since `test: lint test-unit test-integration` runs `lint` first, **`make test` fails at the gate** — contradicting the issue Log's "full suite green" / the close's expected `--verified` evidence. No runtime impact (the closure's `pos` state persists across calls, so iteration is correct), but the gate is red. *Fix:* change `while pos <= #line do` → `if pos <= #line then` (drop the now-unneeded trailing `return nil` inside, keep the outer one), then re-run `make test` to confirm green.

### 3. Important findings
- **Missing highlighter test for `ParleyArtifactRef` col math.** `push_artifact_refs` (`highlighter.lua:27`) emits `col_start = s-1, col_end = e-1` off `iter_refs`' one-past `e`. This off-by-one-prone conversion is untested despite an established harness (`tests/unit/highlighter_spec.lua`, `tests/integration/highlighting_spec.lua`) and the plan (Task 2.1 Step 3) explicitly calling for it. A wrong col would ship unnoticed. *Fix:* add a case asserting a `ParleyArtifactRef` extmark spans exactly `ariadne#11` (and `#15 M4` incl. the interior space) in a chat/markdown buffer.

### 4. Minor findings
- **Keymap binding only asserted via help text.** `keybindings_spec.lua:46` checks the registry-derived *help line* for `<C-g>r`, which passes even if the `resolve_ref` callback wiring (`init.lua:1973`, `:2221`) were absent. Plan Task 2.3 Step 3 suggested a `maparg` assertion; wiring is present so risk is low.
- **Header comment overstates purity.** `artifact_ref.lua:9` says "Pure core (no Neovim/spawn): … parse_resolve_output", but that fn uses `vim.json.decode` and `family_picker_items` uses `vim.fn.fnamemodify` — Neovim APIs (pure/no-IO, but not "no Neovim"). Tighten the wording to "no IO/spawn".
- **Shell fallback inconsistency.** `run_resolve` uses `opts.shell or vim.o.shell` (`artifact_ref.lua:99`) for the sdlc-as-shell-function path, whereas `issues.lua:413` uses `vim.env.SHELL or vim.o.shell or "sh"`. If `vim.o.shell` isn't the login shell where the `sdlc` function is defined, the fallback misses. Low impact (docs steer users to a real binary), but aligning with the issues.lua precedent would be more robust.
- **README keybinding list.** `README.md:112-125` curates `<C-g>` shortcuts and omits `<C-g>r` — consistent with existing omissions (`<C-g>o` open_file, `<C-g>n` search are also absent), so non-blocking, but adding it would aid discoverability of a navigation feature.
- Highlighting runs on every line incl. fenced code blocks in chat, so a `#123` inside a code fence underlines as a ref. Cosmetic; acceptable under the stated "loose detector" design.

### 5. Test coverage notes
- Pure core + dispatch + `run_resolve` (injected fake) coverage is thorough (18 specs, all verified passing). The real gaps are the **highlighter col math** (Important, above) and the **actual keymap invocation** (Minor). I independently confirmed the sdlc `--json` contract end-to-end, which is the highest-risk external dependency — that's solid.

### 6. Architectural notes for upcoming work
- The `parse_resolve_output` plain-text branch is dead in production (`run_resolve` always passes `is_json=true`); it's only exercised by unit tests. Harmless, but if a future consumer never needs plain mode, consider dropping it to avoid a second untested-in-prod path.
- The 0-files-means-github assumption in `dispatch_resolve_result` conflates "github ref" with "sdlc exited 0 but returned no files for any other reason" (e.g. a future sdlc shape change). Today the contract holds (`github:true` is the only empty-files case), but a downstream sdlc change could make the "github/external" notice misleading. If sdlc ever grows other empty-result cases, key the message off the `github` flag rather than `#files == 0`.

### 7. Plan revision recommendations
- None required for scope/traceability — the plan's Core-concepts table matches the code (all three pure entities + four integration points exist at the stated paths; `grammar_pattern` was refactored into the `REPO_PAT`/`BARE_PAT`/`MS_PAT` locals but the public `iter_refs` surface the table names is present). Once the lint fix lands, no `## Revisions` entry is needed. (If you want the plan to reflect reality precisely, a one-line note that `M.grammar_pattern` was inlined as module-local patterns rather than exported would close the only table-vs-code wording drift — optional, Minor.)

---

## Re-review — 2026-07-05T14:43:10-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 160 — navigate ariadne artifact references |
| repo | parley.nvim |
| issue file | workshop/issues/000160-navigate-ariadne-artifact-references.md |
| boundary | whole-issue close |
| milestone | — |
| window | f9cbc2ed547d65ae44a32b78a1212be76faef2eb..HEAD |
| command | sdlc close --issue 160 |
| reviewer | claude |
| timestamp | 2026-07-05T14:43:10-07:00 |
| verdict | SHIP |

## Review

Confirmed against the **real** `sdlc` binary — the integration contract holds exactly across all four Done-when cases:

- `#160` (bare, cwd-anchored) → 3-file family (issue/plan/review) → **picker**
- `ariadne#160 M2` (cross-repo, milestone, **archived** `history/` sidecar) → exit 0, single file → **open** ✓ (Done-when #1)
- `gh#42` → `{github:true, files:[]}` → **external notice** ✓
- `#999999` → **exit 1**, error on stderr, empty stdout → `err` branch → warn ✓

`run_resolve`'s `code ~= 0` branch keys correctly on sdlc's real exit-1-on-not-found, and `parse_resolve_output` reads `kind`/`path`/`milestone` exactly as sdlc emits them. My review is complete.

```verdict
verdict: SHIP
confidence: high
```

This is a clean, genuinely thin editor layer over `sdlc resolve` — the pure core (`iter_refs`, `parse_ref_at_cursor`, `parse_resolve_output`, `dispatch_resolve_result`, `highlight_spans`, `family_picker_items`) is unit-tested by 22 passing specs, the IO seam (`run_resolve`) is behind an injected runner, and the editor wiring is a small shell. I verified `make test` green firsthand (**exit 0, 0 lint warnings / 0 errors in 239 files**, unit + integration all PASS) — so the two blocking items from the earlier FIX-THEN-SHIP review are genuinely resolved: the luacheck-542 `while`→`if` fix landed (`iter_refs` now uses the closure/`if` pattern), and the col math was extracted to a pure `highlight_spans` helper with exact-column unit tests. I also independently confirmed the `sdlc --json` contract against the live binary (highest-risk external dependency), and all integration seam signatures (`build_spawn_argv`, `neighborhood.for_buf`, `open_buf`, `float_picker.open`) match their call sites. Nothing blocks SHIP; only Minor notes remain.

### 1. Strengths
- **ARCH-DRY — clean.** `iter_refs` is the single ref-shape source, consumed by `parse_ref_at_cursor`, `highlight_spans`, and (via `highlight_spans`) the highlighter's shared `push_artifact_refs` (`highlighter.lua:27`), which is itself the one helper both the chat (`:297`) and markdown (`:461`) compute paths call. `issues.build_spawn_argv` is reused verbatim (`artifact_ref.lua:118`), not re-implemented — the "sdlc is a shell function" handling lives once.
- **ARCH-PURE — textbook.** Span-finding, output parse, col math, and 0/1/N dispatch are all pure and injected into the thin `goto_ref_at_cursor` shell; the `runner` seam keeps `run_resolve` spawn-free in tests. The col-math extraction (`highlight_spans`, `artifact_ref.lua:62`) is exactly the "pure core, tested directly" move the prior review asked for.
- **ARCH-PURPOSE / shadow-sweep passes.** The grammar is single-sourced in `sdlc`; parley's `iter_refs` is deliberately a *loose candidate-flagger* that delegates all acceptance to the binary (over-match → sdlc rejects). There is no hand-maintained restatement of the grammar — the correct derivation pattern, confirmed against the live resolver.
- The earliest-of-repo/bare control flow (`artifact_ref.lua:36-46`) correctly fixes the leapfrog bug the plan-review caught (`#15` before `ariadne#11`) and is pinned by a test (`artifact_ref_spec.lua:47`).
- The smart-`gf` follow-up is well-designed: `normal! gf` bypasses the mapping (no recursion), and gating on `parse_ref_at_cursor` under the cursor makes shadowing `gf` transparent on plain paths.
- Docs gate satisfied: new `atlas/context/artifact_refs.md` (thorough, honest about the single-source contract), `atlas/index.md` link, and README `<C-g>r` + `gf` entries all in-range.

### 2. Critical findings
None.

### 3. Important findings
None. (The prior review's two — luacheck-542 lint and untested col math — are both verifiably addressed: `make test` exits 0, and `highlight_spans` has exact-column unit tests for `ariadne#11` and the interior-space `#15 M4`.)

### 4. Minor findings
- **Decoration-provider glue has no integration assertion.** `push_artifact_refs` (`highlighter.lua:16-30`) maps `highlight_spans` → extmark entries, but no test asserts a real `ParleyArtifactRef` extmark lands (right hl_group, right namespace) in a rendered chat/markdown buffer. The col math is now pure-tested and both callers invoke the helper identically (so the #155 "diverging glue seam" risk doesn't apply), keeping this low-risk — but one assertion in `highlighting_spec.lua` would close the last structural gap (a mistyped `"ParleyArtifactRef"` would currently ship silent).
- **Keymap wiring asserted only via help text.** `keybindings_spec.lua:46-49` checks the registry-derived help lines for `<C-g>r`/`gf`; the actual `resolve_ref`/`resolve_ref_gf` callback wiring (`init.lua:1973`, `:1974`, `:2222`, `:2223`) isn't `maparg`-asserted. Wiring is present in source, so risk is low.
- **`M.cmd.ResolveRefOrGotoFile` / `ResolveRefUnderCursor` not directly tested.** The underlying `goto_ref_at_cursor(opts)` fallback is tested (`artifact_ref_spec.lua:190-207`), but the two `M.cmd.*` wrappers (incl. the `normal! gf` fallback string) are only exercised manually. Low risk.
- **Highlighting runs inside fenced code blocks** — a `#15` in a chat code fence underlines as a ref. Cosmetic, consistent with the stated loose-detector design.
- **Header comment now accurate** (`artifact_ref.lua:9` says "no IO/spawn", correctly scoping the vim.json/vim.fn use) and shell fallback now matches `issues.lua` (`:117`) — both prior Minors addressed.

### 5. Test coverage notes
- Pure core + dispatch + `run_resolve` (injected fake) + the `on_no_ref` smart-gf fallback are thoroughly covered (22 specs, all verified passing). I independently confirmed the sdlc `--json` contract end-to-end across family/milestone/github/not-found — the highest-risk external dependency is solid.
- Remaining gaps are the **decoration-provider extmark** (Minor) and the **`M.cmd.*` invocation** (Minor). Both are thin adapters over tested logic; the substantive risk is covered.

### 6. Architectural notes for upcoming work
- **`parse_resolve_output` plain-text branch is dead in production** — `run_resolve` always passes `is_json=true`; the plain mode exists only in unit tests. Harmless and tested, but if no consumer ever needs plain output, dropping it removes a second never-run-in-prod path (Simplicity-First).
- **`dispatch_resolve_result` conflates "0 files" with "github/external"** (`artifact_ref.lua:145`). Today the sdlc contract guarantees exit-0-empty only for `github:true` (verified: not-found is exit 1), so it holds. If sdlc ever grows another empty-result-with-exit-0 case, key the "external" notice off a `github` flag rather than `#files == 0`, or the message will mislabel it.

### 7. Plan revision recommendations
- The Core-concepts table in `workshop/plans/000160-navigate-refs-plan.md` has drifted from the shipped surface (not contradictory about *delivery*, but stale). Append a `## Revisions` entry noting: (a) `M.grammar_pattern` was **not exported** — it was inlined as module-local `REPO_PAT`/`BARE_PAT`/`MS_PAT`; the public shape is `iter_refs`; (b) implementation added pure `highlight_spans` (the close-review col-math fix), `dispatch_resolve_result`, `family_picker_items`, and the `goto_ref_at_cursor` shell; and (c) the `resolve_ref_gf` smart-`gf` surface + `M.cmd.ResolveRefOrGotoFile` were added as an operator follow-up after the first close. This keeps the table honest per the "revise mid-stream via `## Revisions`, don't overwrite" convention. Non-blocking.
