---
id: 000049
status: done
deps: []
created: 2026-04-02
updated: 2026-04-03
---

# chat link behavior

I want to further tune chat link behavior. at some point, I changed it such that inserting into non-chat window of new chat link, it will use absolute link, on the ground that the chat doesn't exist relative to that non-chat file. However, this makes link just too verbose I feel. Now I think on balance, in non-chat file, we should insert using "relative" path, basically file name only.

When opening it though, we should look through all current registered chat roots, starting with the default root. chat files are largely unique, and the semantic we provided would move them around, not easily cloning them. so this should work reasonably well.


## Resolution

Three changes:

1. **`<C-g>i` in markdown files** — changed from absolute path (`:p`) to filename only (`:t`), matching chat-buffer behavior
2. **`resolve_chat_path` fallback** — when local directory resolution fails, searches all registered chat roots (`get_chat_dirs()`) starting with the default. Falls back to local path for downstream handling (e.g. creating new chats)
3. **`<C-g>o` in markdown files** — `open_chat_reference` now handles `🌿:` branch reference lines (previously only handled `@@` syntax and inline links). Also uses `resolve_chat_path` for `@@` references so they search chat roots too

## Done when

- [x] Non-chat files insert relative (filename only) chat references
- [x] Opening a relative chat reference searches all chat roots
- [x] `<C-g>o` works on `🌿:` lines in non-chat markdown files
- [x] All tests pass
