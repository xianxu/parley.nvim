# Boundary Review — parley.nvim#419 (whole-issue close)

| field | value |
|-------|-------|
| issue | 419 — unified-editorial-interface: typeahead for the mode keys and heading comments; conceal comments as badges |
| repo | parley.nvim |
| issue file | workshop/issues/000419-unified-editorial-interface-typeahead-for-the-mode-keys-and-heading-comments-conceal-comments-as-badges.md |
| boundary | whole-issue close |
| milestone | — |
| window | d1bb4ba89c0466ae17c02520afdbbfd705ff0537..27c670ca388c57ef20614adfed96242b34d894c2 |
| command | sdlc close --issue 419 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-24T10:53:34-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The implementation substantially delivers the revised collaborative interface, and the mapped tests pass. Three findings block this boundary: legacy metadata can disable chat protection, monthly descendant updates can disappear from attention, and the brief loader contradicts its PURE classification.

1. **Strengths**

- Verified the packaged manifest and all 83 non-adapter members byte-for-byte against the pinned Ariadne commit.
- Local proposal admission checks complete marker classification before effects and binds writes to the captured source bytes.
- README and atlas updates describe the revised interface, local question limitation, monthly layout, and historical presentation compatibility.

2. **Critical findings**

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: legacy-evidence-preservation
    title: |
      Ignored legacy map values disable valid chat protection
    detail: |
      lua/parley/skills/review/collaboration_value.lua:122 rejects an entire map when an unrelated value fails the old decoder. With collaboration-mode: {chat: [Notes], default: false}, the pinned Go readFrontmatter retains Notes as chat and notices the retired default; Lua instead reports unread frontmatter and produces zero chat sections. A production validate_edits probe then ALLOWED rewriting “operator text” in a numbered Notes item, while the same proposal without default: false was rejected. Preserve recognized chat evidence when processing ignored map values, match the pinned notices, and add admission regressions covering default and unrelated map members. ARCH-PURPOSE, ARCH-SECURE.
  - id: new
    severity: Critical
    kind: defect
    family: attention-event-admission
    title: |
      Rewritten monthly descendants require their parent to remain in the finder
    detail: |
      lua/parley/attention.lua:204 applies state.entries[parent] to rewritten events as well as new discoveries. After a monthly child leaves the finder, a tracked same-root grandchild stops reporting subsequent agent writes even while the root remains tracked. A filesystem-backed probe with a valid parent relation, seen_at=1500 and mtime=2000 produced a rewritten event from attention_model.scan but {} from Attention.discover. Separate admission of new attachments from updates to established entries; preserve the model’s rewrite event without requiring the parent’s continued finder membership. Add a sequence regression covering parent removal followed by a descendant rewrite. ARCH-ORDER, ARCH-PURPOSE.
  - id: new
    severity: Critical
    kind: defect
    family: core-concept-purity
    title: |
      The brief loader contradicts its PURE Core concepts classification
    detail: |
      workshop/plans/000419-collaborative-chat-interface-plan.md:37 lists brief.list/load/context under Pure entities, but lua/parley/skills/review/brief.lua:23 and :70 read files through io.open. tests/unit/review_brief_spec.lua:20 creates and deletes mutable filesystem fixtures. This violates the boundary’s explicit PURE classification rule. Promote the loader to INTEGRATION and document its filesystem seam, or extract pure validation/assembly functions and keep reads in a thin adapter. Add a Revisions entry correcting the table and test strategy. ARCH-PURE.
```

3. **Important findings**

None.

4. **Minor findings**

None.

5. **Test coverage notes**

- `make test-spec SPEC=modes/review` and `SPEC=ui/attention_finder` passed on Neovim 0.12.5, with clean process censuses.
- Additional isolated probes on Neovim 0.11.7 reproduced both behavioral findings.
- Existing tests omit ignored map-value combinations and parent-removal/rewrite sequences.
- `git diff --check` passed. Repository files were unchanged.

6. **Architectural notes for upcoming work**

| Principle | Result |
|---|---|
| ARCH-DRY | Pass: shared policy and edit transformation are reused. |
| ARCH-PURE | **Flag:** brief loader classification contradicts IO behavior. |
| ARCH-PURPOSE | **Flag:** legacy protection and monthly attention have gaps. |
| ARCH-MOCK | Pass: existing provider and filesystem-backed Couch seams are reused. |
| ARCH-CONSTRAINTS | Pass: snapshot limits, viewport bounds, and growth controls are present. |
| ARCH-SECURE | **Flag:** discarded legacy evidence weakens operator-text protection. |
| ARCH-ORDER | **Flag:** attention loses established rewrite events after parent removal. |
| ARCH-FUNERAL | Pass: no new unbounded runtime artifact family identified. |
| ARCH-EVOLVE | Pass: historical projection preserves stored presentation semantics without introducing a rewriting codec. |

7. **Plan revision recommendations**

Add `## Revisions` entries that:

