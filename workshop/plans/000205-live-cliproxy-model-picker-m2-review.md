# Boundary Review — parley.nvim#205 (milestone M2)

| field | value |
|-------|-------|
| issue | 205 — live cliproxy model picker; retire hardcoded model lists |
| repo | parley.nvim |
| issue file | workshop/issues/000205-live-cliproxy-model-picker.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 45d9f28e131fc5b40f6f06743ecfe40fcdff9538..c9e83d8bb8a03db5f037164d7c7cf67e7c410233 |
| command | sdlc milestone-close --issue 205 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-08-31T21:30:15-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The IO shell M2 promised is real and well-proven: `fetch_catalog`/`catalog_cached`/`catalog_stale` land, the process fake gained `/v1beta/models` with the created-less and opaque-id shapes, and — the best thing in this window — a live conformance case against the real binary closes the fake↔fixture circularity that would otherwise let both suites agree on a wrong assumption. What blocks SHIP is the boundary's own headline deliverable: I deleted the live-agent restore block at `lua/parley/init.lua:1329-1343` in a scratch checkout of `c9e83d8` and the entire cliproxy suite stayed green, including the spec whose header comment calls that restart case "the whole point"; the plan's Task 3.3 wrote that test and it was dropped, and one of the three tests that shipped instead calls `build_agent` twice and compares the results. That is the third instance on this issue of a fix shipping with a test that cannot fail — the rule was written into the plan's round-5 Revisions ("break the code on purpose and watch the test go red") and violated by the very next milestone. Six Importants follow, of which two are documented contracts the code silently contradicts (`providers = nil`, the envelope's failure logging), one is a DRY claim in a docstring that is false (the promotion added a *third* copy instead of removing two), and one is the fresh-install path rendering nothing at all.

Two window notes up front. The head commit is an **M3** commit, so this M2 boundary is reviewing M3's picker code too and M3's own close will have an empty window — the M2 checkbox in `## Plan` is still unticked and there is no `## Log` entry for it. And the working tree carries uncommitted M4 changes to `config.lua`; my authoritative verification ran against a `git archive` of `c9e83d8` in a scratch tree, not the dirty checkout.

## 1. Strengths

- **`tests/integration/cliproxy_catalog_spec.lua:87-99`** — the join is proven with concrete values from the real process fake (`display` from `/v1beta`, `created` from `/v1`, and the created-less row surviving the round trip), not a mock restating the implementation. This is what an integration test should look like.
- **`tests/integration/cliproxy_catalog_spec.lua:112-123`** — the #131 dormancy contract is asserted through an *observable* (the port is still free after the fetch settles) rather than an invented API. That was the right call and it holds.
- **`tests/integration/cliproxy_conformance_spec.lua:239-274`** — ARCH-MOCK done properly: the `models/<id>` prefix and the "did the join actually land" assertion run against the real binary, so a proxy that starts emitting bare ids can no longer pass both suites. The rationale comment explains exactly why the fake alone is insufficient.
- **`tests/fixtures/fake_cliproxy:199-231`** — the fake carries the awkward shapes deliberately (absent `created`, an id that does not resemble its display name) instead of a happy path, and the two lifecycle expectations were updated with a comment saying what the case actually asserts rather than being edited to match.
- **`lua/parley/agent_picker.lua:89-91`** — appending the live section *after* the sort, so a moving catalog never reshuffles the configured agents, is a good stability instinct that the plan did not ask for.

## 2. Critical findings

### C1 — the M3 deliverable ships with no test that can fail (`missing-test-for-shipped-behavior`, 3rd in family)

**This is the 3rd finding in family `missing-test-for-shipped-behavior`.** Earlier rounds fixed instances (BR-3, BR-13 twice). Do NOT fix this instance — the rule below is the deliverable.

Verified by deletion, not by reading: I removed `lua/parley/init.lua:1329-1343` in a scratch copy of `c9e83d8` and re-ran `tests/unit/live_agent_state_spec.lua`, `tests/unit/picker_items_spec.lua`, `tests/unit/cliproxy_catalog_spec.lua`, `tests/integration/cliproxy_catalog_spec.lua` — 0 failures, 0 errors across all four. `grep -rn live_agent tests/` confirms no other spec touches it. The plan's Task 3.3 Step 1 wrote precisely the missing case (`parley.setup({})` re-entry, then assert `_state.agent` is still the live pick) and called it "the whole point of this task"; the shipped spec's own header comment repeats that, then does not test it.

The rest of the milestone's coverage has the same hole:
- `tests/unit/live_agent_state_spec.lua:69-75` — `build_agent(row)` called twice and compared. Same pure function, same input; it asserts determinism, nothing about persistence or restore. It cannot fail for any change to the code it is titled after.
- `M.agent_picker` (`lua/parley/agent_picker.lua:118-216`) — the entirety of Task 3.2 — has **zero** tests: `view_for`, the `on_select` branch on `kind`, the `<C-a>` toggle, the background-refresh gate. Task 3.2 has no "write the failing test" step at all; it goes from Implement to "Verify by hand in a real editor", and no `## Log` entry records that hand verification happening.

**The rule (fix this, not the site):** a plan task's Step-1 test block is the milestone's acceptance list. Before `milestone-close`, run the mutation check on every task in the milestone — delete the implementation that task added, confirm the mapped spec goes red, restore — and record the per-task result in `## Log`. A task whose implementation can be deleted with the suite green has not been delivered, whatever the diff shows. The enumeration for this window is exactly four rows: Task 2.1 (fake route), Task 2.2 (`fetch_catalog`/cache/staleness), Task 3.1 (`_build_items` + `_providers_without_models`), Task 3.3 (register + restore) — plus Task 3.2, which needs a Step-1 test block written before it can be checked at all. Tasks 2.1, 2.2 and 3.1 pass this check today; 3.2 and 3.3 do not.

## 3. Important findings

### I1 — the Spec/envelope claims the code does not implement (`stated-design-not-implemented`, 2nd in family)

**This is the 2nd finding in family `stated-design-not-implemented`.** Do not patch the individual sites — walk the enumeration.

Three claims, all shipped unimplemented and unpinned:

1. **`lua/parley/cliproxy.lua:1424-1451` logs nothing and discards the HTTP status.** The plan's Operating envelope: "When it exceeds the budget or the proxy is down, the cached list stays on screen and the failure is logged at debug." There is no `logger` call anywhere in `fetch_catalog`. Worse, line 1437 — `done(obj.code == 0 and (split_status(obj.stdout) or obj.stdout) or nil)` — takes only `split_status`'s first return and drops the status code, so a **401 body is handed to `parse()` as if it were a catalog**. It decodes to `{}`, no write happens, the cache survives — but a wrong `api_keys.cliproxyapi` is now indistinguishable from "the proxy serves no models," with no diagnosis on any channel. Every other consumer in this file routes the same curl through `classify()` (`cliproxy.lua:106`), which exists to name `client_key_mismatch` — #197 built that layer for exactly this failure. The fake even gained a 401 branch for `/v1beta/models` in this diff (`tests/fixtures/fake_cliproxy:407-409`) that **no test enters**, so the fake models a behaviour production ignores (ARCH-MOCK).
2. **"Cache in memory" is not implemented.** Spec Component 2: "Cache in memory; persist to `stdpath('data')/…/catalog.json`". `catalog_cached()` (`cliproxy.lua:1378`) re-opens, re-reads and re-decodes the file on every call, and the picker calls it 2-3× per open (`catalog_stale()` → `catalog_cached()`, then `view_for` → `catalog()`, then again on `<C-a>` and on the repaint). Each call also runs `vim.fn.mkdir` via `catalog_path()` (`cliproxy.lua:1366-1371`) — a filesystem write inside a documented read, on a UI path (ARCH-CONSTRAINTS: repeated work that should be cached).
3. **`providers = nil` does the opposite of what the Spec documents.** The issue Spec line 137 annotates the knob `-- nil providers = every known provider, unfiltered`. Measured: `cat.curate(models, {})` → `{}`. An operator who omits `providers` gets an empty live section with no explanation. Nothing in the plan or the specs covers this case.

**The rule:** every behavioural sentence in the Spec's Components and the plan's Operating envelope is an acceptance criterion. At each milestone close, walk them bullet by bullet and either point at the implementing line plus the test that pins it, or strike the sentence in a `## Revisions` entry. A claim left in the artifact that the code does not honour is worse than no claim.

### I2 — BR-6's guard was applied to one site and the sibling boundaries shipped without it (`missing-input-guard`, 2nd in family)

**This is the 2nd finding in family `missing-input-guard`.** State and fix the rule.

BR-6 (M1 round 3-4) established: "An unknown provider resolved to `owner = nil`, and `m.owner == owner` then pooled every row whose `owned_by` was absent. Unknown providers now contribute nothing." That guard lives at `cliproxy_catalog.lua:161`. This window then wrote the identical comparison fresh at `lua/parley/agent_picker.lua:28` **without it**. Measured against `c9e83d8`:

```
_providers_without_models({{id='claude-opus-5',owner='anthropic'}}, {'claud'})     → { { provider = "claud" } }
_providers_without_models({{id='claude-opus-5',owner='anthropic'}}, {'anthropic'}) → { { provider = "anthropic" } }
_providers_without_models({{id='x'}},                               {'claud'})     → {}
curate(       {{id='claude-opus-5',owner='anthropic'}}, {providers={'claud'}})     → {}
```

A typo — or the very plausible mistake of writing `anthropic` instead of `claude`, since the Spec's own tables use those words — renders `anthropic — (logged out)` as an actionable row that runs `:ParleyProxy login anthropic` and errors. And row 3 shows the answer flips to "fine" if any catalog row happens to lack `owned_by`, which is BR-6's original defect verbatim. `curate` and `_providers_without_models` take the same input and apply opposite policies. None of the three tests at `picker_items_spec.lua:365-382` uses an unknown provider.

The same rule has a second unguarded site: `catalog_cached()` validates only that `decoded.models` is a table, then `view_for(true)` hands those raw rows straight to `_build_items`, which does `m.display .. " - " .. m.id` unguarded (only `m.owner` is `tostring`-wrapped, so a row missing `owner` renders the literal string `X - x (nil)` to the operator — measured). BR-7 already settled where this guard belongs: "a row with no id is not a model, so `parse` drops it — one guard instead of a defence in every consumer." `catalog_cached` is the second entry point into that pipeline and did not get it.

**The rule:** every boundary where data enters the catalog pipeline from outside validates once, at that boundary. The enumeration for #205 is four: `parse` (network JSON — guarded ✓), `catalog_cached` (disk JSON — unguarded), `live_models.providers` (operator config — guarded in `curate`, unguarded in `_providers_without_models`), and `view_for(all)`'s expanded path (raw rows bypass curation entirely). Resolve provider→owner through one helper that returns nothing for an unresolvable name, and shape-check rows once on read.

