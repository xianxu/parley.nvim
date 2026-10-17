# Collaboration modes

A **collaboration mode** says *where the answer to an ask goes*. Each section of a document has one. The **review
mode** (`process-instruction:`, [round.md](round.md) §2 and §3) says *how an edit is made*. They are separate axes,
with separate frontmatter keys. Call them "collaboration mode" and "review mode", never just "mode", when the
difference matters.

| Mode | An ask is answered by |
|---|---|
| **discussion** (the default) | an edit for an imperative, honoring an instruction that only acts, a one-line record for a decision, or a linked **side doc** for a question |
| **collaboration** | an edit or an answer **in place**, folded into clean prose |
| **chat** | a linked, dated **answer doc** for each list item |

This file is harness-neutral, like round.md: it says what a round decides. How files are read and written is the
adapter's job. The marker grammar is [review-convention.md](review-convention.md); this file uses its terms and
restates none of it.

## 1. The frontmatter

```yaml
collaboration-mode:
  default: discussion                        # optional; discussion when absent
  chat: ["Operator instructions"]            # headings answered in chat mode
  collaboration: ["Notes"]                   # headings answered in place
```

- The flow form is the same value: `collaboration-mode: {default: discussion, chat: ["Operator instructions"]}`.
- A bare scalar sets the default for the whole document: `collaboration-mode: collaboration`.
- With no `collaboration-mode:` key, the whole document is discussion.
- Read it from the round's snapshot every round, as the review mode is: the operator may change it between rounds.

## 2. Sections

1. **Find the headings:** every ATX heading (`#` to `######`) outside fenced code. A heading inside a code fence is
   text, not a heading.
2. **Match a name to a heading** by its text, at any level. Compare after lowercasing, collapsing each run of
   whitespace to one space, trimming, and dropping one trailing parenthesised annotation: `### Operator instructions
   (open)` matches `"Operator instructions"`. When two headings share a name, both take the mode.
3. **A named section** runs from its heading to the next heading of the same or a higher level. Its subsections
   take its mode unless they are named themselves, and then the nearer name wins.
4. **Everything else** takes the default, including text above the first heading.

Errors. A failed round writes nothing to an untracked document; a tracked one gets its snapshot written back as
read, which folds the submit, since the reply answered it. When the review mode is bad too, report both.

| Case | The round |
|---|---|
| a name listed under two modes, compared as in step 2 (`"Notes"` and `"notes"` are one name) | **fails**: change nothing, and name the heading and both modes in the reply |
| a mode other than `discussion`, `collaboration`, `chat` (as a key, or as `default` or the bare scalar) | **fails**: change nothing, name the bad mode, and list the three |
| a name that matches no heading | proceeds with the default there, and the reply names it: "`collaboration-mode.chat` names 'Operator instrucions', which matches no heading" |

## 3. The three modes

What every mode keeps from round.md §5:
- Proposals (`🤖~D~`, `🤖~D~{N}`, `🤖<X>{N}`, `🤖{N}`) are never ready by themselves.
- A pending marker (its last turn is an agent turn) is left for the operator.
- Every marker written is a single line.
- A review mode with `scope: whole-doc` still makes its own pass, as its brief directs: that brief is the operator's
  ask too. A collaboration mode changes only where a marker's or an item's answer goes, never whether the review
  mode's pass runs.

### discussion

Each ready 🤖 marker is an ask. Classify it, then act:

| The ask | What you do |
|---|---|
| an **imperative**: a change to the text ("tighten this", "add an example", "can you shorten this?", "fold in" beside a `→ [discussion]` link) | edit the text the marker refers to (round.md §5), under the review mode's directives, and remove the marker. Under `deletions: propose-strike` the edit becomes a proposal marker, as round.md §5 says |
| an imperative that is **unclear in a small way**, whose readings fit in one line | append a `{clarifying question}` turn to the marker ("{the latency numbers or the cost numbers?}") and leave it |
| an **instruction that only acts** | honor it (below) |
| a **decision** or an approval: an answer to a question the text put to the operator ("first in the section", "yes, Friday", "ok") | record it in one line and carry it out (below) |
| anything else: a **question**, "why…?", "let's think about…", a request whose outcome is not yet an edit | open a **side doc** (§4) and replace the marker with `→ [discussion](<name>.side/NN-slug.md)` |

- **The rule is strict.** Every question branches, even a small factual one ("is this number right?"). Never answer a
  question in the document's prose. The operator phrases an imperative ("check this number and fix it") to get an
  edit, or names the section collaboration.
