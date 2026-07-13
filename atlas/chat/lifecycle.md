# Chat Lifecycle

## Creation (`:ParleyChatNew` / `<C-g>c`)
Creates timestamped `.md` in primary `chat_dir`. Multi-root: all roots scanned for discovery; new chats always in primary.

## Slug Rename (auto, on save)
When a chat's `topic:` header changes, the file is auto-renamed to include a slug: `YYYY-MM-DD.HH-MM-SS.mmm_slug-words.md`. The slug is derived from the topic (stop words stripped, kebab-case, max 5 words / 40 chars). The `_` separator ensures unambiguous parsing. References to old filenames resolve via fuzzy timestamp glob with read-repair of stale `🌿:` links. See `lua/parley/chat_slug.lua` for the pure slug logic.

## Move (`:ParleyChatMove`)
Moves entire chat tree (root + descendants) to another chat root; rewrites all `🌿:` references.

## Pruning (`<C-g>p`)
Splits current exchange + following into a new child chat with `🌿:` links. Async LLM topic generation.

## Response (`:ParleyChatRespond` / `<C-g><C-g>`)
Assembles context (with memory summarization), streams LLM response into buffer. The [exchange model](exchange_model.md) is the single source of truth for all buffer mutations during the response lifecycle — streaming text growth, tool block insertion, spinner management, and prompt append all go through the model. Concurrent guard prevents duplicate calls.

Pending responses also hold a per-buffer chat lease (`lua/parley/chat_lease.lua`) anchored on an `invalidate=true` extmark on the response's `🤖:` agent-header line (#138). Each async callback validates the lease before mutating the transcript; ordinary edits and streaming move the anchor and stay valid, while deleting that line — undo/redo of the inserted response, or removing the header — invalidates the lease, stops/suppresses late stream/tool/progress/topic writes, and prevents recursive tool resubmit from using a stale live model. (Pre-#138 the lease keyed on buffer `changedtick`, which mis-read Parley's own writes/spinner frames as drift; the extmark anchor makes `commit` a no-op.)

## Editing, Diagnostics, and Decoration Convergence

`lua/parley/buffer_lifecycle.lua` is the neutral owner of buffer convergence
events. It invokes diagnostics and highlight structure independently on
`InsertLeave`, normal `TextChanged`, `BufWritePost`, `BufEnter`, and `WinEnter`;
chat-response finalization enters the same coordinator after a mutated API leg.
The production `BufEnter` classifier installs the lifecycle synchronously, so a
new chat or Markdown buffer is fully converged before its first entry event
returns; unrelated helper-managed UI events may remain scheduled.
`BufUnload`/`BufDelete` tears down lifecycle, structure, and LineReader state so
obsolete callbacks and reused buffer handles are harmless.

Ordinary insert keystrokes do not rebuild document-wide timezone or managed
footnote diagnostics. Those diagnostics may remain stale during `TextChangedI`
and are synchronously current before the next convergence event returns.
Structural-marker edits mark decorations dirty in bounded changed-row work and
may suppress them until convergence; ordinary prose edits keep the current
structure valid.

`lua/parley/highlight_structure.lua` owns the pure canonical prefix/fence/tool/
reasoning structure. `lua/parley/highlighter.lua` keeps one buffer-owned
structure snapshot and per-window viewport decorations. A redraw reads only
the visible rows plus its fixed context/reasoning allowances, never scans the
whole document for a managed footer, and recomputes separately for scrolling or
multiple windows. `lua/parley/line_reader.lua` is the observable adapter for all
performance-sensitive buffer reads; the report-only `make perf` suite asserts
structural work bounds while treating elapsed timings as evidence rather than
CI budgets.

## Follow Cursor (`:ParleyToggleFollowCursor` / `<C-g>l`)
Toggles auto-follow of streaming insertion point.

## Resubmit All (`:ParleyChatRespondAll` / `<C-g>G`)
Resubmits all questions from start to cursor, replacing existing answers. Stop with `<C-g>x`.

## Context Assembly (Tree of Chat)
Child chats inject ancestor context by walking parent chain to root. Summaries replace full answers when available.

## Review (`:ParleyChatReview`)
Creates a new chat pre-filled with a proof-read prompt for the current file. Inserts a `🌿:` back-link into the source file's front matter pointing to the review chat.

## Deletion (`:ParleyChatDelete` / `<C-g>d`)
Deletes current file only (not children). Purges associated memory and cached metrics.
