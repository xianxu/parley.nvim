# Boundary Review — parley.nvim#383 (whole-issue close)

| field | value |
|-------|-------|
| issue | 383 — S4 presentations: highlight agent rounds from Couch's round sidecar, propose and direct |
| repo | parley.nvim |
| issue file | workshop/issues/000383-s4-presentations-highlight-propose-direct.md |
| boundary | whole-issue close |
| milestone | — |
| window | b6e19e2006181d074e036a1f989cb63bcd983b7a..b11a4ac640ea1c93c0a673809812e271f3201923 |
| command | sdlc close --issue 383 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-18T05:49:46-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Read the full diff; now checking a few call sites (registry witness, diagnostic writers, README) and running the new specs.

Still locating how to run the specs; then I'll run the new #383 specs.

Specs produce no summary lines yet; checking the raw output of one run.

All new specs pass in the isolated harness. Checking whether the new attach-time Couch call breaks other session_sync specs.

Neighbouring suites are green too. Now a quick mutation check: dropping the generation guard and the submit-time clear, to confirm the specs catch both.

Both mutations go red. Last check: the atlas diff, for the docs gate.

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The #383 work matches its Spec and Plan. I ran every new and changed spec in the harness's isolated environment (`PREP_TEST_ENV` + `TEST_RUN`) and all pass: presentation 9, skill_render_round 4, fake_couch_round 5, edit_round 9, edit_round_hooks 4, review_mode 8, review_instruction 9, side_inherit 10 and lock_leave_reminder 18. The nearby suites are green too: document_band 32, session_sync_native 75, session_sync 64 and agentic_document 47. So is the Python export test (25). I also mutated two key guards: without the generation check in `edit_round.refresh`'s reply, edit_round_spec fails 1 case; without `edit_round.clear` in `release_and_send`, edit_round_hooks_spec fails 2. Both specs catch the bugs they exist for.

What keeps this from SHIP: README.md doesn't mention the new `presentation:` frontmatter key or that agent changes are now highlighted. That's an Important gap under the docs gate. Everything else is Minor. Some things I couldn't check here: the real-binary conformance run (no M1 couch on this host) and the deferred live check.

1. **Strengths**
   - `lua/parley/presentation.lua:280` is truly pure and treats Couch's positions as untrusted. A malformed position gives nil and the span is re-found or dropped, never clamped. The seeded 500-round sweep (`tests/unit/presentation_spec.lua:472`) asserts a floor on how many malformed positions it reached (the lesson the author recorded).
   - The round fetch reuses `document_registry.request` with its own reply classifier (`document_registry.lua:39`). The queue, deadline and child-lifetime bounds are shared, not duplicated (ARCH-DRY).
   - One generation counter per buffer guards against stale replies, and a spec tests both orders through the fake's reply-delay seam (`edit_round_spec.lua:210`). The mutation above confirms the test bites.
   - The round kind in `skill_render` keeps the footnote and review-skill diagnostics through publish and clear (`skill_render_round_spec.lua:673`). Keystroke coalescing is pinned by a counted 8/16 spec.
   - The fake compares submit and round times as instants, not text, with a local-offset case (`fake_couch_round_spec.lua:366`). The conformance probe runs the same round case against the real binary.

2. **Critical:** none.

3. **Important**
   - **README update missing for `presentation:`.** `README.md:~90` covers the Couch-pane Alt+Return flow and `process-instruction:`, but not the new key (`direct` | `highlight` | `propose`, default highlight), the highlights that clear on a confirmed submit, or `→ [proposal]` links. The atlas covers all of it (`atlas/modes/session_sync.md`); the README doesn't. Fix: add a short paragraph after the Alt+Return paragraph.