- Correct the brief loader’s classification and filesystem test strategy.
- Enumerate ignored legacy map values and require retained chat evidence plus exact notices.
- Distinguish new side-document discovery from established-entry rewrites, including parent removal from the finder.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"606f5fc3-dd7f-4a21-a54c-773bff826083","repository":"github.com/xianxu/parley.nvim","issue_id":"000419","recipe":"milestone-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/8be23f625f3c5a55","reviewed_head":"27c670ca388c57ef20614adfed96242b34d894c2","slot":"parley.nvim:3","requested_at":"2026-10-24T17:48:29.372022Z"},"phase":"finished","pid":28154,"started_at":"2026-10-24T17:48:29.514339Z","finished_at":"2026-10-24T17:53:23.814925Z","session_id":"01a16f07-4537-7913-a8d1-1d3f31d50d67","outcome":"returned"}] -->

---

## Re-review — 2026-10-24T11:28:29-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 419 — unified-editorial-interface: typeahead for the mode keys and heading comments; conceal comments as badges |
| repo | parley.nvim |
| issue file | workshop/issues/000419-unified-editorial-interface-typeahead-for-the-mode-keys-and-heading-comments-conceal-comments-as-badges.md |
| boundary | whole-issue close |
| milestone | — |
| window | d1bb4ba89c0466ae17c02520afdbbfd705ff0537..d94a67415dfad7e2ea5319353574bdffe6f81bd1 |
| command | sdlc close --issue 419 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-24T11:28:29-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

All three prior findings are addressed with verified evidence. The pinned bundle, local admission, and attention regressions check out. One new blocking regression remains: deleting to the end of a tagged section can also delete the following section.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Production evidence/admission tests pass on both supported runtimes. Restoring pre-fix modules causes 71 evidence failures and six dispatch failures.
  - id: BR-2
    disposition: addressed
    note: |
      The parent-removal sequence passes on both runtimes; restoring pre-fix attention.lua makes that exact regression fail.
  - id: BR-3
    disposition: addressed
    note: |
      Plan line 52 now classifies brief.list/load/context as INTEGRATION, matching brief.lua filesystem reads. The Revisions entry explains the correction; filesystem tests moved to integration and pass.
findings:
  - id: new
    severity: Critical
    kind: defect
    family: section-ownership-through-operations
    title: |
      Tagged section deletion can consume the following section
    detail: |
      lua/parley/entity_range.lua:380 searches backward from found.first, which now points to the attached tag rather than its heading. For {"@@chat@@", "# First", "content", "# Second", "keep me"}, range(nil, lines, 2, {scope="to_end"}) returns first=1,last=5 instead of last=3. DeleteToEnd and daE therefore include the unrelated second section. With a preceding sibling, the same lookup instead returns nil. Preserve the semantic heading anchor independently of the widened source extent, and cover tag/heading cursor positions, preceding/following siblings, and native deletion/undo. ARCH-PURPOSE.
```

1. **Strengths**

   - Verified the manifest and all 83 packaged non-adapter members byte-for-byte against the pinned upstream commit.
   - Legacy-map regressions exercise production protection and visible refusal.
   - Attention tests distinguish established rewrites from new, retired, saved, and already-answered siblings.
   - README and atlas document the new interface and local question limitation.

2. **Critical findings**

   - The section-range defect above blocks shipping. Separate the heading’s semantic position from the attached tag’s source position.

3. **Important findings**

   None.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - `make test-spec SPEC=modes/review` passed on Neovim 0.12.5.
   - Focused head checks: 165 passed on 0.12.5; 135 passed on 0.11.7.
   - Both new section-range probes failed on 0.11.7; direct production probes reproduced the defect on 0.12.5.
   - Reverting prior fixes produced the expected regression failures. Disposable copy removed; reviewed checkout unchanged.

6. **Architectural notes**

   - **ARCH-DRY — pass:** shared policy and edit matching.
   - **ARCH-PURE — pass:** corrected loader classification; deterministic policy/proposal cores.
   - **ARCH-PURPOSE — flag:** section ownership does not survive `to_end`.
   - **ARCH-MOCK — pass:** stateful Couch fixtures exercise production seams.
   - **ARCH-CONSTRAINTS — pass:** snapshot limits and counted-growth controls.
   - **ARCH-SECURE — pass:** unread-map uncertainty refuses local mutation visibly.
   - **ARCH-ORDER — pass:** established rewrite admission has sequence coverage.
   - **ARCH-FUNERAL — pass:** no new persistent runtime owner.
   - **ARCH-EVOLVE — pass:** historical presentation remains separate from current keys; no new round rewrite path.

7. **Plan revision recommendations**

   Add a `## Revisions` entry requiring semantic heading anchors to remain independent of attached source extents, with a section-operation matrix covering `entity`/`to_end`, tag/heading cursor positions, sibling boundaries, and native deletion/undo.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"cdd95b36-6d1c-4bff-a097-d428e29ab3ff","repository":"github.com/xianxu/parley.nvim","issue_id":"000419","recipe":"milestone-review","round":2,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/5b4ce681b4bef229","reviewed_head":"d94a67415dfad7e2ea5319353574bdffe6f81bd1","slot":"parley.nvim:3","requested_at":"2026-10-24T18:22:50.33022Z"},"phase":"finished","pid":74973,"started_at":"2026-10-24T18:22:50.498377Z","finished_at":"2026-10-24T18:28:07.917416Z","session_id":"01a16f26-b989-7641-ac38-9639eaa4b16d","outcome":"returned"}] -->

