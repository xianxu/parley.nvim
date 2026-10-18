# Boundary Review — parley.nvim#378 (whole-issue close)

| field | value |
|-------|-------|
| issue | 378 — Side documents inherit parent ownership |
| repo | parley.nvim |
| issue file | workshop/issues/000378-side-doc-parent-owner.md |
| boundary | whole-issue close |
| milestone | — |
| window | e37e950a9e8697dfae7b3087e97b713844852804..213d9d26757a1c0ff7a4ed6fab24dd9923373af3 |
| command | sdlc close --issue 378 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T15:19:43-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Reviewing the registry timeout path and the tests, then I'll write up the verdict.

Running the specs; the output came back empty, so I'm checking why.

Both specs pass at head. Now writing a quick scratch spec to confirm a suspected queued-submit bug.

Writing the scratch repro spec (stale parent + Alt+Return during the inherit lookup).

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The design holds up. The ownership rule is in the pure `document_session` model. The shell only reads the parent identity from the cached buffer and checks the side folder. Couch re-confirms both the absent child and the parent's registration before anything is registered, and the pane's actor is never read. Both target specs pass at head (`document_session_spec`, `agentic_document_side_inherit_spec`). I reproduced one real bug with a scratch spec through the real opener, since removed. If Alt+Return is pressed while the inherit lookup is still in flight and the parent confirmation then refuses, the press is silently dropped. The side doc also stays stuck in a "move busy" state. The cause is that the new `confirm_parent` executor copies the lookup callback but leaves out its queued-submit handling. There are also two smaller gaps: no test for a parent with no identity, and the atlas claims a band message that some refusal paths never show.

1. **Strengths**
   - The pure model owns the rule (`lua/parley/document_session.lua:218-233`, `:327-337`), so the unit tests are plain event sequences with no IO.
   - The side-folder rule reuses `document_move_plan.side_path` instead of restating it (`lua/parley/agentic_document.lua:496`). That passes ARCH-DRY for the scope rule.
   - The parent's identity comes from Couch, not the buffer cache. It is checked against path, ID and Owner (`document_session.lua:329-330`), and the tests cover each mismatch (`tests/unit/document_session_spec.lua` "refuses a stale…").
   - The integration spec drives the real `<M-o>` mapping with `setup_buf_handler` and the persistent fake registry. The Log shows mutation checks proving the spec depends on the opener call.
   - A hint that arrives during the attach lookup is kept in `state.inherit` and cleared on `changed`/`detach`, so a late reply can't use it.

2. **Critical findings:** none.

3. **Important findings**
   - **A queued Alt+Return is dropped and the doc gets stuck as move-busy when the parent confirmation refuses** (`lua/parley/agentic_document.lua:301-308`).
     - `M.submit` sets `s.queued_submit` while the inherit lookup is probing (`:540-541`).
     - The lookup reply then issues `confirm_parent`, so the lookup callback's flush (`:296`) sees an operation in flight and skips.
     - The `confirm_parent` callback never flushes, so after a refusal the flag stays set for good.
     - Reproduced: parent forgotten in the registry, lookup delayed 0.4 s, `follow(2)` then `document.submit(child)`. Result: phase `plain`, sends 0, child absent. `move_membership(side)` then returns "finish the pending document operation before moving" (`migration_busy` → `queued_submit`, `:588`).
     - Fix: send `confirm_parent` through the same lookup/register executor branch (args `{ effect.parent.path }`), keeping only the `cache(...)` absent-write lookup-only. Then the shared tail (queued flush, `ensure_retry`) runs for all three. Add an integration case like the repro.
     - Family members in this window: the one copy-pasted `confirm_parent` callback. ARCH-DRY.
   - **The "missing parent identity" part of Done-when has no test.** Done-when says tests cover the refusal for "missing, stale or unavailable" identity. Stale is unit-tested and unavailable is integration-tested. Nothing covers an unregistered parent (`M.inherit` returning false at `agentic_document.lua:493`), and no Alt+o test starts from a parent with no registration. Add an integration case: parent not registered, Alt+o to a side child, child absent and sends 0.