4. **Minor**
   - The Spec says highlights use `DiffChange`, but the code links `ParleyAgentChange` to `DiffAdd` (`skill_render.lua:373`). Align one or the other, and add a Revisions note if it was deliberate.
   - The Spec says clearing calls `skill_render.clear_decorations`; the code calls `edit_round.clear` → `clear_round`, to keep footnotes. That's better, but it's only in the Log, not the plan's Revisions.
   - `skill_render.attach_diagnostics` (pre-existing, `skill_render.lua:238`) replaces the whole diagnostic namespace. That drops round diagnostics while their marks stay, until the next keystroke re-derives them.
   - `edit_round.clear` resets `attached` but not `pending`. If a redraw re-attaches while an old scheduled re-derive is still pending, one batch of keystrokes isn't re-derived (ARCH-ORDER edge, self-heals on the next keystroke).
   - ARCH-ORDER: after a confirmed send, a refresh (from a reopen or reload) that comes before Couch records the `submitted:` row would redraw the round, because Couch still says not cleared. Low probability; worth a comment.
   - Lua `mode.parse` accepts `deletions` without checking the export version. Only the Python validator refuses a v3 record that carries it, so the guard holds only for packaged snapshots.
   - When the presentation isn't highlight, `refresh` → `clear` sets `generation[buf]` without registering the BufUnload hook. That leaves one integer per buffer number (negligible ARCH-FUNERAL residue).
   - The Done-when "live check on a real document" is deferred to the operator's Couch restart. The hub approved it and the steps are in the Log; keep it tracked so it isn't lost at close.

5. **Test coverage**
   - The specs drive the production modules against the stateful Python fake through the same `couch.run` seam.
   - The hooks spec covers a legacy session-sync file and a registered plain document, a failed send keeping the highlights, and reopen-after-clear.
   - No spec covers a deletion drawn end to end through `edit_round`. It's covered only in the pure and drawing units.

6. **Architecture**
   - ARCH-DRY pass: one registry client; the `deliver` helper was pulled out in the fake.
   - ARCH-PURE pass: `presentation` has no vim API calls; `edit_round` is the thin shell; `mode.export_version` is a named IO seam.
   - ARCH-PURPOSE pass: every Done-when behavior is delivered except the live check, which is deferred with approval.
   - ARCH-MOCK pass: stateful fake round, cleared by a submit; real-vs-fake conformance probe (I couldn't run the real side here).
   - ARCH-CONSTRAINTS pass: 200-span cap with a visible WARN; coalesced re-derive per keystroke batch; the shared queue is bounded at 4 active / 64 queued.
   - ARCH-SECURE pass: positions are validated in the pure layer, extmarks use `strict=false`, and malformed replies become `unavailable`.
   - ARCH-ORDER pass with Minors: the generation guard is explicit and tested in both orders; the `attached`/`pending` flag pair is a small unwritten state set (see the Minor above).
   - ARCH-FUNERAL pass: per-buffer state is forgotten on BufUnload; the sidecar belongs to Couch.

7. **Plan revisions**
   - Add a "## Revisions" entry: highlights use `ParleyAgentChange` → `DiffAdd`, not `DiffChange`; clearing goes through `edit_round.clear`/`clear_round`, not `clear_decorations`; the deletion re-anchor by context was dropped (a deletion is placed only on a matching hash); the proposal-link spec lives in `agentic_document_side_inherit_spec.lua`, not a new `edit_round_proposal_link_spec.lua`.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: readme-misses-user-surface
    title: |
      README update appears missing for the presentation frontmatter key and agent-round highlighting
    detail: |
      The diff adds a user-typed frontmatter key presentation (direct, highlight or propose, default highlight), plus highlights with reasons that clear on a confirmed Alt+Return and the proposal side-doc link. atlas/modes/session_sync.md documents them; README.md (Couch pane paragraph near line 90) does not.
  - id: new
    severity: Minor
    kind: defect
    family: spec-plan-drift-unrecorded
    title: |
      Spec says DiffChange and clear_decorations; code uses DiffAdd and clear_round, with no plan Revisions entry
    detail: |
      skill_render.lua:373 links ParleyAgentChange to DiffAdd. Clearing goes through edit_round.clear and clear_round to keep footnotes. Both deviate from the issue Spec text and should be recorded in the plan's Revisions, along with the dropped deletion re-anchor and the proposal-link spec's file.
  - id: new
    severity: Minor
    kind: defect
    family: shared-namespace-wholesale-set
    title: |
      attach_diagnostics replaces the whole diagnostic namespace and drops round diagnostics until the next keystroke
    detail: |
      skill_render.lua:238 (pre-existing) calls vim.diagnostic.set with only parley-skill entries. Round marks stay but their diagnostics vanish until on_lines triggers rederive_round.
  - id: new
    severity: Minor
    kind: defect
    family: unwritten-flag-state-set
    title: |
      edit_round.clear resets attached but not pending, so a redraw can lose one re-derive batch
    detail: |
      If a scheduled re-derive from the old token is pending when follow_edits re-attaches, the new on_lines sees pending set and skips, and the old callback returns on the token mismatch. A tagged per-buffer state would make this explicit.
  - id: new
    severity: Minor
    kind: defect
    family: deferred-done-when
    title: |
      Done-when live check on a real document is deferred to the operator's Couch restart
    detail: |
      The hub approved it and the steps are in the issue Log. Offline conformance against the M1 binary stands in. Keep it tracked so the close does not imply it ran.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"40fc91f3-228a-44ee-a9ae-838c5c382f85","repository":"github.com/xianxu/parley.nvim","issue_id":"000383","recipe":"milestone-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/fc79d6515db5a2ca","reviewed_head":"b11a4ac640ea1c93c0a673809812e271f3201923","slot":"parley.nvim:3","requested_at":"2026-10-18T12:42:56.78332Z"},"phase":"finished","pid":63682,"started_at":"2026-10-18T12:42:56.902592Z","finished_at":"2026-10-18T12:49:45.166201Z","session_id":"3fe98d6b-c55e-48a1-8f2e-c9b1c9a96a49","outcome":"returned"}] -->

