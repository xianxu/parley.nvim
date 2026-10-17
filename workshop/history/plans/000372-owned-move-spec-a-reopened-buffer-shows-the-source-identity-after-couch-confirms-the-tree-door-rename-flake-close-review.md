# Boundary Review — parley.nvim#372 (whole-issue close)

| field | value |
|-------|-------|
| issue | 372 — owned-move spec: a reopened buffer shows the source identity after Couch confirms the tree-door rename (flake) |
| repo | parley.nvim |
| issue file | workshop/issues/000372-owned-move-spec-a-reopened-buffer-shows-the-source-identity-after-couch-confirms-the-tree-door-rename-flake.md |
| boundary | whole-issue close |
| milestone | — |
| window | 198a473f2bbbe90f0e804c2f847581aa2c783c91..88acb8bd3ffde461022b14314f9dda8e0f9ccac2 |
| command | sdlc close --issue 372 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T05:49:50-07:00 |
| verdict | SHIP |

## Review

Checking how to run the focused spec, then I'll run it.

Setting up the test environment so I can run the focused spec.

Focused spec passes 16/16. Now confirming the old assertion order goes red under the new deterministic delay.

Revert went red at the identity assertion (15/16), and restoring the fix brings it back to green. Now a quick check of the product-side adoption claim.

```verdict
verdict: SHIP
confidence: high
```

This change fixes a test flake, not a product bug. Couch saves the rename to its registry before its reply reaches the editor. The old spec checked the registry first and then read `document.identity` straight away, so it could see the source path whenever the registry got there first. The fix has two parts:
- **Fake:** a new reply delay in the fake Couch registry (`FAKE_COUCH_REGISTRY_REPLY_DELAY`, with `_OPS` to limit which operations it applies to). It applies after the change is saved and the lock is released.
- **Spec:** the tree-door case holds the rename reply for 0.5 s, so the test always crosses that window. It then waits for the buffer to adopt the new path before checking the registry.

What I verified in the disposable checkout:
- **Focused spec at head:** 16/16 pass.
- **The fix is load-bearing:** I put back the base spec's old assertion order and kept only the new 0.5 s delay. It fails deterministically at the identity assertion (line 225, 15/16). So the fix is needed, and the delay turns an intermittent flake into a reliable regression test.
- **Product-side claim:** `lua/parley/document_session.lua:337-342` sets `state.registration` and `state.path` from the rename reply before it emits `finish_move`. So the editor never reports a confirmed move before it adopts the new path, which matches the issue Log.

Every Done-when clause is delivered, and nothing blocks the close.

1. **Strengths**
   - The delay sits after `flock` is released and after the change is saved (`tests/fixtures/fake_couch_registry.py:170-176`). It models the real order (saved, then reply in transit) and doesn't block the spec's own lookups while the reply is held.
   - The case waits on what the editor itself observes (the buffer's identity), then checks the registry. Once the editor has adopted the new path, the registry is guaranteed to agree, so the follow-up lookup can't race.
   - Both new env names are added to the save/restore list (`agentic_document_owned_move_spec.lua:33-34`), so the delay doesn't leak into other cases.
   - The sweep claim holds. Lines 371/397 already wait for `identity.File == new_path`, and the legacy case (297-299) compares only the ID, which a rename doesn't change.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - **Wrong comment claim:** the fake's comment says the `_OPS` list defaults to "all". In fact `status`, `--owe`/`--fold` and the early-exit modes (`unsupported`, `malformed`, `missing`) return before the delay code, so they never get it. Same class: the `min(reply_delay, 10.0)` cap is silent, while the older `FAKE_COUCH_REGISTRY_DELAY` has no cap. The two knobs behave differently, and nothing tells the caller.
   - **ARCH-DRY:** the fake has two near-identical "comma-list op filter + sleep" blocks: `FAKE_COUCH_REGISTRY_DELAY`/`_DELAY_OPS` at :79-84 and the new reply delay at :170-174. Each also parses `op` its own way. One `_maybe_sleep(prefix, op)` helper could serve both.
   - **Issue file:** the `## Log` / `### 2026-10-17` heading appears twice. One copy is empty.

5. **Test coverage**
   - The regression is deterministic. Without the await change it fails every time; with it, it passes.
   - The fake's new knob is only exercised through this one spec. That's acceptable for a test fixture.

6. **Architecture**
   - **ARCH-DRY:** flagged, Minor (the two delay blocks above).
   - **ARCH-PURE:** pass. Only test code and a fixture changed, and no product logic moved.
   - **ARCH-PURPOSE:** pass. The issue asked to decide which side is wrong. That was settled with a controlled ordering, and the sibling cases in the spec were checked.

7. **Plan revisions:** none needed. The plan matches the code. Optionally, remove the duplicate Log heading.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: doc-claim-unchecked
    title: |
      Fake reply-delay comment says the _OPS list defaults to all ops, but several paths return before the delay
    detail: |
      tests/fixtures/fake_couch_registry.py:165-174. The status op, --owe/--fold and the unsupported/malformed/missing modes all return before the delay code, so they never get it. The new 10 s cap is also silent, while the existing FAKE_COUCH_REGISTRY_DELAY knob has no cap. These are the two instances of this family in the window.
  - id: new
    severity: Minor
    kind: defect
    family: duplicated-helper-logic
    title: |
      ARCH-DRY: two near-identical comma-list op filter + sleep blocks in the fake registry
    detail: |
      The mode=delay block (fake_couch_registry.py:79-84) and the new reply-delay block (:170-174) both parse an _OPS comma list, work out the op on their own, and sleep. A shared _maybe_sleep(prefix, op) helper could serve both. These two blocks are the only instances in the window.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"be9bacbf-42d3-4be6-816c-436af64209a8","repository":"github.com/xianxu/parley.nvim","issue_id":"000372","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/ecbf88d537ac35f5","reviewed_head":"88acb8bd3ffde461022b14314f9dda8e0f9ccac2","slot":"parley.nvim:4","requested_at":"2026-10-17T12:47:42.721518Z"},"phase":"finished","pid":91446,"started_at":"2026-10-17T12:47:42.826213Z","finished_at":"2026-10-17T12:49:44.168042Z","session_id":"06b12fde-9d32-416c-85d3-00d4190c2e8c","outcome":"returned"}] -->