- **When unsure, open a side doc.** It never changes the document unasked, and folding it in later costs one
  marker. "The retry story feels off" opens a side doc that proposes what is off.
- **A fold-in asked from the parent** (🤖[fold in] beside a `→ [discussion](…)` link) is an imperative: edit the
  parent from what the side doc concluded, and mark the link `(folded <date>)`. It is the same fold-in as an
  approval written in the side doc (below), with a second trigger, and it writes only the parent: the folded mark is
  the record. A fold-in written beside an already-folded link
  is honored again, so a fold whose proposals the operator rejected can be redone. If the side doc holds no settled
  proposal to fold, append a one-line `{which: …?}` turn instead, as for an unclear approval. The `discussions:`
  index, closing a thread and renames are a later slice.

**Instructions that only act are honored, never branched.** The carve-out is for an instruction whose only effect is
an action, never for a question that needs continued discussion. These usually appear in a side doc:

| The operator writes (in a side doc) | You do |
|---|---|
| **an edit to this doc** ("shorten point 2") | edit the side doc |
| **an approval** ("ok", "accept", "go with 2", "agreed") | apply what this side doc proposed to the **parent**; append ` (folded <date>)` to the parent's link to this side doc; and replace the marker with its Decided line (below), ending `; folded into the parent.` |
| **an action elsewhere** ("file this", "tell parley.nvim:4") | do it, remove the marker, and add a closing record at the end of the side doc: what was done and where (the issue filed, the message sent) |

- **Unclear what an approval approves** (the side doc proposed two things): append a one-line `{which: …?}` turn
  to the marker rather than guessing.
- **A fold-in is an edit**, made under the parent's review mode. Under `deletions: propose-strike` its replacements
  and deletions are proposals in the parent; the link is still marked `(folded <date>)` in that same write, and an
  approval's Decided line ends `; proposed in the parent, to accept or reject.` instead.

**A decision is recorded in one line.** Wherever the operator writes a decision or an approval, replace the marker
with one line at its spot, `Decided (operator): <the decision, restated>.`, and carry it out (an edit, a fold). The
line is the record, and it keeps the text clean:
- **Anything you add beyond the decision** (why it works, a consequence, a caveat, what you filed or dispatched)
  goes in a new side doc (§4) linked from that line: `Decided (operator): … → [notes](<path>)`. Its `marker:` is the
  operator's decision as written.
- **A bare acknowledgement** ("ok", "sounds good", with nothing for you to add) gets the one line and nothing else:
  no side doc, and no reply prose about it.
- **An approval changes the parent through the parent's own write**, under its lock, like any edit (the adapter),
  and before the side doc's write (§4, "Writes and retries").

### collaboration

Each ready 🤖 marker is an ask, answered in place: round.md §5 as written. Carry out the asked edit, or fold the
answer into clean prose. Never open a side doc unasked.

### chat

Each **item** of the section is an ask, not each marker.

- **An item** starts at a `-`, `*` or `N.` line at the section's shallowest list indent. It runs over its
  sub-items and continuation lines until the next such line, or until a blank line followed by prose indented no
  deeper than that indent: prose in the section belongs to no item and is ignored. Fenced code starts no item, and a
  tab indents to the next multiple of four. An item is **linked** by a ` → [answer](…)` ending any of its lines
  outside fenced code: the link is appended to the item's last line, and a follow-up added after it later leaves the
  item linked. Its **extent** is all of the item except that link.
- **A new ask:** an item with no `→ [answer](…)` link. Write an answer doc (§4) and append ` → [answer](<path>)`
  to the item's last line. For a question the doc answers it. For an instruction you carry it out, and the doc
  records what was done and where.
- **A follow-up:** an item with its link, where the changes since your last read overlap its extent (an added,
  changed or deleted line inside it, a sub-item included). Append the follow-up and its answer to the end of that
  item's existing answer doc, under a `## Follow-up <date>` heading, and leave the link as it is. A change that only
  touches the link is not a follow-up. A deleted link makes the item a new ask again, answered by relinking its
  matching answer doc (§4), and the reply says so. To ask afresh, the operator deletes the link and rewords the item;
  rewording a linked item is a follow-up.
- **A linked item's doc is wherever its link points**, an older `qa/…` file included: a follow-up extends that
  file, never a new one in `<name>.side/`, and leaves an older file's frontmatter as it is.
- **A deleted item** closes its answer doc: never reopen or extend it. A later follow-up on that topic is a new item.
  One exception until a later slice adds a "closed" mark: a deleted item re-added word for word matches its old doc
  by `parent:`, `marker:` and section, and is unlinked, so it is relinked (§4).
