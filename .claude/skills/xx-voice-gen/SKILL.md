---
name: xx-voice-gen
description: Generate a writing style guide from sample writing. Usage: /xx-voice-gen <slug> <folder-path>
---

# Voice Gen

Analyzes a corpus of writing samples and generates a concrete, example-driven style guide.

## Arguments

- `<slug>` — voice identifier (e.g., `xian`). Output will be written to `~/.personal/<slug>-writing-style.md`.
- `<folder-path>` — path to a folder containing sample writing (markdown, text, etc.). Searched recursively.

## Flow

1. **Validate paths:**
   - If `~/.personal/` doesn't exist: create it with `mkdir -p ~/.personal`.
   - If `~/.personal/<slug>-writing-style.md` already exists: warn the user and ask whether to overwrite or abort.
   - If `<folder-path>` doesn't exist or contains no readable files: tell the user and abort.

2. **Discover samples:** Recursively find all markdown/text files in the folder. Report how many files found. Read at least 10-12 diverse samples for a reliable style profile. If fewer than 5 samples exist, warn that the guide may be thin.

3. **Analyze across these dimensions:**
   - **Openings** — how pieces start (question, anecdote, declarative, etc.). With examples.
   - **Sentence structure** — length distribution, fragments, complexity. With examples.
   - **Analogies and references** — style of metaphor, who gets quoted, how sources are cited. With examples.
   - **Vocabulary and diction** — register (formal/casual), signature words, verbal tics. With examples.
   - **Argument structure** — headers, lists, transitions, how arguments build. With examples.
   - **Tone** — hedging vs assertion, humor style, passion markers. With examples.
   - **Use of "I"** — personal perspective patterns. With examples.
   - **Closings** — how pieces end. With examples.
   - **Technical vs opinion writing** — how voice shifts between modes. With examples.
   - **Formatting habits** — bold, footnotes, parentheticals, links, code formatting. With examples.
   - **Paragraph rhythm** — length, pacing patterns. With examples.

4. **Write the style guide** to `~/.personal/<slug>-writing-style.md`. Structure:
   - One section per dimension above
   - **Every pattern backed by specific examples** pulled from the actual writing. Not "conversational tone" — instead: "Opens with a direct question or concrete scene, never with throat-clearing. Example: 'Consider what makes you happy.'"
   - A "Distinctive Patterns to Reproduce" section — numbered list of the most characteristic patterns
   - A "What NOT to Do" section — anti-patterns that would break the voice

5. **Report** — summarize the key findings. What makes this voice distinctive.

## Rules

- **Be specific, not vague.** "Conversational" is useless. "Uses 'pretty' as a casual intensifier: 'pretty technical,' 'pretty interesting'" is actionable.
- **Always cite examples** from the actual corpus. Every claim about the voice should have evidence.
- **Capture range.** Read diverse samples (technical, personal, opinion, etc.) to see how the voice adapts across contexts.
- **Note what's absent.** What the writer does NOT do is as important as what they do. If they never use "furthermore" or "in conclusion," say so.
- **The guide is for AI consumption.** It will be used by `/xx-voice-apply` to rewrite documents. Make it precise enough that an AI can operationalize it.