### I3 — the empty catalog suppresses the login rows that exist for exactly that case (`one-value-two-decisions`, 2nd in family)

**This is the 2nd finding in family `one-value-two-decisions`.** Fix the rule, not the line.

`lua/parley/agent_picker.lua:142-144` — `if #models == 0 then return {} end` — makes one observation decide two independent questions: "are there models to curate?" and "which configured providers are logged out?". On a fresh install with no OAuth logins the proxy answers `/v1/models` with `data: []`, `parse` returns `{}`, so `view_for` returns `{}` and **no `(logged out)` row renders at all**. That is the onboarding path, and the Spec's stated purpose for these rows — "The picker thus answers both 'which model' and 'why is my provider missing'" — is unmet precisely when every provider is missing (ARCH-PURPOSE: the deferred case is the point).

Same gate, second consequence: `fetch_catalog` writes the cache only `if #models > 0` (`cliproxy.lua:1445`), so on that same fresh install `catalog_stale()` is permanently true and every single `:ParleyAgent` fires two fresh curls forever.

**The rule:** a guard added for a degenerate case must be scoped to the decision it actually informs. "The catalog is empty" is evidence about the live section only; the logged-out computation depends on the configured provider list, which is present regardless. Split the two, and add a `_view_for(models, cfg, all)` case with an empty catalog and a non-empty provider list.

### I4 — the helper promotion left three copies, and its docstring says otherwise (`duplicated-logic-not-extracted`, 2nd in family)

**This is the 2nd finding in family `duplicated-logic-not-extracted`.** State the covering rule.

`tests/helpers/ready_port.lua:67-69` reads: *"Promoted from file-local copies in cliproxy_lifecycle_spec.lua and cliproxy_recovery_e2e_spec.lua; a third consumer (#205's dormancy test) is what made the duplication worth removing (ARCH-DRY)."* The copies were not removed. `cliproxy_lifecycle_spec.lua:17,50` and `cliproxy_recovery_e2e_spec.lua:18,26` still define their own `free_port` and `wait_listening`; the diff to `cliproxy_lifecycle_spec.lua` touches only two assertions, and `cliproxy_recovery_e2e_spec.lua` is not in the window at all — while the plan's Task 2.2 **Files** section names both as "Modify … (call the promoted helpers)". Duplication went from two copies to three, under a comment claiming the opposite. They have also diverged: the two file-locals poll with `vim.wait(100, function() return false end)` inline, the promoted one polls `M.is_listening`.

This is the shape the "claimed fixes" check exists for — a rationale that reads as protection while the thing it describes did not happen.

**The rule:** a docstring that claims a consolidation is an assertion about the tree, and must be verifiable by grep at the moment it is written. When a task's **Files** section lists call sites to rewrite, the rewrite is part of that task's Definition of Done, not a follow-up; `grep -c 'local function free_port'` returning >1 is the check.

### I5 — no atlas or README update for any of the surface this window shipped (`atlas-not-updated-for-new-surface`, 2nd in family)

**This is the 2nd finding in family `atlas-not-updated-for-new-surface`.** The instance is not the fix; the plan's structure is.

The only `atlas/` change in the range is `traceability.yaml` — a test-file map, not surface documentation. Undocumented and shipped:

| surface | belongs in |
|---|---|
| `cliproxy.live_models.{providers, per_provider}` + the `provider:term,term` syntax | README config section, `atlas/providers/cliproxy-managed.md` |
| picker live section, `(logged out)` login rows, `<C-a>` full-catalog toggle + title change | `atlas/providers/agents.md`, `atlas/ui/pickers.md`, README's `:ParleyAgent` line (183) |
| `<data_root>/catalog.json` (0600, 10-min TTL) as a derived artifact | `atlas/providers/cliproxy-managed.md:43` already lists the other derived artifacts |
| `M.register_live_agent`, the `<id>*` session-agent naming, `_state.live_agent` persistence | `atlas/providers/agents.md` |

Verified absent: `grep -rn live_models README.md atlas/` returns nothing; `atlas/providers/agents.md` still describes selection as "`:ParleyAgent [name]` (picker or explicit)" with no live section.

**The rule:** the plan lumps documentation into a terminal Task 4.3 ("Atlas + docs"), which structurally guarantees every earlier milestone crosses its boundary with undocumented surface — the exact end-of-project sweep AGENTS.md §8 forbids. Delete Task 4.3 as a lumped task and attach a docs step to each milestone that introduces surface, naming the specific file and section. Then this finding's instances are M2/M3's own step, not a debt.

### I6 — the Spec's documented renders drifted and only containment pins them (`documented-render-not-pinned`, 2nd in family)

**This is the 2nd finding in family `documented-render-not-pinned`.** Extend the rule, don't retype the string.

Measured against `c9e83d8`:

```
live  |  Claude Opus 5 - claude-opus-5 (anthropic)|
login |  antigravity - (logged out)|
```

The Spec documents `Claude Opus 5 — claude-opus-5 (anthropic)` and `antigravity — (logged out)` (em dash), and "Configured agents, **separator**, then **one group per configured provider**". Shipped: hyphen, no separator, no grouping — a flat append. The tests at `picker_items_spec.lua:337-343` assert only `display:find("Claude Opus 5", 1, true) ~= nil`, so all four drifts pass.

BR-5 already settled this for `curate`: "Equality, not containment: order is part of the render," which produced the `SPEC_RENDERS` table keyed by the documented spec string. The picker's rows are documented renders in the same Spec and did not inherit it.

**The rule:** any render written into the Spec is pinned by a full-string equality derived from the Spec text, in whichever module produces it. Extend `SPEC_RENDERS` (or an equivalent keyed table in `picker_items_spec.lua`) to cover the live row, the login row and the section separator, so a row cannot be documented without a test — then decide per drift whether the code or the Spec moves.

### I7 — the Core concepts table names entities the code does not have (`plan-table-missing-entity`, 2nd in family)

**This is the 2nd finding in family `plan-table-missing-entity`.** The hole in the check is the fix.

The Integration points table lists `catalog_cached / catalog_write`. The code ships `M.catalog_cached` ✓ and `M._write_catalog` — `catalog_write` exists nowhere, and the plan's own Task 2.2 Step 3 code block writes inline with no such function. Also new in this window and absent from both tables: `M.catalog_stale`, `M._catalog_path`, and `M.register_live_agent` (the Integration table has "live-agent restore" but not the registrar the picker calls at `agent_picker.lua:177`).

I ran the Notes' prescribed referent grep over the whole plan: 74 dotted referents, 4 unresolved (`cc.resolve_channels`, `M.channels_for_owner`, `M.credential_health_across`, `M.resolve_channels`) — all four defined in Task 4.1's own code blocks, so clean under the rule. That is the point: **the grep pattern `\b\w+(\.\w+)+\s*\(` only matches dotted call syntax, and the Core concepts tables name entities bare.** Table rows are structurally exempt from the very check that exists to keep names honest, which is how `catalog_write` survived a round that reported the sweep run clean.

**The rule:** extend the Notes' check to run in both directions and to cover bare names — every entity named in a Core concepts row must resolve to a `file:line` or be created by a named task, and every function the milestone adds to a listed file must appear in a row. Both are one grep over the table cells, and both belong in the milestone-close checklist rather than in a reviewer's head.

## 4. Minor findings

- `lua/parley/agent_picker.lua:139-155` — `view_for` is a pure composition (models + cfg + a flag → a view) trapped in a closure over `plugin`, `cat` and `cliproxy`, which is why none of I3, I6 or the `<C-a>` bypass is testable. Extracting `M._view_for(models, cfg, all)` with `catalog()` injected is the single change that unlocks coverage for three of the findings above (ARCH-PURE).
- `lua/parley/agent_picker.lua:209` — gating the refresh on `cliproxy.is_managed()` means an operator running their own cliproxy (`manage = false`, documented in `config.lua:115` as the supported opt-out) never populates the catalog, even though `fetch_catalog` is a plain GET that cannot spawn anything. The Spec's constraint was "never spawn the daemon," not "only when managed."
- `lua/parley/cliproxy.lua:1442-1444` — the two GETs are chained, so the worst case is 2×`CURL_MAX_TIME` = 4 s, not the 2 s the envelope states; `handle.update` then swaps the list under a user who may already be typing or have moved the selection (`update` preserves `sel_idx` by index, not by identity).
- `tests/integration/cliproxy_conformance_spec.lua:241,260` — `pending("…")` where the file's five sibling cases use `print("SKIP: …")`. Both work; pick one. (Inconsistent error handling across the diff.)
- `lua/parley/cliproxy.lua:1366-1371` is a near-copy of `config_path()` at `:181-185`; a `data_file(name)` helper would carry the mkdir once.
- `lua/parley/agent_picker.lua:93` builds the live agent name as `m.id .. "*"`, duplicating the convention that `cliproxy_catalog.build_agent` owns at `:220`. Changing the suffix in one place makes the ✓ silently stop rendering, with every test still green — `picker_items_spec.lua:355` hardcodes `"claude-opus-5*"` rather than deriving it from `build_agent`.
- The M3 implementation commit sits inside the M2 review window (base `45d9f28` is the M1 close), so M3's own `milestone-close` will review commits this gate has already seen. `## Plan`'s M2 box is unticked and `## Log` has no M2 entry. (`boundary-crossed-out-of-order`)

## 5. Test coverage notes

Suite state at `c9e83d8`: `make lint` clean (0/0 across 344 files); `make test-spec SPEC=providers/cliproxy-managed` green across all 16 mapped files (integration catalog 5, conformance 7 — both new live cases ran, so the binary was present — lifecycle 53, catalog unit 42, picker items 35, live agent 3). Nothing is failing; the gap is entirely in what the passing tests can detect.

Unpinned behaviour shipped in this window, in rough order of exposure:

| behaviour | where | covered |
|---|---|---|
| live-agent restore before the fallback guard | `init.lua:1329-1343` | no — deletion verified green |
| `M.agent_picker` wiring (`on_select` branching, `<C-a>`, refresh gate) | `agent_picker.lua:118-216` | no |
| `view_for` empty-catalog path | `agent_picker.lua:142` | no |
| unknown provider → login row | `agent_picker.lua:19-38` | no |
| non-200 from either model route | `cliproxy.lua:1437` | no — and the fake's 401 branch is unentered |
| corrupt/partial rows from `catalog.json` | `cliproxy.lua:1378-1390` | no |
| `providers = nil` | `cliproxy_catalog.lua:153` | no |

The three `_providers_without_models` cases and the four `_build_items` live-section cases are good tests of the happy path and worth keeping; they are simply not the cases that would have caught anything in this review.

## 6. Architectural notes

