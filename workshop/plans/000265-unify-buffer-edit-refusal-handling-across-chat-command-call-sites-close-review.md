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
