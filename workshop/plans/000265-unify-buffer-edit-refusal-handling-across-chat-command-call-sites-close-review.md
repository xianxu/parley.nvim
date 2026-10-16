# Boundary Review — parley.nvim#265 (whole-issue close)

| field | value |
|-------|-------|
| issue | 265 — Unify buffer_edit refusal handling across chat command call sites |
| repo | parley.nvim |
| issue file | workshop/issues/000265-unify-buffer-edit-refusal-handling-across-chat-command-call-sites.md |
| boundary | whole-issue close |
| milestone | — |
| window | 99d396d5510868bf63e983b28d43c27b931492f9..aa4b87224ba44fa88733bebd9026194270561e84 |
| command | sdlc close --issue 265 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-16T04:29:20-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Reviewing the #265 diff: next I'm checking the refusal words, then the tests.

I'm checking whether each refusal token has its own words.

I'm running the test suite next, then checking whether the fixes revert to red.

Setting up the isolated test environment to run the specs.

Specs pass. Now I'm reverting two of the reorder fixes to confirm their tests go red.

Mutations go red as claimed. Last, I'm checking the atlas docs diff.

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

**Summary.** The main deliverable works. There is now one refusal policy, `buffer_edit.edit_user_lines`, that does not raise. All 17 audited sites go through it, and the arch spec fails if the raw replace is called directly. The five sites that could leave partial state have been reordered, and the tests behind those reorders are real. I reverted the ExchangeCut clipboard order and the ChatPrune child-before-parent order in the checkout: both cases in `user_edit_refusal_spec` failed, and passed again once restored. All 10 relevant specs pass at head: the policy arch spec, the unit spec, the refusal integration spec, new_question, entity_textobj, entity_delete_parity, comment_float, refusal_vocabulary, buffer_mutation and the refusal unit spec. The Done-when revision is backed by a recorded measurement and is honest. Two Important findings remain, both cheap. First, the private replace drops the editor's `result.error` text that the old raise carried. Second, the enforcement only checks for the name `replace_user_lines`, so commands that edit through `capture_user` + `apply_user` directly still have their own wordings, and one of them, the spell correction, still raises.

1. **Strengths**
   - `lua/parley/buffer_edit.lua:81`: the policy is a small helper that does not raise. Its words come from `refusal.edit` (`lua/parley/refusal.lua:412`), so there is no second phrasebook, as the #261 log entry asked.
   - `tests/helpers/user_edit_capacity.lua`: it triggers a real refusal through the document's own seam. It checks that the hold worked (the probe capture must return `capacity`), which replaces two doubles (in NewQuestion and DeleteEntity). This is the right fix for the "stubbed-verdict-not-seam" finding from #263.
   - The partial-state reorders (`init.lua` ExchangeCut ~4677, ChatPrune ~4527, slug rename ~3329) are each covered by a test that fails without them. I confirmed this for two of them.
   - `tests/arch/user_edit_policy_spec.lua:33`: the "at least 17 sites" check stops a broken scan from reporting a clean pass.
   - The atlas docs (`document.md`, `entity_delete.md`) now state the policy and correct the old "during generation" claim, and the new specs are added to traceability.

2. **Critical:** none.

3. **Important**
   - **The editor's error text is dropped** (`buffer_edit.lua:121`). It now returns `result.reason or result.status`, where the old code used `result.reason or result.error or result.status`.
     - When the editor returns `status='error'` (`document/editor.lua:299`: a write that mutated and then errored, which may be partial), the user sees "unexpected (error); the details are in the Parley log". Nothing writes those details to the log, and the old raise did carry them.
     - The "buffer unchanged" claim also may not hold on this path.
     - Fix sketch: return `result.error` as a third value. Pass it as `detail.notice` (via `refusal.brief`) or log it at the call site, then add a unit case for it.
   - **ARCH-PURPOSE: only one name is enforced.** The arch spec bans `replace_user_lines` but not other ways of editing the user's text, so a new command that calls `capture_user` + `apply_user` directly gets past the policy.
     - The same kind of code already exists, each site with its own wording outside `refusal.lua`:
       - "Define: edit cancelled" (`init.lua:2042`)
       - "Marker edit cancelled" (`init.lua:2241`, `:2248`)
       - "Branch: parent edit cancelled" (`init.lua:2575`)
       - "Interview timestamp unavailable" (`interview.lua:284`)
     - `spell_source.lua:63`/`:66` still raises `error(...)` on a keystroke path. `Source:execute` re-raises it, which is exactly the bare-traceback behaviour the issue sets out to remove.
     - Fix sketch: either route these sites through refusal words, or list them in the plan as stated exceptions or a follow-up issue, and widen the arch spec's wording or scope to match.