4. **Minor findings**
   - The atlas sentence "Anything unconfirmed registers nothing and shows `not inherited: …`" (`atlas/modes/session_sync.md:228-229`) is wrong in two places:
     - When the child lookup is unavailable, the band is "Couch unavailable: agentic state unknown" (`document_session.lua:372`).
     - When a refused inherited register is followed by an absent lookup, the band is empty (`:374-377` → `:367-368`).
     - The plan also said the malformed integration case would assert the band, and it doesn't. Either reword the atlas line or route these paths to `NOT_INHERITED`.
   - The refusal branch (`document_session.lua:374`) handles every `unavailable` register result, not just `owner-conflict`. That includes the registry deadline ("mutation outcome may be unknown"). The follow-up lookup reveals the truth, so this is safe, but the comment and the plan describe it as "owner-conflict" only.
   - `confirm_parent` uses `agentic_submit_timeout_ms` for a background lookup. That matches the existing lookup path, so it's only a note.

5. **Test coverage notes**
   - The unit tests cover the plan's seven listed sequences.
   - The integration tests cover inherit, existing registration, non-side links, and unavailable followed by recovery.
   - Gaps:
     - No test for a parent with no identity.
     - No test for a submit queued across `confirm_parent` (the bug above).
     - A stale parent is only unit-tested; no integration case refuses at the parent step, because malformed mode fails the child lookup first.

6. **Architectural notes**
   - **ARCH-DRY: flag.** The `confirm_parent` executor duplicates the lookup executor and drops its tail, which is exactly the bug above. The scope rule passes: it reuses `side_path`.
   - **ARCH-PURE: pass.** The decision logic is pure and tested without IO. The shell only gathers identity and checks the path.
   - **ARCH-PURPOSE: pass.** The real opener path is wired. Inheritance is limited to side docs, existing registrations are kept, and refusals register nothing. The open frontmatter question was answered (folder membership only) and implemented that way.

7. **Plan revision recommendations**
   - In `## Revisions`, note that an inherited register refusal adopts on any `unavailable` reply, not just `owner-conflict`, and that the follow-up lookup makes this safe.
   - If the atlas or code isn't aligned, add a revision listing which refusal paths show which band.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: effect-executor-shared-tail
    title: |
      confirm_parent executor skips the queued-submit flush: Alt+Return is dropped and the side doc stays move-busy
    detail: |
      agentic_document.lua:301-308 copies the lookup callback but drops its tail (queued_submit flush at :296, ensure_retry). If Alt+Return is pressed during the inherit lookup (queued_submit set at :540-541) and confirm_parent then refuses, nothing is sent or registered and queued_submit stays true. Reproduced through the real opener with a forgotten parent and 0.4 s lookup delay: phase plain, sends 0, child absent, move_membership(side) refused with "finish the pending document operation before moving". Fix: route confirm_parent through the shared lookup/register executor branch (args { effect.parent.path }, cache write lookup-only) and add an integration case. Family in window: this one duplicated callback (ARCH-DRY).
  - id: new
    severity: Important
    kind: defect
    family: done-when-state-coverage
    title: |
      Missing parent identity refusal from the Done-when clause has no test
    detail: |
      Done-when requires tests for missing, stale and unavailable identity. Stale is unit-tested and unavailable is integration-tested, but nothing covers an unregistered parent (agentic_document.lua:493 returns false). Add an integration case: parent with no registration, Alt+o to parent.side/child.md, child stays absent and sends stay 0.
  - id: new
    severity: Minor
    kind: defect
    family: doc-claim-unverified
    title: |
      Atlas says every unconfirmed inherit shows the not-inherited band, but two paths show other bands
    detail: |
      atlas/modes/session_sync.md:228-229. An unavailable child lookup shows "Couch unavailable: agentic state unknown" (document_session.lua:372). A refused inherited register followed by an absent lookup shows an empty band (:374-377 then :367-368). The plan's malformed integration case was meant to assert the band and does not. Reword the atlas or route these paths to NOT_INHERITED.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"5b047517-8f9e-495a-8b23-81f666b90435","repository":"github.com/xianxu/parley.nvim","issue_id":"000378","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/b7b4b935a6c17475","reviewed_head":"213d9d26757a1c0ff7a4ed6fab24dd9923373af3","slot":"parley.nvim:4","requested_at":"2026-10-17T22:16:18.626419Z"},"phase":"finished","pid":50918,"started_at":"2026-10-17T22:16:18.727755Z","finished_at":"2026-10-17T22:19:42.673855Z","session_id":"9366349a-6649-4736-a7ca-2b08caaea425","outcome":"returned"}] -->

