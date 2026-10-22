---
collaboration-mode: discussion
---

# Alt+O Markdown Navigation Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy). This records the hub-approved close-repair design; the original implementation entered through the quick flow.

**Goal:** Follow only the enclosing bullet item's references and land file fragments on their rendered heading slug.

**Architecture:** Keep range, fence and slug decisions pure. Existing reference opening owns buffer/window effects and validates destination arrival. Repair fence state at its shared lexical owner (ARCH-DRY), retaining render and partition contracts.

**Tech Stack:** Lua, Neovim, existing Plenary/make harness and real embedded editor input.

## Core concepts

| Entity | Lives in | Status | Classification |
|---|---|---|---|
| Navigation block metadata | lua/parley/reference_candidates.lua | modified | PURE |
| Navigation range | lua/parley/entity_range.lua | modified | PURE |
| Code fence memo | lua/parley/document/lexical.lua | modified | PURE |
| Heading anchor lookup | lua/parley/markdown_heading.lua | new | PURE |
| File destination plus fragment | lua/parley/issues.lua | modified | PURE |

Navigation owns one transient range per invocation; nested items are bounded by their enclosing indentation. The memo is one boolean per input row; its private opener retains delimiter character and run length. Heading lookup owns a transient used-slug set so normalized duplicate headings get unique suffixes. No persisted formats change; all temporary values end with the call (ARCH-FUNERAL, ARCH-EVOLVE).

| Integration | Lives in | Status | Wraps |
|---|---|---|---|
| Alt+O open and jump | lua/parley/init.lua | modified | Existing file-history/open_buf and Neovim cursor/view APIs |

Actual editor tests use tests/helpers/embedded_nvim.lua and real mappings/files. No new external binary/service is introduced. Pure tests live in tests/unit/entity_range_spec.lua, document_lexical_spec.lua and markdown_heading_spec.lua.

## Approved repair tasks

### Heading normalization — BR-1

- [x] In markdown_heading.lua, normalize rendered inline content before the existing slug/duplicate pass: trim edges, preserve literal spaces as hyphens and remove other whitespace; retain content of Markdown emphasis, code and inline links while preserving literal underscores. HTML headings/inline tags and character-reference decoding are outside the narrowed scope (2026-10-21 Revision below).
- [x] Add regressions in tests/unit/markdown_heading_spec.lua for whitespace, formatting, code/escaped/intra-word underscore controls and duplicate normalized slugs. Run RED before correction and GREEN after, through make -k test-spec with a temporary MAP_FILE selecting this spec. Retain logs.

### Shared fence state — BR-2

- [x] Add RED cases in tests/unit/document_lexical_spec.lua for shorter backtick/tilde closers, mixed delimiter characters and a delimiter followed by non-whitespace.
- [x] Keep is_fence_delim's public return contract; private fence_parts supplies character and suffix. code_block_memo stores opener character/width and only clears it for a matching sufficient-length whitespace-only closer. Preserve custom partition resets, plain-Markdown mode and render/ordinary dialect functions.
- [x] Run GREEN for new cases and existing highlight_structure, outline, outline_parity, picker_items, copy_fence and entity_textobj tests using make -k and an isolated temporary test map. Check final process exit before recording evidence.

### Bullet boundaries — BR-3

- [x] Add range and real mapping RED cases: all three bullet markers with backtick and tilde dedented blocks must exclude outside links; indented fenced blocks retain inside links.
- [x] Detect a true fence opener using the shared memo's before/after state before excluding fenced content. A dedented opener ends the active item even without a blank separator; an indented opener remains in it.
- [x] Rerun make -k test-spec SPEC=context/file_references after all changes land together, plus make -k lint and git diff --check.

## Verification and landing

- [x] Update existing README/atlas guidance and issue Log for corrected behavior; commit the combined fixes and durable evidence, then push.
- [x] Run the required recorded suite on that exact pushed head: sdlc local-check run --name suite. Existing head's pass cannot cover repair changes.
Re-close with behavioral evidence; full boundary review applies if the patch leaves the quick-flow shell. Fix any remaining findings and refresh verification for changed code.
On SHIP, promptly run sdlc merge --yes; it owns current-main integration and authoritative suite. Report verified merge, tracker and archive to hub. No stage: hub updates operator checkout after landing.

## Constraints and visible outcomes

Actions: follow a link; retry with a corrected path/fragment. A found anchor shows its heading; an unknown anchor opens the file at top with a notice; a missing file retains the existing failure behavior. No file bytes are changed. Scans are linear in source/destination bytes plus item nesting; shared memo adds only constant state and work per line to its existing call sites. There are no new tasks, caches or durable records.