4. **Minor**
   - ChatReview gives two warnings on a refusal (the policy's line plus "back-reference not added"). The spec says one; merging them into a single message would fix it.
   - Slug rename: if the rename fails and the header-restore edit is also refused, the buffer keeps the new header while the file keeps its old name. The policy warns, but `"rename failed"` hides it.
   - ChatPrune now edits the parent before `writefile`. If `writefile` raises, the parent buffer is pruned but not saved, and only undo recovers it. This is rare, but it is the opposite risk of the old order and is not written down.
   - A `detached` refusal is silent (`LIFECYCLE.detached = false`), which is a gap against "one readable warning". It is effectively unreachable because `capture_user` re-attaches, but the atlas mentions "a closed chat" as something a user can meet.

5. **Test coverage notes.**
   - The policy unit spec covers four cases: it applies, it refuses (buffer unchanged, exactly one warning), quiet mode logs at debug only, and it works again after release.
   - The integration spec covers ExchangeCut, ChatPrune, slug rename and ChatReview under a real hold.
   - No test covers:
     - the `status='error'` apply path (finding 1);
     - DrillIn, BranchRef, ExchangePaste, ReviewSend or CommentSave refusals;
     - `move_chat_tree`'s reference rewrite. The plan says it is unreachable by a fixture, and #350 is filed for it.

6. **Architecture notes (each principle)**
   - **ARCH-DRY: pass.**
   - **ARCH-PURE: pass.** `refusal.edit` is pure, and the logging sits in the thin helper.
   - **ARCH-PURPOSE: flagged** (Important finding 2).
   - **ARCH-MOCK: pass.** Doubles were replaced by a real hold through the document seam.
   - **ARCH-CONSTRAINTS: pass / N/A.** No hot-path change; the 64-region hold is test-only.
   - **ARCH-SECURE: N/A.** No untrusted input or secrets.
   - **ARCH-ORDER: pass**, with the Minor edge cases above. The edit-then-effect ordering is now explicit and tested.
   - **ARCH-FUNERAL: pass.** Nothing durable is created, and every test releases its hold after the pcall.

7. **Plan revision recommendations**
   - Add a Revisions entry that lists the user-edit paths not covered by `edit_user_lines` (Define, Marker, Branch planned path, Interview, spell correction). For each, say whether it is an exception or a follow-up, so that "one stated policy with the exceptions named" stays true.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: refusal-drops-cause
    title: |
      _replace_user_lines drops result.error, so an editor error is reported as "unexpected (error)" with no details anywhere
    detail: |
      buffer_edit.lua:121 returns result.reason or result.status; the old raise included result.error. For status='error' (editor.lua:299, a write that mutated then errored, possibly partial) the warning points at the Parley log, but nothing writes the error text there. Fix: carry result.error through as detail.notice or log it, and add a unit case.
  - id: new
    severity: Important
    kind: defect
    family: edit-policy-enforced-by-name-only
    title: |
      The arch spec bans only replace_user_lines; direct capture_user/apply_user command sites keep their own wordings, and spell_source still raises
    detail: |
      init.lua:2042 (Define), :2241/:2248 (Marker), :2575 (Branch planned path) and interview.lua:284 each word refusals outside refusal.lua. spell_source.lua:63/:66 raise error() on a keystroke path, and Source:execute re-raises it. Route them through the policy's words, or name them in the plan as exceptions or a follow-up, and widen the arch spec to match.
  - id: new
    severity: Minor
    kind: defect
    family: one-warning-per-refusal
    title: |
      ChatReview gives two warnings on a refused back-reference
    detail: |
      edit_user_lines warns, then init.lua:4155 warns again. Pass quiet=true and send one combined message.
  - id: new
    severity: Minor
    kind: defect
    family: partial-state-on-refusal
    title: |
      Slug rename header restore and ChatPrune write-failure ordering leave edge-case partial state
    detail: |
      If the restore edit after a failed rename is refused, the new header stays while the file keeps its old name. ChatPrune now prunes the parent before writefile, so a writefile error leaves the parent pruned but unsaved.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"a1e8a057-d788-4577-bfdc-cc8186a37e4b","repository":"github.com/xianxu/parley.nvim","issue_id":"000265","recipe":"milestone-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/190e3beb23d42074","reviewed_head":"aa4b87224ba44fa88733bebd9026194270561e84","slot":"parley.nvim:4","requested_at":"2026-10-16T11:24:28.8718Z"},"phase":"finished","pid":2065,"started_at":"2026-10-16T11:24:29.084713Z","finished_at":"2026-10-16T11:29:20.028412Z","session_id":"57a4984c-d787-4343-a5a7-bdfe2b1ca9e5","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T04:46:01-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 265 — Unify buffer_edit refusal handling across chat command call sites |
