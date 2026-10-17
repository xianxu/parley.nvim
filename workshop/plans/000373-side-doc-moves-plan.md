---
collaboration-mode: discussion
---

# Side-document moves implementation plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach. Steps use checkbox syntax for tracking.

**Goal:** A registered document rename preserves its side-document links/index and displaces an orphan folder safely, with the same before/after fixtures as ariadne.

**Architecture:** Extend the existing pure move projection and forward-only leased migration journal. Import producer fixtures through the existing protocol snapshotter, while keeping them out of prompt composition. Parent disk/buffer changes are one witnessed migration stage, before metadata completion.

**Tech Stack:** Lua/Neovim, Python snapshot generator, filesystem adapter, persistent fake Couch registry.

## Dependency and approval gate

- Planning reference only: ariadne#424 branch `000424-side-docs-s3-the-discussions-index-link-removal-fold-in-from-the-parent-and-moves-that-carry-the-side-folder-skill-tl-lead-sdlc-archiving`, observed head `5990bf04a5d7cebb58dcf279b19e142ae3f2fe5f`.
- Read producer `construct/local/universal-review/export.json`, `pkg/reviewexport/move_test.go`, and exported move cases at that pin. Peer receipt e3fdf2bb-d218-4236-a922-de46e94fc86b confirms the contract and that no PR exists yet.
- NO code, generated snapshot, or test changes until #424 lands. Do not base on its branch. Verify its merge SHA, inspect any contract delta, record a Revision, then snapshot from the landed merge.
- Wait for TL approval of this full-flow plan; then `sdlc change-code --issue 373` owns plan-quality and estimate admission. Derive the estimate only when requested after plan-quality passes.

## Scope and policy

