# Boundary Review — parley.nvim#300 (whole-issue close)

| field | value |
|-------|-------|
| issue | 300 — Conversation label icons and app buffer completion |
| repo | parley.nvim |
| issue file | workshop/issues/000300-app-labels-buffer-completion.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4539950f811407dc477b5064b043631cea2b760c..a0ba0403b4b83fc127fc4c56a08e05563eb03e8b |
| command | sdlc close --issue 300 |
| reviewer | codex |
| timestamp | 2026-09-29T10:41:39-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The implementation is small, shares label formatting correctly, and passes the focused suites and real pinned-Blink smoke. No correctness defect was found. One Important coverage gap remains: the tests do not exercise every explicitly promised prefix/path and selection-key combination.

1. **Strengths**

   - Both outline implementations reuse `question_tags.outline_label`, preserving existing anchors and hiding behavior.
   - Blink’s existing buffer provider supplies completion without another dependency.
   - The real-Blink smoke verifies the one/two-character boundary, exclusion of another visible buffer, acceptance, dismissal, and ordinary Enter behavior.
   - README and atlas updates cover both changed surfaces.

2. **Critical findings:** None.

3. **Important findings**

   **Complete the promised acceptance matrix.** At `tests/unit/question_tags_spec.lua:43`, custom-prefix coverage invokes only `apply_outline`; the actual flat/tree parity fixture at `tests/unit/outline_parity_spec.lua:219` uses default prefixes exclusively. At `tests/packaging/completion_compatibility.lua:82`, selection exercises Ctrl-n but never Ctrl-p.

   Family enumeration: custom tagged labels through the **flat builder**, custom tagged labels through the **tree builder**, and **Ctrl-p selection** through real Blink. Parameterize the builder fixture with default/custom prefixes and exercise both selection directions with distinguishable candidates. These tests should detect a caller substituting the default prefix or a missing/wrong Ctrl-p binding.

4. **Minor findings:** None.

5. **Test coverage notes**

   Passed independently:
   
   - `make test-spec SPEC=ui/outline`
   - `make test-spec SPEC=infra/starter`
   - Real completion smoke against verified Blink commit `78336bc89ee5365633bcf754d93df01678b5c08f`
   - Pinned-range `git diff --check`

   The harness could not count orphan processes because `ps` was unavailable. Repository files were unchanged.

6. **Architectural notes**

   - **ARCH-DRY — pass:** both label consumers derive formatting from one helper; completion reuses Blink.
   - **ARCH-PURE — pass:** formatting remains pure; current-buffer lookup stays in the provider boundary.
   - **ARCH-PURPOSE — pass for implementation:** both requested features are delivered without unrelated expansion. Acceptance evidence needs the additions above.

7. **Plan revision recommendation**

   Append a dated `## Revisions` entry recording the missing acceptance combinations and their added regression coverage; update the verification log after rerunning.

```findings
findings:
  - id: new
    severity: Important
    family: acceptance-matrix-coverage
    title: |
      Exercise every promised outline prefix/path and completion selection direction
    detail: |
      tests/unit/question_tags_spec.lua:43 tests custom prefixes only through apply_outline; tests/unit/outline_parity_spec.lua:219 exercises both actual builders only with default prefixes. tests/packaging/completion_compatibility.lua:82 exercises Ctrl-n but never Ctrl-p. The complete missing family is custom tagged labels through the flat builder, custom tagged labels through the tree builder, and real Ctrl-p selection. Parameterize the builder fixture and test both selection directions with distinguishable candidates, with regression assertions that detect default-prefix substitution or a missing/wrong Ctrl-p binding.
```