| repo | parley.nvim |
| issue file | workshop/issues/000265-unify-buffer-edit-refusal-handling-across-chat-command-call-sites.md |
| boundary | whole-issue close |
| milestone | — |
| window | 99d396d5510868bf63e983b28d43c27b931492f9..b7bcc8ee649f2002e7543c76bc4e09cf3dfe5448 |
| command | sdlc close --issue 265 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-16T04:46:01-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Checking test runner and the editor's error status, then running the specs for this diff.

No `timeout` binary on macOS; re-running the specs without it.

Mutation result: dropping the editor-error passthrough in `_replace_user_lines` turns no test red. Checking whether a real non-modifiable buffer would produce `status='error'` cheaply.

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The design holds. There is now one non-raising entry point, `buffer_edit.edit_user_lines`, and one place that words a refusal, `report_refusal` → `refusal.edit`. All 17 replace sites and the keystroke commands that capture by hand go through it. The capacity helper produces a real refusal through the document's own capture API, not a double. All 11 specs I ran pass on the pinned head: unit, arch and integration for user-edit, new_question, entity_delete_parity, entity_textobj, spell_source, comment_float, refusal_vocabulary, refusal and buffer_mutation. Two things keep this from SHIP:

- **BR-1 has no regression test at the line it fixed.** I removed `result.error` from `_replace_user_lines`'s return (`buffer_edit.lua:134`). Every spec stayed green, because the new unit case swaps out that very function.
- **ChatPrune's new rollback only works against the test's fake.** It checks `vim.fn.writefile(...) ~= 0`, but in Neovim a real write failure raises E482 instead of returning -1. I confirmed this for both a missing directory and permission denied. The edit-first reorder therefore adds a new partial state: the parent is pruned, there is no child file, and the user gets a raw Lua error. The only test passes because its fake `writefile` returns -1, which the real one never does.

Done-when: stale. Bullet 3 still asks for a helper that puts a chat buffer under a live generation, which `## Revisions` showed to be impossible; the capacity helper replaced it. Bullet 1 covers only `replace_user_lines` refusals, but the close round also brought the hand-capture keystroke commands under the policy.

