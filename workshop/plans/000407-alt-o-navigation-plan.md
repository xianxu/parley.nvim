---
collaboration-mode: discussion
---

# Alt+O Markdown Navigation Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy). This records the hub-approved close-repair design; the original implementation entered through the quick flow.

**Goal:** Follow only the enclosing bullet item's references and match file fragments to structural heading text through shared canonical keys (latest approved Revision).

**Architecture:** Range/fence logic remains PURE. Parser-backed heading lookup is INTEGRATION, wrapping bundled markdown_inline and codepoint decoding; existing reference opening owns buffer/window effects and validates destination arrival. The latest Revision replaces inline-normalizer syntax rules with parser structure and one key on both sides. Shared lexical fence ownership retains render and partition contracts (ARCH-DRY).

**Tech Stack:** Lua, Neovim, existing Plenary/make harness and real embedded editor input.

## Core concepts

| Entity | Lives in | Status | Classification |
|---|---|---|---|
| Navigation block metadata | lua/parley/reference_candidates.lua | modified | PURE |
| Navigation range | lua/parley/entity_range.lua | modified | PURE |
| Code fence memo | lua/parley/document/lexical.lua | modified | PURE |
| Parser-backed heading lookup | lua/parley/markdown_heading.lua | modified | INTEGRATION |
| File destination plus fragment | lua/parley/issues.lua | modified | PURE |

Navigation owns one transient range per invocation; nested items are bounded by their enclosing indentation. The memo is one boolean per input row; its private opener retains delimiter character and run length. Heading lookup owns an invocation-local duplicate counter and a deferred candidate row; it prefers a complete canonical key and otherwise returns the selected duplicate. No persisted formats change; all temporary values end with the call (ARCH-FUNERAL, ARCH-EVOLVE).

| Integration | Lives in | Status | Wraps |
|---|---|---|---|
| Alt+O open and jump | lua/parley/init.lua | modified | Existing file-history/open_buf and Neovim cursor/view APIs |

Actual editor tests use tests/helpers/embedded_nvim.lua and real mappings/files. No new external binary/service is introduced. Pure range/fence tests live in tests/unit/entity_range_spec.lua and document_lexical_spec.lua. markdown_heading_spec.lua covers PURE level detection and parser-backed integration behavior under real headless Neovim.

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
- [x] Commit/push corrected code and record a fresh required suite on that exact head.

Final correction checks: /tmp/parley407-narrow-final.log passes the full mapped context/file_references selection and document_move_plan51/51, including preserved four-space scanner continuations and the new indentation ownership matrix. /tmp/parley407-narrow-lint.log passes818 files with0warnings/errors; git diff --check is clean. Required suite and close are pending.

### 2026-10-22 — Narrowed corrected-head suite complete

Required suite passed on0f58fb2ebe5c8414088acf323969d9da7484a557, attempt aa7b70d092639e85051983e51eb972a5, exit0 in317.3249s, SHA256862333076c811bfa93f74de3dca1b1ed74429e98feee9df9c48c9c592d768ff7. Re-close is next. Hub directs holding the merge until GitHub DNS recovery is confirmed; no stage.

### 2026-10-21 — Round 3 REWORK; replace the inline-normalizer architecture

Round3 accepts the narrowed HTML/entity scope and the shared BR-4 block rule, with all prior boundary families addressed. BR-1 remains Critical for supported Markdown: nested emphasis, code-span padding and quoted link-title parentheses, including their normalized duplicates (reviewer8/8 failures). Stop extending the hand-written normalizer. Hub delivery10c96539-cd20-4fa3-b3b4-dc21f58cbdb1 directs using bundled markdown_inline syntax structure and canonical matching. This supersedes the earlier raw-text-normalization implementation tasks; their checks record prior attempts, not this repair.

Proposed implementation, pending hub approval:

- Replace anchor_content and its delimiter indexes with an adapter around vim.treesitter.get_string_parser(text, markdown_inline, injections disabled). Walk syntax structure for visible heading text: retain text source spans, recurse through emphasis/code/link-label containers, and omit delimiter, link-destination and link-title spans. The actual bundled grammar represents ordinary text as gaps between children, not named text nodes; copy those gaps rather than relying on a nonexistent text-node type. HTML/entity rendering remains out of scope.
- Keep the existing ATX1–6 row enumeration and shared fence memo. Parser absence or parse failure uses the raw heading content through the same canonical key, without a second inline parser; a miss retains file-top plus notice. Adapter state is invocation-local, with no buffer creation, parser installation, persistent cache or background work (ARCH-FUNERAL, ARCH-CONSTRAINTS).
- Proposed canonical-key interpretation: lowercase and remove every non-letter/digit run from both extracted heading text and percent-decoded fragment. Thus one-two, one_two and one two share onetwo. This deliberately replaces exact GitHub slug reproduction. Empty keys do not match. This proposal assumes ASCII letter/digit keys for the currently tested English headings; confirm that boundary rather than inventing Unicode classification data.
- Duplicate numbering remains first occurrence bare key, second -1, third -2. Proposed resolution checks the complete fragment key first, then a trailing -N against the Nth duplicate, so the reported natural numeric suffix10-21-0040 remains a direct heading match. This precedence needs hub confirmation because natural numeric heading keys can collide with duplicate suffixes; do not guess it in code.
- Model parser-backed heading lookup as INTEGRATION (wraps bundled Neovim treesitter); canonical-key and duplicate selection remain PURE helpers. Test actual bundled grammar under headless make; force unavailable-parser behavior through one narrow injected adapter seam, preserving the public anchor_row call's default behavior.
- Add the reviewer's four first-occurrence cases and four duplicate cases before production changes. Cover parser-backed nested emphasis/links/code, raw fallback on missing grammar, canonical fragment equivalence, naturally numeric headings, duplicate suffixes, empty-key rejection, malformed syntax and existing unknown-anchor notice. Remove tests that require exact punctuation/underscore slug spelling now superseded by canonical matching. Preserve all shared fence/range/native tests.
- Run serial focused RED/GREEN and full mapped navigation tests, lint, fresh required recorded suite, then full re-close. If the next review finds another gap in this rule, return it to the hub instead of patching again, per the hub direction. No stage.

