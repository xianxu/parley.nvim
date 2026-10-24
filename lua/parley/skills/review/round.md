# Review round

One round answers one operator submit of a markdown document. This file is
harness-neutral: it says what a round decides. How you read and write the file
is the adapter's job (`adapters/`). The marker grammar is
[review-convention.md](review-convention.md), the one authored copy; this file
uses its terms and restates none of it. The model it applies (one
collaborative mode, the `@@chat@@` carve-out, scope, legacy keys) is
[collaboration-modes.md](collaboration-modes.md).

## 1. Inputs

- **The document:** the path in the request.
- **Its structure:** read its `@@chat@@` sections, and any legacy mode keys,
  from this snapshot on every round (collaboration-modes.md §3, §7). Nothing
  else in the frontmatter steers the round: there is no mode, presentation,
  processing or instruction key. A legacy key is read as §7 says and noticed
  in the reply, never obeyed as a setting and never a reason to fail.
- **The changes since your last read:** what the operator (or anyone) changed
  in the document since you last read or wrote it, never your own edits. The
  adapter says how to get them. On a first read there are none: read the whole
  document. The operator's direct edits are content (collaboration-modes.md §1).

## 2. Briefs

The files in `briefs/` are named editing briefs: copy-editing, line-editing,
proofreading, developmental and fact-check. Load one when an ask calls for it
("copy edit this section", "proofread the document", "fact-check the
numbers"), by name or by the plain words for it, and follow it within the
ask's scope (§3). Without such an ask, use none: infer how to edit from what
the operator wrote. The operator's words win where they are more specific than
a brief's.

## 3. Scope

A command edits only what it is about (collaboration-modes.md §2): s1, the
marker's anchor or the current or preceding paragraph; s2, a section or the
document when the ask says so; s3, the whole document for a marker before the
first heading. Nothing else in the document is open to edits, and no brief
widens the scope by itself. A question has no scope: it opens a side doc.

Your edits are presented as highlight: build the clean edit, and the adapter
shows the operator what the machine last changed.
Never type proposal marker syntax yourself. A rewrite too large for one write still goes through the
adapter, which says what to do when it refuses.

## 4. Routing

1. **Find the asks:** the ready markers of §5, anywhere in the document, and,
   in each `@@chat@@` section (or legacy chat section), its new and changed
   items.
2. **Classify each marker** as a question or a command (collaboration-modes.md
   §1): when unsure, a question. Each chat item always gets an answer doc
   (§3 there), whether it asks or instructs.
3. **Act:** a question opens a side doc and its link replaces the marker; a
   command edits within its scope, records a decision, folds a discussion in,
   or acts elsewhere. collaboration-modes.md §4 orders the writes when a round
   creates side docs or folds into a parent.

## 5. Markers

Read every 🤖 marker outside fenced code, per the grammar.

- **Ready:** the marker's last turn is human (`[…]`); for an old chain, use its
  final human turn. Route it (§4). A marker with an anchor (`<X>` or `~D~`)
  refers to exactly that text; without one, to the text just before it, back
  to the previous paragraph, bullet or heading. Match the scale of the edit to
  the ask.
- **Done:** a command you have fully carried out is removed. Its result is the
  edited text, not a reply narrated in the document.
- **A question, an unclear command or a longer exchange:** open a side doc
  (collaboration-modes.md §4), replace the ready marker with its link, and add
  its `discussions:` entry in the same apply batch. Do not append a second
  turn.
- **Pending:** the last turn is an agent turn (`{…}`), whoever wrote it. Leave
  it for the operator.
- **Proposals** in an older document (`🤖~D~`, `🤖~D~{N}`, `🤖<X>{N}`,
  `🤖{N}`): never ready by themselves. Resolve them only when the operator asks
  (the grammar's §6).
- Every marker you write is single-line and has at most one commentary turn
  (`<br>` inside that turn for a line break). Read old multi-turn chains, but
  never extend them. Leave an agent-ended chain pending for the operator.

## 6. The reply

After the adapter has written the document, reply briefly in your own pane.
For a tracked document, list the round's edits from `round --json` spans. For
an untracked document, report the observed before/after diff instead; no Couch
round exists. Then name what you left for the operator (open questions,
pending markers), each side doc or answer doc you created, extended or
relinked, every misplaced `@@chat@@` tag, every legacy map name that matches no
heading, every orphan side doc (collaboration-modes.md §4), and the notice lines for
the legacy mode keys the document carries, worded as §7 there says. A refused write is
reported the same way and leaves the document unchanged; a mode key never is.