---

## Re-review — 2026-10-18T06:20:50-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 383 — S4 presentations: highlight agent rounds from Couch's round sidecar, propose and direct |
| repo | parley.nvim |
| issue file | workshop/issues/000383-s4-presentations-highlight-propose-direct.md |
| boundary | whole-issue close |
| milestone | — |
| window | b6e19e2006181d074e036a1f989cb63bcd983b7a..7ec1433a42d89d2b35555b595cd837a018363e9a |
| command | sdlc close --issue 383 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-18T06:20:50-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Verifying the prior fixes: I've confirmed what the BR-4 fix changes, and I'm now checking the other code that writes the same diagnostic namespace before I run the tests.

Running the issue's specs. The first attempt printed nothing, so I'm checking what the runner actually outputs.

Next I'm reverting the BR-4 and BR-5 fixes in this throwaway checkout, one at a time, to check whether any test goes red without them.

I ran all 27 test files mapped to `modes/session_sync`, including the issue's new specs, and they pass. I'm recommending FIX-THEN-SHIP: what's left is Minor and doesn't block the close.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The feature does what the issue asks. The pure `presentation.lua` reads the `presentation:` key and places the agent's spans, treating Couch's positions as untrusted input. `edit_round.lua` fetches the round and draws it, with a per-buffer counter that drops replies a later refresh has overtaken. `session_sync` refreshes the round on reload and attach, and clears it on a confirmed send. The Couch fake models the `round` verb with state, and the conformance probe checks it against the real binary. README and atlas both cover the new surface now.

I reverted the BR-4 fix and its new spec went red, so it is a real fix with a real regression test. But it only fixes one site of a wider problem: two other functions still replace the whole shared diagnostic namespace (a repeat in family `shared-namespace-wholesale-set`). In production the skill run calls `clear_decorations` before `attach_diagnostics`, so the fix rarely fires. The BR-5 fix has no test: I reverted it and every spec stayed green. Nothing blocks.

**Strengths**
- `lua/parley/presentation.lua:42-48`: positions that fail validation are dropped, never clamped. The seeded 500-round sweep in `tests/unit/presentation_spec.lua:70-109` asserts that it actually reaches malformed input (more than 50 cases), which guards the sweep itself.
- `lua/parley/edit_round.lua:95-109`: a single per-buffer counter decides staleness. `clear` and `forget` bump it, so a late Couch reply can never redraw a round the user has already answered.
- `lua/parley/document_registry.lua:38-47`: `classify_round` sorts the reply into `round`, `absent` or `unavailable` by type, instead of reusing the registration classifier for a shape it doesn't fit.
- Keystrokes are coalesced into one re-derive per batch (counted in a spec), and a round over 200 spans says so in a WARN notice.