---

## Re-review — 2026-10-17T15:46:57-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 378 — Side documents inherit parent ownership |
| repo | parley.nvim |
| issue file | workshop/issues/000378-side-doc-parent-owner.md |
| boundary | whole-issue close |
| milestone | — |
| window | e37e950a9e8697dfae7b3087e97b713844852804..45c6e06bbdf9cdd62699691fce3ef8fd6d1789ba |
| command | sdlc close --issue 378 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T15:46:57-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Verifying the round-1 fixes now; next I'll run the integration spec.

Running the integration spec through the harness (temporarily mapping it in the disposable checkout).

All 7 pass. Now a revert check for BR-1 plus a probe for a stale parent with a queued press.

Probe confirms a new issue: with a stale or unavailable parent, a queued press registers and sends to the pane actor. Now the BR-1 revert check.

BR-1's regression test goes red when the fix is reverted. Running the unit spec next.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

All three round-1 findings are fixed, but routing `confirm_parent` through the shared executor tail created a new problem. All 7 integration cases and the 45 `document_session` unit cases pass under the harness. Reverting the BR-1 executor change makes the "parent can no longer be confirmed" case fail, so that regression test does its job. The new problem: a press made while inheritance is still running now gets submitted even when the parent check refuses. With a **stale** or **unavailable** parent, that press registers the side doc to the pane's actor and sends to it. I reproduced both through the real opener. This is the original bug the issue set out to close, and the Done-when says stale or unavailable identity "cannot silently guess ownership". It's cheap to fix and should be fixed before close.

1. **Strengths**
   - `confirm_parent` now goes through the single lookup/register executor (`lua/parley/agentic_document.lua:285-304`). The child-only `cache(s, nil, true)` write stays limited to `kind == "lookup"`, so a missing parent never caches the child as absent.
   - The queue condition in `M.submit` (`agentic_document.lua:536-541`) covers every step of inheritance: the attach lookup, `confirm_parent`, the inherited register, and the re-lookup after a refusal.
   - The unregistered-parent integration case pins the `not parent` guard in `M.inherit`. Without it, `parent.File` would throw inside the Alt+o callback.
   - The integration tests go through the real opener: the `setup_buf_handler` BufEnter path, the real Alt+o mapping and the persistent fake registry.

2. **Critical:** none.

3. **Important**
   - **A press queued during inheritance submits to the pane actor after the parent check refuses** (`agentic_document.lua:298-301` together with `document_session.lua:346-347`).
     - When `confirm_parent` fails (stale ID or owner, unavailable, or absent), the model goes to `plain` with the not-inherited band. The shared tail then flushes `queued_submit`, and `M.submit` resolves the pane actor through `own_slot`, registers, and sends.
     - Probe, with a 0.4 s lookup delay and the real opener:
       - **Stale case:** the parent was re-registered to `ops:9` while its buffer still showed `ops:0`. One press gave `sends=1` and child owner `parley.nvim:1`.
       - **Unavailable case:** Couch was malformed at the parent check, then healthy again. The result was `sends=1` and owner `parley.nvim:1`.
     - The not-inherited band ("navigate again to retry") is overwritten by "submitted to parley.nvim:1".
     - Fix:
       - On a refused `confirm_parent` that was stale or unavailable, drop `queued_submit` instead of flushing it, and let the band ask the operator to navigate again.
       - Decide on purpose whether an *absent* parent (the existing "forgotten" case) may fall back to the pane actor. That matches the unregistered-parent rule.
       - The cleanest way is for the model to return the decision, e.g. a `drop_queued` effect or a flag on the reply. The shell's tail would then stop inferring it from `operation == nil` (ARCH-PURE).
     - Tests:
       - Add integration cases for a stale parent plus a press and an unavailable parent plus a press. Both should assert 0 sends and no registration.
       - Update the atlas line "waits for it, then submits once" to say what happens after a refusal.
     - All instances of this class in the window:
       - the `confirm_parent` refusal branch at `document_session.lua:346-347`;
       - the re-lookup after a refused inherited register (`:376-379`). It is *not* exposed: the absent/plain fallback there is already what an explicit submit on an unregistered doc does.

