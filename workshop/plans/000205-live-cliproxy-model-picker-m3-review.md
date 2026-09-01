# Boundary Review — parley.nvim#205 (milestone M3)

| field | value |
|-------|-------|
| issue | 205 — live cliproxy model picker; retire hardcoded model lists |
| repo | parley.nvim |
| issue file | workshop/issues/000205-live-cliproxy-model-picker.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | 747c8ffc2be7f9e497d80307150f9c48856f96b8..747c8ffc2be7f9e497d80307150f9c48856f96b8 |
| command | sdlc milestone-close --issue 205 --milestone M3 |
| reviewer | claude |
| timestamp | 2026-08-31T23:15:14-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The M3 window is **empty** — `base == head == 747c8ff`, the M2 close commit — so the pinned range contains zero commits. That is not a tool failure (stat/name-status both ran clean); it is the boundary itself being malformed: every M3 commit (`c9e83d8` plus five `M2/M3` commits) landed *before* M2's close, and `747c8ff`'s own diff falls in **neither** window (M2's ended at `60b964b3`; M3's starts *at* `747c8ff`). I closed that inspection gap by hand — reviewed `60b964b..747c8ff` directly and revert-verified all four of its claimed fixes in a scratch worktree; all four go red without the fix, so no unreviewed-and-unpinned code is crossing. The M3 deliverables themselves are present, well-factored and green (`picker_items` 46, `live_agent_state` 13, `cliproxy_catalog` 42+11, mapped suite 0 failures). What holds this back from SHIP is two live behavior defects on the picker path that were raised six rounds ago as BR-29 and then dropped without disposition by the round-10 "backlog cleared" sweep, plus a working tree that would sweep a gutted `config.lua` into the close commit.

## 1. Strengths

