---
id: 000122
status: open
created: 2026-05-06
updated: 2026-05-06
---

# chat_finder: sort by real last-modified time

## Problem

The chat finder list order is currently surprising — chats whose filename creation timestamp is older than other chats sometimes appear "newer" in the list, with their bracket date `[YYYY-MM-DD]` not matching the filename's leading timestamp.

What I want is the **real last-modified time** of the conversation — the moment a question or response was last appended, not creation time, and not noise from sync or the editor opening the file.