4. **Minor**
   - `tests/integration/agentic_document_side_inherit_spec.lua` is not listed under `modes/session_sync` in `atlas/traceability.yaml:803-822`, so `make test-spec SPEC=modes/session_sync` skips it. Its sibling specs `agentic_document_owned_move_spec` and `agentic_document_lifetime_spec` are listed. `make test-integration` still runs it through the glob.

5. **Test coverage**
   - The Done-when "missing / stale / unavailable" refusal is covered for a plain navigation.
   - It is not covered when a press is queued. That is exactly where the defect above lives.
   - The "parent can no longer be confirmed" integration case currently *asserts* the pane-actor fallback for an absent parent. Keep it only if that fallback is the chosen rule for absent parents.

6. **Architecture**
   - **ARCH-DRY: pass.** The duplicated callback is gone and there is one executor.
   - **ARCH-PURE: flag (folded into the Important finding).** Whether a queued press survives a refusal is business logic. Right now the IO shell decides it from `operation == nil`, not the pure model.
   - **ARCH-PURPOSE: flag (same finding).** The issue exists to stop a submit from picking the pane actor for a side doc of a registered parent. The queued-press path brings that back for stale and unavailable parents.

7. **Plan revisions**
   - Add a `## Revisions` entry stating the rule for a press queued during inheritance: it is dropped on a stale or unavailable refusal, and the chosen behaviour for an absent parent should be written down. Add the two integration cases to the Tests list.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      confirm_parent now uses the shared executor tail; reverting agentic_document.lua to 213d9d26's separate branch makes the "parent can no longer be confirmed" integration case fail (6/7), so the regression test is live.
  - id: BR-2
    disposition: addressed
    note: |
      The integration case "offers nothing to inherit from a parent with no registration" asserts the child stays absent with 0 sends; without the not-parent guard, parent.File would throw in the Alt+o callback.
  - id: BR-3
    disposition: addressed
    note: |
      atlas/modes/session_sync.md:228-233 now names the NOT_INHERITED band for an unconfirmed parent and the Couch unavailable band for an unanswered child lookup, and drops the false "every" claim; the adoption comment at document_session.lua:375-376 matches the code.
