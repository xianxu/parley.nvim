# Spec: UI Pickers

Custom `float_picker` for all selection UIs — no external dependencies. Two or three stacked floats: results + optional tag bar + prompt.

## Navigation
Up/down arrow keys wrap around at list boundaries (top wraps to bottom, bottom wraps to top).

## Fuzzy Search
AND-matching across whitespace-split tokens. Token-prefix scoring, bounded edit-distance typo tolerance, subsequence fallback. `{root}` / `[tag]` query tokens scope to bracketed haystack labels of the same kind; in-progress forms (`{char`, `[bu`) work the same way as their completed counterparts.

## Sticky Query
`lua/parley/finder_sticky.lua` extracts `{root}` (and `[tag]` for chat finder) fragments from the prompt on every keystroke and re-seeds them on the next reopen. Plain text is intentionally not preserved in chat, note, and vision finders. Issue Finder and Markdown Finder instead store their complete opaque prompt query verbatim in separate in-memory state, so plain text, structured filters, whitespace, and clearing to the empty string survive repaint and later invocations (#177, #187).

The chat finder additionally pre-seeds `{}` (the primary chat root, which in repo mode is the repo chat root) on the first open of a parley session in plain repo mode, so the default view is scoped to repo chats and global chats are filtered out. The pre-seed is a one-shot — once the user clears or modifies the filter, sticky-query takes over and the default is never re-applied. Skipped in super-repo mode (whose whole point is aggregating siblings, which a `{}` narrowing would defeat).

## Disk-backed loading lifecycle

`finder_scan` owns immutable discovery snapshots, canonical path identity,
outcome reduction, bounded diagnostics, and deterministic deduplication/sorting;
`finder_batcher` applies adapters in event-loop slices. `finder_producer` is the
single acquisition-to-settlement runner, and `finder_loader` owns lazy start,
picker/retained producer ownership, subscribers, cancellation, and settlement
delivery. Finder entry points remain responsible for their pure
recency/facet/render materializers.

`float_picker` can open with zero items and a nonselectable status row. Its
`picker_status` controller animates `scanning…` with `parley.progress` frames,
keeps the prompt live while loading, and tears its timer down when results,
failure, selection, or cancellation retires the status. The implementation
budgets are 25 adapted records or 5ms per slice, 16 concurrent filesystem
operations, ten 512-byte diagnostics, and a 120ms spinner tick.

Markdown, Chat, and Note Finders use this lifecycle (#189). Each opens and
subscribes before starting IO, atomically installs settled results, warns while
retaining rows on partial failure, and leaves a nonselectable error on total
failure. Esc cancels picker-owned acquisition, enrichment, batching, and the
subscription; late callbacks cannot repaint a closed picker. Chat and Note can
instead join an exact retained-prewarm fingerprint: cancellation then removes
only the picker subscriber while the cache-building owner continues. Issue and
Vision retain their existing discovery paths until their later #189 milestones.

Chat enumerates only dated Markdown names and reads ten header lines on cache
misses. Note recursively enumerates Markdown metadata without body reads. Both
apply recency only after raw records settle, update caches from adapted records,
and prune stale entries only for roots that enumerated successfully.

## Recall (Last Selection)
Pickers that opt in via `recall_key` remember the id of the last `<CR>`-confirmed item (in-memory only) and place the cursor there on the next open. `recall_id_fn` lets callers point at the stable identity field (defaults to `item.value`; e.g. `item.name` for agent_picker, `item.dir` for root_dir_picker). Stale recall (id no longer present in items) silently falls through to whatever `initial_index` resolves — typically the first item. Cancel/`<Esc>` does not update recall; only confirmation does. Storage lives on `float_picker._last_selection` keyed by the picker's `recall_key`.

## Tag Bar
Optional filterable bar between results and prompt. The canonical pure facet
state model is
`lua/parley/finder_facets.lua`: source/alphabetical discovery, contextual label
eligibility, immutable persistent-state merge/toggle/set-all transitions, OR
filtering, and picker-tag projection. Callers choose the facet domain, own its
state, and translate the model into the common `[ALL] [NONE] [facet…]` bar;
they carry no finder-specific wrapping logic.

`facet_bar_layout.build/hit` is the shared pure positional authority. It packs
buttons into deterministic display-width-aware rows and records semantic byte
and display-cell spans; rendering, highlights, and mouse hits all consume that
same model. The `float_picker` adapter injects Neovim extended-grapheme units,
renders the model, and dynamically sizes/reflows the results, facet, and prompt
floats on open, resize, and update. Facet activation transitions create or
remove the optional window, while the valid zero-height fallback retains the
logical model without opening an invalid float.

When vertical space caps the facet float, its buffer retains every row. Mouse
wheel input over the bar scrolls its viewport, and hit testing translates
visible screen coordinates through the window `topline` to model row/cell
coordinates; wheel input outside the bar falls through to Neovim. A bar that
fits on one visible row keeps the established presentation, callbacks, and
query-preserving update behavior.

Markdown Finder selects exactly one contextual domain. Ordinary mode shows
source-ordered top-level directory facets (when at least two exist), while an
eligible super-repo expansion shows alphabetically ordered repository facets
derived from the active member roots. Directory and repository choices persist
in separate state domains, so switching modes cannot reinterpret one as the
other. A facet toggle repaints rows and the bar in place without rewriting the
live prompt query; persisted NONE leaves the bar available even when no rows
remain.

## Picker Types
- **Agent** (`:ParleyAgent`): select active agent
- **System Prompt** (`:ParleySystemPrompt`): select active system prompt
- **Chat Finder** (`:ParleyChatFinder` / `<C-g>f`): asynchronously browse chats by recency, tags, and roots; joinable mtime-cached header prewarm; sticky filter fragments across reopens
- **Note Finder** (`:ParleyNoteFinder` / `<C-n>f`): asynchronously browse recursive note metadata with joinable prewarm; special folders bypass recency
- **Markdown Finder** (`:ParleyMarkdownFinder` / `<C-g>m`): browse repository Markdown by recency with contextual directory/repository facets and verbatim query persistence
- **Outline** (`:ParleySearchChat` / `:ParleyOutline`): jump to headings and turns