**Critical:** none.

**Important:** none.

**Minor**
- **New finding in family `shared-namespace-wholesale-set` (2nd in this family).** Instead of patching this site, fix the rule: any code writing the shared `parley_skill` diagnostic namespace replaces only the diagnostic kind it owns.
  - **Prevalence:** 6 writers.
    - Already filter by kind: `publish_footnotes` (:113), `clear_footnote_diagnostics` (:132), `set_round_diagnostics` (:164).
    - Patched after the fact: `attach_diagnostics` (:238). It still wipes footnote diagnostics, which is pre-existing.
    - Still replace everything: `apply_snapshot` (:370, reached on undo/redo through `projection.lua:97`) and `clear_decorations` (:44, called at every skill round start, `skill_invoke.lua:396`).
  - **Effect:** a review-skill run or an undo/redo wipes the agent's highlights before the next confirmed Alt+Return. That contradicts the commit title "round diagnostics survive a skill round".
  - **Fix sketch:** one helper, `replace_kind(buf, is_kind, diagnostics)`, with all six writers routed through it (ARCH-DRY: the three filter loops collapse into it). Also decide and document whether a skill round start should clear the agent round.
- BR-5: the `pending` reset works, but no test fails without it (details under Test coverage notes).
- Plan task checkboxes for Task 2 (`workshop/plans/000383-s4-presentations-plan.md:112-125`) are still `[ ]`, while the issue shows them `[x]`. Cosmetic.

**Test coverage notes**
- Ran: all 27 test files mapped to `modes/session_sync` pass, including `presentation_spec` (9), `skill_render_round_spec` (5), `edit_round_spec` (9), `edit_round_hooks_spec` (4), `lock_leave_reminder_spec` (18) and `agentic_document_side_inherit_spec` (10). The `fake_couch_round_spec`, `review_mode_spec` and `review_instruction_spec` files were not individually confirmed in the output I saw.
- BR-4 revert test: `keeps the round's diagnostics when a skill round sets its own` failed without the fix.
- BR-5 revert test: both `edit_round` specs stayed green without the fix.
- Not covered: the round surviving the real skill-run sequence (`clear_decorations` then edits then `attach_diagnostics`), and the round surviving undo/redo through `apply_snapshot`.

**Architecture**
- **ARCH-DRY: flag (Minor).** The three copies of the "keep other kinds, then set" loop should become one helper; see the namespace finding.
- **ARCH-PURE: pass.** `presentation.lua` has no `vim.api` and its tests run without IO. `edit_round` is a thin shell around it.
- **ARCH-PURPOSE: pass.** The deferred live check is the only open item (BR-6), recorded explicitly.
- **ARCH-MOCK: pass.** The fake keeps a seeded round and `Cleared` after a submit, and the probe runs the same cases against the real M1 binary.
- **ARCH-CONSTRAINTS: pass.** Re-derives are coalesced and cost O(spans), there are at most 200 spans, and each Couch request is bounded with a deadline.
- **ARCH-SECURE: pass.** The reply, span fields, `explain` and positions are all type-checked before use.
- **ARCH-ORDER: pass, with a note.** The counter guard is explicit. The four per-buffer tables `attached`, `pending`, `announced` and `hooked` are still a set of loose flags (BR-5). One more site: `:edit!` in `reload()` detaches the buffer callback without clearing `pending`. That is harmless in practice, because the old scheduled callback runs before the asynchronous reply.
- **ARCH-FUNERAL: pass.** Nothing durable is created on parley's side. BufUnload → `forget` drops all per-buffer state, including `round_marks` through `clear_round`.

