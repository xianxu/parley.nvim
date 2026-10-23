# Review round

One round answers one operator submit of a markdown document. This file is
harness-neutral: it says what a round decides. How you read and write the file
is the adapter's job (`adapters/`). The marker grammar is
[review-convention.md](review-convention.md), the one authored copy; this file
uses its terms and restates none of it.

## 1. Inputs

- **The document:** the path in the request.
- **The settings:** read the document's single-valued `collaboration-mode`,
  `presentation-mode` and `processing-mode`, then its immediately-adjacent
  heading comments, from this snapshot on every round. Resolve each key by
  section comment, document frontmatter, then built-in default, as
  [collaboration-modes.md](collaboration-modes.md) §1–2 defines. Defaults are
  discussion / highlight / free-form. Never use frontmatter section maps for
  new documents; deprecated maps and aliases remain readable under that contract.
- **The instruction:** `processing-instruction:` is the operator's free text,
  separate from `processing-mode:`. It is read anew each round, not taken from
  a request message or cached across submits. The deprecated composite
  `process-instruction:` is a read alias; its leading selectors supply missing
  mode settings and its remaining text supplies a missing instruction (§2).
- **The changes since your last read:** what the operator (or anyone) changed
  in the document since you last read or wrote it, never your own edits. The
  adapter says how to get them. On a first read there are none: read the whole
  document.

## 2. Modes

The stock modes are the files in `modes/`, one per mode. Each has flat
frontmatter (`name`, `order`, `scope`, `frontier`) and a prose
brief.

- **Resolve the single `processing-mode` value:** an exact mode name wins. Otherwise the name must
  be a prefix of exactly one mode name (`copy-edit` is `copy-editing`). A
  name that prefixes several modes is ambiguous, and one that prefixes none is
  unknown. Either way, do no review: tell the operator which name failed and
  list the known modes (the files in `modes/`, by `order`).
- New `processing-mode` is **single-valued**: no list or combined selectors.
  Old `process-instruction: [name][name] text` remains readable with a deprecation
  warning: apply its briefs in order and use the first mode's flags. Automatic
  canonical fill refuses such a multi-mode document, preserving every byte and
  naming the operator's required choice; never drop a brief to make a scalar.
- **The operator's `processing-instruction` text** is part of the brief
  (what to edit, how much, how to reply), and wins where it is more
  specific than a mode's.

Worked processing examples (each is one frontmatter value, or one heading-comment assignment):

| Setting | Example work in its effective region |
|---|---|
| `processing-mode: developmental` | reorganize an argument before polishing its sentences |
| `processing-mode: line-editing` | tighten a wordy sentence while preserving its meaning |
| `processing-mode: copy-editing` | correct inconsistent terminology and grammar |
| `processing-mode: proofreading` | correct a typo without restructuring the paragraph |
| `processing-mode: fact-check` | verify a named claim and report unsupported statements |
| `processing-mode: free-form` | follow `processing-instruction: Explain the tradeoff` |

## 3. Directives from the first mode's flags

| Flag | Value | Directive |
|---|---|---|
| `scope` | `whole-doc` | Edit the whole document as the brief directs; markers are optional. |
| `scope` | `markers-only` | Confine edits to text that 🤖 markers refer to; leave the rest untouched. |
| `frontier` | `on` | Treat everything above the topmost human `🤖[…]` marker as settled: confine edits and findings to that marker and below. |
| `frontier` | `off` | No settled region. |

`presentation-mode:` is independently resolved for the edit's section on every
round: `direct`, `highlight` (the default), or `propose`. The old `presentation:`
key remains a deprecated read alias, not the spelling new writers emit.
It controls how the operator sees edits; it does not change a review mode's
scope or frontier. Build the intended clean edit before the adapter writes it.
Under `propose`, ordinary prose edits become marker proposals; never type
proposal marker syntax yourself. A rewrite too large or unencodable as markers
becomes a linked side-doc proposal by the adapter's refusal path. A side-doc
link that replaces the operator's ready request marker, or a fold-in requested
by `🤖[fold in]` at that link, applies directly: the operator already authorized
that structural action. The adapter checks the link or fold marker in the base
text; a normal `🤖[tighten this]` prose edit still becomes a proposal.
Frontmatter-only changes follow the adapter's dedicated path because
proposals cannot be placed inside frontmatter.
For an untracked document under effective `presentation-mode: propose`, the adapter refuses
the write until Couch tracks it or a hosted Pair workbench owns it. A link
made without a ready marker may itself be a pending proposal; its side doc and
index entry remain until the operator accepts or rejects it.