## Approval and provenance

The hub approved these three repair families in delivery d74a4811-e326-4a39-9e98-848ec3926df1, including testing existing shared-memo consumers. This durable plan was added when implementation sizing indicated the repair may leave the quick shell; it preserves that already-approved design and does not replace prior issue revisions.

## Revisions

### 2026-10-21 — Corrected-head suite complete

The corrected implementation passed its recorded suite. Re-close and landing remain follow-on gate actions written as prose; checking implementation tasks does not claim either gate has already completed.

### 2026-10-21 — Round 2: replace case patches with shared rules

Round2 accepts BR-2 and BR-3, but retains BR-1 for quoted HTML attributes and character references, and raises BR-4 in the repeated navigation-item-boundaries family. Prior green suites do not cover these new counterexamples. Reopen verification; no more isolated heading/bullet exceptions.

Proposed rule for item containment: derive navigation block openers from reference_candidates.markdown_blocks, the occurrence scanner's existing classifier. A block outside an item's content indentation ends it, including ATX headings1–6 (empty or not), thematic/setext walls, block quotes, sibling lists and fenced blocks. Indented counterparts remain owned by the item. Plain lazy continuations remain until a blank or outside block; editing ranges and numbered-item dispatch remain independent. Add the full3-marker ×6-level ×2-indentation ×2-heading-text sweep plus quote/wall/fence negatives and indented positive controls, and real mapping negatives.

~~Proposed rule for inline content: one quote-aware HTML-tag scan (greater-than inside quoted attributes is content), then a real character-reference decoder before slugging rendered text; code spans and backslash escapes keep their current protection. Numeric references cover decimal/hex and invalid-scalar behavior; named references need a complete finite lookup rather than another few hardcoded entity cases. No existing Lua decoder is present. Proposed bounded source artifact: a generated HTML5 named-reference table from the development Python standard library, with an explicit regeneration script/source metadata and reviewable diffs; runtime stays Lua-only. Use Unicode-aware deterministic case conversion where decoded letters need it. Normalize duplicates after this common pipeline.~~ Superseded by the hub’s narrowed scope below; no generated entity data or regeneration script will be added.

The simpler alternative—another pattern for quoted attributes and only a few named entities—fails the same class on the next valid entity or quoted delimiter. A new runtime renderer/library would add a dependency to every plugin user. A finite generated lookup and shared classifier keep ownership explicit. This proposal was sent for hub approval; the narrowed decision below supersedes the data-artifact proposal.

### 2026-10-21 — Hub narrows heading scope; shared block rule approved

Delivery8887bf7d-ec9d-40df-8c27-89b898c13b51 rejects the generated HTML5 table/script as beyond Alt+O's need. Current heading contract: Markdown ATX levels1–6, with inline Markdown formatting stripped (emphasis, code and inline-link labels, preserving literal content). Raw HTML headings/inline HTML and character-reference decoding are out of scope. Unsupported/unmatched anchors use the existing file-top notice; they do not require a new renderer or runtime dependency. Remove the prior incidental HTML-rendering branches and test unsupported forms plus code/escaped literal controls.

The hub approved the shared block-opener/content-indentation rule unchanged. Write the complete boundary matrix, observe RED, then implement metadata reuse and run all existing scanner/range/editor consumers serially. Retain prior shared-fence corrections. Fresh full suite and full re-close remain required; the reviewer must judge the narrowed contract, not the rejected HTML-rendering proposal.

### 2026-10-21 — Narrowed correction verification

The narrower heading contract failed first in /tmp/parley407-narrow-red.log; its pure GREEN run passed15/15 in /tmp/parley407-narrow-green.log. The boundary matrix failed first in /tmp/parley407-boundary-red.log, including real Normal/Insert wrong-destination failures. Shared opener metadata now drives content-indentation ownership; no entity data or HTML renderer is added. Verification is reopened for this correction; prior checked suite tasks describe the earlier reviewed attempt only.

- [x] Record approved scope and RED controls; implement shared block metadata and narrow heading normalization.
- [x] Pass serial mapped navigation tests and document-move scanner consumer; lint and whitespace checks.
- [ ] Commit/push corrected code and record a fresh required suite on that exact head.

Final correction checks: /tmp/parley407-narrow-final.log passes the full mapped context/file_references selection and document_move_plan51/51, including preserved four-space scanner continuations and the new indentation ownership matrix. /tmp/parley407-narrow-lint.log passes818 files with0warnings/errors; git diff --check is clean. Required suite and close are pending.