- **Never** edit, reorder or delete the operator's items, or add 🤖 markers to them. Your only write to the section
  is the appended link.
- **Items are always answered**, whatever the review mode's `scope` or `frontier`: they are the operator's asks,
  not markers, so a frontier drawn from markers doesn't reach them.
- A 🤖 marker inside a chat section is answered as in discussion.

## 4. Side docs and answer docs

A discussion's side doc and a chat item's answer doc are both **side docs**; only their names and link text differ.

**Lifetime:** a side doc is one small file per ask. No round prunes one: the operator deletes a side doc they are
done with (with its link), and a later slice adds closing. The folder grows by one file per question or chat item.

**Where:** every side doc of `<name>.md` lives in `<name>.side/`, beside it: one flat folder per document. A side
doc opened from another side doc goes in the **same folder**, with `parent:` naming the side doc it came from. Never
create a `.side/` inside a `.side/`.

**Names:**

| Kind | Name | Number |
|---|---|---|
| side doc (discussion) | `NN-slug.md` | the next free number in the folder: two digits, widening as needed (`99`, then `100`); nothing is renamed |
| answer doc (chat) | `YYYY-MM-DD-NN-slug.md` | the round's date, then the next free number among that day's answer docs |

- The **slug** names the question in a few words (`lock-granularity`, `s4-cost`): lowercase ASCII letters, digits
  and single hyphens, at most 40 characters; `question` if nothing is left.
- The two kinds share a folder without colliding: a dated name starts with its date, and each kind counts its
  numbers apart (a dated name's year is never a side doc's number).

**Frontmatter**, in this order:

```yaml
---
type: side-doc
parent: ../design.md                         # plain relative path, from this file; no #anchor
marker: "why do we lock per file, not per section?"
collaboration-mode: discussion
process-instruction: "[free-form]"           # only when the parent has one: copied verbatim
---
```

- `marker:` is the ask, verbatim, on one line: a marker's human turn without its brackets, or a chat item's first
  line without its list number or bullet and without a link. Write it as a YAML double-quoted string:
  escape `\` as `\\` and `"` as `\"`. A `<br>` stays as written. It is untrusted text, and quoting it is what keeps it
  from becoming other frontmatter.
- `collaboration-mode: discussion` is always written out: every side doc is discussion, answer docs included, so a
  question asked inside one opens a further side doc rather than an inline back-and-forth.

**Body:** a `# ` title that is the question (or the item, shortened); a first line that links back to the parent and
names the section, as `_From [<parent title>](<parent path>), section "<heading>"._` (the parent's `# ` title, or
its file name when it has none); then the answer. The backlink is
a plain relative path with no `#anchor`, like `parent:`: an editor that opens links as files reads `#` as part of
the name.

**In the parent:** discussion replaces the marker with `→ [discussion](<path>)` at the marker's own spot, and a
decision's notes are linked as `→ [notes](<path>)` at the end of its Decided line. Chat appends ` → [answer](<path>)`
to the item's last line. The path is relative to the parent. Swapping a marker for its
link is applied directly, even under `deletions: propose-strike`: it removes only the marker, like any answered
marker, so it is never shown as a strike-through proposal.

**Writes and retries.** Each document a round changes gets one write, through the adapter. An approval's fold
changes two: the parent it folds into, and the side doc holding the approval, whose marker becomes its Decided line.
Write in this order:
1. Before allocating a name, look for a side doc to reuse: one in the folder whose `parent:` and `marker:` equal
   this ask's, whose backlink names this ask's section, and that **no link in the parent points to**. If one
   exists, link it and write no other, and the reply says it was relinked. It is usually a refused round's
   (step 4); it may also be the doc of a chat item whose link the operator deleted, or of an item re-added word for
   word. A doc already linked from elsewhere is never reused: the same short question in another section, or asked
   again after its first discussion, gets its own doc. Each candidate is reused at most once per round, so two
   identical asks in one section get one reused doc and one new doc, the second's slug saying how it differs.
2. Write the new side docs.
3. Write the parent a fold changes. A stale write is recomputed, as the adapter says. If the operator holds the
   parent's lock, stop there and write nothing else: the ask is answered again after the operator's next submit.
4. Write the remaining documents: the side doc that records a fold, and the submitted document if it is not the
   parent. If a write is refused, the new side docs stay on disk, unlinked, and step 1 finds them next round. If the
   parent's write had landed, the next round finds the parent's link already marked `(folded <date>)` today while
   the side doc still holds the approval: replace the marker with its Decided line, and don't fold again.
