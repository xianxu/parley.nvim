---
topic: one round
file: one-round-tool-use.md
model: claude-sonnet-4-6
provider: anthropic
---

💬: read foo.txt

🤖: [ClaudeAgentTools]
🔧: read_file id=toolu_ABC
```json
{"path":"foo.txt"}
```
📎: read_file id=toolu_ABC
````
    1  hello world
````