**1. Strengths**
- `lua/parley/buffer_edit.lua:81-103`: one small, non-raising API that names the command. `report_refusal` is the single wording point, and it reuses `refusal.describe` instead of keeping its own phrasebook. This is what the #261 M5 log asked for.
- `tests/helpers/user_edit_capacity.lua`: a real refusal through the document's own API. It also checks itself: the probe asserts the next capture is refused with `capacity`.
- `tests/arch/user_edit_policy_spec.lua:42-96`: every file that calls capture/apply directly is listed with a reason, checked both ways (an unlisted caller fails, and so does a listed file that no longer calls), and the hand-wording check is tested against itself.
- The partial-state reorders are correct for refusals: ExchangeCut sets the clipboard only after the cut, slug rename edits the header first, ChatPrune edits the parent first. The integration cases check what the user would see (a paste doesn't duplicate, no orphan child file).
- `move_chat_tree` collects refused rewrites like `asset_errors` instead of stopping halfway through the loop (`init.lua:3958-3963`).

**2. Critical findings**
None.

**3. Important findings**
- **BR-1, not addressed** (`buffer_edit.lua:134`, `tests/unit/user_buffer_edit_spec.lua:76-86`):
  - The unit test swaps out `Edit._replace_user_lines`, so the passthrough it is meant to protect is never run.
  - A real oracle is cheap: set `vim.bo[buf].modifiable = false` on an attached buffer. My probe got `_replace_user_lines` → `nil, "error", "…editor.lua:268: Buffer is not 'modifiable'"` back through the real apply path.
  - Test `edit_user_lines` against that buffer and assert the warning contains `Buffer is not 'modifiable'`.
- **New: ChatPrune's test fakes a write failure in a way production never fails** (`tests/integration/user_edit_refusal_spec.lua:109-123`, `init.lua:4548`):
  - ARCH-MOCK: the fake `writefile` returns -1, but the real function raises.
  - Fix: call `pcall(vim.fn.writefile, …)` and treat both a raise and a non-zero return as failure, then roll back.
  - Rewrite the test to fail the real way: make the target directory read-only, or have the fake `error("Vim:E482…")`.
- **New: Done-when is stale** (issue `## Done when`).
  - Rewrite bullet 3 to match the revision: "a shared helper puts a chat buffer under a real `capacity` refusal".
  - Bullet 4 can stay as is.
  - Widen bullet 1 to cover the keystroke commands that capture by hand (Define, Marker, Branch, PruneTopic, InsertChatReference, InterviewTimestamp, SpellCorrection, PasteImage).
  - State the empty list of sites that deliberately raise.

**4. Minor findings**
- ARCH-DRY: `report_refusal(cmd, x.reason or x.status, x.error)` appears 8 times across init.lua, interview, spell_source and chat_finder. A `report_result(command, result)` helper would make it one fact.
- `init.lua` repeats `require("parley.buffer_edit")` inline about 15 times, even inside functions that already have a local `edits`/`buffer_edit` binding (Branch, PruneTopic).
- `init.lua:4601`: the child-topic `apply_user` result in PruneTopic is still thrown away. It is asynchronous and cosmetic, so being silent is defensible, but the arch spec doesn't name it as an exception.
- The slug-rename "header not restored" warning (`init.lua:3352`) has no test. That is acceptable at Minor.

**5. Test coverage notes**
- The refusal paths are covered with a real `capacity` refusal. Each partial-state site has an integration case except `move_chat_tree`, which can't be reached (filed as #350).
- The editor-`error` status is covered only through a swapped-out function (BR-1).
- ChatPrune's write failure is covered only through a fake that behaves unlike the real function (new finding).
- The arch hand-wording check works on patterns. It would miss `warning("X: " .. tostring(result.status))`. That is acceptable as a backstop.

**6. Architectural notes**
- **ARCH-DRY:** pass, apart from the Minor `report_result` point.
- **ARCH-PURE:** pass. `refusal.edit` is pure, and the IO stays at the command sites.
- **ARCH-PURPOSE:** pass. A shadow sweep of every direct capture/apply caller found each one either routed through the policy or named with a reason.
- **ARCH-MOCK:** flag (ChatPrune's write fake). The capacity helper is a good example of testing through the real seam.
- **ARCH-CONSTRAINTS:** N/A. No hot path changed; the 64-slot hold exists only in tests.
- **ARCH-SECURE:** pass. The editor's error text is cut to 512 characters by `refusal.brief`, and no credentials are involved.
- **ARCH-ORDER:** flag. The edit-first orderings didn't plan for the follow-on IO raising; ChatPrune is the case (BR-4, new finding).
- **ARCH-FUNERAL:** pass. The change creates nothing that persists; test holds are released before assertions.
- The general rule for future "edit first, then IO" commands: the follow-on IO has to be caught whether it raises or returns an error, and its test has to fail the way the real dependency fails.

**7. Plan revision recommendations**
- In `## Revisions`, record Done-when bullets 1 and 3 as rewritten in place, so they stop asking for a live-generation helper.
- Record that ChatPrune's rollback covers both a raised and a returned write failure, once that is fixed.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      The words path is fixed, but no test protects the passthrough at buffer_edit.lua:134. Removing result.error there leaves every spec green, because the unit case swaps out _replace_user_lines. A modifiable=false buffer is a real oracle: probed, it returns 'error' with "Buffer is not 'modifiable'".
  - id: BR-2
    disposition: addressed
    note: |
      Define, Marker, Branch, PruneTopic, InsertChatReference, InterviewTimestamp, SpellCorrection and PasteImage now report through report_refusal or refusal.edit, and spell_source no longer raises. The arch spec lists every direct caller (checked both ways) and rejects hand-worded refusals in the keystroke files. It passes on the head.
  - id: BR-3
    disposition: addressed
    note: |
      ChatReview makes a quiet edit and gives one combined warning. user_edit_refusal_spec.lua:104 asserts exactly one warning.
  - id: BR-4
    disposition: not-addressed
    note: |
      The slug half is done: a failed header restore is now reported. The ChatPrune half is not: the rollback checks writefile ~= 0, but a real Neovim write failure raises E482 (probed), so the rollback never runs. The edit-first reorder now leaves the parent pruned, no child file, and a raw error. Catch the raise as well.
findings:
  - id: new
    severity: Important
    kind: defect
    family: partial-state-on-refusal
    title: |
      ChatPrune's write-failure test fakes writefile returning -1, which the real function never does, so the broken production path passes
    detail: |
      This is the 2nd finding in family partial-state-on-refusal. The rule: a command that edits first and then does fallible IO must treat a raise and an error return from that IO as the same failure and roll back, and its test must fail the IO the way the real dependency does (ARCH-MOCK). Here the fake at user_edit_refusal_spec.lua:113 returns -1, but real vim.fn.writefile raises Vim:E482 (probed for a missing directory and permission denied), so init.lua:4548's rollback never runs in production. Fix: pcall the write, and have the test raise E482 or use a read-only directory. Sweep: of this diff's edit-first sites, only ChatPrune's write can raise. Slug rename's vim.fn.rename returns a status, and ExchangeCut's setreg comes after the edit and changes no file.
  - id: new
    severity: Important
    kind: defect
    family: done-when-tracks-revisions
    title: |
      Done-when bullets 1 and 3 no longer describe what was built after the Revisions entry
    detail: |
      Bullet 3 still asks for a helper that puts a buffer under a live generation; the Revisions entry measured that as impossible and replaced it with the capacity helper. Bullet 1 covers only replace_user_lines refusals, but close round 1 also brought the hand-capture keystroke commands under the policy. Rewrite both bullets in place and state the empty list of sites that deliberately raise.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"4ec49ada-2203-4ed2-8bcd-88a5cee637da","repository":"github.com/xianxu/parley.nvim","issue_id":"000265","recipe":"milestone-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/4524b214f87b624c","reviewed_head":"b7bcc8ee649f2002e7543c76bc4e09cf3dfe5448","slot":"parley.nvim:4","requested_at":"2026-10-16T11:41:57.60677Z"},"phase":"finished","pid":32131,"started_at":"2026-10-16T11:41:57.79695Z","finished_at":"2026-10-16T11:46:00.518111Z","session_id":"acf3963f-32b8-483d-ae22-671db538f6ad","outcome":"returned"}] -->