Design evidence: /tmp/parley407-parser-design.log, make -k with a temporary design-probe map, exit0. Bundled Neovim0.11.7 markdown_inline parsed all four reviewer cases structurally; link_title excludes its parenthesis from the visible label and nested emphasis ownership is explicit. No production edits have been made for this revision.

### 2026-10-21 — Parser/key plan approved with Unicode correction

Hub delivery9b6945ae-2054-4378-80d9-ee793674c844 approves the structural parser replacement and direct-full-key-before-duplicate precedence. Replace the proposed ASCII-only key with lowercase Unicode letters/digits, removing everything else on both sides. Empty keys never match. CJK and accented headings are required tests. No new Unicode data artifact is assumed; use an available Unicode-aware editor API, checking its actual behavior rather than assuming POSIX classes are Unicode.

The public parser-backed anchor lookup is now INTEGRATION, wrapping Neovim markdown_inline and Unicode normalization; outline/editing level remains PURE. Structural text extraction preserves source gaps between children, not nonexistent named text nodes; the destination/title/markup spans are omitted. Existing raw-text inline-normalizer tasks and exact-slug invariants are superseded by this revision. Real grammar tests run under the headless make harness; parser-unavailable behavior uses the single injected parse adapter. No persistent/editor-buffer state is introduced.

RED evidence: /tmp/parley407-parser-rule-red.log, make -k temporary map, exit2,16 failures including reviewer8 and newly required key/fallback/Unicode cases. An additional design probe /tmp/parley407-unicode-design.log proves Vim POSIX alnum is ASCII-only and unsuitable; select a verified Unicode-aware primitive before production key code.

### 2026-10-21 — Exact canonical rule simplified by the hub

Deliveryee127634-4137-417c-9b63-998d982fe878 supersedes general Unicode-letter classification: lowercase/keep ASCII letters and digits, drop other ASCII characters and U+2000–U+206F/U+3000–U+303F, and preserve every other non-ASCII codepoint unchanged. Apply this same compact key on both sides. No category table, word-class approximation or private ABI is used. Non-ASCII case is deliberately unchanged; unusual symbols outside those two ranges participate in the key, and a GitHub fragment that strips them may miss with the existing top+notice. Codepoint decoding is the only editor primitive the key needs. The parser-backed public lookup remains INTEGRATION, with the existing PURE outline/editing dialect untouched.

New rule RED: /tmp/parley407-parser-rule-red3.log, exit2,17 failures including reviewer8, required punctuation/Unicode/canonical behavior, direct numeric precedence, empty keys and parser fallback. Assertion adapters preserve explicit nil so RED shows missing/wrong rows rather than a luassert arity artifact. Proceed with this approved rule; do not patch a subsequent review gap without returning to the hub.

Current replacement verification:

- [x] Checkpoint the approved parser/codepoint rule and reviewer8 RED before replacing production normalization.
- [x] Replace handwritten inline normalization; parser/key focused checks pass33/33 in /tmp/parley407-parser-rule-green.log.
- [x] Pass the serial real-input counterfactual and full mapped tests, lint and whitespace checks; update shipped docs to the exact rule.
- [x] Commit/push the replacement and pass a fresh required recorded suite on its exact head.

Full re-close and normal landing follow those checks; a further rule gap from review goes to the hub.

Parser replacement verification: reviewer8 and canonical/fallback cases fail before replacement (/tmp/parley407-parser-rule-red3.log,17 failures); /tmp/parley407-parser-rule-green.log passes33/33 against actual bundled grammar. Native Unicode counterfactual fails4 mapping cases with the previous resolver, /tmp/parley407-native-rule-red.log; restored replacement passes the complete mapped context/file_references selection including native54/54, heading33/33, range256/256 and scanner22/22, /tmp/parley407-parser-mapped-green.log. Existing heading dialect conformance passes1/1; an initial consumer map named a nonexistent unit documentation path (load failure, not assertion/flake), corrected integration/documentation passes4/4 in /tmp/parley407-parser-docs.log. Lint passes818 files with0warnings/errors in /tmp/parley407-parser-lint.log; diff-check clean. No generated Unicode/HTML data, runtime dependencies or editor buffer state. Fresh recorded suite remains pending.

### 2026-10-22 — Parser/codepoint replacement suite complete

Recorded required suite passes on6dddbafefbc497873df9f87147a9839c59b96082, attempt d4c3cbfb60b5dc221e3b92784ca6c6fa, exit0 in290.1445s, log SHA2563bd0f2ce93b36fae91335d82028b2476539bd27180dd995d1aaf64c95c79607d. Full re-close is next. This evidence covers the replacement, unlike prior suites of the hand-written normalizer. Another rule gap from review goes to the hub, not another patch. No stage.

### 2026-10-22 — Round4 FIX-THEN-SHIP prose corrections

All behavioral findings are addressed. BR-5 replaces stale exact-GitHub-slug acceptance wording with the approved parser/codepoint key, fallback and full-key-before-duplicate contract in Done when. BR-6 corrects the atlas module classification. The Core concepts lifetime description now matches the implemented duplicate count/deferred candidate, replacing the superseded used-slug set. No executable changes or further rule gap; existing focused/full-suite proof remains applicable. Commit these prose corrections and finalize the pending close through issue recovery reconcile, then normal merge.