- **ARCH-DRY — flag.** Three copies of `free_port`/`wait_listening` where the plan promised one (I4); the `<id>*` naming convention written in two modules; `catalog_path`/`config_path` near-copies. The consolidation that *was* done (`ready_port.lua`) is right — it just wasn't finished.
- **ARCH-PURE — flag.** The pure core (`cliproxy_catalog.lua`) and the two pure picker helpers are clean and tested without IO, which is the design working. But `view_for` mixes config reads, disk IO and curation inside a closure, and `catalog_cached` performs a filesystem *write* (`mkdir`) inside a documented read. The extraction in Minor #1 restores the seam.
- **ARCH-PURPOSE — flag.** Two under-deliveries against the stated purpose: the login rows vanish in the one case they exist for (I3), and BR-6/BR-7's rules were applied to the site each finding named while enumerable siblings shipped in this very window without them (I2). Family counts in this round — three at their 2nd instance and one at its 3rd — are the ledger reporting that the enumerations named in earlier rounds were never written down.
- **ARCH-MOCK — pass, with one flag.** This is the window's strongest axis: a stateful process fake carrying the awkward shapes, integration tests running the real production path against it, and a live conformance check against the real binary that specifically defends the assumption the fake and the fixtures share. The flag is that the fake now models a 401 the production code cannot observe and no test enters (I1.1) — a fake satisfies the principle only when production flow and test flow meet at the same boundary.
- **ARCH-CONSTRAINTS — flag.** The declared envelope is not enforced: the "one cached JSON read" is 2-3 reads plus 2-3 `mkdir` calls per open, "cache in memory" does not exist, the 2 s budget is 4 s across chained GETs, and the failure logging the envelope promises is absent. The parts that *are* enforced — never spawning the proxy, the 10-minute TTL, the in-flight guard — are enforced well and, for the first two, tested.

## 7. Plan revision recommendations

Four `## Revisions` entries — three on the plan, one on the issue:

1. **Plan — Core concepts, Integration points.** Rename the `catalog_write` row to `_write_catalog`, and add rows for `catalog_stale`, `_catalog_path` and `register_live_agent` (`lua/parley/init.lua`, new). State in **Notes for the implementer** that the referent check runs in both directions and covers bare table names, not only dotted call syntax — the current grep cannot see a table cell, which is how `catalog_write` survived a sweep reported clean.
2. **Plan — Task 3.2.** Add a Step 1 test block. The task currently has no automated coverage step at all, which is why `M.agent_picker` ships untested; specify `M._view_for(models, cfg, all)` as the pure seam and list the cases (empty catalog + non-empty providers, expanded bypass, `kind` branching in `on_select`).
3. **Plan — Task 4.3 and the docs cadence.** Dissolve the terminal "Atlas + docs" task into per-milestone docs steps naming the specific file and section, per AGENTS.md §8. Record the M2/M3 backlog from I5's table as this boundary's docs step.
4. **Issue — Spec, Component 3.** The Spec still says credential state "comes from parley's existing `/v0/management/auth-files` reader (`cliproxy_auth.lua`, #197), keyed by CHANNEL via `channels_for_login`, never by `owned_by`." The shipped `_providers_without_models` deliberately does the opposite — it infers logged-out from catalog emptiness, keyed by `owned_by` through `provider_owned_by`, because the auth-files reader is callback-async and cannot run synchronously on a picker open (BR-1's point). The plan records this divergence; the Spec does not, and the two mechanisms have genuinely different failure modes (a loaded-but-dead credential still lists models and reads as logged *in*). Revise the Spec to describe what ships and why, and either implement or strike `-- nil providers = every known provider, unfiltered` (Spec line 137) and the em-dash renders and section separator in Component 3.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      `_logged_out_providers` and `provider_states` are gone from the plan; Task 3.1 Steps 4-6 now create and test `_providers_without_models`, which the code delivers, and the prescribed referent grep runs clean (74 referents, 4 unresolved and all defined in Task 4.1's own code blocks). See new finding I7 for the hole the grep still has.
findings:
  - id: new
    severity: Critical
    family: missing-test-for-shipped-behavior
    title: |
      M3's restart-restore and the whole of Task 3.2 ship with no test that can fail
    detail: |
      3rd in family. Deleting lua/parley/init.lua:1329-1343 in a scratch copy of c9e83d8 leaves all four mapped specs green (0 failures); grep confirms no other spec touches `live_agent`. live_agent_state_spec.lua:69-75 calls build_agent twice and compares, asserting only determinism. M.agent_picker (agent_picker.lua:118-216) has zero tests and Task 3.2 has no Step-1 test block. Fix the rule, not the site: run the mutation check per task before milestone-close and record the result in `## Log`.
  - id: new
    severity: Important
    family: stated-design-not-implemented
    title: |
      fetch_catalog logs nothing and discards the HTTP status; "cache in memory" and `providers = nil` are unimplemented
    detail: |
      2nd in family. cliproxy.lua:1437 keeps only split_status's first return, so a 401 body is parsed as a catalog and is indistinguishable from an empty one; there is no logger call anywhere in fetch_catalog despite the envelope's "logged at debug", and the fake's new 401 branch (fake_cliproxy:407) is entered by no test. catalog_cached re-reads and re-decodes the file 2-3x per picker open with a mkdir each time — no in-memory cache exists. curate(models, {}) returns {} where the Spec documents "nil providers = every known provider, unfiltered" (measured). Rule: walk the Spec Components and the Operating envelope bullet by bullet at each close; implement and pin, or strike in `## Revisions`.
  - id: new
    severity: Important
    family: missing-input-guard
    title: |
      BR-6/BR-7's boundary guards applied to one site while two new boundaries shipped without them
    detail: |
      2nd in family. Measured: _providers_without_models(models, {'claud'}) and (models, {'anthropic'}) both emit actionable `(logged out)` rows that run `:ParleyProxy login <typo>`, while curate returns {} for the same input; with an ownerless catalog row the answer silently flips to {}, which is BR-6's original defect verbatim (agent_picker.lua:28 vs cliproxy_catalog.lua:161). Separately catalog_cached validates only that decoded.models is a table, then view_for(true) hands raw rows to _build_items, which concatenates m.display/m.id unguarded — a row without owner renders `X - x (nil)`. Rule: one guarded provider->owner helper, and shape-check rows once at each entry boundary (parse, catalog_cached, live_models.providers, the expanded path).
  - id: new
    severity: Important
    family: one-value-two-decisions
    title: |
      The empty-catalog early return suppresses the logged-out rows that case exists for
    detail: |
      2nd in family. agent_picker.lua:142 lets `#models == 0` decide both "are there models to curate" and "which providers are logged out". On a fresh install with no OAuth logins the proxy returns data:[], so no `(logged out)` row renders at all — the onboarding path the Spec's "why is my provider missing" purpose targets. Same gate, second effect: fetch_catalog writes only when #models > 0 (cliproxy.lua:1445), so catalog_stale stays permanently true and every :ParleyAgent fires two curls forever. Rule: scope a degenerate-case guard to the decision it actually informs.
  - id: new
    severity: Important
    family: duplicated-logic-not-extracted
    title: |
      The ready_port promotion left three copies and its docstring claims the duplication was removed
    detail: |
      2nd in family. ready_port.lua:67-69 says the helpers were "Promoted from file-local copies in cliproxy_lifecycle_spec.lua and cliproxy_recovery_e2e_spec.lua ... worth removing (ARCH-DRY)", but cliproxy_lifecycle_spec.lua:17,50 and cliproxy_recovery_e2e_spec.lua:18,26 still define their own, and the latter is not in the window at all despite being listed in Task 2.2's Files. Two copies became three, and they have diverged in implementation. Rule: a docstring claiming a consolidation must be grep-verifiable when written, and call sites named in a task's Files section are that task's Definition of Done.
  - id: new
    severity: Important
    family: atlas-not-updated-for-new-surface
    title: |
      No atlas or README update for live_models, the picker live/login sections, C-a, or catalog.json
    detail: |
      2nd in family. The only atlas change in the range is traceability.yaml, a test map. `grep -rn live_models README.md atlas/` returns nothing; atlas/providers/agents.md still describes agent selection with no live section; the derived-artifact list at cliproxy-managed.md:43 does not mention catalog.json. The instance is not the fix: the plan lumps docs into a terminal Task 4.3, which structurally guarantees every earlier milestone crosses its boundary undocumented (AGENTS.md 8). Dissolve 4.3 into per-milestone docs steps naming file and section.
  - id: new
    severity: Important
    family: documented-render-not-pinned
    title: |
      The picker's documented rows drifted (em dash, separator, grouping) with only containment assertions
    detail: |
      2nd in family. Measured render is `  Claude Opus 5 - claude-opus-5 (anthropic)` and `  antigravity - (logged out)`; the Spec documents an em dash, a separator between the configured agents and the live section, and one group per configured provider — none present. picker_items_spec.lua:337-343 asserts only find(..., plain), so all four drifts pass. BR-5 already settled this for curate ("equality, not containment") and produced SPEC_RENDERS; the picker's rows are documented renders in the same Spec and did not inherit the rule. Extend the keyed-equality table to the live row, login row and separator.
  - id: new
    severity: Important
    family: plan-table-missing-entity
    title: |
      Core concepts names `catalog_write`, which exists nowhere; three new entities are absent from both tables
    detail: |
      2nd in family. The Integration points table lists catalog_write; the code ships M._write_catalog and the plan's own Task 2.2 code block writes inline. Also missing from both tables: M.catalog_stale, M._catalog_path, M.register_live_agent (called at agent_picker.lua:177). The Notes' referent grep matches only dotted call syntax, so bare table names are structurally exempt from the check meant to keep names honest — which is how this survived a round that reported the sweep clean. Extend the check to run in both directions over table cells.
  - id: new
    severity: Minor
    family: boundary-crossed-out-of-order
    title: |
      The M3 implementation commit sits inside the M2 review window
    detail: |
      Base 45d9f28 is the M1 close, so this M2 gate reviews both 0b4c577 (M2) and c9e83d8 (M3); M3's own milestone-close will have only fix commits left to review. `## Plan`'s M2 box is unticked and `## Log` has no M2 entry. Also, `live_models` in config.lua is assigned to Task 4.2 (M4) by the plan but shipped in the M3 commit.
  - id: new
    severity: Minor
    family: duplicated-logic-not-extracted
    title: |
      The `<id>*` live-agent naming convention is written in two modules
    detail: |
      agent_picker.lua:93 builds `m.id .. "*"` to decide is_current; cliproxy_catalog.build_agent owns the same convention at :220. Changing the suffix in one place makes the current-agent checkmark silently stop rendering with every test green — picker_items_spec.lua:355 hardcodes the literal rather than deriving it from build_agent.
  - id: new
    severity: Minor
    family: stated-design-not-implemented
    title: |
      Assorted envelope and idiom nits: is_managed gate, 4s chained budget, repaint-under-cursor, pending vs SKIP
    detail: |
      agent_picker.lua:209 gates the refresh on is_managed(), so a self-managed running proxy never populates the catalog though fetch_catalog cannot spawn anything. The two GETs are chained, making the worst case 2x CURL_MAX_TIME rather than the stated 2s, and handle.update swaps the list under a user mid-type (sel_idx is preserved by index, not identity). cliproxy_conformance_spec.lua:241,260 use pending() where the file's five siblings print "SKIP:". catalog_path duplicates config_path's mkdir idiom.
