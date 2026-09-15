# Question tag ownership implementation plan

> **For agentic workers:** Follow AGENTS.md §3. Context projection and outline integration can be delegated after the shared pure contract is established. One atomic review boundary; no milestone tags.

**Goal:** A whole-line tag immediately above a question labels that question in the outline and prefixes its user-role AI context, while `@@_@@` hides only the outline entry.

**Architecture:** Shared pure tag association supplies two projections: outline items and a context-only transcript snapshot. The physical parse, exchange model, buffer and navigation coordinates remain authoritative for editing. Existing parser and message emitters consume the context snapshot so flat answers, tool messages, summaries and ancestry do not need independent string-tail surgery.

**Tech stack:** Lua, Neovim, Plenary tests, existing parser/model/fence and provider-fake seams.

## Core concepts

| Name | Lives in | Kind | Status |
|---|---|---|---|
| `parse_tag` | lua/parley/question_tags.lua | PURE | new: whole-line nonempty @@…@@ text |
| `associations` | lua/parley/question_tags.lua | PURE | new: question row → immediately preceding eligible tag |
| `project_context` | lua/parley/question_tags.lua | superseded planned API | deleted |
| `apply_outline` | lua/parley/question_tags.lua | PURE | new: label/hide item projection |
| `initial_index` | lua/parley/question_tags.lua | PURE | new: item selection using file, question and tag rows |
| `context_view` | lua/parley/chat_parser.lua | superseded planned API | deleted |
| `parse_chat` | lua/parley/chat_parser.lua | PURE | modified: explicit exchange preface ownership |
| `compose_question` | lua/parley/question_tags.lua | PURE | new: preface plus literal question for AI context |
| `preface_start` | lua/parley/exchange_model.lua | PURE | new: derived preface start |
| `preface_end` | lua/parley/exchange_model.lua | PURE | new: derived preface end |

A question has at most one attached tag (its immediate predecessor). With consecutive tag lines, only the last can attach. Tag records carry raw spelling, label, tag row and question row. No blank-line tolerance. Existing whole-line delimiter behavior is retained; `_` is the exact anonymous label. Existing configured question prefixes and `highlight_structure.code_block_memo` define question/fence boundaries. Tags in headers or fences are ineligible. Ordinary inline @@text@@ is not a label. The same association map drives both projections (ARCH-DRY).

`project_context(lines, config, header_end)` returns nil when there are no associations, otherwise a fresh same-length line array: each attached tag's source element becomes empty; its question element contains the original user prefix followed by raw tag, newline, then original question text. The embedded newline is a virtual context string, NEVER written to the buffer or passed to physical rendering/model construction. Do not change question.line_start/end, question.content, answer.content, sections or semantic sections on the physical parse.

The physical parser records the optional projected snapshot as context-only metadata. `context_view(parsed, config)` returns the input when no projection exists, otherwise parses and memoizes that snapshot on the ephemeral parsed object. The projected parse has no remaining adjacent standalone tag to project; no recursive context chain. This reuses existing flat/tool/summary parsing without parallel context_content variants. Hand-built parsed fixtures without metadata remain compatible. The cache dies with its parse object; there is no buffer-global cache or invalidation lifecycle.

## Integration points

| Name | Lives in | Kind | Wraps |
|---|---|---|---|
| Flat/file outline builders | lua/parley/outline.lua | INTEGRATION | buffer/file reads, tree recursion |
| Picker preselection/navigation | lua/parley/outline.lua | INTEGRATION | float_picker and real Neovim cursor |
| Initial/live/ancestor/reference context | lua/parley/chat_respond.lua | INTEGRATION | parser, model snapshot, reference loaders, provider messages |
| Branch topic messages | lua/parley/init.lua | INTEGRATION | existing parsed Q/A topic request |
| Answer regeneration | lua/parley/buffer_edit.lua | INTEGRATION | existing answer deletion/survivors |
| User help | lua/parley/keybinding_registry.lua | PURE | existing help-line generation |

## Execution and verification

### 1. Shared rule and pure projections

- Add `tests/unit/question_tags_spec.lua` first and observe failure before implementation. Directly test each named pure function using hand-built lines/items: adjacency, anonymous labels, non-adjacency, first question, final empty prompt, consecutive tags, inline lookalikes, fenced lookalikes, configured prefixes, file-shaped tags and input immutability. Assert context raw tag appears once at the user's start and preserves array length/source indices.
- Implement `lua/parley/question_tags.lua`. Reuse the current fence/prefix classification; do not add another fence parser. Associations and projections run in O(lines + items), use transient tables and introduce no async work.
- Add the module to the existing pure architecture guard and route new tests/source in `atlas/traceability.yaml`.

