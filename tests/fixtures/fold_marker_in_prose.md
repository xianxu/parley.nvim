---
topic: marker quoted in ordinary prose
file: fold_marker_in_prose.md
---

💬: how do I recognise a tool result in the transcript?

🤖: [A]

They look like this:

```text
📎: read_file id=example
```

That prefix is only structural at the top level.

💬: and a tool call?

🤖: [A]

🔧: read_file id=r1
```json
{"path":"x"}
```

📎: read_file id=r1
```
contents
```

📝: read the file

💬: thanks
