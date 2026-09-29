# Boundary Review — parley.nvim#303 (whole-issue close)

| field | value |
|-------|-------|
| issue | 303 — Use familiar keys for app completion |
| repo | parley.nvim |
| issue file | workshop/issues/000303-app-completion-keys.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4539950f811407dc477b5064b043631cea2b760c..d8d32e92dbe181ba95b3f6b972ef83d8493ff254 |
| command | sdlc close --issue 303 |
| reviewer | codex |
| timestamp | 2026-09-29T12:07:02-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned range delivers #303’s completion behavior and preserves the inherited pairing and context-projection contracts. Independent tests passed; removing the five new mappings in memory made the keyboard regression fail as expected. No blocking findings.

1. **Strengths**

   - Starter mappings reuse Blink commands with native fallbacks (`packaging/starter-config/init.lua:169`).
   - Real keyboard tests cover selected/unselected acceptance, dismissal preserving Insert mode, fallback behavior, and prepared-chat coexistence.
   - Context projection preserves raw document content and serialized tool payloads.
   - README and atlas document the changed user-facing behavior.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** Trailing whitespace in `workshop/plans/000300-app-labels-buffer-completion-close-review.md:45` causes the pinned-range `git diff --check` to report an error. Remove that whitespace.

5. **Test coverage notes**

   - Exact pinned Blink commit: **35 keyboard steps passed**.
   - `infra/starter`: **185 tests passed**.
   - Focused pairing, question-tag, message-building, and ancestor suites: **151 tests passed**.
   - In-memory removal of the five mappings failed at step 7: “Tab did not select first candidate.”
   - Full suite not rerun. The harness could not perform its process census because `ps` was unavailable.
   - Repository files remained unchanged.

6. **Architectural notes**

   - **ARCH-DRY — pass:** Built-in Blink commands and shared projection helpers.
   - **ARCH-PURE — pass:** Pairing decisions remain pure; editor effects stay in the mapping callback.
   - **ARCH-PURPOSE — pass:** Requested keys and native fallbacks are implemented and exercised.
   - **ARCH-MOCK — pass:** No new external-service boundary; completion tests exercise real pinned Blink.
   - **ARCH-CONSTRAINTS — pass:** Current-buffer completion and line-local pairing avoid broader scans.
   - **ARCH-SECURE — pass:** No added credential surface; verification uses isolated profiles.
   - **ARCH-ORDER — pass:** Completion state remains Blink-owned; actual event-loop typing exercises transitions.
   - **ARCH-FUNERAL — pass:** No new durable runtime artifact or background owner.

7. **Plan revision recommendations:** None.

```findings
findings:
  - id: new
    severity: Minor
    family: diff-hygiene
    title: |
      Remove trailing whitespace from the committed review transcript
    detail: |
      workshop/plans/000300-app-labels-buffer-completion-close-review.md:45 contains trailing whitespace reported by git diff --check across the pinned range. Remove the whitespace; runtime behavior is unaffected.
```

---

## Re-review — 2026-09-29T12:23:52-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 303 — Use familiar keys for app completion |
| repo | parley.nvim |
| issue file | workshop/issues/000303-app-completion-keys.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4539950f811407dc477b5064b043631cea2b760c..e8471ecf8382c66f64180e367008b0e03f4babe5 |
| command | sdlc close --issue 303 |
| reviewer | codex |
| timestamp | 2026-09-29T12:23:52-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