```

---

## Re-review — 2026-08-31T21:45:46-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 205 — live cliproxy model picker; retire hardcoded model lists |
| repo | parley.nvim |
| issue file | workshop/issues/000205-live-cliproxy-model-picker.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 45d9f28e131fc5b40f6f06743ecfe40fcdff9538..4c79c4566e52966425318e474efbeafffae5b8bd |
| command | sdlc milestone-close --issue 205 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-08-31T21:45:46-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The fix commit `4c79c45` engaged three of the eleven open findings and fully resolved one (BR-26). The atlas work is real and good — `cliproxy-managed.md` now carries the two routes, `catalog.json`, the never-spawns rule and the `live_models` syntax, and the plan's terminal Task 4.3 was correctly dissolved into per-milestone docs steps, which is the rule BR-24 asked for rather than the instance. But BR-19 (Critical) was not touched at all: I re-ran the mutation at head — deleting `lua/parley/init.lua:1329-1343` leaves `live_agent_state_spec` (3), `picker_items_spec` (37) and `cliproxy_catalog_spec` (42) all green, 0 failures, and `M.agent_picker` still has zero tests. BR-20/21/22/23/27/28/29 saw no code change whatsoever. BR-25 landed the separator and the equality assertions but left the em-dash drift in place and then *certified* it: `picker_items_spec.lua:343` names `"  Claude Opus 5 - claude-opus-5 (anthropic)"` the `DOCUMENTED` render while the Spec at issue line 83 says `—`, and the atlas page written this round restates the hyphen a third time, with no `## Revisions` striking the em dash. On top of that I found a new Critical the diff ships on first use: after one live pick, the model renders **twice** in the picker (measured), because `register_live_agent` inserts `<id>*` into `plugin._agents` and the live section then re-emits the same catalog row. Full suite at the pinned head is green (191 spec files, 0 failures) — note the working tree is currently red from uncommitted M4 config work, unrelated to this range.

### 1. Strengths

- **ARCH-MOCK is done properly.** `tests/integration/cliproxy_catalog_spec.lua` drives the real fetch/cache path against the process-level `fake_cliproxy` (not function mocks), and `cliproxy_conformance_spec.lua:236-273` adds a *live* conformance pair against the real binary that catches exactly the drift the fake cannot — a bare id instead of `models/<id>` would make every join miss while both other suites stayed green. That reasoning is written down at the test site. This is the shape the principle asks for.
- **The dormancy contract is pinned by a test that can actually fail** — `cliproxy_catalog_spec.lua:106-114` points at a free port and asserts it stays free after the fetch settles. That is a real negative assertion, not a comment.
- **`fetch_catalog` reuses `api_argv`** (`cliproxy.lua:1435`) rather than rebuilding curl argv — the ARCH-DRY reuse the plan named, with the health probe and `list_models` as the existing consumers.
- **The fake carries the awkward shapes deliberately** (`fake_cliproxy:199-230`): `created` absent on the antigravity rows, an id that does not resemble its display name. The two `list_models` assertions in `cliproxy_lifecycle_spec.lua` were updated with a comment saying *what* the case actually asserts, rather than silently re-baselined.
- **`cliproxy_catalog.lua` is genuinely pure** — 42 unit assertions run with no IO and no mocks, and `curate` copies rows before tagging (`:189`) so re-curation on every `<C-a>` toggle stays side-effect-free.

### 2. Critical findings

**C1 — A picked live model renders twice, both rows checkmarked** (`lua/parley/agent_picker.lua:46-125`)

Measured. `register_live_agent` (`init.lua:4338-4342`) inserts `claude-opus-5*` into `plugin._agents`, and the restart restore at `init.lua:1336-1341` does the same. `_build_items` then emits that name from the configured-agent loop *and* the live section emits the same catalog row:

```
1  agent      claude-opus-5*   ✓ claude-opus-5*[🔧🌎] - claude-opus-5 (cliproxyapi)
2  agent      alpha              alpha - gpt-4 (openai)
3  separator  __live_separator__ ── live · cliproxy ──
4  live       claude-opus-5*   ✓ Claude Opus 5 - claude-opus-5 (anthropic)
ROWS NAMED claude-opus-5*: 2
```

Two rows share one `name`, which is also `recall_id_fn`'s identity key. This is visible on the second `:ParleyAgent` after the very first live pick, and immediately on every restart thereafter. `make_plugin` in `picker_items_spec.lua:10-20` never contains a live agent, so no test reaches the state.

Fix sketch: subtract already-registered names in the live section — `if plugin.agents[m.id .. "*"] then goto continue end` — or, better, derive the exclusion set once in `view_for` so the `<C-a>` path gets it too. Whichever site, pin it with a `make_plugin` variant whose `_agents` contains the live name.

### 3. Important findings

No new Important findings beyond the disposition of the eight still-open ones, plus one:

**I1 — The bidirectional referent check the plan just codified has two syntactic blind spots** (`workshop/plans/000205-live-cliproxy-model-picker-plan.md:1558-1571`)

**This is the 3rd finding in family `plan-table-missing-entity`.** Earlier rounds fixed instances. Do not fix this instance — the rule is what needs fixing.

The reverse pass added this round is `grep -oE '^\+function M\.[A-Za-z0-9_]+'`. `register_live_agent` — the entity BR-26 asked to be added to the table — is defined as `M.register_live_agent = function(model)` (`init.lua:4333`), and `_catalog_path` as `M._catalog_path = catalog_path` (`cliproxy.lua:1372`). Neither form matches. The forward pass still only matches backticked dotted call syntax, so non-function referents escape too: the Integration bullet at plan:1584 says the fake "gains `/v1beta/models` plus a **`catalog` mode**", and Task 2.1 Step 1 is titled "Add the route and a catalog mode" — `grep -n catalog tests/fixtures/fake_cliproxy` finds only comments. No mode exists; the step's own body contradicts its title by saying to extend `healthy` instead, which is what the code did.

The rule: the check must cover every *definition form* the codebase uses (`function M.x`, `M.x = function`, `local function` promoted to `M.x`) and must not be limited to functions — a plan cell naming a fixture mode, a route, a file or a flag is a referent too. State the enumeration of forms in the plan's Notes and run it over both directions, or the next non-existent entity escapes the same way this one did.

### 4. Minor findings

- **M1 — The new atlas section orphans `## Flow`** (`atlas/providers/cliproxy-managed.md:36-38`). `## Model catalog (#205)` was inserted immediately after the `## Flow` heading, so `## Flow` now has an empty body and the entire `setup{ cliproxy.manage = true } → pre_query → ensure_running` narrative (lines 39-98) reads as part of the model-catalog section. Move the new H2 to after the Flow body, or before `## Auth & secrets`.
- The dirty working tree (uncommitted M4 deletion of the agent list in `config.lua`) currently fails `config_tools_spec` and `parley_harness_golden_spec`. Not in the review window — flagged so it isn't mistaken for a regression from this range.

### 5. Test coverage notes

- Full suite at `4c79c45` with a clean tree: **191 spec files PASS, 0 failures**; `make lint` clean, 0 warnings / 0 errors in 344 files.
- The M2 IO seam is well covered (5 integration cases, all failing-capable). The M3 surface is not: `M.agent_picker` — catalog read, `view_for`, the `<C-a>` toggle, `on_select`'s three-way `kind` dispatch, the background repaint — has no test at all, and the `refresh_state` restore survives deletion. That is BR-19, unchanged.
- The fake's new 401 branch (`fake_cliproxy:406`) is entered by no test; no spec drives `fetch_catalog` against a `client_key_mismatch` fake.
- `_providers_without_models` has three cases, none of which is a negative-input case; the two shapes that misbehave (`"claud"`, `"anthropic"`) are exactly the ones untested.

### 6. Architectural notes

- **ARCH-DRY — flag.** Eight file-local `free_port` definitions remain across `tests/` (BR-23; the docstring at `ready_port.lua:67-69` claims a consolidation that grep contradicts). `<id>*` is built in two modules (BR-28). The picker's row string is now hand-restated in four places — code `agent_picker.lua:112`, test constant `picker_items_spec.lua:343`, `atlas/providers/agents.md:11`, and the Spec — and this round *added* one of them.
- **ARCH-PURE — flag.** `cliproxy_catalog.lua`, `_build_items` and `_providers_without_models` are properly pure and directly unit-tested. But `M.agent_picker` fuses the disk read, the config read, the view decision, the toggle state and the async refresh into one untestable 100-line function. `view_for` is business logic ("which rows does this operator see") welded to `catalog()`'s IO. C1 lives precisely in that seam. Extract `view_for(models, cfg, registered, all)` as a pure function and let the thin caller supply `catalog_cached()`.
- **ARCH-PURPOSE — flag.** Shadow-sweep on the picker render: one model, four hand-maintained restatements, none deriving, and they disagree. Separately, three Spec commitments remain unimplemented with no `## Revisions` striking them: `providers = nil` → every provider unfiltered, "cache in memory", and the failure "logged at debug". BR-25's answer fixed two of the four drifts it named and left two — the instance, not the class.
- **ARCH-MOCK — mostly pass.** Production and test flow share the `api_argv` boundary; the fake is stateful and a live conformance check exists. Flagged: the plan's `catalog` mode does not exist (see I1), so the awkward shapes were merged into the default `healthy` response, which is why two unrelated `list_models` assertions had to move.
- **ARCH-CONSTRAINTS — flag.** The declared envelope (plan:76-83) is only partly enforced. Not enforced: the debug log on failure; the 2s budget (the two GETs are chained, so worst case is 2×`CURL_MAX_TIME`); "reads one cached JSON" (`catalog_cached` re-opens, re-decodes and `mkdir`s 2–3× per picker open, on the UI path — repeated expensive work the principle names explicitly); and the 10-minute staleness rule, which never fires on an empty catalog because `fetch_catalog:1445` only writes when `#models > 0`, so every `:ParleyAgent` refires two curls forever. `_catalog_inflight` also has no release path if `vim.system` throws, latching the guard for the session.

### 7. Plan revision recommendations

