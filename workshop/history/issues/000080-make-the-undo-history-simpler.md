---
id: 000080
status: done
deps: []
created: 2026-04-08
updated: 2026-05-04
---

# make the undo history simpler

One of the power of parley is it's a text editor, so you can easily undo things, including agent's actions (e.g. what agent responded). One problem I'm facing is that after adding the status display inline when agent's using tools, we have a spinner. Each spinner update is a new state in the undo history, which makes it very hard to undo to the previous state before the agent response. We should make sure that the spinner updates don't create new states in the undo history.

## Done when

- A single `u` after an agent response returns the buffer to the pre-response state, regardless of how long the spinner ran.
- Streaming behavior unchanged.

## Plan

### Spec

The streaming path in `dispatcher.create_handler` already collapses N chunk-writes into one undo entry by calling `helpers.undojoin(buf)` before and after each chunk write (`lua/parley/dispatcher.lua:494, 538`). The spinner code never adopted the same convention, so each 90ms-cadence frame becomes its own undo entry — ~11/sec until streaming starts.

Fix: add `helpers.undojoin(buf)` calls at two spinner write sites:

1. `set_progress_indicator_line` in `chat_respond.lua` — before each `replace_line_at`. Joins every spinner frame into the previous undo block.
2. `clear_progress_indicator` in `chat_respond.lua` — before `delete_lines_after`. Joins the spinner-cleanup delete into the streaming undo block, so the whole agent response cycle (spinner + streaming + cleanup) collapses to a single undoable unit.

`helpers.undojoin` already pcall-swallows E790 ("nothing to undojoin"), so the very-first call on a fresh buffer is safe.

### Tasks

- [x] Add `helpers.undojoin(buf)` before `replace_line_at` in `set_progress_indicator_line`.
- [x] Add `helpers.undojoin(buf)` before `delete_lines_after` in `clear_progress_indicator`.
- [x] Fix `helpers.undojoin` buffer-context bug: wrap `vim.cmd.undojoin` in `nvim_buf_call(buf, ...)` so the marker reliably lands on the target buffer regardless of which buffer is current. (Discovered in second-pass debugging — see Log.)
- [x] Add `helpers.undojoin(buf)` to the topic-generation spinner in `generate_topic`. Was missing entirely; same pollution shape as the response spinner.
- [x] `make lint` clean. `make test` green except pre-existing keybindings_spec failure.
- [x] Manual verification: user confirmed a single `u` after a tool-using response returns the buffer to pre-submission state.

### Out of scope

- Option 1 (move spinner to extmark virt_lines) — bigger refactor that retires `kind="spinner"` from the model. Defer until a second instance of the same UI-in-buffer pollution appears.

## Log

### 2026-04-08

- Issue authored.

### 2026-05-04

- Investigated: the streaming path already uses `helpers.undojoin` to merge chunk writes; spinner code never adopted the same pattern. Two-call surgical fix in `chat_respond.lua` matches the existing convention.
- Considered option 1 (extmark virt_lines so spinner exits buffer text entirely) but landed on option 2 (undojoin) as the right scope for this issue: same pattern as streaming, ~5 lines, zero new mechanism. Concept-level cleanup left as a future option if a second similar pollution appears.
- **First-pass fix only partially worked** — user observed ~12 spinner entries still polluting the undo stack. Two additional findings during debugging:
  1. `helpers.undojoin(buf)` was calling `vim.cmd.undojoin` directly. `:undojoin` is a Vim command that operates on the *current* buffer; the `buf` parameter was only used for the loaded-check guard. When the spinner timer fired while focus had transiently moved (autocmds firing in another buffer, scheduled callbacks crossing windows), the join marker landed on the wrong buffer and the chat-buffer write created a fresh undo entry. Fix: wrap in `nvim_buf_call(buf, function() vim.cmd.undojoin() end)`. This benefits the streaming path too — that code probably worked-by-luck because users tend to stay focused on the chat buffer during streaming.
  2. The topic-generation spinner in `generate_topic` (chat_respond.lua ~805) had the same pollution shape and was missed in the first pass. Added the same undojoin pattern.
- After both fixes, user confirmed a single `u` returns the buffer to pre-submission state.

