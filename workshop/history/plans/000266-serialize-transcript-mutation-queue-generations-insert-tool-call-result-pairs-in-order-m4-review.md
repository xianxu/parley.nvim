# Boundary Review — parley.nvim#266 (milestone M4)

| field | value |
|-------|-------|
| issue | 266 — Serialize transcript mutation: queue generations, insert tool call/result pairs in order |
| repo | parley.nvim |
| issue file | workshop/issues/000266-serialize-transcript-mutation-queue-generations-insert-tool-call-result-pairs-in-order.md |
| boundary | milestone M4 |
| milestone | M4 |
| window | e48362abb0e37e1db6771020e66b719627894e41..21c1a7dbd1010e6ecb67178b079dbe0150bf151c |
| command | sdlc milestone-close --issue 266 --milestone M4 |
| reviewer | claude |
| timestamp | 2026-09-18T14:54:00-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M4 does what it set out to do and does it cleanly: with child grants gone since M2, the carving geometry (`exclude`, `parent`, the half-open seam flags, the ancestor walk and `tail_lost`) was provably dead, and this window deletes it one concern per commit, then goes one step further and collapses the now-degenerate `slots` list into the grant's own range. I re-derived the behavior-preservation argument independently rather than trusting the commit messages: with no carving, `slots ≡ {{g.first,g.last}}` at every writer (acquire, `reclaim_tail`, `successor_finish`, `move`), so `writable(g,·)`→`contains(g,·)`, the per-slot revocation scan→`overlaps(g,event)`, and `tail_lost` was already subsumed by that revocation (an edit covering `g.last` overlaps `g`, so a non-owner edit revokes it) — the removals change no reachable behavior. The disjointness invariant the deleted `reclaim_tail` overlap scan rested on is closed under every transition (`move` maps endpoints monotonically; an owned edit lies inside its owner; a non-owner edit revokes what it touches), so nothing is broken today. Nothing here blocks the boundary: the two findings are Minor, both in families already in play, so both are stated as rules rather than as instances.

**1. Strengths**

- `lua/parley/document/state.lua:37-40` — the whole geometry is now two one-line predicates over closed ranges, with the reason stated once in a comment. Grant records at `:232-234` carry no nullable geometry at all; that is ARCH-ORDER's "representable state shrinks to legal state" done by deletion rather than by documentation.
- Real regression evidence where it exists, and only there. I ran the head specs against the **base** `state.lua`/`init.lua` in a scratch copy: `document_state_spec:100` ("never nests grants") is red without the change; `document_tail_spec` is 4/4 green on both sides, which is the correct signature for a behavior-preserving removal.
- The removal guard at `tests/arch/document_ownership_spec.lua:98-108` is a live fitness function, not decoration. I planted `return g.slots, g.parent, g.tail_lost` and `p.open_first or p.open_last` as code in `state.lua`: the guard failed both times; a comment-only probe correctly does not fire, and the scoping comment explains why `%.parent`/`%.slots` are restricted to the two grant modules (`sequence.lua` and `append.lua` use both names legitimately).
- The issue Log's "why the tail checks are dead, not merely unused" paragraph is exactly the artifact that stops a later reader restoring them "defensively" — and its two claims (a) and (b) are the ones I verified hold.
- `tests/manual/chat-concurrency.md` was the right page to find: #254's checklist was still telling a live tester to expect concurrent answer writes, "pending slots" and a Stop that drops the round. Both new anchors resolve (`tool_use.md` "Loop Model" `:155`, "Stop during a tool round" `:191`).

**2. Critical findings** — none.

**3. Important findings** — none.

**4. Minor findings**

- Plan Core concepts `:88` still says "`writable`/`resolve` are **not** changed, deliberately" — `writable` is deleted and `resolve` lost `result.slots` and the `'patch range required'` rejection. 3rd in `behavior-change-sweep-by-claim`; the rule already exists (lessons.md:3102-3106) but M4's own lesson restates the scope without it.
- `generation_runner.lua:439` still names the answer's own grant `local parent=…` — the last identifier carrying the nesting vocabulary the milestone removed.
- The disjointness invariant now doing the work of the deleted `reclaim_tail` overlap scan is asserted at no seam that composes events (2nd in `composed-claim-tested-at-one-seam`) — see below.
- `tests/unit/document_append_spec.lua:104-107`: `leaf_intent` duplicates the fixture's `intent` shape because the fixture closure captures the revoked grant. A `intent(bytes, grant)` parameter on the fixture would remove the copy (ARCH-DRY, trivial).

**5. Test coverage notes**

All 37 `tests/unit/document_*_spec.lua` + `tests/arch/*_spec.lua` pass at HEAD (two arch specs shell out to `git ls-files`, so they fail in a `git archive` export and pass in-repo — environmental, verified). `luacheck` clean on all seven changed Lua files. The one new behavioral assertion in this window is the nesting test; everything else is characterization of unchanged behavior, which is right for a removal milestone. The gap is that the *invariant* the removals now lean on — live grants are pairwise disjoint — is only observed at the `acquire` seam (`document_state_spec:33`, a touching region refused) and at single-edit revocations, never after a sequence. `document_write_plan_spec:178` already drives 36 seeded interleavings over two grants plus human edits and would host a `disjoint(live grants)` assertion for a few lines; adding `reclaim_tail`/`successor_finish` to that event mix would close it.

