# Chat Lifecycle

## Creation (`:ParleyChatNew` / `<C-g>c`)
- Creates `.md` in primary `chat_dir` with `YYYY-MM-DD` timestamp
- Multi-root: `chat_dirs` scanned for discovery; new chats always in primary `chat_dir`

## Move (`:ParleyChatMove`)
- Moves entire chat tree (root + descendants) to another registered chat root
- Rewrites all `🌿:` references; updates open buffers

## Pruning (`<C-g>p`)
- Moves cursor exchange + all following into new child chat
- Inserts `🌿:` reference in parent, parent back-link in child
- Async LLM topic generation with spinner on `topic: ?`

## Response (`:ParleyChatRespond` / `<C-g><C-g>`)
- Assembles context (with memory summarization), sends to LLM via curl, streams into buffer
- Web search: shows animated spinner/progress line above streamed text; removed on completion
- Concurrent guard: duplicate calls ignored; use `!` to force

## Follow Cursor (`:ParleyToggleFollowCursor` / `<C-g>l`)
- Toggles auto-follow of streaming insertion point
- On toggle-on mid-stream: jumps to current position
- On response finish: cursor stays at end of response text (not past appended prompt)

## Resubmit All (`:ParleyChatRespondAll` / `<C-g>G`)
- Resubmits all questions from start to cursor, replacing existing answers
- Stop with `:ParleyStop` (`<C-g>x`)

## Context Assembly (Tree of Chat)
- Child chats inject ancestor context: walks parent chain to root, collects Q+A up to branch point
- Summaries replace full answers when available

## Deletion (`:ParleyChatDelete` / `<C-g>d`)
- Deletes current file only (not children); dangling `🌿:` show `⚠️`
- Confirmation if `chat_confirm_delete` is true
- Purges associated memory and cached metrics
