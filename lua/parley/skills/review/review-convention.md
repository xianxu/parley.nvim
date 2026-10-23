---
type: target
slug: review-convention
status: active
created: 2026-05-23
updated: 2026-10-09
---

# Target: Review convention for human-robot collaboration in markdown

A single markup grammar that lets humans and robots converse, propose, and resolve changes inside a markdown file — the file itself stays the editing surface. The operator keeps narrative ownership; the robot contributes via inline markers the operator can accept or reject with one editor gesture each.

The same grammar covers every human-centric document across the ariadne family — targets, plans, atlas drafts, pensives, parley chats. Parley.nvim provides the human editing interface (marking, navigation, Alt+a / Alt+r). Coding environments like Claude Code (and `pair`, a peer-repo wrapper around Claude Code / Codex) participate in the same convention — appending `{}` to an existing chain, opening their own `🤖{}` proposals, or resolving chains under operator instruction per §5 and §6. The grammar is the contract between those tools and any other agent that later joins the conversation.

## Why now

Pieces of the convention already live in `construct/datatype/target.md` and are implemented across parley.nvim and xx-fix, but there is no canonical reference. With parley.nvim narrowed to the marking layer and human resolution, and Claude Code owning agentic resolution, the wire format between them needs one durable home. Drift between the two implementations would silently break documents in flight.

## What this is NOT

- Not a parser specification — tokenization details belong in the implementations (parley.nvim and xx-fix), not here.
- Not a UI framework — only the markup grammar is canonical; rendering, keymaps, and editor integration are tool-specific.
- Not a replacement for git-diff review — these markers iterate inside the file the operator is already editing; diff review remains a separate, complementary safety net.
- Not a turn-tracking protocol — `[]{}` chains express turn order positionally, but the file does not record identity, timestamps, or threading.

## Grammar

### 1. Leading character

Every marker begins with `🤖`. Anything after `🤖` up to the end of the marker's enclosures is the marker; surrounding prose is untouched.

### 2. Four enclosures

Two kinds of enclosures, used in two roles:

| Enclosure | Role | Meaning |
|---|---|---|
| `[H]` | commentary | human's comment or reply |
| `{R}` | commentary | robot's comment, suggestion, or insertion |
| `<X>` | reference | text quoted from the prior edition; preserved on resolve |
| `~X~` | reference | text from the prior edition marked for deletion; markdown strikethrough renders it as a visual deletion preview |

### 3. Combinations

A marker is `🤖` followed by an optional reference (`<X>` or `~X~`), then a chain of zero or more alternating `[]`/`{}` commentary blocks. Common forms:

- `🤖[H]` — human commentary, unanchored.
- `🤖<X>[H]` — human commentary anchored to referenced text X.
- `🤖<X>{R}` — robot proposes replacing quoted text X with R.
- `🤖{R}` — robot suggestion, typically an insertion of new text.
- `🤖[H]{R}` — human asks, robot replies.
- `🤖{R}[H]` — robot suggests, human replies.
- `🤖~D~` — robot proposes deleting D.
- `🤖~D~{N}` — robot proposes replacing D with N.
- `🤖~D~[N]` — human-authored replacement of D with N. Asymmetric: humans normally just edit directly and skip this form; included for completeness.
- `🤖[H₁]{R₁}[H₂]{R₂}…` — chains of dialogue can extend indefinitely. In practice they stay short.

A marker proposes an edit only when its first content block carries the change:
`🤖{N}` (insert), `🤖<X>{N}` or `🤖~D~{N}` (replace), `🤖~D~` (delete). Prefer
`🤖<X>{N}` for ordinary copy-edit replacements where rejecting should leave the
quoted text in place; use `🤖~D~{N}` when the deletion preview matters. Once a
`[]` opens the chain — e.g., `🤖[H]{R}`, `🤖<X>[H]{R}` — the marker is
commentary; accept and reject both discard the chain without touching
surrounding prose. The bare `🤖{N}` form is mildly ambiguous between "I'm
commenting" and "please insert N"; the operator's accept/reject gesture is what
disambiguates, and context tells the agent how to read it.