- **`## Revisions` — the picker render.** Decide the em dash: either implement `—` at `agent_picker.lua:112` and `:121` and update the atlas + test constant, or record that the render is a hyphen and amend the Spec's two rows (issue lines 83, 90) plus `atlas/providers/agents.md:11`. Do not leave a test constant named `DOCUMENTED` asserting the opposite of the document. Say explicitly whether "one group per configured provider" is satisfied by `curate`'s per-provider ordering or still owes per-provider headers.
- **`## Revisions` — Task 2.1.** Strike the `catalog` mode from the Integration-points bullet (plan:1584) and from Step 1's title; the step body already prescribes extending `healthy`, which is what shipped.
- **`## Revisions` — the referent check.** Record the definition-form enumeration from I1, and note that the reverse grep as written would have missed `register_live_agent`, the very entity BR-26 added.
- **`## Revisions` — Spec commitments not implemented.** For each of `providers = nil` unfiltered, in-memory caching, and debug logging: implement and pin, or strike with a reason. The plan's own Notes already prescribe "walk the Spec Components bullet by bullet at each close" (BR-20's rule) — it has not been run.
- **Issue file.** `## Plan`'s M2 box is unticked and `## Log` has no M2 entry; `live_models` shipped in the M3 commit but is still assigned to Task 4.2 (M4). Reassign it to Task 3.2 or note the early landing.

```findings
dispose:
  - id: BR-19
    disposition: not-addressed
    note: |
      Re-measured at 4c79c45: deleting init.lua:1329-1343 leaves live_agent_state (3), picker_items (37) and cliproxy_catalog (42) all green, 0 failures; M.agent_picker still has zero tests and no mutation check was recorded in the Log.
  - id: BR-20
    disposition: not-addressed
    note: |
      cliproxy.lua untouched by the fix commit; status still discarded at :1437, no logger call, no in-memory cache, curate(models, {}) still {}. Also: _write_catalog's false return is discarded and _catalog_inflight has no release path if vim.system throws.
  - id: BR-21
    disposition: not-addressed
    note: |
      Measured at head: _providers_without_models(models, {"claud"}) and {"anthropic"} both return a login row. Worse than reported — _build_items:112 THROWS "attempt to concatenate field 'display' (a nil value)" on a shape-less row, which the <C-a> raw path can reach.
  - id: BR-22
    disposition: not-addressed
    note: |
      view_for's `#models == 0` early return (agent_picker.lua:154) and fetch_catalog's `#models > 0` write gate (cliproxy.lua:1445) are both unchanged.
  - id: BR-23
    disposition: not-addressed
    note: |
      Prevalence is 8, not 3 — free_port is defined file-locally in cliproxy_lifecycle, recovery_e2e, conformance, dispatch, download, caller_teardown, auth_login and openai_tool_loop. Task 2.2's Files still names lifecycle:17,50 and recovery_e2e:18,26 as modify targets; neither was touched, and ready_port.lua:67-69 still claims the consolidation.
  - id: BR-24
    disposition: addressed
    note: |
      atlas/providers/agents.md gained the live section, cliproxy-managed.md gained the routes/catalog.json/live_models, and terminal Task 4.3 was dissolved into per-milestone docs steps (1.7 S5, 2.2 S5, 3.3 S6) — the rule, not the instance. README live_models is now scheduled at M3's boundary and must land there. See new Minor on the heading placement.
  - id: BR-25
    disposition: not-addressed
    note: |
      Separator and equality pinning landed, but agent_picker.lua:112,121 still render a hyphen while the Spec (issue lines 83, 90) documents an em dash, with no Revisions entry striking it; picker_items_spec.lua:343 now names the hyphen "DOCUMENTED" and this round's atlas page restates it a third time. Per-provider grouping is ordering-only.
  - id: BR-26
    disposition: addressed
    note: |
      catalog_write is gone, _write_catalog/_catalog_path/catalog_stale/register_live_agent are in the tables, and the check now runs both directions — but see the new finding: both directions have syntactic blind spots that exempt the assignment form register_live_agent itself uses.
  - id: BR-27
    disposition: not-addressed
    note: |
      The issue file is unchanged across the whole window — M2 box unticked, no Log entry — and live_models is still assigned to Task 4.2 despite shipping in the M3 commit.
  - id: BR-28
    disposition: not-addressed
    note: |
      `m.id .. "*"` still at agent_picker.lua:105 and cliproxy_catalog.lua:220; the test still hardcodes the literal.
  - id: BR-29
    disposition: not-addressed
    note: |
      is_managed gate still at agent_picker.lua:224, GETs still chained, pending() still at conformance:241,260, catalog_path still duplicates the config_path mkdir idiom.
findings:
  - id: new
    severity: Critical
    family: section-merge-not-deduped
    title: |
      A picked live model renders twice in the picker, both rows checkmarked and sharing one recall key
    detail: |
      Measured at head: with `_agents = {"alpha","claude-opus-5*"}` and a live catalog row for claude-opus-5, `_build_items` emits 2 rows named `claude-opus-5*` — one from the configured loop (register_live_agent inserts the name at init.lua:4338, and the restart restore at :1336 does the same) and one from the live section at agent_picker.lua:105. Both carry is_current, and `recall_id_fn` keys on the duplicated name. Visible on the second `:ParleyAgent` after the first live pick, and on every restart after. `make_plugin` (picker_items_spec.lua:10) never holds a live agent, so no test reaches the state. Fix in `view_for` so the `<C-a>` path inherits the exclusion, and pin it with a make_plugin variant whose `_agents` contains the live name.
  - id: new
    severity: Important
    family: plan-table-missing-entity
    title: |
      The bidirectional referent check added this round has two syntactic blind spots and already misses a shipped entity
    detail: |
      3rd in family — do not fix the instance, fix the rule. The reverse pass (plan:1568-1570) is `^\+function M\.`, which misses `M.register_live_agent = function(model)` (init.lua:4333) and `M._catalog_path = catalog_path` (cliproxy.lua:1372) — the assignment form used by the very entity BR-26 added. The forward pass still matches only backticked dotted call syntax, so non-function referents escape: plan:1584 and Task 2.1 Step 1 both name a `catalog` mode on fake_cliproxy that exists nowhere (grep finds only comments; the step body contradicts its own title by prescribing an extension of `healthy`, which is what shipped). The rule: enumerate every definition form the codebase uses and every referent KIND a plan cell can name (function, fixture mode, route, file, flag), and run both directions over that enumeration.
  - id: new
    severity: Minor
    family: docs-insert-orphans-section
    title: |
      The new atlas section was inserted between `## Flow` and its body, refiling 60 lines of flow narrative under the catalog heading
    detail: |
      atlas/providers/cliproxy-managed.md:36-38 — `## Model catalog (#205)` now sits immediately after the `## Flow` heading, leaving Flow with an empty body and putting the `setup{ cliproxy.manage = true }` → pre_query → ensure_running narrative (lines 39-98) under the catalog section. Move the new H2 after the Flow body or before `## Auth & secrets`.
```

---

## Re-review — 2026-08-31T22:04:28-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 205 — live cliproxy model picker; retire hardcoded model lists |
| repo | parley.nvim |
| issue file | workshop/issues/000205-live-cliproxy-model-picker.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 45d9f28e131fc5b40f6f06743ecfe40fcdff9538..28af157c14fb424fc49624c5ca714993900585aa |
| command | sdlc milestone-close --issue 205 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-08-31T22:04:28-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

This round did real work: the `fetch_catalog` write gate is now keyed on HTTP 200 with **both sides pinned by tests that can fail** (401 must not blank a good cache; a genuinely empty registry must reach it), the `ready_port` consolidation actually landed (`grep -rn 'local function free_port\|local function wait_listening' tests/` returns nothing — 12 specs now derive from the helper), the picker's documented rows are pinned as full-string equalities with the Spec revised to what ships, and the referent check now enumerates definition forms and referent kinds. Suite state at head, measured in a scratch `git archive` of `28af157` (not the dirty tree, which carries uncommitted M4 `config.lua` edits): `luacheck` 0/0 across 344 files; all 19 specs mapped to `providers/cliproxy-managed` green, 0 failures, 0 errors — the two live conformance cases ran, so the real binary was present. What blocks SHIP is that **both Criticals are still open, and the newer one is open for the reason the older one exists.** BR-30's dedupe is correct code, but the test that ships with it (`picker_items_spec.lua:425-457`) re-implements the exclusion in its own body instead of calling `view_for` — I deleted `not_already_an_agent` from both call sites at `agent_picker.lua:174,180` in a scratch copy and the file stayed **38/38 green**. And BR-19 is unchanged for a fourth round: deleting `init.lua:1329-1343` leaves `live_agent_state` (3), `picker_items` (38), `cliproxy_catalog` unit (42) and integration (7) all green, and no per-task mutation check was recorded in `## Log`. Two rounds ago the rule was written down; this round the fix for the Critical it produced was written from the same mental model as its own test.

## 1. Strengths

- **`tests/integration/cliproxy_catalog_spec.lua:130-176`** — the write gate pinned from both directions, against the process fake in two different modes. Mutation-checked: swapping `v1_status == 200` back to `#models > 0` reddens the second case; swapping it to an unconditional write reddens the first. This is what the rest of the milestone's coverage should look like.
- **`lua/parley/cliproxy.lua:1436-1442, 1453-1462`** — capturing the HTTP status rather than defending downstream is the root-cause fix, and the comment explains *why* both naive gates are wrong. The commit message's account (the operator's real catalog was erased by exactly this while fixing it) is corroborated by the code.
- **BR-23 done at the class, not the site.** Eight file-local copies collapsed to one helper across specs that were never named in the finding, including two (`cliproxy_conformance`, `openai_tool_loop`) outside the plan's Files list.
- **The side-quest is the right shape.** Eleven `tests/integration/cliproxy_*` specs now redirect their own data dir, and `workshop/lessons.md:887-911` records the rule with the diagnostic tell. Fixing the class of "a spec escapes the sandbox and edits the operator's live config" was worth more than the finding that triggered it.
- **`tests/integration/cliproxy_conformance_spec.lua:233-268`** — still the window's strongest ARCH-MOCK work: the `models/` prefix and the join are asserted against the real binary, so the fake and the fixtures cannot agree on a wrong assumption unchallenged.

## 2. Critical findings

### BR-19 — not-addressed (4th round). `missing-test-for-shipped-behavior`

Re-measured at head, exactly as before: `init.lua:1329-1343` deleted → 3/38/42/7 successes, 0 failures. `M.agent_picker` (`agent_picker.lua:130-251`) still has zero tests — `view_for`, the `on_select` `kind` branching, the `<C-a>` toggle and the refresh gate are all unreachable from any spec. No `## Log` entry records a mutation check for any task in this milestone.

One correction to the window framing worth recording: `register_live_agent` and the restore block landed in **`440ab17`, inside the M1 window** — they are pre-base code here. That does not dispose the finding (Task 3.3 owns them and the coverage gap is real), but it means the mutation-check discipline needs to run per *task*, not per commit range, or this keeps slipping between boundaries.

### BR-30 — not-addressed. `missing-test-for-shipped-behavior` / claimed-fix

The code is right. The test cannot fail. `picker_items_spec.lua:441-447` does:

```lua
for _, m in ipairs(live) do
    if not plugin.agents[m.id .. "*"] then filtered[#filtered + 1] = m end
end
local items = agent_picker._build_items(plugin, { live = filtered })
```