**Plan revision recommendations**
- Add a Revisions note that `clear_decorations` (skill round start, review with no markers) and `apply_snapshot` (undo/redo) also clear the agent round, or change them so they don't.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Plan Task 2 carries the one-line adversarial strategy (plan:122) and presentation_spec.lua:70-109 implements it with a reach assertion; the leftover case list is harmless prose.
  - id: BR-2
    disposition: addressed
    note: |
      README.md:102-110 now documents presentation: direct/highlight/propose, reasons, clearing on confirmed Alt+Return, the proposal link via Alt+o, the 200 cap, and the pair#661 requirement; it matches edit_round.lua and presentation.lua.
  - id: BR-3
    disposition: addressed
    note: |
      Plan Revisions (2026-10-18 close review) record DiffAdd vs DiffChange, clear_round vs clear_decorations, hash-only deletion placement, and the proposal-link spec file; matches skill_render.lua and edit_round.lua.
  - id: BR-4
    disposition: addressed
    note: |
      skill_render.lua:239-240 restores the round kind; reverting it fails the new skill_render_round_spec case. Siblings of the class are raised as a new finding.
  - id: BR-5
    disposition: not-addressed
    note: |
      edit_round.lua:120 now resets pending, but reverting it leaves edit_round_spec and edit_round_hooks_spec green; no regression test pins the lost-batch interleaving.
  - id: BR-6
    disposition: addressed
    note: |
      Issue Task 6 states the live check is deferred to the operator's Couch restart, with steps in the Log; the close does not claim it ran.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: shared-namespace-wholesale-set
    title: |
      apply_snapshot and clear_decorations still replace the shared namespace wholesale and wipe the agent round
    detail: |
      2nd finding in this family. The rule: every writer of the parley_skill diagnostic namespace replaces only the kind it owns, through one helper replace_kind(buf, is_kind, diagnostics). Prevalence, 6 writers in skill_render.lua. Three filter by kind (113, 132, 164). attach_diagnostics (238) is patched after the fact and still wipes footnote diagnostics, which is pre-existing. apply_snapshot (370, undo/redo via projection.lua:97) and clear_decorations (44, every skill round start at skill_invoke.lua:396) still clear everything. So the agent's highlights vanish on a review-skill run or an undo/redo before the next confirmed submit, and the BR-4 restore rarely fires in production.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"fcd3daab-6610-4000-853d-de5164c98cf7","repository":"github.com/xianxu/parley.nvim","issue_id":"000383","recipe":"milestone-review","round":3,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/b7cd8e79013fbada","reviewed_head":"7ec1433a42d89d2b35555b595cd837a018363e9a","slot":"parley.nvim:3","requested_at":"2026-10-18T13:10:21.303694Z"},"phase":"finished","pid":10027,"started_at":"2026-10-18T13:10:21.494735Z","finished_at":"2026-10-18T13:20:50.091601Z","session_id":"b884b39a-1c2a-4fce-bc3f-850402b59a96","outcome":"returned"}] -->

---

## Re-review — 2026-10-18T06:44:42-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 383 — S4 presentations: highlight agent rounds from Couch's round sidecar, propose and direct |
| repo | parley.nvim |
| issue file | workshop/issues/000383-s4-presentations-highlight-propose-direct.md |
| boundary | whole-issue close |
| milestone | — |
| window | 82b180a5bdc9907722bad7c16f3e7ee42fb57a3d..845884bcc17313d4415e4935b8da9dc67bf786d9 |
| command | sdlc close --issue 383 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-18T06:44:42-07:00 |
| verdict | SHIP |

## Review

I've disposed most of the earlier findings. Now I'm checking BR-5 (re-attach / pending), then I'll run the round spec.

Running the round and skill_render specs, then reverting the BR-7 fix to check that the test goes red.

The `timeout` command isn't available here, so I'm running the unit suite without it.

Unit suite is green. Now reverting `skill_render.lua` to the BR-7 parent to confirm the new test fails without the fix.

```verdict
verdict: SHIP
confidence: high
```

This window holds the fix for BR-7, and it fixes the rule, not just the cited site. `replace_kind(buf, owns, diagnostics)` in `lua/parley/skill_render.lua:59-70` is now the only place that writes the `parley_skill` diagnostic namespace. All six writers go through it: footnote publish and clear, round set and clear, `attach_diagnostics`, `clear_decorations` and `apply_snapshot`. `snapshot` also leaves round diagnostics out. I grepped `lua/` and found no other writer of that namespace: `diag_display` only reads it, and `timezone_diagnostics` has its own namespace. The unit suite passes at head. I restored `skill_render.lua` from `845884bc^` and the new spec failed at `skill_render_round_spec.lua:68`. Putting the head version back made it pass again, and the checkout is clean. BR-5's fix is in the tree, but no test fails without it, so it stays not-addressed. It is Minor and doesn't block. Nothing in this window adds a Critical or Important defect, and the Spec, Revisions and Done when are unchanged apart from recording the fix.

