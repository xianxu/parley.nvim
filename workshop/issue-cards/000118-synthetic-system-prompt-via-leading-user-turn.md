---
id: '000118'
status: done
created: 2026-05-04
updated: 2026-05-04
actual_hours: N/A
---

# synthetic system prompt via leading user turn

## Problem

For compatibility with providers / models that handle a real `system` field poorly (older completion-style endpoints, certain local proxies, some fine-tuned open models), let the agent opt into delivering the system prompt as a **synthetic leading user turn followed by a synthetic assistant ack**, instead of via the provider's `system` field.

The classic pattern:

```
user:       <system prompt content>
assistant:  Got it. I will follow this.
user:       <real first user turn>
...
```

The synthetic assistant ack ("Got it…") is more than ceremony — it puts the model in a state where it has *committed* to the rules, which empirically strengthens adherence on models trained without strong system-role priors.
