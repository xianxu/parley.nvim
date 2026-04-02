---
id: 000047
status: open
deps: []
created: 2026-04-01
updated: 2026-04-01
---

# convert the parley generation into a more structured approach

Use output schema to constraint output, and do something like:

```
<reply>
  <thinking> ... for the 🧠: line </thinking>
  <answer> ... </answer>
  <summary> ... for the 📝: line </summary>
 </reply>
```

This way result would be more predictable. I don't remember if all LLM providers support schema, if they do, we can add comment in those schema as prompting hints.

## Done when

-

## Plan

- [ ]

## Log

### 2026-04-01