Issue #303’s completion behavior passed all 35 keyboard checks against the verified pinned Blink version. BR-1 is addressed. The pinned range also introduces a recording viewer with an independently reproduced stale-load race, unbounded draft persistence with silent save failures, and missing atlas documentation.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      The committed review transcript at line 45 no longer contains trailing whitespace; the pinned-range check reports only demo/REHEARSAL.md.
findings:
  - id: new
    severity: Critical
    family: latest-selection-owns-async-result
    title: |
      An older file read can replace the newly selected recording
    detail: |
      demo/viewer.html:87-89 awaits f.text() without checking whether that selection is still current. Executing the production handler with controlled promises, selecting A then B and completing B before A leaves A displayed. ARCH-ORDER: guard completion with a selection generation, ignore superseded results, and add a regression covering both completion orders.
  - id: new
    severity: Important
    family: durable-drafts-have-bounded-retention
    title: |
      Browser drafts accumulate without cleanup and failed saves remain invisible
    detail: |
      demo/viewer.html:56,95-97 creates a persistent key for each cast URL with no removal or retention bound. Storage exceptions are swallowed while the UI promises retained notes. A stateful storage probe retained 100 keys for 100 casts; an injected quota failure silently discarded the revision on reload. ARCH-FUNERAL/ARCH-CONSTRAINTS: define bounded retention and visibly report unsaved changes; cover retention and storage failure with regression tests.
  - id: new
    severity: Important
    family: new-workflows-reach-atlas
    title: |
      Atlas update appears missing for the recording viewer and caption-drafting workflow
    detail: |
      demo/README.md:82 introduces viewer.html, URL/file loading, Alt+T stamps, browser persistence and caption downloads, but the atlas changes in this range describe completion and chat tags only. Document the viewer, its storage lifecycle and verification entry point in atlas/infra/starter.md or a linked atlas page.
  - id: new
    severity: Minor
    family: diff-hygiene
    title: |
      Pinned-range whitespace validation still fails in the rehearsal script
    detail: |
      demo/REHEARSAL.md:10,12,14,18,22,24,26 contains trailing whitespace. This is the 2nd finding in family diff-hygiene. Earlier rounds fixed instances: apply the rule that every added line across the entire pinned range passes git diff --check, and sweep all seven occurrences rather than fixing one line.
```

1. **Strengths**

   - Completion uses Blink’s existing actions and fallback chains rather than introducing another mapping implementation.
   - The keyboard regression exercises actual remappable input, prepared app chats, selected/unselected acceptance, native fallbacks, legacy shortcuts and pairing.
   - Chat context projection preserves source text for rendering while filtering outgoing context; tests cover configured prefixes, fences and tool payloads.

2. **Critical findings**

   - **Stale recording selection:** `demo/viewer.html:87-89`. A superseded asynchronous read replaces the current recording. Reproduction and fix direction are recorded above.

3. **Important findings**

   - **Draft lifecycle and failed saves:** `demo/viewer.html:56,95-97`.
   - **Missing viewer atlas coverage:** `demo/README.md:82`.

4. **Minor findings**

   - Seven committed whitespace errors remain in `demo/REHEARSAL.md`; BR-1 itself is fixed.

5. **Test coverage notes**

   - **Passed:** all 35 completion steps using Blink commit `78336bc89ee5365633bcf754d93df01678b5c08f`.
   - **Reproduced:** reversed file-read completion displays the older recording; storage failure loses the latest draft on reload.
   - **Not green:** `make test-spec SPEC=infra/starter` exited 2. Many cases passed, but the bootstrap spec did not print its completion summary. The environment also could not perform process-census checks because `ps` was unavailable. This run does not substantiate a passing starter suite.
   - No repository tests were found for the new viewer. Add the deterministic regressions described above.

6. **Architectural notes**

   - **ARCH-DRY — pass:** completion delegates to Blink; tag association and projection share classification.
   - **ARCH-PURE — pass:** pairing decisions remain separate from editor effects.
   - **ARCH-PURPOSE — pass for #303:** the requested keys and fallbacks are delivered.
   - **ARCH-MOCK — flag:** viewer persistence and asynchronous loading lack committed tests with controllable stateful dependencies.
   - **ARCH-CONSTRAINTS — flag:** draft storage reaches quota without visible failure handling.
   - **ARCH-SECURE — pass:** inspected viewer labels use `textContent`; no new credential handling was found.
   - **ARCH-ORDER — flag:** superseded file reads retain authority to replace the player.
   - **ARCH-FUNERAL — flag:** per-cast persistent drafts have no removal policy.

7. **Plan revision recommendations**

   Append a timestamped `## Revisions` entry accounting for the viewer’s additional scope, selection-order invariant, draft retention policy and verification. Alternatively, move that addition to a separately specified and reviewed boundary. The completion plan itself matches the implementation.

