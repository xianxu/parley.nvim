---
id: '000047'
status: done
created: 2026-04-01
updated: 2026-05-04
actual_hours: N/A
---

# allow multi-line thinking (🧠) blocks

## Problem

The chat system prompt forces the `🧠:` thinking line to be a single
plaintext line with no newlines (`lua/parley/defaults.lua:6`). Models
fight this constraint in two failure modes:

1. They compress reasoning into one comma-spliced sentence that is hard
   to read and not actually reflective.
2. They give up on the constraint and trail reasoning into the answer
   body, defeating the separation that 🧠: was meant to provide.

The original framing of this issue (#47) proposed a full structured
output schema with XML/JSON wrappers around `<reply>/<thinking>/
<answer>/<summary>`. That has been rejected — provider parity is bad
(Anthropic has no native JSON schema; tool-call workarounds conflict
with free-form answer; OpenAI/Gemini have it but Copilot/Ollama vary),
streaming partial JSON is painful, and the visible 🧠/📝/👂 markers
are part of the on-disk chat format and are wired into folds, finder,
exporter, highlights, and memory. Replacing them is a large migration
for marginal correctness gain.

The narrow form of the original concern is: **let thinking span
multiple lines.** That is what this issue now covers.