### 2. Outline integration

- Add RED cases to `tests/unit/outline_parity_spec.lua` and `tests/unit/outline_spec.lua`: both builders agree on label/hide behavior; nested child indentation and file attribution survive; tag-line cursor preselects the merged question; Enter opens the actual question row; filtering sees the label only.
- Call `apply_outline` before trailing-empty-question removal in both builders. A merged row remains type question, keeps question lnum/file and records tag_lnum. Preserve source item tables rather than mutating shared inputs.
- A question containing an inline branch must still yield its question item plus branch rows, so an attached tag can label it. Cover this with a regression alongside the #241 same-line sibling cases; branch recursion and child-file destinations remain unchanged.
- The current tree picker always starts at index1; explicitly compute initial_index from the current file/cursor, matching tag_lnum or question lnum and falling back to the existing nearby-item behavior. Flat picker uses the same helper. Anonymous tags cannot become selectable hidden entries. Keep branch selection's #250 line1 destination.

### 3. Context integration without physical changes

- Add parse-vs-live parity cases in `tests/unit/build_messages_spec.lua`, parser/position cases in `tests/unit/parse_chat_spec.lua`, and ancestor cases in `tests/unit/ancestor_messages_spec.lua` (confirm existing path before editing). Use the actual parser, buffer/model and existing message emitters. Include plain and tool answers, summaries/window omission, first/final question, `_`, file references and raw-request mode.
- At physical `parse_chat` completion record only optional projected snapshot metadata. Implement `context_view` and ensure physical render/model data are unchanged in `tests/unit/exchange_model_spec.lua` and `tests/unit/render_buffer_roundtrip_spec.lua`.
- `build_messages` and `resolve_remote_references` consume the same context view. Reference-shaped tags use the existing `extract_file_refs`/retention/reference-loader rules. Avoid fetching unrelated resources or bypassing policy. Preserve the current raw-request behavior: decoded raw_payload must still be written to the physical question record that respond reads before dispatch.
- `_ancestor_messages` and branch topic-message assembly in init.lua consume context views, so all provider-facing Q/A projections agree. Topic generation already consuming built messages needs no second transform. Search all question.content/answer.content readers and document each consumer as physical rendering or provider context.
- `build_messages_from_model` takes one immutable buffer snapshot through the target exchange and the following question boundary, applies the same context projection, then reads its existing model block ranges from that snapshot. Keep physical model block starts/sizes unchanged. The lookahead must include an immediately following question so its tag is removed from the prior answer even when that next question is outside the requested context window. Use configured user-prefix stripping. No whole-buffer read or projection per streamed token.
- Assert no tag remains in assistant text/tool text/summary fallback and exactly one raw tag reaches its user message when that exchange is retained. Existing memory omission policy remains authoritative for omitted questions.

### 4. Preserve tags through regeneration

- Add a RED `tests/integration/chat_respond_spec.lua` case: two exchanges with a tag immediately before the second question; regenerate the first answer through the existing fake transport; confirm tag spelling, adjacency and second question survive after completion. Repeat for anonymous tag; preserve existing branch/private-note survivor tests.
- In `buffer_edit.delete_answer`, use the shared association map from a real snapshot to exclude the next question's attached tag from the doomed range. Leave it in place immediately before that question; do not append it to the old question's survivor block. Keep standalone unrelated tags' existing behavior. The full completion regression guards margin cleanup and model rebasing, not just the deletion helper.

### 5. Help, validation and review

- Extend chat/Markdown help generated by `keybinding_registry.help_lines`: adjacent tags replace question labels/search text; `_` hides outline entries only; blank lines break association. Document context ownership in `atlas/ui/outline.md` and the applicable chat lifecycle/context map, keeping atlas links and traceability current.
- Run targeted `make test-spec SPEC=ui/outline` and `make test-spec SPEC=chat/exchange_model`, plus mapped build-messages/ancestor/reference suites. Confirm new tests RED→GREEN, then `make test` and `git diff --check`. Stage new modules before the indexed fresh-clone checks.
- Preserve unrelated local defaults.lua and workshop chat edits. Full-suite packaging fake-chat tests are known to create synthetic workshop chats through inherited cwd; identify only files created by this run and verify exact synthetic contents before removing those artifacts.
- Record evidence, commit and run `sdlc close --issue 240 --verified '<evidence>'`. Address fresh-review findings, open a PR, and stop before merge unless requested.

## Architectural checks