findings:
  - id: new
    severity: Important
    kind: defect
    family: effect-executor-shared-tail
    title: |
      A press queued during inheritance submits to the pane actor after a stale or unavailable parent refusal
    detail: |
      This is the 2nd finding in family effect-executor-shared-tail. Rule: the shared executor tail must flush a queued press only when the model says the operation that admitted it still authorizes it; it must not infer that from operation == nil. Today a confirm_parent refusal (document_session.lua:346-347) leaves no operation, so the tail (agentic_document.lua:298-301) calls M.submit, own_slot resolves parley.nvim:1, and the doc registers and sends there. Probe through the real opener: a stale parent (re-registered to ops:9 while the buffer showed ops:0) gave sends=1 to parley.nvim:1, and an unavailable parent check gave the same. That violates the Done-when rule that stale or unavailable identity cannot silently guess ownership (ARCH-PURPOSE, ARCH-PURE). Fix: have the model emit a decision such as drop_queued on stale or unavailable refusals (and decide the absent-parent case on purpose), then add integration cases asserting 0 sends and no registration. Instances in the window: the confirm_parent refusal branch, which is exposed; and the re-lookup after a refused inherited register (document_session.lua:376-379), which is not exposed because its absent fallback is the ordinary unregistered submit.
  - id: new
    severity: Minor
    kind: defect
    family: traceability-mapping
    title: |
      The new side-inherit integration spec is not mapped in atlas/traceability.yaml
    detail: |
      tests/integration/agentic_document_side_inherit_spec.lua is missing from the modes/session_sync tests list (atlas/traceability.yaml:803-822), so make test-spec SPEC=modes/session_sync skips it. Its sibling specs agentic_document_owned_move_spec and agentic_document_lifetime_spec are listed. This is the only instance in the window.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"cb08d1bd-e305-4776-b4c4-4e7618afd6c2","repository":"github.com/xianxu/parley.nvim","issue_id":"000378","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/2a5f7833ed0ae6c5","reviewed_head":"45c6e06bbdf9cdd62699691fce3ef8fd6d1789ba","slot":"parley.nvim:4","requested_at":"2026-10-17T22:42:55.511849Z"},"phase":"finished","pid":38869,"started_at":"2026-10-17T22:42:55.606101Z","finished_at":"2026-10-17T22:46:55.702904Z","session_id":"eb3fc06a-6ab4-4b87-a2e8-391eb1d68a3c","outcome":"returned"}] -->

---

## Re-review — 2026-10-17T16:22:05-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 378 — Side documents inherit parent ownership |
| repo | parley.nvim |
| issue file | workshop/issues/000378-side-doc-parent-owner.md |
| boundary | whole-issue close |
| milestone | — |
| window | e37e950a9e8697dfae7b3087e97b713844852804..d5fe338844805de44ca981df5df6f3cee2092e1b |
| command | sdlc close --issue 378 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T16:22:05-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Checking one remaining path in the model: a witness that goes stale while inheritance is in flight.

Now running the targeted specs, and confirming the stale-witness path in the pure model.

Running the session_sync spec suite through make (it also covers the BR-5 mapping check).

All green. Next, a mutation check: I'll remove the shell's `drop_queued` handler and confirm the BR-4 regression tests fail.

Mutation confirmed (both BR-4 cases fail with "submitted to parley.nvim:1" without the fix). Now probing the cancel path in the pure model.

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

Both open findings are fixed. For BR-4, the pure model now emits `drop_queued` on every inheritance *reply* that ends without a registration, and the shell clears the queued press when it sees that effect. I checked this with a mutation test: with the shell's `drop_queued` handler removed, both new integration cases fail with `submitted to parley.nvim:1`. With it restored, `make test-spec SPEC=modes/session_sync` passes in full; side_inherit has 8 tests and document_session has 46. For BR-5, the new spec is now in the session_sync mapping, and `spec_test_map.sh list-tests` returns it.

One gap remains, in the same family as BR-4. Inheritance has a second way to end, and the rule doesn't cover it. A `changed` event (the buffer reloads with different content) while `confirm_parent` or the inheriting lookup is in flight cancels the operation. That path emits only `cancel`, so `queued_submit` stays set. The shell tail then still decides whether to flush based on `operation == nil`. It is a narrow window and it doesn't block the gate, but it is the third finding in this family, so the fix should cover the whole rule, not just this path.

Done-when: current. The rule that "missing, stale or unavailable identity cannot silently guess ownership" already covers the new `drop_queued` decision. The Revisions entry only sharpens how that rule is met; it adds no new surface.

**1. Strengths**
- `document_session.lua:351` computes `inheriting` once and drives all three ending branches from it (refused parent, absent after a refused register, child lookup unavailable). The decision now sits in the pure model, as BR-4 asked (ARCH-PURE).
- The unit test at `tests/unit/document_session_spec.lua:685-697` checks both sides of the rule: inheritance endings drop the press, and ordinary lookups never do.
- `agentic_document_side_inherit_spec.lua:171-185` checks for a late arrival (`vim.wait(600)`), 0 sends, no registration, a lookup that stays absent, and the band. Mutation shows these assertions fail without the fix.
- A table-driven unit case at `document_session_spec.lua:651-664` covers all five refusal answers, each followed by a successful navigation. That meets the Done-when clause for both refusal and later success.

