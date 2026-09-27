---
id: '000081'
status: done
created: 2026-04-08
updated: 2026-04-09
actual_hours: N/A
---

# support anthropic tool use protocol

## Problem

Foundation for evolving parley into an agentic environment. Scope: implement client-side tool use loop so the LLM can call tools (read/edit/write files, etc.) and parley executes them and feeds results back.

This is the first of a decomposed series from the original brainstorm. Once tool use exists, a `CLAUDE.md`-style constitution (#82) and a skill system (#83) largely become conventions rather than new machinery. Transcript-driven replay (#84) and file-reference freshness (#85) build on v1's data capture.

Original motivation (for context, not scope of this issue):
- Eventually have a `CLAUDE.md` constitution file for a personal assistant — [issue 000082](./000082-claude-md-constitution-file.md)
- Eventually have a skill system (folder of markdown pulled in on demand) — [issue 000083](./000083-skill-system.md)
- Foundation for a "1000 shot" personal assistant environment
