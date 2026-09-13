# Boundary Review — parley.nvim#232 (whole-issue close)

| field | value |
|-------|-------|
| issue | 232 — chat outline drops @@ annotations because the tree builder has its own item rule |
| repo | parley.nvim |
| issue file | workshop/issues/000232-chat-outline-drops-annotations-because-the-tree-builder-has-its-own-item-rule.md |
| boundary | whole-issue close |
| milestone | — |
| window | 6d864498a8ee4c517a2ecfd18afae1e26cc04ba6..f549d835b2fdc6040a2af10f6e4750f495b0bb03 |
| command | sdlc close --issue 232 |
| reviewer | codex |
| timestamp | 2026-09-12T19:59:36-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The review could not run: both required pinned-range inspections (`git diff --stat` and `git diff --name-status`) failed with exit code 71: `sandbox-exec: sandbox_apply: Operation not permitted`. This verdict reflects blocked inspection, not an identified code defect.

1. **Strengths:** None validated.
2. **Critical findings:** No code findings established.
3. **Important findings:** Required repository inspection is unavailable.
4. **Minor findings:** None.
5. **Test coverage:** Tests and Spec/Plan could not be inspected or verified.
6. **Architecture:** ARCH-DRY, ARCH-PURE, ARCH-PURPOSE, ARCH-MOCK, ARCH-CONSTRAINTS, ARCH-SECURE, ARCH-ORDER, and ARCH-FUNERAL are all **unverified**.
7. **Plan revisions:** None established. Restore read-only command execution and rerun this boundary review.

```findings
findings:
  - id: new
    severity: Important
    family: review-evidence-availability
    title: |
      Required pinned-range inspection failed
    detail: |
      Both required git diff inspections (--stat and --name-status) failed with exit code 71: sandbox-exec: sandbox_apply: Operation not permitted. Restore read-only execution and rerun the review against the supplied base and head; no implementation conclusions are supported.
```

---

## Re-review — 2026-09-12T20:01:49-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 232 — chat outline drops @@ annotations because the tree builder has its own item rule |
| repo | parley.nvim |
| issue file | workshop/issues/000232-chat-outline-drops-annotations-because-the-tree-builder-has-its-own-item-rule.md |
| boundary | whole-issue close |
| milestone | — |
| window | 6d864498a8ee4c517a2ecfd18afae1e26cc04ba6..f549d835b2fdc6040a2af10f6e4750f495b0bb03 |
| command | sdlc close --issue 232 |
| reviewer | codex |
| timestamp | 2026-09-12T20:01:49-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

The implementation fulfills #232: tree outlines use the shared classifier, annotations appear, and both delimiters are stripped. Required pinned-range inspections succeeded. A headless probe confirmed the operator’s annotation appears at HEAD and is absent at BASE; the display correction also discriminates between both versions. No blocking findings. Confidence is limited by the read-only environment preventing the normal test suite.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Required pinned-range stat and name-status commands both completed with exit code 0; full patch and pinned issue inspection also succeeded.
```

1. **Strengths**
   - `lua/parley/outline.lua:290` reuses the existing classifier, preserving fence exclusion and chat-heading policy.
   - `lua/parley/outline.lua:292` excludes parser-unrecognized branch lines, preserving the child’s upward parent-link behavior.
   - `tests/unit/outline_parity_spec.lua:80` checks builder parity; separate assertions pin annotation presence, nested placement, and delimiter formatting.
   - Atlas documentation and test traceability were updated together.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**
   - Independently executed the real tree builder on the operator’s file: HEAD displays `→ plan for 9/10/2026` at line 87; BASE omits it.
   - Direct classifier probe: HEAD produces `→ my note`; BASE produces `→ @my note@`.
   - Baseline code was loaded into memory without modifying the checkout.
   - Reviewed all five new test cases; did not rerun the filesystem-writing suite. Neovim emitted sandbox startup warnings, but the final probe completed successfully.

6. **Architectural notes**
   - **ARCH-DRY — pass:** Both builders derive non-branch classification from one helper.
   - **ARCH-PURE — pass:** Classification adds no IO; existing builders retain buffer/file access.
   - **ARCH-PURPOSE — pass:** Both affected builders were checked; tree-specific branch handling remains deliberate.
   - **ARCH-MOCK — pass:** No new external dependency or interaction.
   - **ARCH-CONSTRAINTS — pass:** Existing linear scan retained; no additional file reads introduced.
   - **ARCH-SECURE — pass:** No new trust boundary, credential handling, or executable input.
   - **ARCH-ORDER — pass:** Classification holds no state between events; expansion behavior is unchanged.
   - **ARCH-FUNERAL — pass:** Production creates no new durable artifacts.

7. **Plan revision recommendations:** Append a `## Revisions` entry recording the test relocation to `tests/unit/outline_parity_spec.lua`; the Log explains it, but the Plan still names `picker_items_spec.lua`.