**2. Critical findings**
None.

**3. Important findings**
- **The `changed` path ends inheritance without `drop_queued`** (`document_session.lua:168-191`, `agentic_document.lua:300-303`). **This is the 3rd finding in family `effect-executor-shared-tail`.**
  - **Reproduction (pure model, via `nvim -l`):** run inherit, then the child lookup returns absent, giving `confirm_parent`. Then `changed` returns only `cancel`, with phase `unknown` and no operation. A later `open` returns absent and shows the plain band.
  - **Shell impact:** `cancel` aborts the request, so its tail never runs and `queued_submit` stays true. That has three consequences:
    - `migration_busy` stays true.
    - The next lookup that finishes (the retry loop or a recheck) reaches the tail at `:300`, sees no operation, and calls `M.submit`. That goes to `own_slot`, so the press is sent to the pane's actor.
    - A deliberate press in between submits immediately and leaves the queue armed, so a second send can follow.
  - **Trigger:** BufReadPost or FileChangedShellPost with changed content during inheritance (`agentic_document.lua:455`).
  - **Rule:** the shell must flush a queued press only on an explicit model effect that authorizes it (for example `flush_queued`, emitted where an inheritance or attach lookup ends in a registration or an ordinary plain result). It must never infer authorization from `operation == nil`. Equivalently, the queue flag moves into the model, so that every transition ending an admitting operation decides its fate, including `changed`/cancel, the stale-witness branch at `:282-288`, and `detach`.
  - **Every place that can end an admitting operation:**
    1. `confirm_parent` reply: covered.
    2. Inheriting lookup reply, absent or unavailable: covered.
    3. Inherited register refused, then re-lookup absent: covered.
    4. `changed` cancelling `lookup` or `confirm_parent`: **not covered**.
    5. A witness that goes stale (`live` false) on `lookup` or `confirm_parent` at `:286-288`: **not covered**. It returns `{}`, and the tail then flushes.
    6. An inherited register that goes to `pending`: this flushes into a `retry` resubmit to the inherited owner, which is arguably still authorized, but the decision should be made explicitly.
  - **Atlas:** the claim at `atlas/modes/session_sync.md:232` that "anything else drops the press" is wrong for cases 4 and 5.
  - **Tests to add:** unit cases for 4 and 5 that assert `drop_queued` (or the absence of `flush_queued`), plus one integration case that triggers FileChangedShellPost during inheritance and asserts 0 sends.

**4. Minor findings**
None new.

**5. Test coverage notes**
- The integration suite covers a forgotten parent and a re-owned parent. The unavailable-parent case is covered only at unit level, which is acceptable because the shell handles the same effect.
- I reproduced the cancel path at the model level only. I did not run an integration test for it.

**6. Architectural notes**
- **ARCH-DRY: pass.** `confirm_parent` reuses the one executor tail, and `NOT_INHERITED` has a single definition.
- **ARCH-PURE: flag.** Who may flush the queue is still decided partly in the shell (`agentic_document.lua:300`), which is the Important finding above.
- **ARCH-PURPOSE: flag.** The same finding applies: the rule is enforced for reply endings but not for cancel or stale-witness endings.

**7. Plan revision recommendations**
- Add a `## Revisions` entry. It should restate the rule as "the queued press is flushed only by an explicit model decision" and list the cancel and stale-witness endings among the cases that drop the press.

