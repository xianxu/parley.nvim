# Review round

One round answers one operator submit of a markdown document. This file is
harness-neutral: it says what a round decides. How you read and write the file
is the adapter's job (`adapters/`). The marker grammar is
[review-convention.md](review-convention.md), the one authored copy; this file
uses its terms and restates none of it.

## 1. Inputs

- **The document:** the path in the request.
- **The instruction:** the document's frontmatter `process-instruction:` value,
  read from the file itself on every round (the operator may change it between
  rounds). Its form is `[name][name] free text`: each leading `[name]` names a
  mode, and the rest is the operator's own instruction for this round. With no
  frontmatter, no `process-instruction:`, or no `[name]`, the mode is
  `free-form`.
- **The changes since your last read:** what the operator (or anyone) changed
  in the document since you last read or wrote it, never your own edits. The
  adapter says how to get them. On a first read there are none: read the whole
  document.

## 2. Modes

The stock modes are the files in `modes/`, one per mode. Each has flat
frontmatter (`name`, `order`, `scope`, `deletions`, `frontier`) and a prose
brief.

- **Resolve each `[name]`:** an exact mode name wins. Otherwise the name must
  be a prefix of exactly one mode name (`[copy-edit]` is `copy-editing`). A
  name that prefixes several modes is ambiguous, and one that prefixes none is
  unknown. Either way, do no review: tell the operator which name failed and
  list the known modes (the files in `modes/`, by `order`).
- **Several modes:** apply every named mode's brief, in the order named. Only
  the **first** mode's flags govern the round, since one round has one set of
  directives.
- **The operator's text** after the names is part of the brief for the whole
  round (what to edit, how much, how to reply), and wins where it is more
  specific than a mode's.

## 3. Directives from the first mode's flags

| Flag | Value | Directive |
|---|---|---|
| `scope` | `whole-doc` | Edit the whole document as the brief directs; markers are optional. |
| `scope` | `markers-only` | Confine edits to text that 🤖 markers refer to; leave the rest untouched. |
| `frontier` | `on` | Treat everything above the topmost human `🤖[…]` marker as settled: confine edits and findings to that marker and below. |
| `frontier` | `off` | No settled region. |
| `deletions` | `apply-with-gutter-why` | Apply removals directly, and say why each went (in your reply, or a `🤖{…}` note beside the cut). |
| `deletions` | `apply` | Apply mechanical removals directly and silently. |
| `deletions` | `propose-strike` | Apply no removal or replacement yourself: propose each as a marker for the operator to accept or reject: a deletion as `🤖~D~`, a replacement in the form the grammar's §3 prefers. |

The frontier's edges: the topmost human marker is found outside fenced code,
and the text it refers to (§5) is on the open side. With no human marker, there
is no settled region.

The **edit region** is what these leave open: the whole document or only the
markers' text (`scope`), minus the settled region (`frontier`).

## 4. Collaboration modes

The review mode (§2, §3) says how an edit is made. A section's **collaboration
mode** says where an ask's answer goes: an edit, a linked side doc, or an answer
doc. [collaboration-modes.md](collaboration-modes.md) holds the modes; this
step applies them.

1. **Resolve** the frontmatter's `collaboration-mode:` (collaboration-modes.md
   §1, and §2 with its errors table). With no key, the whole document is
   discussion. A name listed under two modes, or a mode that is not one of the
   three, fails the round: change nothing and report it (§6).
2. **Give each section its mode**, by its heading (collaboration-modes.md §2).
3. **Find the asks** by each section's mode: the ready markers of §5 in the
   edit region, and, in a chat section, its new and changed items, whatever
   the edit region.
4. **Route each ask** by its section's mode (collaboration-modes.md §3).
   Collaboration is §5 as written. Discussion and chat may create side docs and
   fold into a parent; collaboration-modes.md §4 orders those writes.

## 5. Markers

Read every 🤖 marker in the edit region (§3), outside fenced code, per the
grammar.

- **Ready:** the chain's last turn is human (`[…]`). Act on it as its
  section's collaboration mode says (§4); in collaboration mode, apply the
  asked change to the text the marker refers to, or answer the question. A marker
  with an anchor (`<X>` or `~D~`) refers to exactly that text; without one, to
  the text just before it, back to the previous paragraph, bullet or heading.
  Match the scale of the edit to the ask. The ask is carried out under the
  first mode's `deletions` directive: under `propose-strike`, the change it
  asks for is written as a proposal marker in place of the human marker, and
  that proposal is the answer.
- **Done:** a ready marker whose ask you have fully carried out is removed. An
  answer is folded into clean prose (the grammar's §6 light-touch default), not
  narrated as a reply.
- **Unclear:** append a `{clarifying question}` turn to the marker and leave it.
- **Pending:** the last turn is an agent turn (`{…}`), whoever wrote it. Leave it
  for the operator.
- **Proposals** (`🤖~D~`, `🤖~D~{N}`, `🤖<X>{N}`, `🤖{N}`): never ready by
  themselves. Resolve them only when the operator asks (the grammar's §6).
- Every marker you write is single-line (`<br>` inside a turn for a line break).

## 6. The reply

After the adapter has written the document, reply briefly in your own pane:
what you changed and what you left for the operator (open questions, proposals
to accept or reject), each side doc or answer doc you created, extended or
relinked, every `collaboration-mode:` name that matches no heading, and every
orphan side doc (collaboration-modes.md §4). An error (an unknown review or
collaboration mode, a name under two collaboration modes, a refused write) is
reported the same way and leaves the document unchanged.
