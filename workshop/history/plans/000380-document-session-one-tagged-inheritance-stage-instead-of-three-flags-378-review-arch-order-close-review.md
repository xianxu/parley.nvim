# Boundary Review — parley.nvim#380 (whole-issue close)

| field | value |
|-------|-------|
| issue | 380 — document_session: one tagged inheritance stage instead of three flags (#378 review, ARCH-ORDER) |
| repo | parley.nvim |
| issue file | workshop/issues/000380-document-session-one-tagged-inheritance-stage-instead-of-three-flags-378-review-arch-order.md |
| boundary | whole-issue close |
| milestone | — |
| window | d293e6ec3b878a060f4d02f0c8e0c51a54d4cd8d..8bd27502d14a6af76fa54b4cfe76066c826f0da3 |
| command | sdlc close --issue 380 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T19:39:24-07:00 |
| verdict | REWORK |

## Review

Still reviewing: I'm writing a quick probe to compare retry behaviour at the base and head commits.

Now the probe spec: retry of an inherited pending register, then a refusal; plus a stray matching event during confirm_parent.

```verdict
verdict: REWORK
confidence: high
```

The change is meant to collapse the inheritance flags without changing behaviour, and most of it does. One tagged `state.inheritance` with an asserted stage set replaces the scattered `args.inherit`, `args.inherited` and `state.inherit` flags. The #378 settle table is unchanged. The new 26-row transition table is a good guard. Two problems remain, and I reproduced both with a throwaway spec run against the base and head versions of `document_session.lua`; the probe was deleted afterwards. First, behaviour drifted: an inherited register that went pending and is then retried is no longer treated as an inheritance. Second, the step that clears the stage runs too early, and that opens a nil-index crash in `confirm_parent`. Neither path has a test.

1. **Strengths**
   - `lua/parley/document_session.lua:166-170`: `inherit_as` asserts against a closed `STAGES` set, so a misspelled stage fails loudly instead of quietly reading as nil.
   - `admits` and `inheriting` (`:174-182`) now read one field instead of a four-way OR over op args and the kind.
   - `tests/unit/document_session_spec.lua:773-841`: the transition table also checks that a second inherit and a stale reply leave the stage alone, checks that no operation carries `args.inherit` or `args.inherited`, and pins the row count (26).
   - Moving `parent` into the model, instead of keeping it in op args, removes duplicated state. `confirm_parent` still emits `parent` for the shell.

2. **Critical**
   - **A retried inherited register is no longer an inheritance** (`document_session.lua:250-270` with `:440`). Steps: inherit → confirm → register → `uncertain` → pending → `retry` → reply `{kind="unavailable", code="owner-conflict"}`.
     - At base, the retried register carried `args.inherited`. So the refusal led to a fresh lookup, the phase went to `probing`, and the first owner was adopted. A press during the retry was also held (`queued = {inheriting=true}`).
     - At head, the same refusal goes back to pending (`reconcile`), and `queue_submit` is not admitted.
     - The cause: `pending()` and `retry` only carry `operation.args`, and the stage now lives outside them and is cleared at `:321`.
     - Fix: keep the stage on the pending record (for example `state.pending.inheritance`) and restore `registering` in `retry`. Then add a transition row and a settle row for pending → retry → refused or registered.
     - If dropping this is a deliberate choice, record it in the plan instead. Even then, the #378 comment "Refused or lost … a fresh lookup says what is there, and that is adopted" no longer holds for a retried register.

3. **Important**
   - **The stage is cleared on any matching event, not when the operation ends** (`:320-321`), and `confirm_parent` then reads `inheritance.parent` without a guard (`:393`).
     - Reproduced: during `confirm_parent`, a stray matching non-reply event (for example `saved` with the confirm witness) returns `{}` at `:389`, but has already cleared the stage. The real reply then crashes with `attempt to index local 'inheritance' (a nil value)`. Base read `operation.args.parent` and survived this.
     - Every place where the stage dies while its operation stays alive:
       - (a) a non-terminal matching event on lookup, `confirm_parent` or register: lookup quietly loses the hint, register loses `admits`, `confirm_parent` crashes;
       - (b) `changed` during an inherited register (`:228` clears it, `:240-244` keeps the operation);
       - (c) register → pending (`:447`), which is the Critical above.
     - The doc comment at `:156-158` says the stage is "alive exactly as long as the operation it names", which does not hold in (b) or (c).
     - Fix: clear the stage only on the paths that actually end the operation, or guard `:393`. Then fix the comment.
   - **No regression test covers pending → retry for an inheritance, or a non-terminal event mid-inheritance.** Both bugs above shipped green. Rows should go into the transition table and the settle table.

4. **Minor**
   - Two behaviour changes were made but not written up in the Log:
     - a second inherit while one is in flight is now refused, where it used to overwrite;
     - a hint during a submit lookup is no longer stashed. This one is unreachable, because submit lookups need `state.registration`.
   - `register → changed, then answered` now settles (drops) the press when the `changed` arrives, not when the reply arrives. It still passes, because the settle table counts decisions rather than which dispatch made them.

5. **Test coverage notes**
   - The new table only drives terminal replies plus `changed` and `detach`. It never enters `retry`, a non-reply matching event, or `pending` followed by a later event.
   - The Log's mutation check covers clearing on `changed`, but not the eager clear at `:321`.

6. **Architecture**
   - **ARCH-DRY: pass.** One source of truth replaces four.
   - **ARCH-PURE: pass.** All changes are in the pure model, and the tests drive it without IO.
   - **ARCH-PURPOSE: flag (folded into the Critical).** The issue's point is that the stage alone decides inheritance. But the retried register shows that stage and operation lifetimes drift apart through `pending`, so the stage is not yet the complete model of "is this an inheritance". Nothing outside the model reads the old flags; `grep` across `lua/` finds no consumers.

7. **Plan revisions**
   - If the pending/retry case is dropped deliberately, add a `## Revisions` entry saying a pending inherited register loses its inheritance on retry. Otherwise add one saying the stage survives `pending` and `retry`.
   - Correct the "alive exactly as long as the operation" claim.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: inheritance-stage-lifetime-vs-operation
    title: |
      A retried inherited register is no longer an inheritance: a refusal goes to pending and a press is not held
    detail: |
      Path: inherit, confirm, register, uncertain, pending, retry, then reply unavailable/owner-conflict. Base: lookup, probing, adopt the first owner, press held with inheriting=true. Head: reconcile, pending, queue_submit not admitted. Reproduced by running a spec against base and head. Cause: pending() and retry (document_session.lua:102-110, 250-270) carry only operation.args, and the stage is cleared at :321. Fix: keep the stage on state.pending, restore it as registering in retry, add transition and settle rows. Otherwise record the change as a deliberate Revision.
  - id: new
    severity: Important
    kind: defect
    family: inheritance-stage-lifetime-vs-operation
    title: |
      Stage cleared on any matching event, not on operation end; confirm_parent then nil-indexes inheritance.parent
    detail: |
      document_session.lua:320-321 clears state.inheritance before the kind dispatch. A matching non-terminal event returns {} at :389 with the operation still alive. A later confirm_parent reply crashes at :393 (reproduced: attempt to index local 'inheritance' (a nil value)), where base read operation.args.parent. Every case: (a) non-terminal matching event on lookup, confirm_parent or register; (b) changed during an inherited register (:228 clears, :240-244 keeps the op); (c) register going pending (:447). The comment at :156-158 ("alive exactly as long as the operation") is false for (b) and (c). Fix: clear only on paths that end the operation, or guard :393, then fix the comment.
  - id: new
    severity: Important
    kind: defect
    family: transition-table-misses-nonterminal-paths
    title: |
      No test covers pending then retry for an inheritance, or a non-terminal event mid-inheritance
    detail: |
      The 26-row table (tests/unit/document_session_spec.lua:773-841) drives only terminal replies plus changed and detach, so both lifetime bugs ship green. Add rows: registering, uncertain, retry, then refused or registered (stage and settle decision); and a stray matching event during confirming, then the real reply.
  - id: new
    severity: Minor
    kind: defect
    family: undeclared-behavior-change
    title: |
      Unlogged behaviour changes: second inherit refused instead of overwriting; changed during register drops the press earlier
    detail: |
      document_session.lua:283 now refuses an inherit while state.inheritance is set; base overwrote state.inherit. The settle row register, changed then answered now drops at the changed dispatch, not at the reply. Note both in the Log.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"01fc0a27-c082-4619-aa3f-5642eebb0dd9","repository":"github.com/xianxu/parley.nvim","issue_id":"000380","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/f1c5aaae2ad7a259","reviewed_head":"8bd27502d14a6af76fa54b4cfe76066c826f0da3","slot":"parley.nvim:4","requested_at":"2026-10-18T02:37:37.515225Z"},"phase":"finished","pid":63476,"started_at":"2026-10-18T02:37:37.667013Z","finished_at":"2026-10-18T02:39:24.573742Z","session_id":"8416932e-fde3-467f-b0fc-d4fc4f256db5","outcome":"returned"}] -->