- **ARCH-DRY/PURE:** one pure association and projection module, directly tested; context consumers reuse parser/message emitters.
- **ARCH-PURPOSE:** both outline and all AI-context paths implement question ownership; physical editing and resubmit preserve the tag.
- **ARCH-MOCK:** actual local files/buffers/model; existing transport fake for request/completion. No new external service.
- **ARCH-CONSTRAINTS:** linear transient scans per outline/context snapshot; projected parse memoized per parse instance, no streaming-chunk scan.
- **ARCH-SECURE:** file-reference grammar and loaders unchanged; references now belong to their following user question. Synthetic test roots avoid credentials.
- **ARCH-ORDER:** projection is synchronous and pure; remote reference and request/completion tests retain existing barriers. Physical parse is never replaced by a context parse in mutation code.
- **ARCH-FUNERAL:** context snapshots/cache die with parsed requests; no persisted metadata, timers or jobs. Tests delete their fixtures and stop fake transports through existing teardown.

## Revisions

### 2026-09-14 — Operator-directed exchange preface (authoritative design)

**Reason:** The operator explicitly requested an exchange `preface` field for authored material before a question. **Delta:** This section supersedes the virtual-snapshot architecture, `project_context`/`context_view`, context-snapshot parser metadata, and the context-only treatment of physical answer spans above. Those functions and metadata will NOT be implemented. Outline conventions and the rest of the approved behavior remain unchanged. Existing question spans stay anchored on the actual question line; the previous answer's span now correctly ends before the next exchange's preface.

#### Exchange representation

Parsed exchanges gain optional `preface = {line_start, line_end, content}`. Initially only one eligible immediately adjacent whole-line @@…@@ tag populates it. Store raw text, including delimiters; question.content remains the literal question text. This is a separate owned component, not text injected into a physical question line. Broader preface syntax is outside this change.

The live positional model gains optional `exchange.preface = {size}`. Its source range is derived relative to the existing question block: `preface_start(k) = block_start(k, 1) - preface.size`, `preface_end(k) = block_start(k, 1) - 1`. Keep `blocks[1]` as the question and exchange_start as the question anchor. Existing gap_before already counts the pre-question rows; preface identifies ownership within that leading material and MUST NOT be counted twice in exchange_total_size. Store no absolute coordinates or content in the live model. Tests must cover previous-answer growth/removal shifting preface and question together.

#### Current functions and files

- Keep `parse_tag`, `associations`, `apply_outline`, `initial_index` in question_tags.lua; add pure `compose_question(preface_content, question_content)` for provider-facing question text. Remove the planned context projection/view functions entirely.
- In chat_parser.parse_chat, classify associations before appending content. Do not feed an attached preface line into content_parts or cb_append_line. When the following question starts, finalize both the old component AND cb_attach_to_current_answer at preface.line_start-1. The latter rescans original source lines into semantic_sections, so skipping only the ordinary append would leave the tag in the previous live answer. Assign the preface record to the newly created exchange.
- Keep question.line_start/end and question.content unchanged. Previous answer content, content_blocks, semantic sections, summary/reasoning accumulation must all exclude the next exchange's preface. Earlier standalone tags remain ordinary content. Collect file references from preface plus question using the canonical extractor, keeping normal resolution, deduplication and retention rules.
- Extend exchange_model.from_parsed_chat to retain the optional preface size within existing gap_before. Add derived `preface_start` and `preface_end` methods; absent preface returns nil. No new answer-block kind and no index migration. Document the distinction between physical leading rows and their preface ownership in the model header and atlas.
- render_buffer.render_exchange emits preface lines before the question. render_buffer.positions exposes the optional preface span. Golden roundtrips must preserve the exact tag location once, including the first exchange and a final empty question.
- build_messages, build_ancestor_messages, branch topic-message assembly in init.lua, and build_messages_from_model call compose_question. Live continuation reads the model-derived preface span from the current buffer, then combines it with the question block. No virtual snapshot or parser cache is necessary. Raw request mode keeps its existing physical question record side effect.
- The initial parsed question's file_references includes preface references, so resolve_remote_references requires no parallel ownership rule. Test both local and remote-shaped tags using existing loaders/fakes and verify they are attributed to the following question only.
- Because previous answer.line_end excludes the preface, existing resubmit deletion should naturally preserve it. Do not add special tag filtering to buffer_edit.delete_answer unless the full regeneration test exposes another ownership bug. Test preceding-answer regeneration AND regeneration of the tagged question through completion, including margins and anonymous prefaces.
- Outline projection consumes the shared association; the tree may use parsed preface rows directly. Keep the earlier specified type/lnum/tag_lnum, search, preselection, anonymous, empty-placeholder and inline-branch rules.

#### Revised validation

