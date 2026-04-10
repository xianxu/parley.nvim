---
topic: two rounds
file: two-round-tool-use.md
model: claude-sonnet-4-6
provider: anthropic
---

💬: read foo.txt and bar.txt

🤖: [ClaudeAgentTools]
🔧: read_file id=toolu_A
```json
{"path":"foo.txt"}
```
📎: read_file id=toolu_A
````
    1  hi from foo
````
🔧: read_file id=toolu_B
```json
{"path":"bar.txt"}
```
📎: read_file id=toolu_B
````
    1  hi from bar
````