---

## Re-review — 2026-10-17T20:05:54-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 380 — document_session: one tagged inheritance stage instead of three flags (#378 review, ARCH-ORDER) |
| repo | parley.nvim |
| issue file | workshop/issues/000380-document-session-one-tagged-inheritance-stage-instead-of-three-flags-378-review-arch-order.md |
| boundary | whole-issue close |
| milestone | — |
| window | d293e6ec3b878a060f4d02f0c8e0c51a54d4cd8d..e4fd6fb1734bcc2be5546291877c8870dbdf16a6 |
| command | sdlc close --issue 380 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T20:05:54-07:00 |
| verdict | SHIP |

## Review

Running the document_session unit tests now, then I'll revert the fix to check that the new tests catch the regression.

Both specs pass. Next I'm reverting the retry fix to confirm the tests fail without it.

```verdict
verdict: SHIP
confidence: high
```

All four findings from round 1 are fixed. The inheritance stage is no longer a separate `state.inheritance` field; it now sits on the operation record itself. That means `pending()` copies it with the operation (`document_session.lua:105`, `state.pending = copy(operation)`), retry reissues it with `previous.inheritance` (`:275`), and it ends when the operation ends. Nothing clears it on a matching event any more. I ran `document_session_spec` and `agentic_document_side_inherit_spec` on the pinned head and both pass. I then broke the fix two ways in the disposable checkout: retry dropping `previous.inheritance`, and `pending()` dropping `inheritance`. Each time, both the settle table and the transition table failed, so the new rows really test the fix. The only thing left is a Minor: the issue's Plan text still describes the design from before the rework.

