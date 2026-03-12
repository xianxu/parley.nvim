# Lessons

## 2026-03-07
- Avoid escaped-quote initialization inside Makefile shell recipes (e.g. `all_tests=\"\"`), which can become a literal token (`""`) and be treated as a filename.
- Prefer newline-producing helper commands plus plain `for` iteration over manually concatenating quoted strings in Make recipes.
- Always run the new Make target against at least one changed input path to catch recipe-level quoting bugs early.

## 2026-03-08
- When spec docs are changed, always run `make test-changed` before closing the task and report the result explicitly.
- For provider tool revisions, verify against the provider's own platform docs (not secondary references) and include exact revision strings before changing code/docs.
- Keep provider/model capability rules in `lua/parley/provider_params.lua` (or capability layer), not in `providers.lua` transport assembly code.
- For any non-trivial or multi-step request, write the concrete execution plan into `tasks/todo.md` before further implementation or reporting.
- After every code/config change, run `make lint` before handing back results; treat lint warnings as failures.

## 2026-03-09
- When a callback may run in Neovim fast-event context, never call direct `vim.api.nvim_*` buffer/window APIs there; gate with `vim.in_fast_event()` and defer UI updates via `vim.schedule`.
- For OpenAI/Codex streams, `reasoning_content` can be the only early activity while tool-call events are absent; progress UI must parse and surface reasoning-state cues, not only tool events.
- Normalize provider progress events to a shared shape (`kind`/`phase`/`message`) so UI logic stays provider-agnostic and avoids duplicated event-specific branching.
- When users ask to show actual server-event text, propagate raw progress text as a dedicated field (e.g. `progress_event.text`) and render from that, instead of only showing coarse event type/label strings.
- Apply the same raw-text rendering rule to tool progress events, not only reasoning events, so users can see tool query/url/input evolution in the status cue.
- When a user reports behavior changed after `git stash`, treat that as a strong causality signal: compare exact stash diff and affected runtime paths before concluding the issue is only model-side randomness
- For user-facing header names, prefer explicit semantic keys (e.g. `system_prompt`) over overloaded/internal terms (e.g. `role`), and preserve aliases for backward compatibility during transitions.
- If message assembly has a global whitespace trim pass, add explicit post-trim handling for fields that require terminal newlines (e.g. appended `system_prompt+` content), and assert that in tests.
- When live validation updates the status of one interaction path (for example, left/right now works), record that correction immediately and narrow the next change to the still-failing paths instead of treating the whole area as still broken.
- When anchoring picker content to a window edge, verify both the visual window options (for example `scrolloff`) and the actual buffer line count; row math based only on window height can look correct in tests but drift in live UI.
- Distinguish bottom-anchored initial placement from keyboard navigation behavior: selection reset may pin to the edge, but arrow-key movement should preserve the current view and only scroll when crossing a visible boundary.

## 2026-03-11
- When a UI bug reproduces only in live interaction, do not stop at helper-level or state-only tests; add runtime tracing on the actual event path before claiming the root cause.
- For bottom-anchored pickers, verify visual-row semantics against the real rendered selection path before mapping “next item” onto logical list indices.