**6. Architectural notes**

- **ARCH-DRY** — pass, and improved: the slot list was a second copy of the grant's range and is gone. Only the test-helper duplication above remains.
- **ARCH-PURE** — pass. `state.lua` is a pure reducer; `document_state_spec` and `document_tail_spec` drive it with no IO, no mocks.
- **ARCH-PURPOSE** — pass. The shadow-sweep over `lua/`, `atlas/`, `README.md`, `docs/`, `tests/manual/`, `workshop/targets/` for `writable|slots|open_first|open_last|tail_lost|patch range required|child grant|parent slot|reserved slot|carv` finds no live residual except plan `:88`. Collapsing the slot list rather than stopping at the plan's line list is the class fix, not the instance.
- **ARCH-MOCK** — N/A: no external binary or service on this path; the document specs use the injected `fake_document_editor` driver at the same seam production uses.
- **ARCH-CONSTRAINTS** — pass. `exclude` was the only growth path inside a grant record (slots could reach the 17 cap); `acquire` is now O(regions × ≤16 grants) with no allocation per boundary, and snapshots copy less per `sync`.
- **ARCH-SECURE** — N/A: no untrusted input, no secret. Noted and dismissed: `acquire` now ignores an `event.parent` field instead of rejecting it, which is safe because any genuinely nested region is refused as `'overlap'` — the loud outcome, pinned by `document_state_spec:100`.
- **ARCH-ORDER** — structural pass (the transition function is the only mutator; four nullable geometry fields left the state), behavioral flag as raised.
- **ARCH-FUNERAL** — pass. Nothing durable is created; revoked grants are still collected at the next `acquire` (`state.lua:229`) and wholesale on `finish_generation`/`reload`/`detach`.

**7. Plan revision recommendations**

- One `## Revisions` entry (M4): correct the DocumentState bullet at plan `:88`. It should read that M1 deliberately left `resolve` alone, and that **M4** removed `writable` and narrowed `resolve` (slot list and `'patch range required'` gone) — no reason string was *added*, so the original rationale still holds. Everything else in the plan outside `## Revisions` matches the code; the M4 entry already records the slot-collapse and the already-done Task 4.3 accurately.

```findings
dispose:
  - id: BR-1
    disposition: withdrawn
    note: |
      Already withdrawn in round 3 and not re-raised; nothing in this window revives it.
findings:
  - id: new
    severity: Minor
    family: behavior-change-sweep-by-claim
    title: |
      Plan Core concepts still says state.lua's `writable`/`resolve` are unchanged, which M4 falsified
    detail: |
      This is the 3rd finding in family `behavior-change-sweep-by-claim`. Do NOT fix only this instance.
      The rule exists already (lessons.md:3102-3106, BR-10): sweep the superseded CLAIM across atlas,
      README, code comments AND the plan's own Core concepts. M4's new lesson (lessons.md:3137-3142)
      restates the same rule with a different scope — it adds `tests/manual/` and `docs/` but drops the
      plan's Core concepts, and the dropped item is exactly what leaked. Fix at the rule: state the sweep
      scope ONCE as one enumerated list (atlas/, README.md, docs/, tests/manual/, code comments,
      user-visible strings, and the plan outside `## Revisions`), and derive the grep terms mechanically
      from the identifiers the diff removes (`git diff BASE..HEAD | grep '^-'`) rather than from memory.
      Measured at HEAD: plan :88 "`writable`/`resolve` are **not** changed, deliberately" — state.lua's
      `writable` is deleted and `resolve` lost `result.slots` and the `'patch range required'` rejection;
      1 live residual, atlas/README/lua/tests-manual all clean under that grep. Lesser site of the same
      class, an identifier rather than a claim: generation_runner.lua:439 still calls the answer's own
      grant `parent`. Plan fix is a `## Revisions` entry, not an overwrite.
  - id: new
    severity: Minor
    family: composed-claim-tested-at-one-seam
    title: |
      Disjointness — the invariant that replaced reclaim_tail's overlap scan — is asserted at no seam that composes events
    detail: |
      This is the 2nd finding in family `composed-claim-tested-at-one-seam`, so the rule, not the instance.
      Rule: when a runtime guard is deleted because an invariant makes it dead, that invariant becomes the
      guard, and it is tested by driving SEQUENCES of the production transitions and asserting it after
      every step — not by testing each transition's local contract. state.lua:243-244 and
      atlas/chat/document.md:91-93 now assert "no other live grant can cover g.last" / "disjoint from every
      other live grant"; it composes acquire's overlap refusal, observed_edit's revocation, `move`'s
      endpoint mapping, `successor_finish` and `reclaim_tail`. Tests cover only the acquire seam
      (document_state_spec:33) and single-edit revocations (:38-47). I verified by case analysis that the
      invariant holds at HEAD, so nothing is broken — but a future change to `move` or to owner selection
      would now silently let reclaim_tail narrow onto a tail another grant covers, where the deleted scan
      failed closed. Cheap fix: assert pairwise disjointness of live grants after each step of the existing
      seeded interleaving loop (document_write_plan_spec:178), and add reclaim_tail/successor_finish and
      owned boundary insertions to that event mix.
```