1. **Strengths**
   - `skill_render.lua:54-70`: one helper with an ownership predicate. It replaces three copied filter loops and two wholesale `vim.diagnostic.set` calls (ARCH-DRY: pass).
   - `skill_render_round_spec.lua:61-77`: one spec runs the round through every other writer (attach, snapshot, clear_decorations, apply_snapshot, footnote publish/clear) and checks the marks too. It goes red when the fix is reverted.
   - The plan's Revisions entry (`plan.md:224`) and the atlas (`session_sync.md:331-335`) both state the rule, and they match the code.
   - `apply_snapshot` behaves as before for footnotes: it replaced everything before and it still removes everything except the round. The one change is that the round now survives.

2. **Critical findings**: none.

3. **Important findings**: none.

4. **Minor findings**
   - `skill_render.lua:82-85`: `M.dismiss = M.clear_decorations` no longer clears the agent's round. The operator now has no way to hide the agent highlights on demand; only a confirmed submit or `presentation:` set to something other than highlight removes them. The Revisions entry records this, but the comment "Dismiss the live round decorations" is now ambiguous.
   - BR-5 is still open: the `pending` reset at `edit_round.lua:121` is correct, but nothing tests it.

5. **Test coverage notes**
   - BR-7: covered by a spec that goes red without the fix (checked by revert).
   - BR-5: not covered. A spec in `edit_round_spec.lua` would pin it: schedule a re-derive, `clear` then redraw before the schedule runs, type once, and assert `M.stats.rederives` goes up after the new keystroke.
   - I ran only the unit suite. The integration suite (including `edit_round_spec`) was not run in this review.

6. **Architectural notes**
   - ARCH-DRY: pass. The duplicated filter loops are gone into `replace_kind`.
   - ARCH-PURE: pass. Only the thin vim-API rendering layer changed; ownership is a pure predicate passed to the helper.
   - ARCH-PURPOSE: pass. A shadow sweep of every writer of the namespace found all six on the helper, so the class is fixed, not just the named site. A future writer must pass `not_round` (or its own kind) to `replace_kind` and never call `vim.diagnostic.set` on this namespace directly. A lint or arch spec could enforce that later.

7. **Plan revision recommendations**: none. The Revisions entry for round 2 matches the code.

```findings
dispose:
  - id: BR-5
    disposition: not-addressed
    note: |
      Fix is present (edit_round.lua:121 resets pending with attached) and is correct by inspection, but no spec fails without it; add a clear-then-redraw-then-keystroke rederive-count spec.
  - id: BR-7
    disposition: addressed
    note: |
      All six writers go through replace_kind (skill_render.lua:59); snapshot filters the round out; skill_render_round_spec.lua:61-77 goes red at line 68 with skill_render.lua restored from 845884bc^ and green at head.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: dismiss-scope-unstated
    title: |
      The dismiss binding no longer clears the agent's round, so the operator cannot hide the highlights on demand
    detail: |
      skill_render.lua:85 aliases dismiss to clear_decorations, which now keeps the round. The plan Revisions entry says this is intended, but the doc comment still says it dismisses the live round decorations. Reword the comment, or add a separate round dismiss if hiding on demand is wanted.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"f846f7ad-d597-4a90-81d7-23f9eb9219bb","repository":"github.com/xianxu/parley.nvim","issue_id":"000383","recipe":"fix-review","round":4,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/11d8e13e5f0ce9a6","reviewed_head":"845884bcc17313d4415e4935b8da9dc67bf786d9","slot":"parley.nvim:3","requested_at":"2026-10-18T13:38:49.119147Z"},"phase":"finished","pid":96509,"started_at":"2026-10-18T13:38:49.212511Z","finished_at":"2026-10-18T13:44:41.979253Z","session_id":"2918caaa-6710-4dca-b20e-8d22c05dd6b1","outcome":"returned"}] -->