Direct pure tests cover preface classification/composition, model-derived positions and movement, and outline item projection. Parser tests prove preface ownership and removal from every previous-answer representation, with first/last questions, strict adjacency, configured prefixes and fenced lookalikes. Existing render and model fixtures defend physical layout. Real parse/live/ancestor message parity proves raw preface appears once at the following user message start and never in prior assistant/tool/summary text; file-reference and raw-request tests defend their established contracts. Full resubmit tests prove preface survives both relevant regenerations. No externally observable change is accepted merely because the parser test passes.

The operator's field makes ownership explicit at the shared exchange boundary (ARCH-PURE/DRY/PURPOSE), replacing context-specific copies of the transcript. Preface metadata is ephemeral parsed/model data with existing lifetimes (ARCH-FUNERAL). The only new persistent content is what the operator already wrote in the chat.

### 2026-09-14 — Symbol table reconciled

Reason: keep the reviewable function inventory aligned with the operator-directed design. Delta: the Core concepts table marks discarded planned APIs deleted and lists the new preface functions; the superseded design prose remains above as revision history.

### 2026-09-14 — Complete ownership and function-level verification

Reason: plan-quality PQ-1 identified consecutive unanswered questions; PQ-2 requires function-specific adversarial strategies. Delta: the question START anchor and the receiving question's literal content remain unchanged. The PRECEDING component may be an answer or an unanswered question: its content and end span must shrink to exclude the next exchange's preface. This explicitly supersedes the earlier unconditional “question.line_start/end and question.content unchanged” wording. Every attached tag has exactly one owning exchange, independent of whether the preceding exchange has an answer.

The following strategies supersede the earlier enumerated test instructions (examples remain illustration only; concrete cases live in executable specs). Direct pure tests need no IO mocks; integrations use real Neovim/parser/files and existing transport fakes.

| Function | Adversarial input class | Mechanical guard/oracle |
|---|---|---|
| `parse_tag` | Generated delimiter boundaries and surrounding text | Accept only whole-line nonempty marker; preserve exact raw label |
| `associations` | Generated tag/question placements across configured prefixes, headers and fence boundaries | Exactly adjacent eligible tags attach once; no unrelated source row changes ownership |
| `compose_question` | Absent/present preface and arbitrary multiline literal question text | Raw prefix occurs exactly once; no mutation or delimiter rewriting |
| `apply_outline` | Hand-built ordered item streams with labels, hidden items and branch rows | Question identity/file/lnum/indent retained; only declared label/hide transformation; inputs unchanged |
| `initial_index` | Competing source/tag row matches in multiple files | Exact owning question selected; hidden rows never selectable |
| `parse_chat` | Transcript grammar compositions including consecutive unanswered questions and structured answers | Source-span partition assigns each preface once; all old-component text/sections end before it; real question markers remain at recorded starts |
| `preface_start`, `preface_end` and model position methods | Generated prior-block growth/removal and exchange gaps | Derived preface and question spans agree with source positions, shift together and never double-count |
| `render_exchange`, `positions` | Parsed transcripts with prefaces at each exchange boundary | Parse/render golden equality and agreement between exposed spans and source markers |
| `build_messages`, `build_messages_from_model`, ancestor/topic consumers | Same transcript through every context entry, including reference/raw-request/tool/window branches | Exact role/content parity and preface exactly once in its retained user message, never prior assistant; existing request side effects/policies retained |
| `question_picker` | Actual buffers/files with current cursor on tag/question/branch | Correct preselection and real navigation destination; effective filter matches displayed label |
| `respond` regeneration path | Both neighboring exchange resubmission orders through existing fake transport | Completion leaves preface spelling/adjacency intact and model/question anchors coherent |

Operating envelope (PQ-3): representative long interactive chat is 5,000 lines at roughly100 bytes/line (~0.5MB source). The new work is one linear association scan per physical parse/outline build and O(attached tags) metadata, with no durable cache or per-token work; strings are referenced rather than duplicating the transcript. Measure baseline/current parse+outline on 100,1,000,5,000-line synthetic transcripts, report medians rather than flaky timing assertions. Provisional incremental budget is20ms at5,000 lines on this development machine; exceeding it triggers profiling/replanning before close. Larger chats retain all content with linear cost (no silent truncation); no claim of an enforced document-size limit. This replaces all superseded snapshot-cache cost claims.

### 2026-09-14 — Preface cursor ownership

Reason: consumer sweep found both parser and init exchange-at-line helpers start at the question row; after extracting a preface they would either return no exchange or let an earlier unanswered-question margin claim it. Delta: use preface.line_start as the semantic ownership lower bound while retaining physical question starts, and stop an unanswered question's margin before the next preface. Parser find_section_at_line returns the owning exchange and no answer section for a preface. Test both helpers and the response selection path with cursor on preface. This completes the ownership change rather than introducing another navigation policy.
