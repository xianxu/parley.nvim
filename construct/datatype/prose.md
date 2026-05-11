---
type: type
name: prose
description: Use when the user wants to capture a pre-manuscript prose fragment tied to a specific long-running parent work (book, blog, essay, spec). The trigger always names a parent — "for X" — which distinguishes prose from `pensive` (standalone, no parent). Triggers on "capture this prose for X", "note this for X", "save this thought for X", "jot this for X". Heuristic: prose is a ledger (many fragments per file, sentence-to-paragraph each); pensive is a session (one topic per file, hundreds-to-thousands of words). If a prose entry grows past ~3 paragraphs and develops a thesis, graduate it to a pensive.
---

# prose

A *prose* artifact is a journal of pre-manuscript fragments — sentences and half-thoughts that came to mind for a specific long-running work (typically a `product`: a book, a blog, an essay, a spec) before they have a chapter or post to live in. Distinct from `pensive` (one focused thinking session per file): prose is a *ledger* of many fragments tied to one parent, appended over time, where entries graduate into the parent's drafts and leave the original behind as history.

## Frontmatter shape

| Field | Required | Notes |
|---|---|---|
| `type` | yes | `prose` |
| `parent` | yes | Relative path to the parent artifact this prose belongs to. Typically a `product` file in the same folder (e.g. `book-4.md`). One parent per prose file. |
| `created` | yes | ISO date the prose file was first written. |
| `updated` | yes | ISO date of the most recent entry. Bumped on each append. |
| `target_repo` | no | Path to a peer repo where graduated entries get published (e.g. `../xianxu.dev`). Used by the graduation step, not by capture. Inherited from the parent product when unset. |

## Body skeleton

An instance has:

1. `# <parent-slug> prose scratchpad` — title.
2. A short intro paragraph stating what the file is. Pattern: *"Rolling accumulator of prose fragments… not edited, not structured — raw input that may or may not survive to the manuscript. Newest entries on top."* Wording can vary; intent shouldn't.
3. A `**Format.**` line restating the entry shape (one or two sentences).
4. A `**Lifecycle.**` line restating the graduate-then-leave-as-history rule.
5. A `---` separator.
6. **Entries**, reverse-chronological (newest on top), each as:
   - `## YYYY-MM-DD HH:MM` — local time, minute precision. Multiple entries on the same day get distinct timestamps; don't merge into one block.
   - **`**topic:**`** (recommended) — short noun phrase summarizing the fragment.
   - **`**tag:**`** (recommended) — space-separated hashtags as loose grouping hints (e.g. `#ch-0-1 #voice #trust`). Not a schema; the same fragment may be tagged differently than a similar one elsewhere — that's fine.
   - **`**candidate home:**`** (optional) — short hint about where this might graduate (a chapter, a post slug, a section).
   - **Fragment body** — the user's words, in the user's voice. Verbatim by default.
   - **`*[framing — agent annotation]*`** sub-block (optional) — interpretive note the agent added alongside the fragment (why it's load-bearing, how it connects to other fragments). Visually set apart so the user's voice and the agent's analysis don't blur. Use sparingly.

Concrete example of a fully-shaped entry lives at `data/life/42shots/book-4/prose.md` (the brain that authored this prototype).

## Authoring instructions

When the dispatcher applies `prose.md`:

1. **Resolve the parent.**

   The trigger usually names the parent: *"capture this prose for book-4"*, *"note this for my personal blog"*. Find the parent product:

   - `rg -l "^type: product" | xargs rg -l "^name: <X>$"` for exact slug match.
   - Fuzzy match on the `name:` field if the user's reference doesn't match a slug exactly (e.g., "blog" → search descriptions).

   **Disambiguate when multiple products match** (e.g., "blog" matches both `xianxu-dev` and any 42shots-blog product): present 2–3 options with one-line context each and ask. Don't proceed without disambiguation.

   **No match:** ask whether to create a new product first, or capture as a `pensive` instead (pensive is a better fit when the thought isn't tied to a specific long-running work).

2. **Locate or create the prose file.**

   Default location: sibling to the parent product file. If parent is at `data/life/42shots/book-4/book-4.md`, prose at `data/life/42shots/book-4/prose.md`.

   - **File exists** → §7 update-existing flow from the dispatcher: append new entry.
   - **File doesn't exist** → create it with frontmatter, title, intro paragraph, format note, lifecycle note, `---` separator, then the first entry.

   **Special case — product in default file form.** Products without an entity-nested folder live at `data/product/<slug>.md` (the product datatype's default location). Adding prose graduates them to folder form: `data/product/<slug>/<slug>.md` + `data/product/<slug>/prose.md`. **State this consequence to the user before doing the move** — it changes the product's path and any pre-existing references to it need updating. The graduation is one `git mv` + an `rg` sweep; do it explicitly, don't silently relocate.

3. **Compose the entry.**

   - **Timestamp:** `date "+%Y-%m-%d %H:%M"` — local time, minute precision.
   - **Topic:** infer one short noun phrase from the content. If genuinely unclear, ask the user.
   - **Tags:** suggest 2–4 hashtags drawn from the fragment's content plus the parent's existing tag vocabulary (scan prior entries' `**tag:**` lines in the same prose.md). Loose, not enforced.
   - **Candidate home:** if there's an obvious chapter / post / section fit (the parent's component slugs, or a chapter slug if the parent is a book), suggest one. Otherwise leave blank.
   - **Fragment body:** the user's words. **Verbatim by default — don't paraphrase the author's voice.** Light editing only for typos if explicitly invited. The whole point of prose-capture is preserving voice as-spoken.
   - **Agent annotation:** if you have analytical context worth preserving (why this fragment is load-bearing, how it relates to other fragments, what thesis it seeds), append a `*[framing — agent annotation]*` sub-block. Use sparingly — the file is the user's accumulation, not the agent's commentary log.

4. **Append at the top.**

   Newest entries on top, oldest at the bottom. Insert the new entry between the `---` separator and the current top entry. Do not reorder existing entries.

5. **Update frontmatter.** Bump `updated:` to today's date.

6. **Don't ceremoniously confirm.** Confirm only the destination path if there was a disambiguation, then write. Prose capture is low-friction by design.

7. **Don't commit.** Per the dispatcher's universal rule, leave the file uncommitted for the user to review on their own schedule.

## Search recipes

```sh
# All prose files
rg -l "^type: prose"

# Prose for a specific parent
rg -l "^type: prose" | xargs rg -l "^parent:.*book-4"

# All entries on a specific date or month (across all prose files)
rg -l "^type: prose" | xargs rg "^## 2026-05"

# Entries tagged a particular way
rg -l "^type: prose" | xargs rg "^\*\*tag:\*\*.*\bvoice\b"

# Entries with a candidate home (i.e., the agent or user has identified a target)
rg -l "^type: prose" | xargs rg -B1 -A4 "^\*\*candidate home:\*\*"

# Tag vocabulary in use across one prose file (for tag-suggestion priming)
rg "^\*\*tag:\*\*" data/life/42shots/book-4/prose.md | tr ' ' '\n' | rg '^#' | sort -u

# Recent entries across all prose files (last seven days, by date pattern; adjust month/day range)
rg -l "^type: prose" | xargs rg "^## 2026-05-(0[5-9]|1[0-1])"

# Fragments whose body mentions a phrase (use case: "did I already capture something about X?")
rg -l "^type: prose" | xargs rg -i "financial advisor"
```

## Rules

- **One prose file per parent.** Multiple prose streams for one parent only when the single file genuinely gets unwieldy — use `prose-<subtopic>.md` siblings then, but don't design it up front.
- **Append-only history.** Old entries remain even after they graduate into a draft. Prose is the trace of how the thinking arrived; the draft is the artifact.
- **Author's voice in entries; agent's voice in annotations.** Keep the boundary visible. `*[framing — agent annotation]*` marks agent analysis so the file's voice doesn't blur.
- **Newest on top.** The file opens to the most recent thought. Don't reorder.
- **No reflowing of existing entries.** Edits should be surgical (append, occasional in-place correction on a single entry, never a wholesale rewrite).
- **Greppable headers.** `## YYYY-MM-DD HH:MM` enables date-range queries. Don't drift to free-form entry titles.
- **Tags are hints, not schema.** No registry, no validation, no enforcement. Re-using a tag across entries is good; coining a new one mid-stream is also fine.
- **Verbatim by default.** Capture preserves the author's exact phrasing. Don't sand the rough edges; the rough edges *are* the voice.
- **Prose vs pensive: session or ledger?** If a fragment grows past ~3 paragraphs and develops a thesis, it has become a thinking session — graduate it to a `pensive` rather than letting it bloat the prose file. If a putative pensive is dominated by one-line observations rather than connected argument, those observations should have been prose entries.