1. **Strengths**
   - `issue(..., inheritance)` (`document_session.lua:77-88`) keeps the stage on the operation record and out of the effect. That covers the whole lifetime family at once, instead of patching each site.
   - The `confirm_parent` reply reads a stage that was captured once (`local inheritance = operation.inheritance`, `:324`). `confirm_parent` is only ever issued with a stage (`:432`), and it never goes pending, so the nil-index from BR-2 can't happen.
   - `inherit_as` checks the stage name against `STAGES`, so a misspelled stage fails loudly.
   - The transition table checks rejected transitions on every row: a second inherit and a stale reply must leave the stage alone. It also checks that no operation still carries the old `args.inherit` or `args.inherited`.
   - The existing settle rows are unchanged; the three `retried` rows are only appended, so "passes unchanged" holds.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - The issue's Plan checklist item 1 still says "one `state.inheritance = {stage, parent}` … cleared when that operation's matching event arrives". Item 2 still says "26 rows". The code no longer has `state.inheritance`, the stage is never cleared on a match, and the table has 29 rows. Other instances of the same problem: none in the code comments; `:73-76` and `:160-163` are accurate.

5. **Test coverage**
   - Pending then retry is now covered in both tables, including retry then refused (goes to relooking) and retry then registered.
   - A non-terminal matching event mid-inheritance is covered: a stray `saved` arrives during confirming, the stage stays, and the real reply still completes the step.
   - Both reverts above turned the tests red.

6. **Architecture**
   - **ARCH-DRY: pass.** The four signals (`state.inherit`, `args.inherit`, `args.inherited`, the `confirm_parent` kind check) are now one field read through `stage_of`. Nothing else in `lua/` read the old flags. `confirm_parent`'s `args.parent` repeats `inheritance.parent`, but the shell needs it in the effect, so that's acceptable.
   - **ARCH-PURE: pass.** All the changes are inside the pure state machine, and the tests drive it without IO.
   - **ARCH-PURPOSE: pass.** Every consumer named in the Spec now reads the stage: `admits`, `inheriting`, the settle step, the lookup-absent branch and the register-refusal branch. None of the old flags remain.

7. **Plan revisions:** update Plan item 1 so it says the stage lives on the operation record (and on `state.pending` while pending), with no `state.inheritance`. Update item 2 to "29 rows".

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      pending() copies operation incl. inheritance (:105) and retry passes previous.inheritance (:275); removing that argument fails the settle table and the transition table.
  - id: BR-2
    disposition: addressed
    note: |
      No clearing on a match any more; the stage is captured at :324 and only ends with the operation. The stray-saved-during-confirming test pins it.
  - id: BR-3
    disposition: addressed
    note: |
      New transition rows for uncertain, retried, refused and registered, the stray non-terminal event case, and three retried settle rows. Mutating pending() or retry turns both tests red.
  - id: BR-4
    disposition: addressed
    note: |
      The Log's declared behaviour changes cover both: a second inherit is refused (first hint wins), and changed during the inherited register keeps the stage.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: plan-text-stale-after-rework
    title: |
      Plan checklist still describes state.inheritance cleared on matching event, and 26 rows
    detail: |
      Plan item 1 names state.inheritance and clearing on a matching event, and item 2 says 26 rows. The code holds the stage on the operation or pending record, never clears it on a match, and the table has 29 rows. Instances: Plan item 1 and Plan item 2; the code comments are accurate.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"e45292e8-e9ee-44cb-b98e-6fa87e198333","repository":"github.com/xianxu/parley.nvim","issue_id":"000380","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/35dbf79454725fbe","reviewed_head":"e4fd6fb1734bcc2be5546291877c8870dbdf16a6","slot":"parley.nvim:4","requested_at":"2026-10-18T03:03:58.738983Z"},"phase":"finished","pid":32700,"started_at":"2026-10-18T03:03:58.936545Z","finished_at":"2026-10-18T03:05:54.192608Z","session_id":"f567fff9-53ef-44d1-85a3-c5cc63b5096d","outcome":"returned"}] -->