---

## Re-review — 2026-10-24T11:50:13-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 419 — unified-editorial-interface: typeahead for the mode keys and heading comments; conceal comments as badges |
| repo | parley.nvim |
| issue file | workshop/issues/000419-unified-editorial-interface-typeahead-for-the-mode-keys-and-heading-comments-conceal-comments-as-badges.md |
| boundary | whole-issue close |
| milestone | — |
| window | d1bb4ba89c0466ae17c02520afdbbfd705ff0537..588a7b6f042e4e166a5095152515ab450721a872 |
| command | sdlc close --issue 419 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-24T11:50:13-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

The pinned implementation matches the active Spec, including its documented local-review limitation. BR-4 is addressed with reachable regression coverage: restoring the pre-fix range implementation causes 24 range tests and all 8 native deletion/undo tests to fail. No new blocking findings emerged. README and atlas updates cover the introduced surfaces.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Prior disposition retained. Evidence decoding preserves independent chat declarations; unread-map refusal reaches production admission, with both member orderings covered by regression tests.
  - id: BR-2
    disposition: addressed
    note: |
      Prior disposition retained. attention.lua preserves established rewritten events independently of parent membership; attention_finder_spec.lua:806 covers removed parents and unproven siblings.
  - id: BR-3
    disposition: addressed
    note: |
      Prior disposition retained. The plan classifies brief.list/load/context as filesystem INTEGRATION, matching brief.lua's io.open calls and the relocated temporary-folder tests.
  - id: BR-4
    disposition: addressed
    note: |
      entity_range.lua:137 retains a private semantic heading anchor, consumed by inner ranges and to_end lookup. Regression control produced 24 range failures and 8 native deletion/undo failures without the fix; corrected tests pass on both supported runtimes.
```

1. **Strengths**

   - Section source extents and semantic heading ownership are separated without changing the public range shape (`lua/parley/entity_range.lua:137`).
   - Local proposal validation requires complete marker classifications and checks protected-byte overlap before dispatch (`lua/parley/skills/review/local_proposal.lua:64`).
   - All 84 exported members were independently verified against the pinned Ariadne Git source and manifest digests.
   - Existing invocation, move, ownership, and persistence owners remain authoritative.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**

   - Passed `make test-spec SPEC=chat/entity_delete` on Neovim 0.12.5, including existing parity/textobject coverage and new native regressions.
   - Passed 213 focused tests on Neovim 0.11.7 covering ranges, deletion/undo, policy, structure, proposals, briefs, paths, and presentation.
   - Passed all 28 Python protocol-export tests.
   - BR-4 mutation control: **24 range failures plus 8 native failures without the fix**, zero test errors.
   - Harness process censuses were clean; tracked source remained unchanged. The complete repository suite was not rerun during this review.

6. **Architectural notes**

   - **ARCH-DRY — pass:** shared policy, range ownership, and edit matching serve their consumers.
   - **ARCH-PURE — pass:** policy/proposal/path/presentation logic is separated from structural and filesystem integration.
   - **ARCH-PURPOSE — pass:** consumer and template changes implement the active pivot and documented local exception.
   - **ARCH-MOCK — pass:** existing provider, embedded-editor, filesystem, and fake-Couch seams remain in use.
   - **ARCH-CONSTRAINTS — pass:** snapshot, viewport, span, and discovery bounds have corresponding controls.
   - **ARCH-SECURE — pass:** untrusted classifications and source bytes are checked before mutation; unread protection refuses visibly.
   - **ARCH-ORDER — pass:** existing generation, cancellation, and source-witness owners govern completion; controlled ordering tests cover stale outcomes.
   - **ARCH-FUNERAL — pass:** no new persistent runtime owner or growing artifact family is introduced.
   - **ARCH-EVOLVE — pass:** legacy documents remain intact; historical presentation is projected without rewriting opaque round fields.

7. **Plan revision recommendations:** None required.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"8b855448-d5e2-497a-bcac-d117827ab1a3","repository":"github.com/xianxu/parley.nvim","issue_id":"000419","recipe":"milestone-review","round":3,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/5f980e0a78d40c57","reviewed_head":"588a7b6f042e4e166a5095152515ab450721a872","slot":"parley.nvim:3","requested_at":"2026-10-24T18:44:29.227557Z"},"phase":"finished","pid":86714,"started_at":"2026-10-24T18:44:29.393915Z","finished_at":"2026-10-24T18:49:59.437797Z","session_id":"01a16f3a-8a20-7060-8f52-56f9d818bded","outcome":"returned"}] -->
