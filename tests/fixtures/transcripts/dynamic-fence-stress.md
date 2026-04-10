---
topic: fences
file: dynamic-fence-stress.md
model: claude-sonnet-4-6
provider: anthropic
---

💬: read example.md

🤖: [ClaudeAgentTools]
🔧: read_file id=toolu_F
```json
{"path":"example.md"}
```
📎: read_file id=toolu_F
`````
    1  ```lua
    2  local x = 1
    3  ```
    4  ````bash
    5  echo hi
    6  ````
`````
