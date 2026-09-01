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