- **`_view_for` extraction is the right call, and its own comment says why** (`lua/parley/agent_picker.lua:140-143`): the first dedupe was tested by re-implementing it in the spec body, so reverting the fix left the suite green. Extracting the production seam is exactly the fix for an unfalsifiable test.
- **`classify()` as the catalog write gate** (`lua/parley/cliproxy.lua:1494-1502`) — reusing the existing single source for "is this cliproxy's `/v1/models` contract" after three weaker gates (`#models > 0`, curl exit code, HTTP 200) each lost data. ARCH-DRY done properly, with the failure history in the comment.
- **`fake_cliproxy` is a real subprocess fake serving both routes** with the awkward shapes (`created`-less antigravity rows, an opaque id whose displayName doesn't resemble it, a gpt-* id under `antigravity`), and the v1beta branches mirror `/v1/models` per mode. ARCH-MOCK: pass — production and test flow share the `api_argv` boundary, and `cliproxy_conformance_spec.lua` covers live drift.
- **Revert-verified, by me, not by commit message**: BR-41 (`management.key` minting), BR-40 (overlap dedupe), BR-21r (login-row `loggable` guard, ownerless `(nil)` render) each fail their test when reverted; injecting one hardcoded `key = "<C-x>"` into `agent_picker.lua` turns `single_source_sweeps_spec` red, and the guard's allowances (1/4/5) are exactly the measured counts — no slack.
- **`build_agent` returns `nil` rather than raising** (`cliproxy_catalog.lua:222-227`) because its callers are a picker callback and a session restore. Correct instinct, and both callers handle it.

## 2. Critical findings

None.

## 3. Important findings

**I1 — `is_managed()` gates the refresh, so `manage = false` gets six false `(logged out)` rows and no catalog, ever.** `lua/parley/agent_picker.lua:282`. `fetch_catalog` has exactly one production caller, and it is behind `cliproxy.is_managed()`. With `manage = false` — documented at `config.lua:115` as the supported opt-out — nothing ever calls `_write_catalog`, so `catalog_cached()` returns `{}` forever; `_view_for` then falls back to `cc.providers()` (all six) and `_providers_without_models({}, …)` marks every one logged out. Fix: drop the `is_managed()` conjunct. The dormancy contract it purports to protect is already pinned independently by `tests/integration/cliproxy_catalog_spec.lua:103-113` ("does not start a proxy when none is running") — `fetch_catalog` is a plain GET and cannot spawn anything. The Spec's condition was "only if the proxy already answers", not "only when managed". ARCH-PURPOSE: this ships the easy subset — the picker delivers nothing but six wrong rows to an entire supported configuration.

**I2 — the background repaint moves the selection by index, so `<CR>` can fire on a row the user never pointed at.** `agent_picker.lua:283-291` → `float_picker.lua:1685-1707`. `update()` preserves `sel_idx` as an *integer* and only clamps it; `next_selection_index` exists but no caller passes it. Failure scenario: cold catalog, picker opens with N agents + separator + 6 `(logged out)` rows; user arrows onto `antigravity - (logged out)` to start a login; ~200 ms later the refresh lands and the tail becomes ~9 live model rows; the cursor holds the same index, now over a live model, and `<CR>` registers a model agent instead of running `:ParleyProxy login antigravity`. Fix: capture `recall_id_fn(selected)` before `handle.update` and pass the re-derived index as `next_selection_index` — the picker already has the identity function.

**I3 — the M3 boundary reviews zero commits, and `747c8ff` is in no window at all.**
> **This is the 2nd finding in family `boundary-crossed-out-of-order`.** Do not fix this instance — fix the rule.

The rule: **`sdlc` must refuse a `milestone-close` whose window is empty, and must refuse a close for `Mx` when the window contains commits whose subject claims `M(x+1)`.** Both are mechanical `git log --grep` checks. The mechanism that produced the hole is the #174 "bundle the fixes into the close commit so the reviewed anchor is HEAD" convention: it makes the close commit's own content unreviewable *by construction*, because the next window opens exclusive of it. Either the next window must start at the previous boundary's **parent**, or a close commit must carry no code. Measured prevalence on this issue: 7 commits of M3 code landed before M2's close, and `747c8ff` changed `fetch_catalog`, `_view_for`, `_providers_without_models`, `_build_items` and the arch guard with no gate over it. The same accounting leak dropped **BR-29**: carried `not-addressed` across six rounds, then omitted entirely from the round-10 "demoted backlog, cleared" revision (`plan.md:1771-1801`) — I1 and I2 above are its two live legs.

**I4 — Spec Component 3 still names a credential source the code does not use.**
> **This is the 5th finding in family `stated-design-not-implemented`.** Do not fix this instance — fix the rule.

The rule: **every repo symbol the Spec names in backticks must be executably swept, the same way `tests/arch/single_source_sweeps_spec.lua` already sweeps this issue's other consolidations** — a spec that greps the issue's `## Spec` and the plan's Core-concepts tables for `identifier`-shaped tokens and asserts each is `require`d/referenced by the milestone's code, or struck in `## Revisions`. BR-1 established this for the *plan*; the Spec was never brought under it, and prose sweeps have now failed five times. The instance: the Spec says credential state comes from `cliproxy_auth.lua`'s `/v0/management/auth-files` reader "keyed by CHANNEL via `channels_for_login`, **never by `owned_by`**", and `_providers_without_models` does precisely the forbidden thing (`agent_picker.lua:25,32`) — `agent_picker.lua` never requires `cliproxy_auth`. The plan records the divergence and its reason (the reader is callback-async, unusable on a picker-open path); the Spec does not. This is not cosmetic: the Spec itself measures that `claude-sonnet-4-6` lands under `anthropic` on one proxy start and `antigravity` on the next, so with only antigravity logged in, `claude` reads as logged **in** and its `(logged out)` row never appears — contradicting the Done-when. No fixture exercises that; `CATALOG_V1` has six stable owners and no reattributed id.

**I5 — the working tree would commit a `config.lua` that deletes every configured agent.** `git status` shows ` M lua/parley/config.lua`: an uncommitted local edit stripping all 18 agents down to one `ToolOpus*` plus two commented stubs. The plan's own close recipe is `git add -u && git commit` (`plan.md`, Task 3.3 Step 7), which stages exactly that. Stash or revert it before the close, and prefer explicit paths over `git add -u` in the recipe.

**I6 — the M3 e2e the plan calls its Done-when is not recorded.** Task 3.3 Step 5 demands: pick `claude-opus-5` from the picker, send a message needing a tool and a web lookup, confirm from `:ParleyLog` that the request carried both the client tools and a `web_search` tool on the Anthropic wire, and "Record the evidence in `## Log`". The Log has M1-close and M2-close entries only. `build_agent`'s three-way strategy *is* unit-pinned (`cliproxy_catalog_spec.lua:289-360`), so the gap is narrow — but it is the Spec's Done-when, and it should be recorded or explicitly struck rather than skipped silently.

## 4. Minor findings

- `fetch_catalog`'s callback means two different things by path: the in-flight path returns `M.catalog_cached()`, the network path returns the freshly-parsed list *even when the write was declined* (`cliproxy.lua:1456` vs `:1509`). Today's only consumer ignores the argument, but the surface is new and about to grow. `cb(M.catalog_cached())` in the `else` branch makes it uniformly "the catalog you should render".
- `render_opts`'s host/port/secret derivation is now copied into `fetch_catalog` (`cliproxy.lua:238-241` vs `1464-1466`) — BR-41 traded a side effect for a duplicate. **This is the 4th finding in family `duplicated-logic-not-extracted`; don't fix the instance.** The rule: when a helper is avoided for a side effect, split the helper — extract a side-effect-free `endpoint_opts()` that `render_opts` composes — rather than inlining its body at the new call site.
- `_catalog_inflight` is never cleared if `vim.system` raises synchronously (missing `curl`), wedging refresh for the session. A `pcall` around the launch, or clearing the flag in the failure path, closes it.
- `workshop/plans/000205-…-plan.md` carries 76 step checkboxes across M1-M4 and **none** are ticked, including for the two closed milestones. The durable plan is unusable as a progress record; the issue's `## Plan` milestone rows are doing all the work.
- `recall_id_fn` returns `item.name` for the separator (`"__live_separator__"`), so the picker can recall onto an inert row.
- `fake_cliproxy`'s header claims it models "one id claimed by a second owner"; `CATALOG_V1` has seven distinct ids. The `gpt-oss-120b-medium`/`antigravity` row is presumably what's meant — say that, since the real reattribution is across restarts and can't appear twice in one payload.

## 5. Test coverage notes

Coverage is genuinely strong and, unusually, mutation-checked rather than asserted. All four fixes in the un-windowed `747c8ff` fail when reverted; the arch guard fails when a literal is injected and its allowances are exact. `_view_for` and `_select` were extracted specifically so the production path is what the tests drive — the right response to a test that couldn't fail. Gaps worth closing, in priority order: (a) no test drives `manage = false` through the picker, which is why I1 survived six rounds; (b) no test asserts the selection survives a background repaint, which is I2; (c) no fixture reattributes an id across owners, so the `owned_by`-instability failure mode in I4 is unexercised; (d) the `<C-a>` closure itself and the refresh gate remain untested glue, which the M2 ledger already noted and correctly deprioritized now that `_view_for`/`_select` carry the semantics.

## 6. Architectural notes

- **ARCH-DRY — pass, one nit.** `agent_name`, `classify`, `api_argv`, `PROVIDER_OWNED_BY` are all single-sourced and reused; the only duplication is the `render_opts` copy (Minor, above).
- **ARCH-PURE — pass.** `cliproxy_catalog.lua` is genuinely IO-free and tested from captured fixtures with no mocks. `_build_items`/`_view_for`/`_providers_without_models` read only static maps. `_select` was correctly moved to Integration points (BR-38); `curate` copies rows before tagging so it stays side-effect-free over the cache's own tables (`cliproxy_catalog.lua:186-190`) — a nice catch.
- **ARCH-PURPOSE — flag.** I1: `manage = false` operators get the feature's inverse. The M4 deferral of `oauth-model-alias` and the `config.lua` model lists is legitimate declared scope, not under-delivery.
- **ARCH-MOCK — pass.** Stateful process fake behind the same `api_argv` seam, both routes, mode-mirrored, plus a live conformance spec.
- **ARCH-CONSTRAINTS — flag.** The envelope is declared and mostly enforced (mtime-memoized cache read, zero main-thread network, `--max-time 2`, in-flight guard, debug-not-popup on failure — the last of which BR-20's remainder actually implemented this round). Flags: the repaint violates the keystroke-adjacent path's implicit contract by moving the selection under the user (I2), and the in-flight guard has no release on a synchronous launch failure (Minor).

## 7. Plan revision recommendations

- **Spec, Component 3** — replace the "`cliproxy_auth.lua` … keyed by CHANNEL via `channels_for_login`, never by `owned_by`" sentence with what ships: logged-out is inferred from catalog emptiness keyed by `provider_owned_by`, because the auth-files reader is callback-async and cannot run on a picker-open path. State the failure mode the Spec's own `owned_by`-instability measurement implies, and either accept it or file the follow-up. (I4)
- **Plan, operating envelope** — record that the refresh currently requires `manage = true`, or strike the requirement when I1 is fixed. Note the two GETs are chained, so the worst case is 2×`CURL_MAX_TIME`.
- **Plan, `## Revisions`** — add a round-11 entry disposing **BR-29** explicitly. Round 10's "demoted backlog, cleared" claims a cleared backlog while omitting it; two of its four legs are the Importants above.
- **Plan, Chunk 3** — tick the 18 M3 step checkboxes (and retroactively M1/M2's 45) or state in the plan that the issue's `## Plan` rows are the record and these are narrative.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      `_providers_without_models` is defined at agent_picker.lua:19 and appears in the plan's Core-concepts table; I re-ran the referent sweep across both tables and every named symbol resolves.
findings:
  - id: new
    severity: Important
    family: stated-design-not-implemented
    title: |
      `is_managed()` gates the catalog refresh, so `manage = false` never populates the catalog and the picker shows six false `(logged out)` rows
    detail: |
      agent_picker.lua:282. fetch_catalog has exactly one production caller and it sits behind cliproxy.is_managed(). With manage=false — documented at config.lua:115 as the supported opt-out — _write_catalog is never reached, catalog_cached() returns {} forever, _view_for falls back to cc.providers() (all six) and every one renders `(logged out)`. The dormancy contract this gate claims to protect is already pinned independently by cliproxy_catalog_spec.lua:103-113; the Spec's condition was "only if the proxy already answers", not "only when managed". This is BR-29's first leg, carried not-addressed for six rounds and then omitted from the round-10 "backlog cleared" revision. ARCH-PURPOSE.
  - id: new
    severity: Important
    family: async-callback-not-resolved
    title: |
      The background repaint preserves the selection by index, so `<CR>` can fire on a row the user never pointed at
    detail: |
      agent_picker.lua:283-291 calls handle.update with no next_selection_index; float_picker.lua:1685-1707 keeps sel_idx as an integer and only clamps it. Cold catalog: the picker opens with N agents + separator + 6 `(logged out)` rows; the user arrows onto `antigravity - (logged out)` to start a login; ~200ms later the refresh lands and the tail becomes ~9 live model rows at the same indices; `<CR>` registers a model agent instead of running the login. Fix by capturing recall_id_fn(selected) before update and passing the re-derived index — the picker already owns that identity function. BR-29's third leg.
  - id: new
    severity: Important
    family: boundary-crossed-out-of-order
    title: |
      The M3 window is empty and commit 747c8ff falls in no review window at all
    detail: |
      This is the 2nd finding in family `boundary-crossed-out-of-order`. Do NOT fix this instance — fix the rule. The rule: sdlc must refuse a milestone-close whose window is empty, and refuse a close for Mx whose window contains commits whose subject claims M(x+1); both are mechanical git log --grep checks. Measured: seven M3 commits (c9e83d8 plus five "M2/M3" commits) landed before M2's close, and 747c8ff — which changed fetch_catalog, _view_for, _providers_without_models, _build_items and the arch guard — sits outside M2's window (ended 60b964b3) and outside M3's (starts at 747c8ff). The #174 "bundle fixes into the close commit so the anchor is HEAD" convention creates the hole by construction; the next window must open at the previous boundary's PARENT, or close commits must carry no code. The same leak silently dropped BR-29, whose two live legs are the two findings above. I closed this round's gap by hand: I reviewed 60b964b..747c8ff and revert-verified all four of its fixes go red without them.
  - id: new
    severity: Important
    family: stated-design-not-implemented
    title: |
      Spec Component 3 names `cliproxy_auth.lua`/`channels_for_login` as the credential source and forbids `owned_by`; the code uses only `owned_by`
    detail: |
      This is the 5th finding in family `stated-design-not-implemented`. Do NOT fix this instance — fix the rule. The rule: every repo symbol the Spec names in backticks must be swept EXECUTABLY, the way tests/arch/single_source_sweeps_spec.lua already sweeps this issue's other consolidations — a spec that parses the issue `## Spec` and the plan's Core-concepts tables and asserts each named symbol is required/referenced by the milestone's code or struck in `## Revisions`. BR-1 established this for the plan; the Spec was never brought under it and prose sweeps have now failed five times. Instance: agent_picker.lua never requires cliproxy_auth; _providers_without_models keys on provider_owned_by (agent_picker.lua:25,32), which Component 3 explicitly forbids. Not cosmetic — the Spec's own measurement (claude-sonnet-4-6 under `anthropic` on one start, `antigravity` on the next) means that with only antigravity logged in, `claude` reads as logged IN and its `(logged out)` row never appears, contradicting the Done-when. No fixture reattributes an id across owners.
  - id: new
    severity: Important
    family: close-stages-unreviewed-worktree
    title: |
      The working tree carries an uncommitted `config.lua` deleting every configured agent, and the plan's close recipe is `git add -u`
    detail: |
      git status shows ` M lua/parley/config.lua`: a local edit stripping all 18 agents to one ToolOpus* plus two commented stubs. Plan Task 3.3 Step 7 closes with `git add -u && git commit`, which stages exactly that into the M3 close commit. Stash or revert before the close, and name explicit paths in the recipe instead of `git add -u`.
  - id: new
    severity: Important
    family: missing-test-for-shipped-behavior
    title: |
      M3's own Done-when e2e — a live pick carrying tools plus web_search on the Anthropic wire, evidenced from `:ParleyLog` — is not recorded in `## Log`
    detail: |
      This is the 4th finding in family `missing-test-for-shipped-behavior`. Do NOT fix this instance — fix the rule. The rule: a plan step whose deliverable is EVIDENCE (a manual e2e, a live probe) must be treated like a test at the boundary — recorded in `## Log` with its observation, or struck in `## Revisions` with the reason — because unlike a spec file it leaves no trace when skipped, so the gate cannot tell "done" from "forgotten". Instance: plan Task 3.3 Step 5 demands picking claude-opus-5 and confirming from :ParleyLog that the request carried both the client tools and a web_search tool; `## Log` has M1-close and M2-close entries only. The gap is narrow — build_agent's three-way strategy is unit-pinned at cliproxy_catalog_spec.lua:289-360 — but it is the Spec's stated Done-when.
  - id: new
    severity: Minor
    family: one-value-two-decisions
    title: |
      `fetch_catalog`'s callback argument means the cached catalog on one path and the freshly-parsed, possibly-rejected list on the other
    detail: |
      cliproxy.lua:1456 resolves with M.catalog_cached() on the in-flight path; :1509 resolves with the parsed list even when the classify() gate declined the write, so a caller that trusts the argument gets {} whenever the proxy is down. Today's sole consumer re-reads the cache and ignores it, but the surface is new. `cb(M.catalog_cached())` in the else branch makes it uniformly "the catalog you should render".
  - id: new
    severity: Minor
    family: duplicated-logic-not-extracted
    title: |
      `render_opts`'s host/port/secret derivation is copied verbatim into `fetch_catalog`
    detail: |
      This is the 4th finding in family `duplicated-logic-not-extracted`. Do NOT fix this instance — fix the rule. The rule: when a helper is avoided because of a side effect, SPLIT the helper rather than inlining its body at the new call site — extract a side-effect-free `endpoint_opts()` that render_opts composes. Instance: cliproxy.lua:238-241 and :1464-1466 are byte-identical derivations that must now stay in sync; BR-41 correctly removed the management.key minting but paid for it with a copy.
  - id: new
    severity: Minor
    family: missing-input-guard
    title: |
      `_catalog_inflight` is never cleared if `vim.system` raises synchronously, wedging refresh for the session
    detail: |
      cliproxy.lua:1471 sets the flag before the first vim.system call; a synchronous raise (missing curl) leaves it true and every later fetch short-circuits to the cache for the rest of the session. A pcall around the launch, or clearing the flag on the failure path, closes it.
  - id: new
    severity: Minor
    family: plan-command-does-not-run
    title: |
      The durable plan has 76 step checkboxes and none are ticked, including for the two closed milestones
    detail: |
      workshop/plans/000205-live-cliproxy-model-picker-plan.md: Chunk 1 35 unticked, Chunk 2 10, Chunk 3 18, Chunk 4 13. The issue's `## Plan` milestone rows carry all the progress state, so the durable plan cannot be read as a record of what was done. Tick them, or state in the plan that the issue file is the record.
```

---

## Re-review — 2026-08-31T23:31:03-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 205 — live cliproxy model picker; retire hardcoded model lists |
| repo | parley.nvim |
| issue file | workshop/issues/000205-live-cliproxy-model-picker.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | 747c8ffc2be7f9e497d80307150f9c48856f96b8..604812f197dd9f5230feb360095bacb123b75549 |
| command | sdlc milestone-close --issue 205 --milestone M3 |
| reviewer | claude |
| timestamp | 2026-08-31T23:31:03-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

This window has two commits and no test changes. It disposes ten prior findings, and the two that required *code* — BR-42 (`is_managed()` gating the catalog refresh) and BR-43 (repaint clobbering the selection) — landed as unpinned edits in a module the suite already drives headlessly. BR-42's edit is correct on inspection; BR-43's is not. I reproduced it against the production `float_picker`: `update`'s `next_selection_index` is written straight into `sel_idx`, which indexes `filtered`, while the new code at `agent_picker.lua:288-308` computes the index against the full `items` list. With a query typed — the picker's primary interaction — the operator pointing at `antigravity - (logged out)` lands on `antigravity-pro` after the refresh, which is precisely the "`<CR>` fires on a row you never pointed at" failure BR-43 exists to prevent, now deterministic rather than accidental. The artifact work in this window is genuinely good — the Spec restatement carries a proper `## Revisions` entry, the `git add -u` recipes are gone, and the M3 Done-when evidence is on the record with the response block types and the reasoning for why the answer is the evidence. But a boundary that ships a wrong fix for the finding it claims to close, with no test that could have caught it, is not a boundary to cross. Mapped suites are green (`providers/cliproxy-managed` 20 files / 0 failures; `modes/super_repo` 12 files / 0 failures) — which is the point: nothing in the suite touches this path.

## 1. Strengths

- **The `is_managed()` reasoning is right and the atlas says why.** `atlas/providers/cliproxy-managed.md:78-82` separates "parley will not START a proxy" from "there is no proxy," and notes the dormancy contract is untouched because `fetch_catalog` is a plain GET. That is the correct decomposition, and putting the *reason* in the atlas rather than only the code comment is what makes it survive.
- **The Spec restatement is honest about what it does not cover.** `workshop/issues/000205-live-cliproxy-model-picker.md:95-105` names the uncovered case (a loaded-but-dead credential) and hands it to #197's dispatch-failure path, instead of quietly widening the claim. The `## Revisions` entry at :354 records the reason for the change rather than overwriting history — exactly the AGENTS.md §1 discipline.
- **The M3 Done-when evidence is specific enough to be checkable.** The `## Log` entry records the strategy (`anthropic_tools_route`), the server tools in the payload, the response block types, and — the good part — *why the answer is the evidence*: the inert paths return a stale Neovim version from memory, so `v0.12.5` distinguishes "the search ran" from "the request succeeded."
- **BR-46 verified closed by measurement, not by claim.** All eleven `git add -u` recipes are gone, the Notes carry the rule with its failure history, and neither window commit staged `lua/parley/config.lua` — `git status` still shows it modified and unstaged.

## 2. Critical findings

None.

## 3. Important findings

**I-1 — `next_selection_index` is `items`-space at every caller and `filtered`-space in the picker; the BR-43 fix is wrong under an active query.** `lua/parley/float_picker.lua:1690-1692` assigns `sel_idx = next_selection_index`, and `sel_idx` indexes `filtered` (`:1024`, `:1029`). `lua/parley/agent_picker.lua:299-306` computes the index by scanning the full `items` list. When a query is active, `apply_filter(false)` → `set_selection(sel_idx)` clamps that items-index into a much shorter `filtered`. Measured against the real picker (18 agents + separator + two `antigravity*` login rows, query `antigravity`): selected before = `antigravity`, index handed to `update` = 20, selected after = `antigravity-pro`.

Fix in `float_picker`, not at the call site — there are two other consumers with the same latent defect (`finder_loader.lua:261` passes `result.initial_index`, computed against `items` by `chat_finder.resolve_finder_initial_index`; `agent_picker.lua:261`, the `<C-a>` expand repaint, passes nothing at all and so keeps a stale filtered index). Either accept an identity and resolve it *after* `apply_filter` — the picker already owns `recall_id_fn`, which is the same "find my row again" the new loop hand-rolls (ARCH-DRY) — or translate the items-index to its filtered position inside `update`. Then document the handle contract in `atlas/ui/pickers.md`, which owns the picker surface and was not updated for the new `selected()` method.

**I-2 — a declined refresh records no attempt, so the 10-minute envelope never engages and every picker open re-spawns two `curl`s.** `fetch_catalog` writes the cache only on the accept path (`cliproxy.lua:1500-1502`); `catalog_cached` returns `{}, nil` with no file (`:1390-1391`); `catalog_stale` is `not at or …` (`:1438`). With no proxy answering, `at` is never set, so staleness never resets: every agent-picker open spawns two `vim.system` `curl` processes that connection-refuse, forever, with no backoff. `atlas/providers/cliproxy-managed.md:78` states "Refreshed on picker open when older than 10 minutes," which is not what happens for anyone without a live proxy — and this commit extends that population to the `manage = false` opt-out. Record the *attempt* (a `last_attempt_at`, or a timestamped empty cache marker) so the declared envelope actually bounds the work. ARCH-CONSTRAINTS.

**I-3 — this is the 5th finding in family `missing-test-for-shipped-behavior`.** Earlier rounds fixed instances. Do NOT fix this instance — the rule is: **a boundary that changes runtime behavior must change a test file in the same window; if the diff touches `lua/` and touches no spec, the boundary does not close.** Measured prevalence on this issue: BR-3, BR-20, BR-31, BR-47, and now BR-42/BR-43 — six instances across twelve rounds, and this round is the first where the window contains *zero* test changes at all while claiming two behavior fixes. The excuse that these paths are untestable does not hold: `tests/unit/float_picker_spec.lua` drives `float_picker.open` headlessly today (76 tests, including keymap dispatch and async status transitions), `tests/unit/picker_items_spec.lua` already builds the `plugin` table `M.agent_picker` needs, and `tests/integration/openai_tool_loop_spec.lua:75-76` already stubs `cliproxy.is_managed` — the same seam stubs `fetch_catalog`. Both fixes were cheap to pin, and I-1 is what an unpinned fix costs.

## 4. Minor findings

- `git add <the files this task names>` (11 sites in the plan) is a placeholder, not a command — the recipes no longer run as written. 4th in family `plan-command-does-not-run`; the rule is that a fenced block in a plan is an *executable* recipe, so a constraint must be expressed as real paths, not as prose inside the command.
- `docs/parley.nvim.md.parley-backup.1` is untracked and `*.parley-backup.*` is not in `.gitignore`; it will follow any future `git add -A`.
- `workshop/lessons.md` gained nothing this round despite four families now at ≥4 recurrences, which AGENTS.md §4 asks for by name.

## 5. Test coverage notes

Zero test files changed. `make test-spec SPEC=providers/cliproxy-managed` → 20 files, 0 failures, 0 errors; `SPEC=modes/super_repo` (which carries `float_picker_spec`) → 12 files, 0 failures, 0 errors. Both stay green with I-1 present, which is the coverage statement: no spec constructs a picker, types a query, and repaints. The pure layer is well covered (`picker_items_spec` 46 tests over `_build_items`/`_view_for`/`_providers_without_models`), and `_view_for`'s own docstring records why it was extracted — the first dedupe was tested by re-implementing it in the spec body, so reverting the fix left the suite green. That lesson is exactly what I-3 is asking to apply one layer up.

## 6. Architectural notes

- **ARCH-DRY — flag.** BR-49 open (`render_opts`'s host/port/secret derivation duplicated at `cliproxy.lua:238-241` and `:1464-1466`). The new identity→index loop is a third hand-rolled "find my row again" next to `recall_id_fn` (I-1).
- **ARCH-PURE — pass.** `_build_items`, `_view_for` and `_providers_without_models` are pure and tested without IO; `selected()` is a thin read on the shell.
- **ARCH-PURPOSE — flag.** Five findings this round said "fix the rule, not the instance" (BR-44, BR-45, BR-47, BR-49, plus the family escalations). Every one moved only the instance. The sibling repaint site at `agent_picker.lua:261` is untouched by BR-43's fix — the class, not the site.
- **ARCH-MOCK — flag.** `fake_cliproxy` is a real stateful subprocess fake serving both routes with the awkward shapes, which is right. But its own comment at `tests/fixtures/fake_cliproxy:203` claims "one id claimed by a second owner, which the real proxy does across restarts" and `CATALOG_V1` has seven ids each with exactly one owner. The fake cannot exercise the instability the Spec measured.
- **ARCH-CONSTRAINTS — flag.** I-2. The plan declares an operating envelope for the picker-open path; the implementation does not enforce it on the failure path.

## 7. Plan revision recommendations

- Strike or correct the Integration-points bullet claiming `fake_cliproxy` carries "one id claimed by two owners" — it does not, and that shape is what the `(logged out)` signal's correctness turns on.
- Add a row for `lua/parley/float_picker.lua` (`selected`, `modified`) to the Core-concepts tables; this window modified it and no table names it. 4th in family `plan-table-missing-entity` — the rule the plan's own bidirectional convention already implies is that a file appearing in a milestone's diff must appear in a table, which wants a check next to `tests/arch/single_source_sweeps_spec.lua` rather than another manual add.
- Either tick the 76 step checkboxes or state in the plan that `## Plan` in the issue file is the record (BR-51).

```findings
dispose:
  - id: BR-42
    disposition: not-addressed
    note: |
      Gate correctly removed and the atlas explains why, but no test pins it — `M.agent_picker` is driven by zero specs, and `is_managed` is already stubbable (openai_tool_loop_spec.lua:76).
  - id: BR-43
    disposition: not-addressed
    note: |
      The fix restores by identity then converts to an index in the WRONG coordinate space; measured wrong under an active query (see I-1). Sibling site agent_picker.lua:261 untouched.
  - id: BR-44
    disposition: not-addressed
    note: |
      Instance documented in `## Log`; the rule was not implemented and no issue was filed against the repo that owns `sdlc` (no Go source in this tree).
  - id: BR-45
    disposition: not-addressed
    note: |
      Spec restated with a proper Revisions entry, but the demanded executable sweep was not built; and the new prose claims immunity via the static map while matching on `m.owner`, which is the wire's `owned_by` — the field this same Spec measures as unstable at :59. No fixture carries that shape.
  - id: BR-46
    disposition: addressed
    note: |
      Verified: 11 `git add -u` recipes replaced, Notes rule added, and neither window commit staged lua/parley/config.lua (still unstaged in the worktree).
  - id: BR-47
    disposition: addressed
    note: |
      Evidence is on the record with payload, server tools, response block types and why the answer is the tell. The unwritten rule is carried forward in the lessons.md Minor.
  - id: BR-48
    disposition: not-addressed
    note: |
      lua/parley/cliproxy.lua is untouched in this window; :1456 and :1509 still resolve with different meanings.
  - id: BR-49
    disposition: not-addressed
    note: |
      cliproxy.lua:238-241 and :1464-1466 are still byte-identical derivations; no `endpoint_opts()` extracted.
  - id: BR-50
    disposition: not-addressed
    note: |
      `_catalog_inflight` is still set before the first vim.system call with no pcall or failure-path clear; blast radius widened now that the is_managed gate is gone.
  - id: BR-51
    disposition: not-addressed
    note: |
      Measured on 604812f: 76 unticked checkboxes, 0 ticked, and no statement added that the issue file is the record.
findings:
  - id: new
    severity: Important
    family: one-value-two-decisions
    title: |
      `next_selection_index` is an items-index at every caller and a filtered-index in the picker, so the BR-43 repaint fix lands the cursor on the wrong row under an active query
    detail: |
      float_picker.lua:1690-1692 writes next_selection_index into sel_idx, which indexes `filtered` (:1024, :1029); agent_picker.lua:299-306 computes it against the full `items` list. Measured against the production picker with 18 agents + separator + two `antigravity*` login rows and query "antigravity": selected before = antigravity, index handed to update = 20, selected after = antigravity-pro. This is the 4th finding in family `one-value-two-decisions` — the rule is that a value must carry ONE meaning across every path and consumer, so fix it in float_picker (resolve an identity after apply_filter, reusing recall_id_fn) rather than at the call site. Two other consumers share the defect: finder_loader.lua:261 passes an items-space initial_index, and agent_picker.lua:261 (the <C-a> expand repaint) passes nothing and keeps a stale filtered index. Also document the new `selected()` handle method and the third-arg contract in atlas/ui/pickers.md, which owns the picker surface and was not updated.
  - id: new
    severity: Important
    family: retry-not-rate-limited
    title: |
      A declined catalog refresh records no attempt, so `catalog_stale()` never resets and every agent-picker open re-spawns two curls with no backoff
    detail: |
      fetch_catalog writes the cache only on the accept path (cliproxy.lua:1500-1502); catalog_cached returns `{}, nil` with no file (:1390-1391); catalog_stale is `not at or ...` (:1438). With no proxy answering, the timestamp is never set, so staleness is permanently true and each picker open spawns two vim.system curls that connection-refuse. atlas/providers/cliproxy-managed.md:78 documents "Refreshed on picker open when older than 10 minutes" — a cadence that does not hold for anyone without a live proxy, a population this commit extends to the `manage = false` opt-out. Record the attempt (last_attempt_at, or a timestamped empty marker) so the declared envelope bounds the work. ARCH-CONSTRAINTS.
  - id: new
    severity: Important
    family: missing-test-for-shipped-behavior
    title: |
      The window changes runtime behavior in two modules and contains zero test changes
    detail: |
      This is the 5th finding in family `missing-test-for-shipped-behavior`. Do NOT fix this instance — the rule is: a boundary whose diff touches `lua/` and touches no spec file does not close. Measured prevalence on this issue: BR-3, BR-20, BR-31, BR-47, and now BR-42/BR-43 — and this is the first round with no test change at all while claiming two behavior fixes. The paths are testable today: float_picker_spec.lua drives float_picker.open headlessly including keymaps and async status, picker_items_spec.lua already builds the plugin table M.agent_picker needs, and openai_tool_loop_spec.lua:76 already stubs cliproxy.is_managed (the same seam stubs fetch_catalog). The cost of skipping it is the other Important finding this round.
  - id: new
    severity: Minor
    family: plan-command-does-not-run
    title: |
      `git add <the files this task names>` replaced `git add -u` at 11 sites, so the plan's commit recipes are no longer executable
    detail: |
      This is the 4th finding in family `plan-command-does-not-run`. The rule: a fenced command block in a plan is an executable recipe, so a constraint must be expressed as real paths, not as prose inside the command. BR-46's intent was right; name the files each task actually touches.
  - id: new
    severity: Minor
    family: lesson-not-recorded
    title: |
      Four finding families are at four or more recurrences and `workshop/lessons.md` gained nothing this round
    detail: |
      AGENTS.md section 4 asks for a lessons.md rule per code review. stated-design-not-implemented (6), single-source-not-enforced (5), duplicated-logic-not-extracted (4) and missing-test-for-shipped-behavior (4) are exactly what the file exists to stop repeating; its only #205 entry is the M2 sandbox lesson. BR-47's unwritten rule — an EVIDENCE step is recorded in `## Log` or struck in `## Revisions`, because unlike a spec it leaves no trace when skipped — belongs there too.
  - id: new
    severity: Minor
    family: close-stages-unreviewed-worktree
    title: |
      `docs/parley.nvim.md.parley-backup.1` is untracked and `*.parley-backup.*` is not gitignored
    detail: |
      This is the 2nd finding in family `close-stages-unreviewed-worktree`. Do NOT fix this instance — the rule BR-46 established covers it: stage named paths, never `-u`/`-A`. The addition here is that parley's own backup artifacts should be gitignored so they cannot be swept even by a slip.
```

---

## Re-review — 2026-08-31T23:48:25-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 205 — live cliproxy model picker; retire hardcoded model lists |
| repo | parley.nvim |
| issue file | workshop/issues/000205-live-cliproxy-model-picker.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | 747c8ffc2be7f9e497d80307150f9c48856f96b8..bb7ad56c8f6c782f102bf4898fe0f7dc8c1a6793 |
| command | sdlc milestone-close --issue 205 --milestone M3 |
| reviewer | claude |
| timestamp | 2026-08-31T23:48:25-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

This window does real work — the `is_managed()` gate is gone and pinned, the repaint restores by identity in the widget that owns the coordinate space, `endpoint_opts` kills the duplicate derivation, `settle()` centralises the in-flight clear, and `workshop/lessons.md` finally carries the four recurring rules. Full suite green (192 spec files, exit 0) and `make lint` clean at `bb7ad56`. What blocks SHIP is that the BR-53 fix introduced a confirmed regression on M3's own Done-when path: keying staleness on the last *attempt* means one failed probe arms a 10-minute silence that survives the login the picker just launched — I measured `catalog_stale() == false` and `catalog_cached()` empty with the fake proxy up and answering, so the operator who picks `antigravity - (logged out)`, completes the OAuth, and reopens the picker sees the same six logged-out rows and no way to force a refresh. Secondary: the headline BR-52 fix is not falsifiable by its own test — I reverted the widget to items-space resolution in a scratch worktree and all four new `float_picker update selection` cases stayed green, because the fixture's target is the last filtered row and `get_selected_item()` clamps.

## 1. Strengths

- **The BR-42 fix is pinned and mutation-verified.** `tests/unit/picker_items_spec.lua:559-586` drives the real `M.agent_picker` with `is_managed` stubbed false; reintroducing the `is_managed()` conjunct at `lua/parley/agent_picker.lua:287` turns it red (measured). The stubs are restored *before* the asserts, and the seam is the module boundary, not the function under test.
- **BR-53's own test is genuinely falsifying.** Reverting `catalog_stale` to `not at or …` makes `tests/integration/cliproxy_catalog_spec.lua:262-272` fail with its own message (measured). It also runs against a real unbound port rather than a mock — ARCH-MOCK done right.
- **The BR-52 fix landed in the correct module.** Resolving the identity inside `update` after `apply_filter` (`lua/parley/float_picker.lua:1720-1727`) is the right place: `filtered` is in scope there and nowhere else. Exposing `selected()` (`:1741`) rather than an index is the right shape for the handle.
- **`endpoint_opts()` is the split BR-49 asked for**, not a second copy — `render_opts` composes it, and the existing "does not mint a management key just to refresh the catalog" test still guards the side-effect-freedom that motivated the inline in the first place.
- **`lessons.md` states rules, not incidents** — "break the code on purpose and watch the test go red", "grep the tree for siblings before calling a sweep done", "a boundary touching `lua/` with no spec change does not close". These are the right four.

## 2. Critical findings

**C1 — a failed catalog attempt silences the picker for 10 minutes, through the login it just started.** `lua/parley/cliproxy.lua:1459-1463`. `catalog_stale()` now returns false for `CATALOG_TTL` after *any* attempt, and `_write_catalog` has exactly one production caller — inside `fetch_catalog`'s accept path. `agent_picker.lua:287` is the only refresh trigger. Measured in a scratch worktree: fetch against a dead port, then bring `fake_cliproxy` up and re-point the endpoint → `catalog_stale() == false`, `#catalog_cached() == 0`. So: no proxy running → open picker (one failed attempt) → pick `antigravity - (logged out)` → `:ParleyProxy login antigravity` succeeds → reopen picker → still six logged-out rows, no live models, for up to ten minutes, with no operator-reachable reset (`M._reset_catalog_clock` at `:1455` has zero production callers and is documented "Test seam"). This is the Done-when the login row exists to serve. Fix sketch: give failure its own short backoff (`CATALOG_RETRY_BACKOFF ≈ 30s`, with its own basis line in the plan's operating envelope), **and** call the clock reset from the production proxy-start/login path so a successful login always re-arms the next open. Also update `atlas/providers/cliproxy-managed.md:78`, which still documents only the success cadence. ARCH-CONSTRAINTS.

## 3. Important findings

**I1 — BR-52's test cannot fail on the thing BR-52 was about.** `tests/unit/float_picker_spec.lua:1182-1199`. I replaced the widget's `filtered`-space loop with an items-space one (`sel_idx = i` over `items`) and all four cases stayed green. Cause: the fixture's target `bbb-four` is the **last** filtered row (`filtered = {bbb-two, bbb-four}`, measured), and `get_selected_item()` clamps `math.min(sel_idx, #filtered)` — so items-index 5 clamps to 2, the right answer by accident. `:1201`'s title ("addresses the filtered list") is likewise unverified: with no query, `filtered == items`. Fix sketch: pick a fixture where the target is *early* in `filtered` and *late* in `items` — e.g. query `bbb` over `{aaa-1, aaa-2, aaa-3, bbb-target, bbb-other}`, target `bbb-target` at filtered index 1 and items index 4; the broken form clamps to 2 and returns `bbb-other`. Then re-run the revert and confirm red. This is the rule the same commit wrote into `lessons.md`.

**I2 — BR-52's two named siblings are untouched; the value still carries two meanings.** `lua/parley/finder_loader.lua:261` still passes `result.initial_index`, computed in items space by `chat_finder.resolve_finder_initial_index`, into the numeric branch that writes `sel_idx` (filtered space) — and `finder_loader` explicitly reads `picker.current_query()` first, so a query is live on that path. `lua/parley/agent_picker.lua:261` (the `<C-a>` repaint) still passes nothing and keeps a stale filtered index across a wholesale item swap. **This is the 5th finding in family `one-value-two-decisions`.** Do not fix these two sites. The rule: **a value crossing a module boundary carries ONE meaning; when a second is needed the type distinguishes them and the widget resolves both in its own space.** The enumeration is `grep -n "\.update(" lua/` — five call sites; sweep all five in this round, and either convert the numeric branch to items-space (resolving through `filtered` like the string branch) or rename it so the space is in the name.

**I3 — `atlas/ui/pickers.md` is not updated for the new picker surface.** That file owns the picker contract (`:56` documents `recall_id_fn` and `initial_index`), and this window adds a public handle method `selected()` and a third `update` argument whose type selects its coordinate space. **This is the 3rd finding in family `atlas-not-updated-for-new-surface`.** The rule: **a new public method on, or contract change to, a shared widget handle updates the atlas page that owns that widget in the same commit** — mechanically, any diff touching a `return { … }` handle literal in `lua/parley/float_picker.lua` requires a matching `atlas/ui/pickers.md` hunk.

**I4 — BR-45 not addressed: no executable Spec sweep, and the Spec's new immunity claim is false.** `tests/arch/` is unchanged in this window, so the demanded sweep does not exist. Worse, the restated Component 3 (`workshop/issues/000205-live-cliproxy-model-picker.md`) now asserts "Catalog rows attach to a provider through the static `PROVIDER_OWNED_BY` map, which is unaffected by the shared-id instability above" — but `agent_picker.lua:32` matches `m.owner`, and `cliproxy_catalog.lua:76` sets `owner = m.owned_by`, the wire field the same Spec measures as unstable ("`claude-sonnet-4-6` landed under `anthropic` on one proxy start and `antigravity` on the next"). Only the left side of the comparison is static. Concretely: `claude` logged in, its models served under `owned_by = "antigravity"` on this start → `provider_owned_by("claude") = "anthropic"` finds zero rows → false `(logged out)` for a provider you are logged into. **This is the 6th finding in family `stated-design-not-implemented`.** Do not patch the prose again — build the sweep BR-45 specified (parse the issue `## Spec` + the plan's Core-concepts tables for backticked identifiers; assert each is required/referenced by the milestone's code or struck in `## Revisions`), and add the fixture that reattributes one id across owners, which no fixture carries.

**I5 — BR-44 not addressed: the rule is still unimplemented and no issue exists for it.** No `sdlc` source lives in this tree, and I verified `/Users/xianxu/workspace/ariadne` has no issue covering an empty/overlapping review window and no commits since 2026-08-30. **This is the 3rd finding in family `boundary-crossed-out-of-order`.** The concrete next action is not a code change here: file the ariadne issue stating the rule (`milestone-close` refuses an empty window; refuses an `Mx` close whose window carries `M(x+1)`-subject commits; the next window opens at the previous boundary's **parent**), and link it from #205 with `--deps` so the gap is tracked rather than re-measured every round.

**I6 — the plan's Core-concepts tables gained no rows for this window's new surface.** `M._reset_catalog_clock` (`cliproxy.lua:1455`, module-public, sibling of `catalog_stale` which *is* tabled), the `selected()` handle method, and `endpoint_opts` are all absent; `lua/parley/float_picker.lua` appears in neither table. **This is the 5th finding in family `plan-table-missing-entity`.** The rule: **the Core-concepts sweep must run in both directions.** `tests/arch/single_source_sweeps_spec.lua` already sweeps table→code; add code→table — for the milestone's diff, every added `function M.<name>` under `lua/` and every added key in a returned handle literal must appear in a Core-concepts row or be struck in `## Revisions`.

## 4. Minor findings

- **BR-48 still open.** `cliproxy.lua:1544` resolves `settle(models)` with the freshly-parsed list even when `classify()` declined the write, while `:1482`, `:1490` and `:1521` resolve with `M.catalog_cached()`. `settle(M.catalog_cached())` in the else branch makes the argument uniformly "the catalog you should render".
- **BR-50 still open for the case it named.** `settle()` covers the callback paths, but `_catalog_inflight = true` (`:1493`) precedes `get(…)` → `vim.system(…)`, which raises synchronously on a missing binary — verified: `vim.system({"definitely-not-a-binary-xyz"})` errors `ENOENT … (cmd)`. The flag is stranded true for the session *and* `cb` is never called, violating this function's own "every exit path resolves the callback exactly once" contract. A `pcall` around the two launches, settling on failure, closes both.
- **BR-55 still open at one site.** `workshop/plans/000205-live-cliproxy-model-picker-plan.md:1483` is `git add tests/ lua/` — a directory-wide add that stages the operator's uncommitted `lua/parley/config.lua`, which the plan's own new Notes rule at `:1604` forbids. Twelve of thirteen recipes name paths; name them here too.
- **The `catalog_stale` doc comment now documents the wrong function.** `cliproxy.lua:1448-1449` ("Is the cache old enough to be worth a background refresh? / `---@return boolean`") sits above the newly inserted `M._reset_catalog_clock` at `:1455`; `M.catalog_stale` at `:1459` has no doc block at all. **This is the 2nd finding in family `docs-insert-orphans-section`.** The rule: an insertion point is *after* the preceding function's doc block **and** body, never between a doc comment and the definition it annotates — check by reading both neighbours' rendered docs after any insert.
- `tests/unit/picker_items_spec.lua:577` opens a real picker via `M.agent_picker` and never closes the handle. Harmless today because the block is last in the file; a `describe` added after it inherits an open float.
- `local was = handle.selected and handle.selected()` (`agent_picker.lua:298`) guards a method the same module's own widget always returns.

## 5. Test coverage notes

- Suite is green and lint-clean at `bb7ad56` (192 spec files, `make test` exit 0; `make lint` 0 warnings / 0 errors in 345 files), run in a detached worktree at HEAD.
- Two of the three behaviour claims are falsifiable: BR-42 (revert the gate → red) and BR-53 (revert the clock → red). BR-52's is not (I1).
- C1 has no test at all, and none of the existing catalog specs would notice it: the closest, `:262-272`, asserts exactly the property that causes it.
- BR-49 and BR-50 ship without tests. BR-49 is fine — the pre-existing management-key spec covers the side-effect property that motivated it. BR-50's remaining gap is testable: stub `vim.system` to raise and assert `cb` fires and a second `fetch_catalog` still spawns.

## 6. Architectural notes for upcoming work

- **ARCH-DRY — pass.** `endpoint_opts` and `settle` both consolidate rather than copy; no new duplicated logic in the diff.
- **ARCH-PURE — pass.** The identity resolution moved into the module that owns `filtered`, and it is exercised headlessly without mocks. `endpoint_opts`'s vault read stays in the IO shell.
- **ARCH-PURPOSE — flag (I2, I4).** BR-52 and BR-45 were each answered at the site the finding named while the enumerable siblings the finding *listed* stayed in the tree. `lessons.md` now states this rule in the same commit that violates it twice.
- **ARCH-MOCK — pass.** The new integration case runs against a real unbound port; the unit case stubs at the module seam and restores. No stateless double stands in for a stateful interaction.
- **ARCH-CONSTRAINTS — flag (C1).** BR-53 correctly bounded an unbounded retry, but reused `CATALOG_TTL` for a decision it was never measured for. M4 inherits this surface: when `resolve_channel` starts deriving from the catalog, a 10-minute-stale-and-unrefreshable catalog becomes a dispatch failure, not just a picker render.

## 7. Plan revision recommendations

- **`## Revisions` — C1.** Record that `catalog_stale()` now keys on the last *attempt*, that this arms a `CATALOG_TTL` silence after a failure, and what the failure backoff constant and its basis are. The `### Operating envelope` "Staleness" bullet must gain the failure branch — right now it states only the success cadence, and `atlas/providers/cliproxy-managed.md:78` restates that stale claim.
- **`## Core concepts` — I6.** Add `_reset_catalog_clock` and `endpoint_opts` (Integration points, `lua/parley/cliproxy.lua`, new) and a `lua/parley/float_picker.lua` row for `update` (modified) / `selected` (new), or record in `## Revisions` why the widget is out of scope for the tables.
- **`## Revisions` — I1.** The round-2 entry claims BR-52 is "Pinned by a test with an active query, verified to fail without the fix". Amend it: the test fails without identity support, not without correct coordinate-space resolution, and the fixture is being changed to distinguish the two.
- **Notes / Task 4.1 — BR-55.** Replace `git add tests/ lua/` at `:1483` with the files that task touches.

```findings
dispose:
  - id: BR-42
    disposition: addressed
    note: |
      Gate removed at agent_picker.lua:287; pinned by picker_items_spec.lua:559-586 and mutation-verified red by reintroducing the is_managed() conjunct.
  - id: BR-43
    disposition: addressed
    note: |
      Superseded by BR-52's widget-side fix; identity restore works and goes red if the string branch is removed.
  - id: BR-44
    disposition: not-addressed
    note: |
      Rule still unimplemented and no ariadne issue filed — verified no matching issue and no commits there since 2026-08-30.
  - id: BR-45
    disposition: not-addressed
    note: |
      tests/arch/ unchanged, so no executable Spec sweep; and the restated Spec's PROVIDER_OWNED_BY immunity claim is contradicted by agent_picker.lua:32 matching m.owner, which cliproxy_catalog.lua:76 sets from the wire's owned_by.
  - id: BR-48
    disposition: not-addressed
    note: |
      cliproxy.lua:1544 still settles with the parsed list on the declined path while every other exit resolves with catalog_cached().
  - id: BR-49
    disposition: addressed
    note: |
      endpoint_opts() extracted at cliproxy.lua:238-249 and composed by render_opts; the management-key spec still guards the side-effect-freedom that motivated the original inline.
  - id: BR-50
    disposition: not-addressed
    note: |
      settle() covers the callbacks only; _catalog_inflight is still set before vim.system, which raises synchronously on a missing binary (verified ENOENT), stranding the flag and dropping cb.
  - id: BR-51
    disposition: addressed
    note: |
      The plan now states at its head that the issue file, not its checkboxes, is the record of progress.
  - id: BR-52
    disposition: not-addressed
    note: |
      Code fix is correct, but the test passes with items-space resolution substituted (measured), the two sibling consumers it named are untouched, and atlas/ui/pickers.md was not updated.
  - id: BR-53
    disposition: addressed
    note: |
      Fix landed and is mutation-verified red; it introduced a new post-login blindness window, raised separately as a Critical.
  - id: BR-54
    disposition: addressed
    note: |
      Three spec files changed with real assertions, two of the three behaviour claims mutation-verified, and the rule is in lessons.md.
  - id: BR-55
    disposition: not-addressed
    note: |
      Twelve recipes name paths, but plan.md:1483 is `git add tests/ lua/`, a directory-wide add that stages the operator's uncommitted config.lua — the hazard the plan's own Notes rule at :1604 forbids.
  - id: BR-56
    disposition: addressed
    note: |
      lessons.md gained the four recurring failures plus the evidence rule, each stated as a check rather than an incident.
  - id: BR-57
    disposition: addressed
    note: |
      Verified with git check-ignore -v — .gitignore:47 now matches docs/parley.nvim.md.parley-backup.1.
findings:
  - id: new
    severity: Critical
    family: retry-not-rate-limited
    title: |
      A failed catalog attempt silences the picker for the full 10-minute TTL, through the login it just launched
    detail: |
      cliproxy.lua:1459-1463 keys staleness on the last ATTEMPT, and _write_catalog has one production caller inside fetch_catalog's accept path, reached only via agent_picker.lua:287's catalog_stale() guard. Measured in a scratch worktree: fetch against a dead port, then bring fake_cliproxy up and re-point the endpoint — catalog_stale() is false and catalog_cached() is empty. So an operator with no proxy running opens the picker, picks `antigravity - (logged out)`, completes the login, reopens, and still sees six logged-out rows for up to ten minutes with no reachable reset (M._reset_catalog_clock at :1455 has zero production callers, documented "Test seam"). That is M3's own Done-when. Give failure its own short backoff with its own basis in the operating envelope, and reset the clock from the production proxy-start/login path. atlas/providers/cliproxy-managed.md:78 still documents only the success cadence. ARCH-CONSTRAINTS.
  - id: new
    severity: Important
    family: test-title-overstates-guard
    title: |
      The BR-52 test passes with the bug reintroduced — the fixture's target is the last filtered row, which the selection clamp reaches anyway
    detail: |
      tests/unit/float_picker_spec.lua:1182-1199. Replacing float_picker.lua:1720-1727's filtered-space loop with an items-space one left all four cases green. filtered = {bbb-two, bbb-four} (measured), so the target is at index 2 of 2 and get_selected_item()'s math.min(sel_idx, #filtered) clamps items-index 5 to it. :1201's "addresses the filtered list" is unverified too — no query means filtered == items. Use a fixture where the target is early in filtered and late in items (query "bbb" over {aaa-1, aaa-2, aaa-3, bbb-target, bbb-other}), then re-run the revert and confirm red. This is the rule the same commit added to lessons.md.
  - id: new
    severity: Important
    family: one-value-two-decisions
    title: |
      update()'s numeric branch still means items-space at its callers and filtered-space in the widget
    detail: |
      This is the 5th finding in family `one-value-two-decisions`. Do NOT fix the two sites — fix the rule: a value crossing a module boundary carries ONE meaning, and when a second is needed the type distinguishes them AND the widget resolves both in its own space. The string branch does this; the numeric branch does not. Enumeration is `grep -n "\.update(" lua/` — five call sites. finder_loader.lua:261 passes chat_finder.resolve_finder_initial_index's items-space value on a path that reads picker.current_query() first, so a query is live; agent_picker.lua:261 (the <C-a> repaint) passes nothing and keeps a stale filtered index across a wholesale item swap. Sweep all five in this round.
  - id: new
    severity: Important
    family: atlas-not-updated-for-new-surface
    title: |
      atlas/ui/pickers.md gained nothing for the new selected() handle method and update()'s third-argument contract
    detail: |
      This is the 3rd finding in family `atlas-not-updated-for-new-surface`. Do NOT just add the paragraph — state the rule: a new public method on, or contract change to, a shared widget handle updates the atlas page that owns that widget in the same commit. Mechanically: a diff touching the `return { … }` handle literal in lua/parley/float_picker.lua requires a matching atlas/ui/pickers.md hunk. That file already owns this surface (:56 documents recall_id_fn and initial_index) and now understates it.
  - id: new
    severity: Important
    family: plan-table-missing-entity
    title: |
      The plan's Core-concepts tables gained no rows for this window's new module-public surface
    detail: |
      This is the 5th finding in family `plan-table-missing-entity`. Do NOT just add rows — the rule is that the Core-concepts sweep must run in BOTH directions. tests/arch/single_source_sweeps_spec.lua already sweeps table→code; add code→table so that every added `function M.<name>` under lua/ and every added key in a returned handle literal must appear in a Core-concepts row or be struck in `## Revisions`. Instances this window: M._reset_catalog_clock (cliproxy.lua:1455, module-public, sibling of the tabled catalog_stale), the selected() handle method, endpoint_opts — and lua/parley/float_picker.lua appears in neither table at all.
  - id: new
    severity: Minor
    family: docs-insert-orphans-section
    title: |
      catalog_stale's doc comment now annotates _reset_catalog_clock, and catalog_stale has none
    detail: |
      This is the 2nd finding in family `docs-insert-orphans-section`. cliproxy.lua:1448-1449 ("Is the cache old enough to be worth a background refresh?" + `---@return boolean`) sits above the newly inserted M._reset_catalog_clock at :1455; M.catalog_stale at :1459 has no doc block. The rule: an insertion point is after the preceding function's doc block AND body, never between a doc comment and the definition it annotates — verify by reading both neighbours' rendered docs after any insert.
```