```findings
dispose:
  - id: BR-4
    disposition: addressed
    note: |
      Model emits drop_queued on confirm_parent refusal, inheriting lookup absent/unavailable; mutation removing the shell handler fails both new integration cases with sends=1 to parley.nvim:1.
  - id: BR-5
    disposition: addressed
    note: |
      atlas/traceability.yaml:816 lists the spec; spec_test_map list-tests modes/session_sync returns it and test-spec ran it (8 pass).
findings:
  - id: new
    severity: Important
    kind: defect
    family: effect-executor-shared-tail
    title: |
      Inheritance cancelled by a changed event (or a stale witness) never drops the queued press; a later lookup tail re-aims it at the pane actor
    detail: |
      3rd finding in this family. Rule to fix: the shell flushes a queued press only on an explicit model effect authorizing it (e.g. flush_queued), never by inferring from operation == nil; or move the queue flag into the model so every transition that ends an admitting operation decides it. Probe (pure model): inherit, then lookup absent, then confirm_parent; then changed returns only cancel, phase unknown, no drop_queued (document_session.lua:168-191). The shell cancels the request, so the tail never runs and queued_submit stays true: migration_busy is stuck, and the next lookup completion flushes via agentic_document.lua:300-303 to M.submit and own_slot (pane actor); a deliberate press in between leaves the queue armed, so a second send can follow. Trigger: BufReadPost/FileChangedShellPost with changed content during inheritance (agentic_document.lua:455). Enumerated endings: (1) confirm_parent reply, covered; (2) inheriting lookup absent/unavailable, covered; (3) refused inherited register then re-lookup absent, covered; (4) changed cancelling lookup/confirm_parent, NOT covered; (5) stale witness on lookup/confirm_parent at document_session.lua:286-288 returns an empty list and the tail flushes, NOT covered; (6) inherited register going to pending flushes into a retry resubmit to the inherited owner, which should be decided explicitly. The atlas claim that anything else drops the press (session_sync.md:232) is false for cases 4 and 5. Add unit cases for 4 and 5 and one integration case (file reload during inheritance, assert 0 sends).
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"fb2c200a-b303-45f0-bbb3-1bf281292577","repository":"github.com/xianxu/parley.nvim","issue_id":"000378","recipe":"small-diff-review","round":3,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/e73b8a933dc21ef1","reviewed_head":"d5fe338844805de44ca981df5df6f3cee2092e1b","slot":"parley.nvim:4","requested_at":"2026-10-17T23:16:07.491955Z"},"phase":"finished","pid":56231,"started_at":"2026-10-17T23:16:07.58833Z","finished_at":"2026-10-17T23:21:56.676757Z","session_id":"6cf28373-b7fa-4521-8667-d56ea22ffb35","outcome":"returned"}] -->

---

## Re-review — 2026-10-17T17:12:43-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 378 — Side documents inherit parent ownership |
| repo | parley.nvim |
| issue file | workshop/issues/000378-side-doc-parent-owner.md |
| boundary | whole-issue close |
| milestone | — |
| window | e37e950a9e8697dfae7b3087e97b713844852804..d4ecabfb8cd3d7cd39c8e720e81d6c87e9d63adb |
| command | sdlc close --issue 378 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T17:12:43-07:00 |
| verdict | SHIP |

## Review

Checking the round-3 fix for BR-6 now: reading the model's live-witness path, then running the specs and a revert check.

Found the test runner; running the unit and integration specs next.

Setting up the test environment the same way make does, then running the three specs.

All green. Now a revert check: I'll make the settle step ignore inheritance and confirm the `changed` endings go red.

Revert check passes: the mutation makes the unit table fail (45/46). Last step is checking the issue's Done-when against the revised Spec.

```verdict
verdict: SHIP
confidence: high
```

BR-6 is fixed by changing the rule, not by patching one more case. The press held during inheritance (an Alt+Return pressed before the owner is known) now lives in the pure model as `state.queued`. Every call to `controller.dispatch` settles it in one place (`lua/parley/document_session.lua:175-195`). Once the operation holding the press ends, the model emits exactly one `flush_queued` or `drop_queued`. The shell submits only on `flush_queued` (`lua/parley/agentic_document.lua:300-302`), and the old fallback that flushed whenever `operation == nil` is gone. That covers every ending BR-6 listed:
- **(4) `changed`:** it cancels the operation and drops the press.
- **(5) stale witness:** the `not live` branch clears the operation and drops the press. A reply whose witness doesn't match the current operation decides nothing.
- **(6) inherited register goes pending:** it now drops the press explicitly.
- **detach:** drops the press.

I re-ran the specs here. `document_session_spec` passed 46/46, `agentic_document_side_inherit_spec` 9/9, `agentic_document_spec` 47/47 and `agentic_document_lifetime_spec` 10/10. As a revert check, I made the settle step flush regardless of inheritance (`not queued.inheriting` → `true`): the unit table failed (45/46), then I restored the file. The atlas sentence (`atlas/modes/session_sync.md:231-239`) now matches the code. Nothing blocks SHIP.

Done-when: current — the third bullet ("missing, stale or unavailable identity cannot silently guess ownership") covers the Revisions rule that a held press is never re-aimed at the pane's actor. The other bullets cover inheriting through the real opener, keeping an existing child's owner, and integration tests against the persistent registry fake. The integration spec exercises each of these.

1. **Strengths**
   - The model owns the held press (`document_session.lua:175-195`), and one guard covers every event, so a new ending gets a decision without any extra code.
   - `admits` and `inheriting` (`document_session.lua:158-167`) name, in one place, which operations may hold a press.
   - The table test (`tests/unit/document_session_spec.lua`, "settles a queued press exactly once on every ending") walks 22 endings across 6 starting operations. For each, it checks one decision of the expected kind, that a non-matching reply decides nothing, and that no second decision follows. These are invariants stated outside the implementation.
   - Before inheriting, the parent's registration is re-read from Couch (`confirm_parent`), so it doesn't rely on what the parent buffer last saw. The registration it then sends uses `resume_only`, so it never sends anything.

2. **Critical:** none.

3. **Important:** none.

4. **Minor** (not raised as findings)
   - The `not live` branch for a lookup or `confirm_parent` is practically unreachable. Generation only increases on `changed`, `rename` or `detach`, and each of those first clears a pending lookup. The general settle step covers it anyway, but no fixture enters that branch.
   - Inheritance is tracked by three flags (`state.inherit`, `args.inherit`, `args.inherited`) plus the `confirm_parent` kind. A tagged inheritance stage would make the legal combinations explicit (ARCH-ORDER, for later).

5. **Test coverage notes**
   - The new integration case (file reload during inheritance, 0 sends) actually exercises the detach ending, because the reload unloads the buffer. The implementer says so in the Revisions; the `changed` ending is covered only by the unit table. That is acceptable, since the shell has no decision logic left.

6. **Architecture**
   - **ARCH-DRY** pass: the queue flag and the tail flush are gone, and there is one `confirm_parent` executor.
   - **ARCH-PURE** pass: the decisions are in the model, and the shell only carries out effects.
   - **ARCH-PURPOSE** pass: the whole class of endings was swept, not just the instance BR-6 named.
   - **ARCH-MOCK** pass: tests use the registry fake.
   - **ARCH-CONSTRAINTS** pass: one extra lookup on Alt+o, async.
   - **ARCH-SECURE** pass: the parent's identity is re-checked with Couch, not trusted from the buffer.
   - **ARCH-ORDER** pass, with the Minor note above.
   - **ARCH-FUNERAL** pass: nothing durable is created besides the registration.

7. **Plan revisions:** none needed; the round-3 Revisions entry matches the code.

```findings
dispose:
  - id: BR-6
    disposition: addressed
    note: |
      Model owns state.queued; dispatch settles once per ending (document_session.lua:175-195); shell flushes only on flush_queued. Unit table covers changed/detach/pending/refusals; reverting the inheriting guard turns it red (45/46).
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"9afda979-bd13-4305-b99e-cddbf19b2849","repository":"github.com/xianxu/parley.nvim","issue_id":"000378","recipe":"milestone-review","round":4,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/b7f729e07ea1a96d","reviewed_head":"d4ecabfb8cd3d7cd39c8e720e81d6c87e9d63adb","slot":"parley.nvim:4","requested_at":"2026-10-18T00:02:52.834352Z"},"phase":"finished","pid":14143,"started_at":"2026-10-18T00:02:53.179849Z","finished_at":"2026-10-18T00:12:42.469879Z","session_id":"31087a73-f76b-4c0a-b1a6-b7ce0f25a749","outcome":"returned"}] -->