**One line.** A marker never spans lines: it opens and closes on the same line
of the file. A line break inside a `[]`/`{}` turn — a multi-paragraph proposal, a
two-line reply — is written `<br>` (`🤖{first line<br>second line}`), and
resolution turns it back into a real line break (§5). A literal `<br>` that
belongs in the text — a markdown table cell — is written `\<br>` inside a turn
and restored as `<br>`. An anchor (`<X>`, `~D~`) quotes a single line of the
document verbatim and is never encoded. Writers — humans, agents, tools —
always emit single-line markers; readers may still tolerate a legacy marker
that spans lines. Being line-local is what lets an editor render a marker
compactly and re-render it line by line.

### 4. `Alt+q` — insert human commentary (parley.nvim, pair's scrollback viewer)

| Selection | Inserted marker |
|---|---|
| text selected | `🤖<selected text>[human comment]` |
| nothing selected | `🤖[human comment]` |

A selection spanning lines is refused rather than quoted across a line break
(an anchor quotes a single line, §3).

### 5. `Alt+a` — accept marker, `Alt+r` — reject marker

Resolution collapses a marker into its final text. Text taken from a `[]`/`{}`
turn (`R`, `N` below) has each `<br>` turned back into a line break (and each
`\<br>` into a literal `<br>`); an
anchor's `X` or `D` is the document's own prose and is restored verbatim (a
markdown table may legitimately contain `<br>`):

| Marker | Accept to | Reject to |
|---|---|---|
| `🤖[H]` | *(empty — comment removed)* | *same* |
| `🤖<X>[H]` | `X` | *same* |
| `🤖<X>{R}` | `R` *(robot's replacement accepted)* | `X` |
| `🤖<X>[H]{R}` | `X` *(commentary chain discarded, anchor preserved)* | *same* |
| `🤖{R}` | `R` | *(empty)* |
| `🤖[H]{R}` | *(empty)* | *same* |
| `🤖{R}[H]` | *(empty)* | *same* |
| `🤖~D~` | *(empty — deletion accepted)* | `D` |
| `🤖~D~{N}` | `N` *(robot's replacement accepted)* | `D` |
| `🤖~D~[N]` | `N` *(human's replacement accepted)* | `D` |
| `🤖[]{}[]{}…[]{}` | *(empty — full conversation discarded, surrounding text untouched)* | same |

### 6. Agentic resolution (Claude Code / xx-fix)

When the operator asks an agent to resolve outstanding markers ("we're aligned, please resolve"), the agent walks each chain and reads the *last* commentary block — typically the trailing `[H]` if there's no further robot reply — interprets it as accept or reject, and applies §5. The agent does not unilaterally resolve markers the operator hasn't acknowledged; resolution is always operator-initiated.

One case *is* operator-initiated the moment it's written: a `🤖[H]` the operator authored **as a question or instruction directed at the agent** (per `AGENTS.base.md §1`). That marker is itself the operator's ask, so the agent answers it and resolves it in place *that same turn* — folding the answer into the prose and dropping the marker. This is not unilateral resolution of an unacknowledged marker; the operator's authored `[H]` *is* the acknowledgment.

**Fold into clean prose, not a narrated reply — the light-touch default.** When you resolve a `🤖[H]` by folding the answer in, the result must read as **clean documentation that stands on its own**, not as a reply to the operator: drop the meta ("a fair correction…", "this answers your question…", "as you noted…") — the reader of the finished document never saw the marker. This is the right default for any **light-touch review**: a document carrying a few `🤖[]` markers that is *not* going through xx-fix's full docflow (§ the heavier propose/review cycle). There the goal is simply a clean document, not a tracked review conversation — so resolve-and-fold, don't stage a dialogue.

## Revisions

- **2026-10-09** — markers are single-line; a line break inside a `[]`/`{}` turn is `<br>` (a literal one `\<br>`), decoded on resolve; anchors stay verbatim (§3 "One line", §5). Earned by parley.nvim#312, which renders markers compactly and opens chains in a thread view — both need a marker to be line-local, and agents write markers too, so the rule belongs here rather than in one editor.
- **2026-07-22** — added the "fold into clean prose, not a narrated reply" light-touch default to §6 (earned resolving light `🤖[]` review markers on a framing doc outside the full docflow — the first-pass resolutions had leaked reply-narration into the documentation prose).
