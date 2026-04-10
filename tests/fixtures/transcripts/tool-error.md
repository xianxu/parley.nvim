---
topic: error
file: tool-error.md
model: claude-sonnet-4-6
provider: anthropic
---

💬: read /etc/hosts

🤖: [ClaudeAgentTools]
🔧: read_file id=toolu_E
```json
{"path":"/etc/hosts"}
```
📎: read_file id=toolu_E error=true
````
path /etc/hosts is outside working directory
````
