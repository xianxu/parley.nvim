---
id: 000043
status: done
deps: []
created: 2026-03-31
updated: 2026-04-03
---

# proof read function <C-g>C should insert reference to the chat

this facilitate future navigation. put it as last line in front matter

## Resolution

`ChatReview` now finds the closing `---` of the source file's YAML front matter and inserts a `🌿: {chat-file}: proof read` reference line just before it. If the file has no front matter, no reference is inserted (graceful no-op).

## Done when

- [x] `<C-g>C` inserts chat reference in source file's front matter
- [x] Reference placed as last line before closing `---`
- [x] Uses existing `🌿:` branch prefix format
- [x] All tests pass
