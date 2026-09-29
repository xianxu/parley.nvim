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

---

## Re-review — 2026-09-29T10:46:37-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 300 — Conversation label icons and app buffer completion |
| repo | parley.nvim |
| issue file | workshop/issues/000300-app-labels-buffer-completion.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4539950f811407dc477b5064b043631cea2b760c..e46ba3ccf16bddec3ef4771de912214fccfcfbf6 |
| command | sdlc close --issue 300 |
| reviewer | codex |
| timestamp | 2026-09-29T10:46:37-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

BR-1 is addressed across its complete family. Both outline builders now have default/custom-prefix coverage, and the real-Blink smoke exercises both selection directions with distinct candidates. No blocking correctness or architectural findings remain.

1. **Strengths**
   - Both outline paths reuse `question_tags.outline_label`, preserving indentation, anchors and hiding behavior.
   - Completion reuses the pinned Blink provider and restricts vocabulary to the current buffer.
   - README and atlas updates describe both changed surfaces.

2. **Critical findings:** None.

3. **Important findings:** None. BR-1 is addressed.

4. **Minor findings:** One trailing-whitespace line in the generated prior review artifact; cosmetic only.

5. **Test coverage**
   - Passed `make test-spec SPEC=ui/outline`.
   - Passed `make test-spec SPEC=infra/starter`.
   - Passed all 14 keyboard-smoke steps against verified Blink commit `78336bc89ee5365633bcf754d93df01678b5c08f`.
   - Independently reversed Ctrl-p’s mapping in memory: the smoke failed at step 9 with “Ctrl-p did not move to first candidate.”
   - Process census was unavailable because the environment restricts `ps`. Repository files were unchanged.

6. **Architecture**
   - **ARCH-DRY — pass:** shared label formatter; existing completion provider reused.
   - **ARCH-PURE — pass:** formatting stays pure; buffer lookup remains at the provider boundary.
   - **ARCH-PURPOSE — pass:** both requested features and the previously missing acceptance combinations are delivered.

7. **Plan revisions:** None needed. The dated BR-1 revision accurately records the expanded coverage.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      tests/unit/outline_parity_spec.lua parameterizes both actual builders with default/custom prefixes and asserts their rendered labels. tests/packaging/completion_compatibility.lua exercises Ctrl-n twice and Ctrl-p back across distinct candidates. Both suites and the real pinned-Blink smoke pass; independently reversing Ctrl-p in memory makes step 9 fail.
findings:
  - id: new
    severity: Minor
    family: patch-whitespace-hygiene
    title: |
      Remove trailing whitespace from the generated review artifact
    detail: |
      git diff --check identifies one instance in this window: workshop/plans/000300-app-labels-buffer-completion-close-review.md:45. Remove the spaces from that blank line when regenerating the artifact.
```

---

## Re-review — 2026-09-29T12:35:53-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 300 — Conversation label icons and app buffer completion |
| repo | parley.nvim |
| issue file | workshop/issues/000300-app-labels-buffer-completion.md |
| boundary | whole-issue close |
| milestone | — |
| window | 7cb00fc1f74976bd3aaf087141542e19fc4f59ec..d20c778ebeb8d6b218db64a643b4323f99b1be10 |
| command | sdlc close --issue 300 |
| reviewer | codex |
| timestamp | 2026-09-29T12:35:53-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The runtime changes passed focused verification, and BR-2 is corrected. One Important issue remains: the keybinding suite fails two architecture checks because the current stacked branch’s issue lacks the required Core concepts inventory. #303 explicitly documents the revised Enter behavior.

```findings
dispose:
  - id: BR-2
    disposition: addressed
    note: |
      The pinned review artifact's blank line is clean; git diff --check across the complete pinned range reports no whitespace errors.
  - id: BR-1
    disposition: addressed
    note: |
      Default/custom prefixes exercise both outline builders; the real pinned-Blink smoke exercises Ctrl-n/p navigation and passes.
findings:
  - id: new
    severity: Important
    family: core-concepts-traceability
    title: |
      Restore the stacked branch's Core concepts inventory
    detail: |
      tests/arch/single_source_sweeps_spec.lua:208 and :356 fail under make test-spec SPEC=ui/keybindings. On branch 000303-app-completion-keys, the checker selects workshop/issues/000303-app-completion-keys.md, which contains no Core concepts table. It reports content, context_text, is_local_tag, keys, local_rows, outline_label and project as undocumented exports. Add the complete inventory with ownership, paths and inherited status, append a Revisions entry, and rerun the suite. ARCH-PURPOSE: the existing traceability guard must pass for the actual stacked branch.
```

1. **Strengths:** Shared outline formatting covers both builders and custom prefixes. Context projection preserves raw transcript text and tool payloads. Real Blink tests exercise production starter options. Viewer tests control asynchronous completion order and use stateful storage.

2. **Critical findings:** None.

3. **Important findings:** The Core concepts inventory failure above. This is a branch-sensitive documentation/checker mismatch, not a demonstrated runtime defect.

4. **Minor findings:** None remaining.

5. **Test coverage:** Passed `ui/outline`, `infra/starter`, `chat/format`, all 35 pinned-Blink keyboard steps, eight viewer tests, and range-wide whitespace checks. `ui/keybindings` failed only the two architecture checks identified above. Process-orphan inspection was unavailable because `ps` was blocked.

6. **Architecture:** ARCH-DRY **pass**—shared projections and existing Blink commands. ARCH-PURE **pass**—pairing decisions remain stateless. ARCH-PURPOSE **flag**—branch traceability fails. ARCH-MOCK **pass**—real Blink and stateful storage tests. ARCH-CONSTRAINTS **pass**—line-local pairing and current-buffer completion. ARCH-SECURE **pass**—storage validation and visible failures. ARCH-ORDER **pass**—superseded reads are rejected in both tested completion orders. ARCH-FUNERAL **pass**—draft eviction, legacy cleanup, and player disposal are present.

7. **Plan revision:** Append a #303 `## Revisions` entry recording the stacked export inventory and successful architecture-check rerun.
