# Boundary Review — parley.nvim#295 (whole-issue close)

| field | value |
|-------|-------|
| issue | 295 — Continue private note prefixes on Return |
| repo | parley.nvim |
| issue file | workshop/issues/000295-private-note-return.md |
| boundary | whole-issue close |
| milestone | — |
| window | 2f03ab371596a55a05e0ac9f73978fc75a6bceb0..35684bcfe4933e0aaf22903f0a9038a1c9dcf068 |
| command | sdlc close --issue 295 |
| reviewer | codex |
| timestamp | 2026-09-28T15:06:15-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

Native continuation is a small, appropriate implementation, and all 14 private-note tests pass. However, existing comment leaders can override a custom private prefix, leaving continuation text public. README documentation and acceptance-test coverage also need completion.

1. **Strengths**
   - Reuses native editing and undo without replacing Return mappings.
   - Keyboard tests verify default continuation, splitting, repeated Return, undo, mapping coexistence, and non-chat isolation.
   - Atlas documentation explains column-one privacy and unsupported-prefix behavior.

2. **Critical findings**
   - `lua/parley/init.lua:2679`: appending the private leader lets existing shorter leaders win. Through production `prep_chat`, `>PRIVATE: first` followed by Return and `second` produces `>second`; Parley classifies that continuation as ordinary text. Give the configured leader precedence and add overlap regressions.

3. **Important findings**
   - `README.md:57`: the private-note instructions omit the new Return behavior.
   - `tests/integration/private_note_prefix_spec.lua:85`: custom prefixes are not tested for splits or repeated empty lines. The prompt test at line 119 checks options but never verifies Return submits.

4. **Minor findings:** None.

5. **Test coverage notes**
   - All 14 private-note tests passed twice.
   - `make test-spec SPEC=ui/keybindings` returned nonzero twice; `branch_child_spec.lua` did not produce a completion summary. The full mapped-suite requirement remains unverified.
   - Process cleanup verification was unavailable because the harness could not use `ps`.
   - The production overlap probe reproduced the defect; native probes confirmed that prepending the private leader fixes the tested collisions.

6. **Architecture**
   - **ARCH-DRY — pass:** native continuation avoids duplicating editor behavior.
   - **ARCH-PURE — pass:** the addition is thin editor-option configuration inside `prep_chat`.
   - **ARCH-PURPOSE — flag:** custom-prefix continuation can lose privacy, defeating the issue’s central purpose.

7. **Plan revisions**
   - Append a `## Revisions` entry defining private-leader precedence and adding the overlap and acceptance-test matrix. The existing `prep_chat` concept row matches the modified symbol.

```findings
findings:
  - id: new
    severity: Critical
    family: private-continuation-preserves-classification
    title: |
      Existing comment leaders can strip the configured private prefix
    detail: |
      lua/parley/init.lua:2676-2679 appends the private leader after existing definitions. Production prep_chat with Markdown comments and chat_local_prefix=">PRIVATE:" turns Return into ">second", classified as text rather than private. Native probes also reproduce collisions with //PRIVATE:, %PRIVATE:, XCOMMPRIVATE:, and /*PRIVATE: under default comments. This window has one composition site; sweep shorter single-line, nested, block, and user-defined leaders there. Give the private leader precedence while preserving other definitions, and add keyboard regressions asserting continued lines remain private. ARCH-PURPOSE.
  - id: new
    severity: Important
    family: user-surface-readme-coverage
    title: |
      README update is missing for private-note Return continuation
    detail: |
      README.md:57-61 documents private-note insertion and configuration but remains unchanged in this range. The sole new user-facing surface is Insert-mode Return continuation. Document continuation, deleting the prefix to exit, and regular-chat scope alongside the existing private-note instructions.
  - id: new
    severity: Important
    family: acceptance-matrix-behavioral-coverage
    title: |
      Acceptance tests omit custom-prefix boundary cases and prompt submission
    detail: |
      tests/integration/private_note_prefix_spec.lua:78-96 exercises repeated empty lines and mid-line splits only with the default prefix; custom cases cover only end-of-line Return. Lines 119-123 assert prompt options without pressing Return or observing submission. These are the missing cases in the stated Done-when matrix. Parameterize split/repeated-line cases across default and custom prefixes, and drive prompt Return through its real callback with an observable submission boundary.
```

---

## Re-review — 2026-09-28T15:12:44-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 295 — Continue private note prefixes on Return |
| repo | parley.nvim |
| issue file | workshop/issues/000295-private-note-return.md |
| boundary | whole-issue close |
| milestone | — |
| window | 2f03ab371596a55a05e0ac9f73978fc75a6bceb0..7a42de80e07e2000196340d5ee7fcf1bf85e25b4 |
| command | sdlc close --issue 295 |
| reviewer | codex |
| timestamp | 2026-09-28T15:12:44-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

All three prior findings are addressed, with no new defects found in the pinned range. The private-note regressions pass and detect deliberately reverted behavior. Confidence is limited by an incomplete mapped-suite run in this sandbox.

1. **Strengths**
   - Private leaders take precedence while preserving existing comment definitions (`lua/parley/init.lua:2678`).
   - Keyboard tests cover nine prefixes across repeated Return, empty lines, splits, and whitespace boundaries.
   - Native undo, existing mappings, spell typeahead, and prompt submission are exercised.
   - README and atlas document continuation, exit behavior, and scope.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage**
   - Private-note suite: **37 passed**.
   - Scratch mutation restoring old leader order: **19 failures**, confirming regression sensitivity.
   - Scratch mutation removing prompt submission: **the prompt test fails**.
   - Lint: **0 warnings/errors**; pinned diff whitespace check passes.
   - `make test-spec SPEC=ui/keybindings` exited nonzero; `branch_child_spec.lua` produced no completion summary. Full-suite success remains independently unverified. Process census was unavailable because sandboxed `ps` could not run.

6. **Architecture**
   - **ARCH-DRY — pass:** reuses native continuation and undo.
   - **ARCH-PURE — pass:** change remains thin editor-option configuration.
   - **ARCH-PURPOSE — pass:** precedence correction covers the enumerated overlap family and preserves complete private prefixes.

7. **Plan revisions:** None required; existing revisions describe the implemented scope and corrections.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      lua/parley/init.lua:2678 prepends the private leader. Tests at tests/integration/private_note_prefix_spec.lua:79-109 cover shorter single-line, nested, block, and user-defined leaders; reverting precedence in a scratch copy causes 19 failures.
  - id: BR-2
    disposition: addressed
    note: |
      README.md:62-64 now documents Return continuation, deleting the prefix to exit, and regular-chat versus prompt scope, consistent with prep_chat and the passing keyboard tests.
  - id: BR-3
    disposition: addressed
    note: |
      tests/integration/private_note_prefix_spec.lua:79-103 parameterizes repeated-empty-line and split cases across nine prefixes; lines 132-143 drive actual Return through prompt submission. Removing the production submission callback in a scratch copy makes that test fail.
```