---

## Re-review — 2026-09-29T12:30:56-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 303 — Use familiar keys for app completion |
| repo | parley.nvim |
| issue file | workshop/issues/000303-app-completion-keys.md |
| boundary | whole-issue close |
| milestone | — |
| window | 7cb00fc1f74976bd3aaf087141542e19fc4f59ec..a16021b7cc2909bacd16ec2c100e3178db9b706c |
| command | sdlc close --issue 303 |
| reviewer | codex |
| timestamp | 2026-09-29T12:30:56-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

The pinned changes satisfy issue #303’s documented contract. All four open findings are addressed, with meaningful regression evidence for the behavior fixes. No new blocking findings emerged. Confidence is limited by the real-Blink rerun failing to load its local dependency.

```findings
dispose:
  - id: BR-2
    disposition: addressed
    note: |
      demo/viewer.html:96-105 guards successful and failed reads by selection generation. Both completion-order regressions pass and fail when the success guard is removed in memory.
  - id: BR-3
    disposition: addressed
    note: |
      demo/viewer.html:112-158 bounds persisted drafts to 20, migrates legacy keys after successful persistence, and visibly reports storage failures. Retention and warning mutations independently make the corresponding regressions fail.
  - id: BR-4
    disposition: addressed
    note: |
      atlas/infra/starter.md now documents viewer loading, timestamp insertion, downloads, selection ownership, bounded storage, legacy cleanup, and the production-script verification command; these match demo/viewer.html.
  - id: BR-5
    disposition: addressed
    note: |
      git diff --check across the complete pinned range exits successfully, including demo/REHEARSAL.md.
```

1. **Strengths**
   - Completion policy uses Blink’s existing commands and native fallback behavior, avoiding another mapping implementation.
   - Viewer tests execute the production script with controlled asynchronous reads and stateful storage.
   - Storage failures preserve editable, downloadable text; migration removes legacy data only after persistence succeeds.
   - Tag projection preserves original text while sharing exclusion logic across model-context consumers.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage**
   - All eight viewer tests passed.
   - In-memory mutations confirmed failures when selection ownership, retention enforcement, or visible storage warnings were removed.
   - `make test-spec SPEC=infra/starter` passed. Its process census was skipped because `ps` was unavailable.
   - Full-range whitespace validation passed.
   - Inspected the 35-step real-Blink keyboard regression, but its rerun failed with `module 'blink.cmp' not found`; this review does not claim a successful keyboard rerun.
   - Inspected related Lua regression coverage; did not rerun the full repository suite.

6. **Architecture**
   - **ARCH-DRY — pass:** Blink commands and shared tag-classification helpers centralize behavior.
   - **ARCH-PURE — pass:** Pairing decisions remain pure, with editor effects in the mapping callback.
   - **ARCH-PURPOSE — pass:** Completion mappings and the explicitly added viewer corrections fulfill the revised contract.
   - **ARCH-MOCK — pass for reviewed corrections:** Stateful storage and controlled file promises exercise production handlers. Browser-player integration remains outside that evidence.
   - **ARCH-CONSTRAINTS — pass:** Draft count is bounded; storage exhaustion produces a visible recovery path.
   - **ARCH-SECURE — pass:** Stored drafts are validated; unreadable or malformed storage is preserved rather than silently overwritten.
   - **ARCH-ORDER — pass:** Selection generations enforce latest-selection ownership, including stale failures; tests control both completion orders.
   - **ARCH-FUNERAL — pass:** Draft eviction and legacy-key cleanup define persistent-data removal; replaced players are disposed.

7. **Plan revision recommendations:** None. The existing revision records the viewer scope and its required corrections.