— it re-derives the exclusion in the spec and hands the already-filtered list to `_build_items`, which never had the bug. Measured: reverting `agent_picker.lua:174` and `:180` to the pre-fix expressions leaves `picker_items_spec` at 38/38.

The blocker is structural, and the round-6 review already named the fix: `view_for` and `not_already_an_agent` are closures over `plugin`, `cat` and `cliproxy`, so there is nothing a test *can* call. Extract `M._view_for(models, cfg, all)` (pure — models in, view out) and have the picker inject `catalog()`; then this test calls the production function, and it also unlocks coverage for BR-22's remaining sites and the `<C-a>` bypass in one move (ARCH-PURE).

## 3. Important findings

### BR-20 — not-addressed (partially). `stated-design-not-implemented`

The status half is fixed and pinned. Three of the enumeration remain, none struck in `## Revisions`:
- **No logging.** Zero `logger` calls in `fetch_catalog` (`cliproxy.lua:1420-1467`) against the envelope's "the failure is logged at debug." A 401 or a down proxy is silent on every channel.
- **"Cache in memory" does not exist.** `catalog_cached` (`:1376-1390`) re-opens/re-decodes per call and `catalog_path` (`:1366-1371`) runs `vim.fn.mkdir` inside it — 3-4 reads plus 3-4 mkdirs per picker open, on a UI path (ARCH-CONSTRAINTS).
- **`providers = nil`.** Measured at head: `curate(models, {})` → `{}`, against the Spec's `-- nil providers = every known provider, unfiltered`.
- Also still open from the round-7 note: `_write_catalog`'s `false` return is discarded, and `_catalog_inflight` (`:1364`) has no release path if `vim.system` throws — one raise permanently disables refresh for the session.

### BR-21 — not-addressed. `missing-input-guard`

Measured at head, unchanged:

```
_providers_without_models({{id='claude-opus-5',owner='anthropic'}}, {'claud'})     → { { provider = "claud" } }
_providers_without_models({{id='claude-opus-5',owner='anthropic'}}, {'anthropic'}) → { { provider = "anthropic" } }
_providers_without_models({{id='x'}},                               {'claud'})     → {}
_build_items(p, {live={{id='x'}}})        → error: attempt to concatenate field 'display' (agent_picker.lua:112)
_build_items(p, {live={{display=…}}})     → error: attempt to concatenate field 'id'      (agent_picker.lua:105)
```

`agent_picker.lua:25` still does `m.owner == owner` with `owner` possibly nil, where `cliproxy_catalog.lua:161` guards it. The throw is now reachable one step earlier too: `not_already_an_agent` (`:162`) concatenates `m.id` before `_build_items` gets the row, so a corrupt `catalog.json` crashes `<C-a>` rather than rendering `X - x (nil)`. The four-boundary enumeration (parse ✓, `catalog_cached` ✗, `live_models.providers` ✗ in one of two consumers, the expanded path ✗) is unchanged.

### BR-22 — not-addressed. `one-value-two-decisions`

The two sites the finding *named* are fixed and the reasoning comments are good. The class survives at two more sites in the same function, which is the finding's own point:
- **`agent_picker.lua:174`** — `if all then return { live = …, logged_out = {} }`. `all` decides both "bypass curation" and "hide the login rows." Expanding the catalog is when "why is my provider missing" is most acute, and that is exactly when the answer disappears.
- **`agent_picker.lua:245`** — `if models and #models > 0 and handle and …`. The background repaint is gated on list length, so the one case the write gate was just fixed to record (200 + empty registry = every channel logged out) never repaints: the open picker keeps rendering models that no longer exist.

Both are `#models`/`all` deciding a question they are not evidence about. Gate the repaint on *fetch success*, and scope the expanded view's bypass to curation only.

### New — `single-source-not-enforced` (3rd in family)

**This is the 3rd finding in family `single-source-not-enforced`.** Earlier rounds fixed instances. I am not asking for the instance to be fixed alone — the rule below is the deliverable.

`<C-a>` at `agent_picker.lua:228` is a hardcoded literal that never reaches `lua/parley/keybinding_registry.lua`. Every sibling picker key in this repo has a `help_only` registry row with a `config_key` — `cf_next_recency` (`:757`), `nf_next_recency` (`:822`), `if_toggle_done` (`:869`) are all `<C-a>`. So the new key is neither discoverable nor rebindable, and the self-contradiction is inside this diff's own module: the mapping directly above it (`agent_picker.lua:220-226`) binds `<C-g>?` to `plugin.cmd.KeyBindings()`, opening the help that will not list `<C-a>`.

Measured prevalence of the rule across the tree — 8 literal keys in float_picker `mappings` tables, none registered:

```
agent_picker.lua          <C-a>                      (new this window)
root_dir_picker.lua       <C-d> <C-n> <C-r>          (pre-existing)
system_prompt_picker.lua  <C-d> <C-e> <C-n> <C-r>    (pre-existing)
```

The same rule covers this round's two consolidations, both of which are now correct and both of which are held in place only by prose: `ready_port.lua` (nothing stops a ninth file-local `free_port`; its docstring at `:66-69` still says "promoted from … two files", when it was eight) and the `_set_data_dir` seatbelt in `lessons.md` (nothing stops spec #16 from omitting it, which is how the operator's live proxy broke).

**The rule:** when a round's fix is "sweep every consumer onto the single source," the deliverable includes the executable guard that keeps them there. This repo already does exactly that in `tests/arch/` — `scratch_placement_spec.lua` guards the scratch-placement invariant the same way. Three greps, one arch spec: a registry row for every literal `key = "<…>"` in a picker `mappings` table; zero `local function free_port` in `tests/`; a `_set_data_dir` call in every `tests/integration/cliproxy_*_spec.lua`. Prose in a docstring or `lessons.md` is not enforcement.

## 4. Minor findings