The scope is the existing registered-document mover (#332/#359), including owned move commands and native saveas recovery. Timestamp chat-slug renames and other documents' links are unchanged. The active document always owns its canonical `<stem>.side/` name.

The destination document must be absent for orphan displacement. Preserve existing explicit-overwrite behavior otherwise; if native saveas! overwrites an existing document whose side folder is occupied, do not label that folder an orphan or move it. Refuse the side migration visibly and retain recovery evidence. This intersection needs TL confirmation with the plan.

Rewrite the moving document's references even when its old side folder is absent: the rename still changes the canonical side path. Preserve other bytes. Use the current supported Markdown destinations and block `discussions:` entries (`- doc: relative/path`), including quoted scalars and comments that can be preserved exactly. An ambiguous relevant construct refuses before effects; never guess or apply a partial rewrite. Preserve existing child-backlink syntax support. Shared fixtures are mandatory minimal cases, not a replacement for those existing supported forms.

For old journals, read the current version-1 schema unchanged. New S3 journals use version 2 with explicit parent-rewrite and orphan-displacement records; validate by version, never infer missing progress as completed. Only a v2 journal can authorize new effects. Old v1 operations retain their original behavior and remain recoverable.

## Core concepts

| Name | Kind | Lives in | Status |
|---|---|---|---|
| Move projection and side path | PURE | `lua/parley/document_move_plan.lua` | modified |
| Parent side-reference rewrite | PURE | `lua/parley/document_move_plan.lua` | new |
| Migration transition model | PURE | `lua/parley/document_move_state.lua` | new |
| Validated protocol snapshot | PURE | `scripts/sync-review-protocol.py` | modified |
| Leased migration journal | INTEGRATION | `lua/parley/document_move.lua` | modified |
| Editor move handoff | INTEGRATION | `lua/parley/agentic_document.lua` | modified |
| Protocol source/output adapter | INTEGRATION | `scripts/sync-review-protocol.py` | modified |

The move projection owns path decisions and byte edits given complete observations; the IO adapter enumerates files, checks identities/hashes, and executes effects. Reuse `side_path`, `frontmatter.quoted_span`, Markdown candidate scanning and existing byte-span machinery instead of another path/YAML implementation (ARCH-DRY/PURE).

The journal owns one operation per namespace/document ID under the existing `document_lease` resource, including async metadata completion. Registry membership/rename stays behind `document_registry`, using the persistent fake Couch registry and its existing conformance seam (ARCH-MOCK). No new Couch verb or live provider is required.

## Export v2 contract

Accept manifest versions 1 and 2; reject booleans and unknown versions. Version 1 retains its old role set and optional collaboration member. Version 2 adds `fixture` records with safe case name and normalized `examples/<name>/...` paths. Require `name` to match the case component; admit only `case.md`, `before/<relative path>` and `after/<relative path>` shapes, no escape or duplicates. Validate every member's byte count/SHA before writing, including adapters excluded from snapshots.

Copy fixture bytes under the review snapshot's `examples/` directory, preserving manifest paths. Prompt composition remains round → grammar → collaboration modes; modes are selected as today and local adapter remains last. Neither fixture prose nor fixture documents enter SKILL.md or mode discovery. Provenance names the actual manifest version.

Extend generated-output ownership/preflight to examples recursively: no symlinks, special files, or writes through a symlinked directory; stale fixture files are reported and require explicit removal, just like stale modes. Legacy v1 exports remain accepted, but syncing one reports that it contains no move fixtures. The shipped snapshot test requires both move cases and validates their hashes. Tests discover cases via fixture manifest records, never a second handwritten case list.

## Move ordering and recovery (ARCH-ORDER)

1. Acquire existing document-ID lease. Capture canonical OLD/NEW identities, parent preimage, source tree, target-folder identity and chosen free suffix before effects. An occupied NEW document still refuses the owned move.
2. If target side folder exists, prove it was present at admission while NEW was absent and is a real directory. Record its inode witness, chosen suffix, and displacement progress in the journal. Never treat a later-arriving folder as that captured orphan.
3. Persist complete journal before effects. All renames use existing atomic no-replace operations; document-ID leases do not exclude another document targeting the same path, so filesystem no-replace publication is the cross-document authority.
4. Move captured orphan to its first free `<newstem>_N.side/`, then move document/source folder using existing ownership proofs. Recovery recognizes a published rename with a missing checkpoint only from recorded inode witnesses. Occupied/raced suffix or changed orphan leaves a visible pending operation; do not silently select a different destination after any effect without a persisted revision.
5. Apply child backlink edits and parent-reference edits under preimage CAS. Record independent checkpoints. Parent rewrite has before/after hashes and an authorized temp path in the journal, and recovery distinguishes before, after, and unknown bytes.
6. Synchronize loaded parent bytes, session baseline and journal NEW witness before returning a locally successful move or allowing save acknowledgement. Reuse existing hooks; add a dedicated parent-rewritten hook if needed rather than overloading `document_moved` with two meanings. A stale/modified buffer is preserved and leaves recovery pending; do not force-reload over edits.
7. Preserve `record_write` support while Couch metadata is pending: only an already-synchronized parent may adopt subsequent operator saves. Recovery must never reapply old parent edits onto newer operator bytes.
8. Confirm registry rename, finish existing local handoff, delete journal and owned temps, release lease. Report the full orphan destination through the existing notification surface; recovery may repeat an accurate pending notice but must never suffix the orphan twice.

### Authoritative v2 transition model (PQ-1)

`document_move_state.step(state, event)` is pure and returns the next state plus at most one requested effect or a pending/refusal outcome. `document_move_state.restore(record)` validates the persisted tagged state; `initial(intent)` starts it. The one mutable owner is an operation-local dispatcher in document_move.lua; all fresh and recovered v2 operations call that dispatcher. The shell never advances journal checkpoint fields itself. `journal.state` is replaced only from the dispatcher snapshot; existing v1 checkpoint handling remains in its compatibility branch. Add an architecture guard over v2 writes so a second checkpoint owner fails tests.

The phase names denote the next unproven effect, not a claim that an asynchronous call has finished:

| Phase | Proven observation/completion event | Next phase | Effect when proven not yet published |
|---|---|---|---|
| prepared | journal persisted | orphan | inspect captured orphan and chosen suffix |
| orphan | no displacement needed, or recorded orphan inode at suffix with canonical target vacant | document | no-replace rename captured orphan |
| document | owned rename/native write proven against captured witness | side | existing document move/adopt |
| side | canonical side tree has recorded source identity, or no source side tree was captured | children | no-replace source side rename |
| children | every required backlink projection proven after | parent | CAS next child rewrite |
| parent | parent bytes equal recorded rewrite after hash, or rewrite is a no-op | editor | CAS parent rewrite |
| editor | loaded bytes, baseline and NEW witness acknowledge the same parent generation | metadata | synchronize the editor without discarding edits |
| metadata | Couch confirms the expected ID and NEW path | complete | one registry rename request |
| complete | local finish and cleanup acknowledged | retired | delete journal/temps, release lease |

Events are discriminated records: `journal_saved`, `observed` (phase, proof = before/after/unknown, exact witness/generation), `effect_failed`, `editor_synced` (generation), `saved` (new hash/generation), `metadata_reply`, `cleanup_done`. A matching after-proof advances; before-proof permits the phase's effect; unknown/failed proof returns pending with the same phase. An event for an old phase/generation is ignored or refused without effects. `children` additionally records a bounded set of completed entry identities, not independent booleans. Invalid phase/progress combinations refuse restore.

`saved` is allowed only in metadata after editor synchronization; it replaces the current document witness without re-entering parent rewriting. Before editor synchronization it returns pending and cannot authorize a save acknowledgement. A refused/lost metadata response retains phase metadata; reopening re-observes filesystem/editor identity before replaying the same rename. Late callbacks are correlated with the operation generation and cannot mutate retired state.

Fresh and recovered paths restore the same model and feed it adapter observations; persisted before/after witnesses let a crash after publication but before checkpoint be recognized without repeating the rename. The existing document-ID lease owns dispatcher lifetime, while no-replace and CAS own cross-document/path exclusion. No new background task outlives the operation. Test controllable event sequences against preservation, legal ordering, single-publication, and stale-event invariants; IO tests inject publication/checkpoint failures through the existing fs adapter.

## Operator view

The phases above stay internal. The operator sees only:

| View | Meaning | Action |
|---|---|---|
| moving | Local move or metadata confirmation is active | Wait |
| done | Expected identity confirmed and local cleanup complete | None |
| interrupted | The journal is retained; a concrete reason names the missing proof | Reopen |

Reopen resumes and finishes from recorded witnesses. A refusal before any effect aborts cleanly. If bytes changed or remain unknown after effects, the operation stays interrupted with the same reopen action and a concrete reason; it never overwrites those bytes. No rollback beyond pre-effect abort, no repair menu, and no exposed phase/checkpoint names. The orphan destination is an informational result, not another required action. Existing v1 journal compatibility retains its validated on-disk behavior.

## Operating envelope and residue

This is an explicit user move, not a keystroke path. Retain current 4 MiB/file, 4096 entries, 512 Markdown children, 256 KiB journal and 32 pending-operation limits. Parent bytes are read once per observation/revalidation phase, not per link. Store hashes/paths/witnesses, not whole document copies, in the journal. Test limits and scale so large prose/whitespace cannot cause quadratic scans (ARCH-CONSTRAINTS).

Suffix search examines at most 4096 occupied candidates per admission; reaching the bound refuses before effects with a named limit. The no-replace syscall is still authoritative after probing. No unbounded loop on a busy UI thread. Seek TL approval for this new explicit budget.

Generated fixture trees are a fixed shipped snapshot replaced by a deliberate sync; stale outputs are refused. New temp files belong to the journal and are removed by existing cleanup; completed journals are deleted, unresolved journals retain the existing 32-operation cap. Orphan displacement renames existing bytes rather than copying or creating a new durable family; it is retained user content under the same deletion policy as other side docs. No automatic deletion (ARCH-FUNERAL).

## M1 — Export contract and pure projection boundary

**Files:**
- Modify `scripts/sync-review-protocol.py`, `tests/unit/review_protocol_export_test.py`.
- Regenerate `lua/parley/skills/review/export.json`, `SKILL.md`, canonical protocol files, and exported `examples/` only after producer lands.
- Modify `lua/parley/document_move_plan.lua`, `tests/unit/document_move_plan_spec.lua`.
- Create `lua/parley/document_move_state.lua` and `tests/unit/document_move_state_spec.lua` for the pure transition contract; the M2 adapter consumes it.
- Add `tests/unit/document_move_shared_spec.lua`; map it in `atlas/traceability.yaml`.

- [x] Verify #424 landed and pin its merge commit from Git. Re-read export and reference projection; append any contract delta as a Revision before coding.
- [x] Test `validate_manifest`, `render_snapshot`, `read_source` and `read_output` with malformed role/path/version/digest and symlink trees; mutation-free preflight plus deterministic snapshot comparison is the guard. Run `python3 -m unittest discover -s tests/unit -p review_protocol_export_test.py` red before implementation.
- [x] Implement minimal version-aware validation/snapshot ownership; sync from the pinned source and run `--check`. Verify deterministic output twice and all hashes.
- [x] Test new `rewrite_side_references(bytes, old, new)` and existing `rewrite_parent` with generated valid/ambiguous path/scalar/Markdown byte streams; exact untouched-byte comparison and relevant-syntax refusal are the guard. Test `project` with adversarial occupancy and canonical-path observations; all-or-nothing effects and first-free bounded suffix selection are the guard.
- [x] Extend the existing projection with the parent rewrite and orphan-displacement effects from supplied observations. No IO in the projection. Expose orphan destination in its result, not a parallel shell-only string.
- [x] Load every exported fixture group through manifest metadata, parse the bounded `move: OLD NEW` operation from case.md, project its before tree, and compare the complete path→bytes result to after. Run both fixtures without fixtures-specific expected strings. Include `_1` occupied → `_2` and empty-directory cases in supplemental local tests.
- [x] Implement/test `document_move_state.initial`, `restore`, and `step` with generated reordered/duplicated/stale event sequences; preservation and legal-phase invariants are the oracle, with the single-writer architecture guard enforced when M2 connects the adapter.
- [x] Use a temporary make target following Makefile.parley's `PREP_TEST_ENV`/`TEST_RUN`/orphan/sentinel recipe for the two pure specs; run serially. Confirm old projection fails the shared cases, then green.
- [ ] Complete recorded full-suite verification and `sdlc milestone-close --issue 373 --milestone M1`; address findings before M2. The contract candidate and atlas updates are prepared.

## M2 — Journal, editor handoff and acceptance boundary

**Files:**
- Modify `lua/parley/document_move.lua`, `lua/parley/agentic_document.lua`.
- Extend `tests/integration/document_move_spec.lua`, `tests/integration/agentic_document_owned_move_spec.lua`.
- Add fixture-driven actual-filesystem coverage in `tests/integration/document_move_shared_spec.lua`; map it in `atlas/traceability.yaml`.
- Inspect `lua/parley/init.lua` reference openers, `tests/integration/open_reference_spec.lua`, existing registry fake/helper.
- Update `README.md`, `atlas/modes/review.md`, and relevant existing mover atlas entries; keep `atlas/index.md` correct.

- [ ] Test `document_move.begin`, journal validation, `advance`, `recover` and `record_write` with forged/partially published operation histories; no-replace identity proofs, preimage CAS, and before/after complete-tree comparisons are the guard. Require v1 compatibility and v2 tagged-state validation.
- [ ] Extend journal creation/validation/recovery and no-replace orphan displacement as one coherent change. Preserve existing lease, inode, tree, preimage, size and symlink checks. Reject malicious forged orphan/temp/checkpoint tuples before any effects.
- [ ] Drive `advance`/`recover` with filesystem faults at publication/checkpoint boundaries and raced observations; retained journal plus byte/inode comparison proves exactly one displacement and no overwritten content.
- [ ] Drive `agentic_document.move_path`, native saveas handoff and recovery with adversarial editor/save/metadata interleavings through the persistent fake; buffer/disk/baseline generation agreement and preserved operator bytes are the guard.
- [ ] Implement parent synchronization hook and NEW witness update, then run focused tests red→green. Registry rename remains the final external confirmation after filesystem and editor stages.
- [ ] Execute exported before/after cases against the real mover in an isolated tree, with the existing fake registry. Compare all files byte-for-byte, including unchanged nested side doc and displaced orphan. Assert returned/visible displacement path.
- [ ] Audit Alt+o from a registered parent into a side doc through the actual opener and registry fake. If it registers, prove effective owner and child registration; if not, file a separate unclaimed same-repo issue with exact call-path and reproducible evidence, as this issue's Done-when allows. Report it to TL; do not silently expand into a registration feature.
- [ ] Run mapped review tests and focused mover/editor tests serially, lint, Python contracts, pinned sync `--check`, and diff whitespace checks. Record commands/counts and red→green evidence.
- [ ] Push candidate, run `sdlc local-check run --name suite`, inspect all failures under tl-worker's flake rule. Ask TL to sequence the real-config live check; no unapproved staging. Live check: rename registered design.md with a discussion link/index and an orphan spec.side, open the rewritten link, confirm spec_1.side unchanged, save/reopen, verify registry identity.
- [ ] Update documentation and Log; close M2 with its binary review, then `sdlc close --issue 373 --verified ...`. Merge current main and run `sdlc pr` → `sdlc merge --yes`, satisfying fresh CI/suite gates. Report Git-verified merge SHA/PR and any registration followup to hub; TL owns project ticks.

## Approval questions for TL

Confirm preserving the explicit-overwrite exception safely (no orphan displacement without pre-admission absent NEW), the 4096 suffix-probe bound, and the supported index syntax/refusal policy. These are the only proposed details beyond the operator's existing move contract. Code waits for both approval and #424 landing.

## Revisions

- 2026-10-17 — TL approved both milestones and all three policies (receipt 6d2d8e58-b402-4f59-af38-d945acb5c1af): bounded suffix search before effects, orphan classification only from pre-admission absent NEW, quoted/comment-preserving discussions scalars with refusal on ambiguity. This resolves the approval questions above; YAML is authoritative and disagreement refuses, matching #424. Implementation still waits for #424 to land.

- 2026-10-17 — Producer dependency landed: ariadne PR #284, Git-verified merge 5fa50f084f8062fafb493bec86b8207fc8f5617a. Diff against planning pin 5990bf04 shows no changes under construct/local/universal-review or pkg/reviewexport/move_test.go. This merge is the implementation snapshot pin; the dependency wait is satisfied. No scope or policy change.

- 2026-10-17 — Plan-quality round 1: PQ-1 required an authoritative recovery model; added the named pure v2 reducer, phase/event table, dispatcher ownership, stale-event and save-generation rules above. PQ-2 required function-level adversarial strategies; compressed checklist test inventories into named function contracts and mechanical guards. No implementation yet; request TL approval of this internal model clarification before rerunning change-code.

- 2026-10-17 — TL approved PQ-1/PQ-2 revision (1d0cc2d0-52f2-4a29-be12-f6cb80656c29) and clarified operator recovery (256baa18-a8de-4113-bf8b-a071b4bad7a6): moving/done/interrupted only; reopen resumes, pre-effect refusal aborts, unknown/changed bytes remain interrupted with reason and no overwrite. No post-effect rollback or repair menu. Added the explicit mapping above.

- 2026-10-17 — M1 scale regression through rewrite_side_references exposed quadratic backtracking in the reused reference_candidates.markdown_links pattern on 20KB unmatched opening brackets (/tmp/parley-373-scan-red.log: 37 pass, 1 CPU-bound failure). Preserve scanner matching semantics/spans but replace backtracking with monotone scanning, verified against the old pattern by generated differential inputs. This is the operating-envelope correction for the new whole-document consumer, not a syntax extension. Shared fixture checks live in integration/document_move_shared_spec.lua because their loader reads exported files; the projection itself remains pure.

- 2026-10-17 — M1 candidate implements the approved contract. Parent references resolve through the same canonical path helpers as backlinks, including absolute/dot-relative own-folder paths. The mapped review composition test now excludes the actual file-edit adapter heading rather than banning a Couch command mention from the newly imported canonical S3 prose. No local adapter behavior changed.

- 2026-10-17 10:54 PDT — Sequencing revision approved by TL (82d18b04-a8d1-44b8-9056-8a140b0351cc): M1 is the export, fixtures and consumed projection. Move the reducer module, its unit tests and traceability rows to M2 with its dispatcher, preserving the implementation at bbe6022fb37ff24edbd5e77190ac8c59b1d37ae2. This supersedes M1’s reducer file/checklist placement above: that checked implementation is deferred, not part of the M1 review window. The recorded suite correctly rejected an unconsumed runtime module; keep that guard unchanged. Runtime design, phase/event contract, estimate and scope are unchanged. Restore the reducer and tests from that commit only when M2 connects the dispatcher, and re-run their contracts plus the single-owner guard then.

- 2026-10-17 — M1 review round 1 requires the complete safety classes: paragraph-wide exact-width inline-code masking for both parent and child rewrites (including escaped runs, soft breaks, CRLF and paragraph/fence boundaries); expected regular-file leaves and directory ancestors checked before any output mutation (root protocol files, modes and fixtures); and complete-rewrite scale tests for malformed destination openers as well as opening brackets. These correct preservation/preflight/scale defects within the approved contract (ARCH-PURPOSE/SECURE/CONSTRAINTS). The Core concepts table’s move projection and exporter rows belong to M1; transition model, journal and editor handoff belong to M2 under the approved sequencing revision.
