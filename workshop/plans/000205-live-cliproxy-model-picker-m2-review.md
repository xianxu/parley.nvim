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