- **BR-27 — not-addressed.** `## Plan`'s M2 box is still unticked and `## Log` has no M2 entry; `live_models` is still assigned to Task 4.2 (M4) in the plan at `plan.md:1471` despite shipping in the M3 commit.
- **BR-28 — not-addressed, now worse.** `m.id .. "*"` at `agent_picker.lua:105`, `:162`, `cliproxy_catalog.lua:220` and `picker_items_spec.lua:444` — the BR-30 fix added a third production copy and a fourth in the test. Changing the suffix in `build_agent` still leaves every test green.
- **BR-29 — not-addressed.** `is_managed()` gate at `:243`; the two GETs still chained (4 s worst case vs the envelope's 2 s); `pending()` at `conformance:235,254` vs `print("SKIP:")` at its five siblings; `catalog_path` still duplicates `config_path`'s mkdir idiom.
- **BR-32 — not-addressed.** `atlas/providers/cliproxy-managed.md:36-38` unchanged: `## Model catalog (#205)` still sits immediately after `## Flow`, leaving Flow with an empty body and refiling ~60 lines of flow narrative under the catalog heading.
- **New, `unmeasured-family-branch` (2nd in family).** `fake_cliproxy:404-410` adds two `/v1beta/models` branches on unmeasured assumptions: `needs_login` serves the **full** `CATALOG_V1BETA` while `/v1/models` serves `data: []` (a state the real proxy may not have), and `client_key_mismatch` answers 401. The conformance spec only exercises `/v1beta` on a healthy proxy, and the new "records a genuinely empty catalog" test now rides the first branch. The rule the family wants: a fake branch no live conformance check covers is an assumption, and should say so at the branch.
- `tests/integration/cliproxy_lifecycle_spec.lua:1` — the new `require` was inserted above the file's header comment, orphaning it from the module it describes. `cliproxy_dispatch_spec.lua:25` left a double blank line where `free_port` was.
- The issue file now ends without a trailing newline.

## 5. Test coverage notes

Everything passes; the gap remains in what a passing suite can detect. Unpinned behaviour at head:

| behaviour | where | covered |
|---|---|---|
| live/agent dedupe (BR-30's fix) | `agent_picker.lua:159-180` | **no** — reverting it leaves 38/38 green |
| live-agent restore before the fallback guard | `init.lua:1329-1343` | **no** — deletion verified green |
| `M.agent_picker` wiring (`on_select` kinds, `<C-a>`, refresh gate) | `agent_picker.lua:130-251` | no |
| `view_for` empty-catalog → login rows (BR-22's fix) | `agent_picker.lua:176-186` | no |
| expanded view drops login rows | `agent_picker.lua:174` | no |
| unknown / mistyped provider → actionable login row | `agent_picker.lua:25-31` | no |
| corrupt rows from `catalog.json` (throws) | `agent_picker.lua:105,112,162` | no |
| `providers = nil` | `cliproxy_catalog.lua:153` | no |
| non-200 → logged | nowhere | n/a — unimplemented |

Six of these nine resolve to one change: extract `M._view_for(models, cfg, all)` as a pure function and inject `catalog()`.

## 6. Architectural notes

- **ARCH-DRY — flag.** `ready_port` is now genuinely one source (the round's best consolidation), but the `<id>*` convention went from 2 copies to 4 in the same commit that fixed a bug caused by it, and `catalog_path`/`config_path` remain near-copies. Cite BR-28.
- **ARCH-PURE — flag.** `cliproxy_catalog.lua` and `_providers_without_models` are clean, IO-free and tested directly — the design working. But `view_for`/`not_already_an_agent` are closures over `plugin`/`cliproxy`, and the direct consequence showed up this round: the Critical fix could only be "tested" by copying it into the spec. `catalog_cached` still performs a filesystem write inside a documented read.
- **ARCH-PURPOSE — flag.** BR-22's fix landed at the two sites the finding named and left two enumerable siblings in the same function; BR-21's guard class is still unswept across the four boundaries the finding enumerated. That is the instance, not the class — twice, in a round whose commit message says it fixes rules rather than sites.
- **ARCH-MOCK — pass, one flag.** The fake carries the awkward shapes, integration tests run the production path against it, and live conformance defends the shared assumption. The flag is the two unmeasured `/v1beta` branches (Minor above); the 401 branch that BR-20 said no test enters is now entered by `cliproxy_catalog_spec.lua:130`.
- **ARCH-CONSTRAINTS — flag.** The declared envelope is still not enforced: no in-memory cache, no debug logging on failure, 4 s across chained GETs against a stated 2 s, and 3-4 `mkdir` calls per picker open. What *is* enforced — never spawning the proxy, the 10-minute TTL, the in-flight guard — is enforced well and tested.

## 7. Plan revision recommendations

1. **Plan — Task 3.2, Step 1 (still missing).** The round-6 recommendation to add a Step-1 test block was not applied; Task 3.2 still goes from Implement straight to "verify by hand," which is why `M.agent_picker` has zero tests. Specify `M._view_for(models, cfg, all)` as the pure seam and enumerate the cases: empty catalog + non-empty providers, expanded bypass, live/agent overlap, `on_select` `kind` branching.
2. **Plan — Notes for the implementer.** Add the mutation check as a named pre-`milestone-close` step with its per-task enumeration and a `## Log` line for each result. BR-19 has now survived four rounds because the rule lives in a Revisions entry rather than in the checklist the boundary actually runs.
3. **Plan — Operating envelope.** Either implement the in-memory cache, the debug logging and the 2 s budget, or strike them in `## Revisions` with the measured reason. Three rounds of BR-20 have restated claims the code does not honour.
4. **Plan — Task 4.2.** `live_models` shipped in the M3 commit; move it out of Task 4.2's Files so the plan stops assigning delivered work to a future milestone.
5. **Issue — Spec, Component 3.** Still says credential state comes from the `/v0/management/auth-files` reader keyed by CHANNEL via `channels_for_login`. The shipped `_providers_without_models` infers logged-out from catalog emptiness keyed by `owned_by`. The plan records the divergence; the Spec does not, and the two have genuinely different failure modes (a loaded-but-dead credential still lists models and reads as logged *in*).

```findings
dispose:
  - id: BR-19
    disposition: not-addressed
    note: |
      Re-measured at 28af157: deleting init.lua:1329-1343 leaves live_agent_state (3), picker_items (38), cliproxy_catalog unit (42) and integration (7) all green. M.agent_picker still has zero tests, Task 3.2 still has no Step-1 test block, and no per-task mutation check appears in `## Log`. Note the code sits in 440ab17, inside the M1 window — the check must run per TASK, not per commit range, or it keeps falling between boundaries.
  - id: BR-20
    disposition: not-addressed
    note: |
      Status capture is fixed and pinned. Still open: zero logger calls in fetch_catalog (cliproxy.lua:1420-1467) vs the envelope's "logged at debug"; no in-memory cache (catalog_cached re-decodes + mkdirs 3-4x per open); curate(models, {}) still returns {} against the Spec's "nil providers = every known provider"; _write_catalog's false return discarded; _catalog_inflight has no release path if vim.system throws. Nothing struck in `## Revisions`.
  - id: BR-21
    disposition: not-addressed
    note: |
      Unchanged and measured at head: _providers_without_models(models,{'claud'}) and (models,{'anthropic'}) both emit actionable login rows; an ownerless catalog row still flips the answer to {}. The throw moved one step earlier — not_already_an_agent (agent_picker.lua:162) concatenates m.id before _build_items:105/:112 does, so a corrupt catalog.json crashes the <C-a> path outright. The four-boundary enumeration is unchanged.
  - id: BR-22
    disposition: not-addressed
    note: |
      The two sites the finding named are fixed with good comments. The class survives at two more in the same function: agent_picker.lua:174 lets `all` decide both "bypass curation" and "hide login rows", and :245 gates the background repaint on `#models > 0`, so the 200-plus-empty-registry case the write gate was just fixed to record never repaints. Gate repaint on fetch success; scope the expanded bypass to curation only.
  - id: BR-23
    disposition: addressed
    note: |
      `grep -rn 'local function free_port|local function wait_listening' tests/` returns nothing; 12 specs now require the helper, including two outside the plan's Files list. Residue: ready_port.lua:66-69 still says "promoted from two files" when it was eight, and nothing guards against a ninth copy — folded into the new single-source-not-enforced finding.
  - id: BR-25
    disposition: addressed
    note: |
      The separator ships, picker_items_spec.lua:343-346 pins separator/live/current/login as full-string equalities keyed off a DOCUMENTED table, and the issue carries a `## Revisions` entry striking the em dash and the grouping claim with reasons. Code and Spec now agree.
  - id: BR-27
    disposition: not-addressed
    note: |
      `## Plan`'s M2 box is still unticked with no `## Log` entry, and plan.md:1471 still assigns `live_models` to Task 4.2 though it shipped in the M3 commit.
  - id: BR-28
    disposition: not-addressed
    note: |
      Worse this round: `m.id .. "*"` is now at agent_picker.lua:105 and :162, cliproxy_catalog.lua:220, and picker_items_spec.lua:444 — the BR-30 fix added a third production copy and a fourth in its own test.
  - id: BR-29
    disposition: not-addressed
    note: |
      is_managed() gate at agent_picker.lua:243, GETs still chained, pending() at conformance:235,254 vs five siblings printing "SKIP:", catalog_path still duplicating config_path's mkdir idiom.
  - id: BR-30
    disposition: not-addressed
    note: |
      The code fix is correct; the test cannot fail. picker_items_spec.lua:441-447 re-implements the exclusion in the spec body and hands an already-filtered list to _build_items, which never had the bug. Measured: reverting agent_picker.lua:174 and :180 to the pre-fix expressions leaves the file 38/38 green. Blocker is structural — extract M._view_for(models, cfg, all) as a pure function so a test can call the production path.
  - id: BR-31
    disposition: addressed
    note: |
      The plan's Notes now enumerate definition forms (function M.x(, M.x = function(, M.x = alias, local function) and referent kinds (functions, fixture modes, routes, files, flags). I ran both passes: the reverse surfaces all 7 M.* entities the window adds and each has a table row; the forward's only unresolved names are historical mentions inside `## Revisions` and file paths. The phantom `catalog` fixture mode is gone from Task 2.1, and the plan's stated mode list matches fake_cliproxy's own Modes header exactly.
  - id: BR-32
    disposition: not-addressed
    note: |
      atlas/providers/cliproxy-managed.md:36-38 unchanged — `## Model catalog (#205)` still sits immediately after the `## Flow` heading, leaving Flow with an empty body and ~60 lines of flow narrative filed under the catalog section.
findings:
  - id: new
    severity: Important
    family: single-source-not-enforced
    title: |
      The new <C-a> bypasses the keybinding registry, and this round's two consolidations have no executable guard
    detail: |
      3rd in family — the rule, not the instance. agent_picker.lua:228 hardcodes <C-a> while every sibling picker key carries a help_only registry row with a config_key (keybinding_registry.lua:757, :822, :869 are all <C-a>), so the key is neither discoverable nor rebindable — and the mapping directly above it (:220-226) binds <C-g>? to the very help that omits it. Measured prevalence: 8 literal keys in float_picker mappings tables across agent_picker (1, new), root_dir_picker (3) and system_prompt_picker (4), none registered. The same rule covers this round's correct-but-unguarded sweeps: nothing stops a ninth file-local free_port, and nothing stops the next tests/integration/cliproxy_*_spec.lua from omitting _set_data_dir — the omission that broke the operator's live proxy. Rule: when a fix is "sweep every consumer onto the single source," the deliverable includes the guard that keeps them there. tests/arch/scratch_placement_spec.lua is the in-repo precedent; three greps in one arch spec cover all three invariants.
  - id: new
    severity: Minor
    family: unmeasured-family-branch
    title: |
      The fake's two new /v1beta/models branches are unmeasured assumptions, and one now backs a test
    detail: |
      2nd in family. fake_cliproxy:404-410 has needs_login serve the FULL CATALOG_V1BETA while /v1/models serves data:[] — a combination not measured against the real proxy — and client_key_mismatch answer 401. The conformance spec exercises /v1beta only on a healthy proxy, so neither branch is checked against the binary, and the new "records a genuinely empty catalog" case rides the first. Rule: a fake branch no live conformance check covers is an assumption and should be labelled as one at the branch, so a later reader does not mistake it for measured behaviour.
```

---

## Re-review — 2026-08-31T22:19:51-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 205 — live cliproxy model picker; retire hardcoded model lists |
| repo | parley.nvim |
| issue file | workshop/issues/000205-live-cliproxy-model-picker.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 45d9f28e131fc5b40f6f06743ecfe40fcdff9538..a568ddf349480c92c533f0746153381b6f97dd93 |
| command | sdlc milestone-close --issue 205 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-08-31T22:19:51-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

This round did real structural work: `_view_for` is exactly the right extraction — a pure function on the production path that a test can actually drive — and I independently reproduced the commit body's mutation claims to the exact numbers (reverting the dedupe reddens 3 tests, reverting the empty-catalog gate reddens 1). `tests/arch/single_source_sweeps_spec.lua` is a genuine fitness function: I violated each of its three invariants in a scratch copy and each guard went red. So BR-30, BR-22 and BR-33 are properly closed as rules, not instances. What blocks SHIP is that **BR-19 is open for a fourth round and I re-measured it as still true**: I deleted the restart-restore block at `lua/parley/init.lua:1329-1343` in a scratch copy and ran the entire unit + integration + arch suite — zero new failures. `M.agent_picker` and the new `keybinding_registry.key_for` both have zero tests, and no per-task mutation check appears in `## Log`. BR-20 and BR-21 also remain measurably open (I reproduced all six of their claims at head). Note separately: `tests/unit/parley_harness_spec.lua` fails at HEAD, at the M2 base, and on `main` — pre-existing repo debt, not this window's — but it means `make test` cannot be cited green as close evidence without a note.

## 1. Strengths

- `lua/parley/agent_picker.lua:141` — `_view_for(models, cfg, opts)` is the correct answer to "the test re-implemented the fix." Pure, on the production path, no IO, and `picker_items_spec.lua:425-476` drives it directly. This is ARCH-PURE done right.
- `lua/parley/cliproxy.lua:1437-1447` — gating the cache write on **HTTP 200** rather than curl's exit code, with both sides pinned (`cliproxy_catalog_spec.lua:130` a 401 must not blank the cache; `:155` a genuine empty registry must reach it). The comment explains *why* the obvious gate was wrong. That is the class fixed, not the instance.
- `tests/arch/single_source_sweeps_spec.lua` — I verified all three guards empirically: hardcoding `<C-a>` back into `agent_picker.lua`, stripping `_set_data_dir` from `cliproxy_catalog_spec.lua`, and adding a `local function free_port` to `ready_port_spec.lua` each turned exactly one test red. The `LEGACY_UNREGISTERED` ratchet (may shrink, never grow) is the right shape for pre-existing debt.
- `tests/integration/cliproxy_catalog_spec.lua:104-115` — the dormancy contract is pinned by pointing at a free port and asserting it *stays* free, not by asserting a mock wasn't called.
- `tests/integration/cliproxy_conformance_spec.lua:227-268` — two new live conformance checks against the real binary, including the join itself. The comment correctly identifies that fixture-and-fake agreeing proves nothing.
- `workshop/lessons.md:887` — the bare-spec-run lesson is written from the actual damage (the operator's live proxy 401-ing their own bearer), and the arch spec enforces it.

## 2. Critical findings

**BR-19 (open, 4th round) — `lua/parley/init.lua:1329-1343`, `lua/parley/agent_picker.lua:175-260`.** Re-measured at `a568ddf`: I removed the restore block in a scratch copy and ran every spec under `tests/unit`, `tests/integration`, `tests/arch` — the failure set was identical to the unmutated baseline (0 new failures). `grep -rn live_agent tests/` still reaches only `live_agent_state_spec.lua`, which tests `register_live_agent`, never the restore ordering the Spec calls load-bearing. `M.agent_picker` has zero tests; the new `keybinding_registry.key_for` (a public function added this round) has zero tests — `grep -rn key_for tests/` returns only a string inside an assertion message. Fix sketch: the finding's own rule — run the delete-it-and-see check per task and record the result in `## Log`. The two ad-hoc verifications this round (BR-30, BR-22) show the technique works; it just isn't a gate yet.

## 3. Important findings

**BR-20 (open) — `lua/parley/cliproxy.lua:1360-1470`.** HTTP-status capture is fixed and pinned; three of the finding's items are not. Measured at head: zero `logger` calls anywhere in `fetch_catalog` against the envelope's "the failure is logged at debug"; `catalog_cached()` re-opens, re-reads and re-`json.decode`s the file with a `vim.fn.mkdir` on every call (2 per picker open, +1 per `<C-a>`) against Component 2's "Cache in memory"; and `curate(models, {})` returns `{}` against the Spec's `-- nil providers = every known provider, unfiltered` (I ran it). `_write_catalog`'s `false` return is still discarded and `_catalog_inflight` still has no release path if `vim.system` throws. None of these are struck in `## Revisions`. Fix sketch: the rule the finding states — walk Spec Components and the envelope bullet by bullet; implement or strike.

**BR-21 (open) — `lua/parley/agent_picker.lua:19-38`, `:105`, `:112`, `:154`.** All four claims reproduced at head:
```
_providers_without_models(models, {"claud"})     -> { { provider = "claud" } }   -- offers ":ParleyProxy login claud"
cat.curate(models, { providers = {"claud"} })    -> {}                            -- same input, opposite answer
_providers_without_models({{id="x"}}, {"claud"}) -> {}                            -- nil == nil; BR-6's defect verbatim
_view_for({{display="no id"}}, …, {all=true})    -> error: concatenate field 'id' (a nil value)
_build_items(…, { live = {{id="y"}} })           -> error: concatenate field 'display' (a nil value)
```
`catalog_cached` validates only `type(decoded.models) == "table"`, so a corrupt `catalog.json` crashes `:ParleyAgent` outright on the `<C-a>` path. Fix sketch: one guarded provider→owner helper shared by both sites, and a shape check on rows at the `catalog_cached` boundary.

## 4. Minor findings

- **BR-27** (open) — `## Plan`'s M2 box unticked, no M2 `## Log` entry, and `plan.md:1473` still assigns `cliproxy.live_models` to Task 4.2 though it shipped in the M3 commit. Additionally the boundary is being crossed with a **192-line uncommitted deletion in `lua/parley/config.lua`** (the default `agents` block), which is what reddens `config_tools_spec` and `parley_harness_golden_spec` in the working tree but not at committed HEAD.
- **BR-28** (open) — worse, not better: `m.id .. "*"` now at `cliproxy_catalog.lua:220`, `agent_picker.lua:105` and `agent_picker.lua:154`.
- **BR-29** (open) — `is_managed()` gate at `agent_picker.lua:249`; the two GETs still chained (worst case 2×`CURL_MAX_TIME`, not the stated 2s); `pending()` at `cliproxy_conformance_spec.lua:231,249` where five siblings print `SKIP:`; `catalog_path` still duplicates `config_path`'s `data_root`+`mkdir` idiom.
- **BR-32** (open) — `atlas/providers/cliproxy-managed.md:36-38` unchanged; `## Flow` still has an empty body and ~60 lines of flow narrative still sit under `## Model catalog (#205)`.
- **BR-34** (open) — `fake_cliproxy:399-410`: `needs_login` serves `data:[]` on `/v1/models` but the **full** `CATALOG_V1BETA`, and `client_key_mismatch` answers 401 on `/v1beta`. Both conformance checks run only on a healthy proxy, so neither branch is measured, and neither carries a comment saying so.
- **NEW** — `keybinding_registry.lua:759` declares `scope = "global"`. Rendered help confirms `<C-a>` now appears under the **Global** heading in every context, including a chat buffer where `<C-a>` is Vim's increment. The three sibling `<C-a>` rows use `chat_finder`/`note_finder`/`issue_finder` scopes and only render in their own surface. Also `agent_picker_mappings` appears nowhere in `config.lua`, unlike `chat_finder_mappings`/`note_finder_mappings`/`issue_finder_mappings`.
- Not re-raised (BR-23 is disposed): `tests/helpers/ready_port.lua:65-67` still says "Promoted from file-local copies in cliproxy_lifecycle_spec.lua and cliproxy_recovery_e2e_spec.lua" — it was eight files. Cosmetic residue; the arch guard now carries the real invariant.
- `tests/integration/cliproxy_lifecycle_spec.lua:1` — the sweep inserted the `require` above the file's header comment; the ten sibling specs kept theirs first.
- README still due at M3 for `live_models`, `<C-a>` and the `(logged out)` row (BR-24's disposition scheduled it there; the code is already in the tree).

## 5. Test coverage notes

- Mutation-verified this round: dedupe fix → 3 red, empty-catalog fix → 1 red, each arch guard → 1 red. All match what the commit body claims.
- Uncovered: the restart restore (whole block deletable, suite green), `M.agent_picker`, `keybinding_registry.key_for`, and the two new fake branches.
- `tests/unit/parley_harness_spec.lua` fails 2/2 at HEAD, at base `45d9f28`, and on `main`. Pre-existing, unrelated to #205 — but `make test` is not green, so the close needs either that fixed or an explicit note in `--verified`.

## 6. Architectural notes

- **ARCH-DRY — flag.** Three sites of `<id>*` (BR-28); `catalog_path`/`config_path` idiom (BR-29); provider→owner resolution written twice with different guards (BR-21). Pass on `api_argv` reuse and the now-guarded `ready_port` consolidation.
- **ARCH-PURE — pass, with one flag.** `_view_for` and `cliproxy_catalog` are pure and tested without mocks; the IO shell is thin and in `cliproxy.lua`. Flag: `M.agent_picker` still mixes disk read, config read, keymap wiring and background fetch with no seam — the untested remainder BR-19 names.
- **ARCH-PURPOSE — flag.** Shadow-sweep on the Spec-as-source: three Component/envelope statements (in-memory cache, `nil providers`, debug logging) have no deriving consumer and no `## Revisions` strike (BR-20). Strong pass on how BR-22 and BR-33 were answered — both swept the class (two more sites in the same function; a guard for all three consolidations) rather than the named instance.
- **ARCH-MOCK — pass, with one flag.** Process-level fake behind the same seam as production, two new live conformance checks against the real binary. Flag: BR-34's two unlabelled, unmeasured branches.
- **ARCH-CONSTRAINTS — flag.** The single-flight guard and the never-spawn rule are implemented and pinned. Three envelope statements are not enforced: the debug log, the 2s budget (chained GETs make it 4s), and "reads one cached JSON" (2-3 reads + `mkdir` per open).

## 7. Plan revision recommendations

- **Task 4.2 / `## Plan`**: `cliproxy.live_models` shipped in the M3 commit. Move it out of Task 4.2's Files and record the boundary slip in `## Revisions` (BR-27).
- **Operating envelope**: either implement the debug log and the in-memory cache, or strike both with a reason; and correct the latency budget to 2×`CURL_MAX_TIME` (or parallelize the GETs) (BR-20, BR-29).
- **Spec Component 6**: strike `-- nil providers = every known provider, unfiltered` or implement it (BR-20).
- **Notes for the implementer**: add the per-task mutation check as a step with a `## Log` line, so BR-19's rule has a place to be recorded rather than being applied ad hoc per finding.

```findings
dispose:
  - id: BR-19
    disposition: not-addressed
    note: |
      Re-measured at a568ddf — deleted init.lua:1329-1343 in a scratch copy and ran every unit/integration/arch spec: 0 new failures vs baseline. M.agent_picker and the new key_for have zero tests; no mutation check recorded in the Log.
  - id: BR-20
    disposition: not-addressed
    note: |
      Status capture fixed and pinned; zero logger calls in fetch_catalog, no in-memory cache (mkdir+decode 2-3x per open), curate(models, {}) still {} — all measured, none struck in Revisions.
  - id: BR-21
    disposition: not-addressed
    note: |
      All four reproduced at head, including two live throws — _view_for concatenates a nil id and _build_items a nil display, so a corrupt catalog.json crashes the picker.
  - id: BR-22
    disposition: addressed
    note: |
      Verified by reverting the empty-catalog early return in a scratch copy — picker_items_spec goes 41/1 red. The write gate keys on HTTP 200 with both sides pinned.
  - id: BR-27
    disposition: not-addressed
    note: |
      M2 box unticked, no Log entry, plan.md:1473 still assigns live_models to Task 4.2; and the tree carries a 192-line uncommitted deletion in config.lua at the boundary.
  - id: BR-28
    disposition: not-addressed
    note: |
      Three production sites now — cliproxy_catalog.lua:220, agent_picker.lua:105 and agent_picker.lua:154.
  - id: BR-29
    disposition: not-addressed
    note: |
      is_managed gate at agent_picker.lua:249, GETs still chained, pending() at conformance:231,249, catalog_path still duplicating config_path's mkdir idiom.
  - id: BR-30
    disposition: addressed
    note: |
      Verified by reverting the exclusion in _view_for — picker_items_spec goes 39/3 red. _view_for is the right structural answer; the test now drives the production path.
  - id: BR-32
    disposition: not-addressed
    note: |
      cliproxy-managed.md:36-38 unchanged; Flow still has an empty body with its narrative filed under the catalog heading.
  - id: BR-33
    disposition: addressed
    note: |
      Registry row + key_for + arch spec; I violated each of the three invariants in a scratch copy and each guard went red. See the new Minor on the row's scope value.
  - id: BR-34
    disposition: not-addressed
    note: |
      Both branches unchanged at fake_cliproxy:399-410, still exercised by no conformance check and still unlabelled as assumptions.
findings:
  - id: new
    severity: Minor
    family: wrong-taxonomy-value
    title: |
      The new <C-a> registry row declares scope "global", so it renders under Global in every help screen though it only works inside the agent picker
    detail: |
      keybinding_registry.lua:759 sets scope = "global" because the scope forest has no agent_picker entry; the three sibling <C-a> rows use chat_finder/note_finder/issue_finder. Rendered help_lines("chat", config) confirms the row appears under the Global heading in a chat buffer, where <C-a> is Vim's increment and parley binds nothing. keybindings_spec.lua:244 only asserts the scope is a valid label, never the right one. The rule: when a taxonomy has no correct value for a new row, add the value rather than filing it under the nearest wrong one — here, an agent_picker scope with a label and display-order entry, as the three finders already have. Also add agent_picker_mappings to config.lua so the documented config_key has an example, as the other *_mappings keys do.
```