The frontier's edges: the topmost human marker is found outside fenced code,
and the text it refers to (§5) is on the open side. With no human marker, there
is no settled region.

The **edit region** is what these leave open: the whole document or only the
markers' text (`scope`), minus the settled region (`frontier`). A section's
processing override applies these flags within that section's extent, not to
sibling sections; nearer overrides delimit their own regions. Its presentation
override changes the write's display, not those processing flags or ask routing.

For the same imperative `🤖[tighten this]`, these are the worked presentation outcomes:

| Effective setting | Result |
|---|---|
| `presentation-mode: direct` | write the clean tightened sentence |
| `presentation-mode: highlight` | write the clean sentence and show the changed spans |
| `presentation-mode: propose` | let the adapter produce a proposal for the sentence; keep the original pending acceptance |

## 4. Collaboration modes

The review mode (§2, §3) says how an edit is made. A section's **collaboration
mode** says where an ask's answer goes: an edit, a linked side doc, or an answer
doc. [collaboration-modes.md](collaboration-modes.md) holds the modes; this
step applies them.

1. **Resolve** each section's `collaboration-mode:` with the shared precedence
   (collaboration-modes.md §1–2). An invalid value or malformed mode comment
   fails the round: change nothing and report it (§6). Legacy section maps are
   read with a deprecation warning and their existing conflict checks.
2. **Give each section its independent settings**, by its heading; omitted keys
   inherit without erasing the section's other axes (collaboration-modes.md §2).
3. **Find the asks** by each section's mode: the ready markers of §5 in the
   edit region, and, in a chat section, its new and changed items, whatever
   the edit region.
4. **Route each ask** by its section's mode (collaboration-modes.md §3).
   Collaboration is §5 as written. Discussion and chat may create side docs and
   fold into a parent; collaboration-modes.md §4 orders those writes.

## 5. Markers

Read every 🤖 marker in the edit region (§3), outside fenced code, per the
grammar.

- **Ready:** the marker's last turn is human (`[…]`); for an old chain, use its
  final human turn. Act on it as its section's collaboration mode says (§4);
  in collaboration mode, apply the
  asked change to the text the marker refers to, or answer the question. A marker
  with an anchor (`<X>` or `~D~`) refers to exactly that text; without one, to
  the text just before it, back to the previous paragraph, bullet or heading.
  Match the scale of the edit to the ask. Build the clean result; the document's
  `presentation-mode:` governs whether Couch writes it directly or as a proposal.
- **Done:** a ready marker whose ask you have fully carried out is removed. An
  answer is folded into clean prose (the grammar's §6 light-touch default), not
  narrated as a reply.
- **Unclear or longer exchange:** open a side doc with the question or context
  (collaboration-modes.md §4), replace the ready marker with its link, and add
  its `discussions:` entry in the same apply batch. Do not append a second turn.
- **Pending:** the last turn is an agent turn (`{…}`), whoever wrote it. Leave it
  for the operator.
- **Proposals** (`🤖~D~`, `🤖~D~{N}`, `🤖<X>{N}`, `🤖{N}`): never ready by
  themselves. Resolve them only when the operator asks (the grammar's §6).
- Every marker you write is single-line and has at most one commentary turn
  (`<br>` inside that turn for a line break). Read old multi-turn chains, but
  never extend them. Leave an agent-ended chain pending for the operator.

## 6. The reply

After the adapter has written the document, reply briefly in your own pane.
For a tracked document, list the round's edits from `round --json` spans. For
an untracked `direct` or `highlight` document, report the observed before/after diff
instead; no Couch round exists. Then name what you left for the operator (open questions, proposals
to accept or reject), each side doc or answer doc you created, extended or
relinked, every `collaboration-mode:` name that matches no heading, and every
orphan side doc (collaboration-modes.md §4). An error (an unknown review or
collaboration mode, a name under two collaboration modes, a refused write) is
reported the same way and leaves the document unchanged.