5. A side doc that no link points to and whose marker or item is gone (a refused round wrote it, and the operator
   deleted or rewrote the ask meanwhile) is an **orphan**. Keep it: side docs are never pruned. Name it in the
   reply, so the operator can link it or let it go. A closed doc, whose linked item the operator deleted, is not an
   orphan: leave it and don't name it.

## 5. States and actions

The reference for what each situation produces. The examples in [examples/](examples/) show most rows as
before/after documents.

| # | Situation | The operator does | You do | The operator sees |
|---|---|---|---|---|
| 1 | any section | edits text directly, submits | read the changes since your last read; find no ask; write the snapshot back unchanged, folding the submit | the reply "read your edits; no asks" |
| 2 | discussion | 🤖[tighten this paragraph] | edit the paragraph under the review mode's deletions directive, and remove the marker; under propose-strike, write it as a proposal marker instead (round.md §5) | the changed paragraph, or a proposal to accept or reject |
| 3 | discussion | 🤖[why do we lock per file, not per section?] | create `<name>.side/NN-lock-granularity.md` holding the question and its answer; replace the marker with `→ [discussion](…)` | the link where the marker was; the text otherwise unchanged |
| 4 | discussion | 🤖[add the numbers], with two readings | append `{the latency numbers or the cost numbers?}` | the marker, pending them |
| 5 | discussion, unsure | 🤖[the retry story feels off] | treat it as a question: a side doc proposing what is off | a `→ [discussion]` link |
| 6 | side doc | 🤖[a follow-up question] | open a further side doc in the same folder, `parent:` naming this one, and link it here | a link in the side doc; the parent untouched |
| 7 | side doc | 🤖[ok] or 🤖[go with 2] | apply the proposal to the parent through the parent's write; mark the parent's link `(folded <date>)`; replace the marker with `Decided (operator): …; folded into the parent.` | the parent changed; the one Decided line in the side doc |
| 8 | side doc | 🤖[ok], when it proposed two things | append `{which: the rename or the strict rule?}` | the marker, pending them |
| 9 | side doc | 🤖[file this as a parley issue] | file it; add a closing record at the end of the side doc | the side doc's record |
| 10 | parent, after a discussion | 🤖[fold in] by the link | edit the parent from the discussion; mark the link `(folded <date>)` | the folded text |
| 11 | collaboration | 🤖[why…?] | answer in place, folded into clean prose | the answer in the text |
| 12 | chat | adds item `5. what does S4 cost?` | create `<name>.side/<date>-NN-s4-cost.md`; append ` → [answer](…)` to item 5 | the link at item 5's end |
| 13 | chat | adds item `6. move #353 to :2` | do it; the answer doc records what was done and where; append the link | the link; the reply says it was done |
| 14 | chat | edits a linked item, or one of its sub-items | append the follow-up and its answer to the item's answer doc; leave the link | the reply names the doc it extended |
| 15 | chat | deletes an item | nothing: its answer doc is closed and never reopened | the item gone; the doc kept |
| 16 | any | a name in `collaboration-mode:` matches no heading | do the round with the default there; name the dangling entry in the reply | the reply line |
| 17 | any | holds the lock past your write | defer to their next submit (the adapter's exit 3) | the locked state; past 30 minutes, a one-line ping |
| 18 | any | (a previous round's write was refused) | link the side docs that round wrote, found by `parent:`, `marker:` and section among the unlinked ones; create no duplicates | the links, as if the first write had landed |
| 19 | discussion | 🤖[why?] in a section, when an earlier 🤖[why?] elsewhere already has its linked side doc | open a new side doc: a linked doc is never reused | a new `→ [discussion]` link; the earlier discussion untouched |
| 20 | discussion | 🤖[first in the section] answering a question in the text, or a bare 🤖[ok] | replace the marker with `Decided (operator): <the decision, restated>.` and carry it out; anything you add goes to a side doc linked `→ [notes](…)`; a bare acknowledgement gets only the line | one line in the text; the reasoning a click away |

## 6. Older documents

Documents with no `collaboration-mode:` are discussion, and nothing is migrated. In a chat section, an item that
ends in `→ done: …` (the TL's older form of an answered instruction) counts as answered, like a linked one. A document whose
`process-instruction:` free text says "answer the operator's 🤖 comments in place" still opens side docs for
questions: free text governs how edits are made, not where answers go, so it cannot reroute an answer. Give such a
document `collaboration-mode: collaboration` to keep answers in place.
