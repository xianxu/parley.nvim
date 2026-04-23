---
name: xx-voice-apply
description: Rewrite a document to match a personal writing voice/style. Usage: /xx-voice-apply <slug> <document-path>
---

# Voice Apply

Rewrites a document to match a specific writing voice, guided by a style guide.

## Arguments

- `<slug>` — voice identifier (e.g., `xian`). Resolves to `~/.personal/<slug>-writing-style.md`.
- `<document-path>` — path to the document to rewrite.

## Flow

1. **Resolve voice file:** Look for `~/.personal/<slug>-writing-style.md`.
   - If `~/.personal/` doesn't exist: tell the user to create it: `mkdir -p ~/.personal`
   - If the style file doesn't exist: tell the user to generate one first: `/xx-voice-gen <slug> <folder-of-sample-writing>`
   - Do NOT proceed without a valid style file.

2. **Read the style guide** — load the full voice file. This contains specific patterns, examples, vocabulary, sentence structure, and anti-patterns.

3. **Read the document** — load the target document.

4. **Rewrite in two passes:**
   - **Pass 1: Content audit.** Read the document for structure and argument. Do not change anything yet. Note which sections feel off-voice.
   - **Pass 2: Voice rewrite.** Rewrite the document applying the style guide. Preserve the content, structure, and meaning. Change the voice: sentence structure, word choices, openings, closings, transitions, emphasis patterns. Use specific patterns from the style guide, not vague "make it more conversational."

5. **Show the diff** — present the changes so the user can review before accepting.

## Rules

- **Preserve content.** The rewrite changes voice, not substance. Don't add or remove arguments, examples, or sections unless the style guide specifically calls for it (e.g., "never write long concluding summaries").
- **Be specific.** When applying a style pattern, you should be able to point to a rule in the style guide that justifies the change.
- **Don't over-apply.** Not every sentence needs every pattern. The style guide describes tendencies, not rigid rules. A document that hits every pattern in every paragraph will feel forced.
- **Respect the document type.** A letter to a CEO and a blog post have different constraints even in the same voice. Adapt the intensity of voice application to the context.
