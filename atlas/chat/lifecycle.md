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
