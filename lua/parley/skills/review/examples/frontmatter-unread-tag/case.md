# frontmatter-unread-tag

submitted: note.md
outcome: ok

A closed leading header that cannot be read (its closing fence is indented, so it is not YAML frontmatter) is still
a header (collaboration-modes.md §3 and §7, #581). The `@@chat@@` tag and `## Notes` inside it declare nothing, so
the body is not a chat section and its marker is an ordinary command: the paragraph is edited (scope s1) and the
marker removed. The header stays byte for byte, and the reply carries the unread-header notice.

## Reply

- Retries: added an example of the backoff.
- frontmatter could not be read, so any legacy mode keys in it were not read
