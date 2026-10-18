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
- **Fold-in is asked from the parent:** a 🤖[fold in] at or beside a `→ [discussion](…)` link is the one trigger.
  It is an imperative: edit the parent at the link's spot from what the side doc settled (its `Decided (operator): …`
  line, or its single proposal), through the parent's own write; mark the link `(folded <date>)`; and add a closing
  note at the end of the side doc, `Folded into the parent on <date>: <what was applied>.` The fold adds no index entry (§4, "The index"): the
  parent's changed text is its record, as a `Decided (operator): …` line when the side doc settled a decision.
  - **A fold-in beside an already-folded link** is honored again, so a fold whose proposals the operator rejected
    can be redone.
  - **One level per fold:** a 🤖[fold in] by 06's link in side doc 02 folds 06 into 02 only; folding 02 into its
    own parent takes a 🤖[fold in] by 02's link there.
  - **Ask instead of guessing**, with a one-line `{…}` turn on the operator's marker: when the side doc settled
    nothing (no Decided line and no single proposal: `{which: …?}`), when the text around the link has changed so
    much that the outcome no longer fits, or when the link is an `→ [answer](…)`: a chat item is the operator's text
    and an answer doc never folds into it.

**Instructions that only act are honored, never branched.** The carve-out is for an instruction whose only effect is
an action, never for a question that needs continued discussion. These usually appear in a side doc:

| The operator writes (in a side doc) | You do |
|---|---|
| **an edit to this doc** ("shorten point 2") | edit the side doc |
| **an approval** ("ok", "accept", "go with 2", "agreed") | replace the marker with its Decided line (below). The parent is not touched: the reply says to fold in from the parent, with a 🤖[fold in] by its link to this side doc |
| **an action elsewhere** ("file this", "tell parley.nvim:4") | do it, remove the marker, and add a closing record at the end of the side doc: what was done and where (the issue filed, the message sent) |

- **Unclear what an approval approves** (the side doc proposed two things): append a one-line `{which: …?}` turn
  to the marker rather than guessing.
- **A fold-in is an edit**, made under the parent's review mode. Under `deletions: propose-strike` its replacements
  and deletions are proposals in the parent; the link is still marked `(folded <date>)` in that same write, and the
  side doc's closing note reads `Proposed in the parent on <date>: …`, to accept or reject there.

**A decision is recorded in one line.** Wherever the operator writes a decision or an approval, replace the marker
with one line at its spot, `Decided (operator): <the decision, restated>.`, and carry it out when it asks for an edit
in this document. The line is the record, and it keeps the text clean:
- **Anything you add beyond the decision** (why it works, a consequence, a caveat, what you filed or dispatched)
  goes in a new side doc (§4) linked from that line: `Decided (operator): … → [notes](<path>)`. Its `marker:` is the
  operator's decision as written.
- **A bare acknowledgement** ("ok", "sounds good", with nothing for you to add) gets the one line and nothing else:
  no side doc, and no reply prose about it.
- **A decision in a side doc stays in the side doc.** It is what a later fold-in from the parent applies.

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
- **A deleted item** leaves its answer doc in place, and its index entry goes with the link (§4, "The index"). The
  doc is written to again only when a later ask reaches it: a deleted item re-added word for word matches its old doc
  by `parent:`, `marker:` and section, and is unlinked, so it is relinked (§4). A new item on the topic is a new ask.
- **Never** edit, reorder or delete the operator's items, or add 🤖 markers to them. Your only write to the section
  is the appended link.
- **Items are always answered**, whatever the review mode's `scope` or `frontier`: they are the operator's asks,
  not markers, so a frontier drawn from markers doesn't reach them.
- A 🤖 marker inside a chat section is answered as in discussion.

## 4. Side docs and answer docs

A discussion's side doc and a chat item's answer doc are both **side docs**; only their names and link text differ.

**Lifetime:** a side doc is one small file per ask, and it has no closed state. No round deletes, marks or locks
one: only its references in the parent come and go (below, "The index"). The folder grows by one file per question
or chat item, and moves with its document (§5).

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

**Writes and retries.** Each document a round changes gets one write, through the adapter. A fold-in changes two:
the parent it folds into, and the side doc that gets the closing note. A new side doc's index entry rides the
parent's write, in the same round as its link. Write in this order:
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
4. Write the remaining documents: the side doc that gets a fold's closing note, and the submitted document if it is
   not the parent. If a write is refused, the new side docs stay on disk, unlinked, and step 1 finds them next round;
   that round adds both the link and the entry. If the parent's write had landed, the next round finds the parent's
   link already marked `(folded <date>)` today while the side doc has no closing note for it: add the note, and
   don't fold again.
5. A side doc that no link points to and whose marker or item is gone (a refused round wrote it, and the operator
   deleted or rewrote the ask meanwhile) is an **orphan**. Keep it: side docs are never pruned. Name it in the
   reply, so the operator can link it or let it go. A side doc whose link the operator deleted is not an orphan:
   leave it and don't name it.

### The index

A side doc has one **attachment** and up to two **references** in its parent:

| What | Where | What it means | When it is removed |
|---|---|---|---|
| **the attachment** | the side doc's own `parent:` and `marker:` | which document, and which ask, it belongs to | never: reuse (above) and moves (§5) key on it |
| **the link** | `→ [discussion](…)`, `→ [answer](…)` or `→ [notes](…)` in the parent's text | where the thread sits | by the operator; you then drop its entry |
| **the index entry** | the parent's `discussions:` frontmatter | the side doc waits for the operator's review | by the operator: reviewed; the link stays |

```yaml
discussions:
  - doc: design.side/07-s3-side-docs.md
```

- **Which document's index:** the side doc's `parent:`, the document that holds its link. A side doc opened from a
  side doc is listed in that side doc's index, not the top document's.
- **Add an entry** when you write something the operator should read in that side doc: creating it with its answer,
  appending a chat follow-up to an answer doc, or making an edit they asked for in it. Append it at the end; an entry
  already listed stays where it is. A record that needs nothing from them adds none: a fold's closing note, or a note
  of an action taken.
- **The operator's removal of an entry means reviewed.** Add it back only when you next write something for them in
  that side doc.
- **The operator's removal of a link** (the `→ [discussion](…)`, or a chat item with its `→ [answer](…)`) tells you
  to drop its entry, which you see in the changes since your last read. Deleting a link drops its entry; removing an
  entry never touches the link. This one-way rule is what keeps an index from growing forever.
- **Never remove a link** by your own edit. A fold that rewrites the paragraph holding a link keeps the link.
- **An entry whose file is missing:** name it in the reply and leave it for the operator to remove.
- **The write:** the index is the parent's frontmatter, so it changes in the parent's one write (above).
- **Seen is not reviewed:** an editor's "seen" means the operator looked at the file; a side doc can be seen and
  still listed, for a second read.

## 5. Moves

A side doc's folder belongs to its document: renaming or moving the document moves the whole `<name>.side/` tree
with it. Archiving a document (sdlc moving an issue or plan to `workshop/history/`) is such a move. Every link is
relative, so a move that keeps the file name keeps everything resolving. When you move or rename a document:

1. Move the file and its `.side/` folder together; on a name change the folder takes the new name.
2. Rewrite each side doc's `parent:` and backlink when they name the old file.
3. On a name change, rewrite the parent's own links and its `discussions:` entries into the folder.
4. If the file is registered with Couch, run `couch --session-sync rename OLD NEW`.

- **A taken folder name:** when `spec.side/` already exists as you move a document to `spec.md`, it is an
  **orphan** (its document is gone; a taken `spec.md` would stop the move). Rename the orphan to `spec_1.side/` (then
  `_2`, … until free), and give the moving document `spec.side/`: every tool finds a document's side docs from its
  file name. Name where the orphan went in the reply.
- **A side doc keeps its name for life:** links and entries point at its `NN-slug`. Don't rename one inside the
  folder. When you find a dangling link or entry, name it in the reply.
- **Links into the folder from other documents** are not rewritten: side docs are local references.

parley's mover follows the same steps on `:saveas` and its own move commands; the move examples are its fixtures
too ([examples/](examples/), exported in `export.json`).

## 6. States and actions

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
| 7 | side doc | 🤖[ok] or 🤖[go with 2] | replace the marker with `Decided (operator): …`; leave the parent; the reply says to fold in from the parent's link | the one Decided line in the side doc |
| 8 | side doc | 🤖[ok], when it proposed two things | append `{which: the rename or the strict rule?}` | the marker, pending them |
| 9 | side doc | 🤖[file this as a parley issue] | file it; add a closing record at the end of the side doc | the side doc's record |
| 10 | parent, after a discussion | 🤖[fold in] by the link | edit the parent from what the side doc settled, through the parent's write; mark the link `(folded <date>)`; add a closing note to the side doc; add no entry | the folded text and the folded link |
| 11 | collaboration | 🤖[why…?] | answer in place, folded into clean prose | the answer in the text |
| 12 | chat | adds item `5. what does S4 cost?` | create `<name>.side/<date>-NN-s4-cost.md`; append ` → [answer](…)` to item 5 | the link at item 5's end |
| 13 | chat | adds item `6. move #353 to :2` | do it; the answer doc records what was done and where; append the link | the link; the reply says it was done |
| 14 | chat | edits a linked item, or one of its sub-items | append the follow-up and its answer to the item's answer doc; leave the link | the reply names the doc it extended |
| 15 | chat | deletes an item | drop its answer doc's index entry; the doc stays | the item and the entry gone; the doc kept |
| 16 | any | a name in `collaboration-mode:` matches no heading | do the round with the default there; name the dangling entry in the reply | the reply line |
| 17 | any | holds the lock past your write | defer to their next submit (the adapter's exit 3) | the locked state; past 30 minutes, a one-line ping |
| 18 | any | (a previous round's write was refused) | link the side docs that round wrote, found by `parent:`, `marker:` and section among the unlinked ones; create no duplicates | the links, as if the first write had landed |
| 19 | discussion | 🤖[why?] in a section, when an earlier 🤖[why?] elsewhere already has its linked side doc | open a new side doc: a linked doc is never reused | a new `→ [discussion]` link; the earlier discussion untouched |
| 20 | discussion | 🤖[first in the section] answering a question in the text, or a bare 🤖[ok] | replace the marker with `Decided (operator): <the decision, restated>.` and carry it out; anything you add goes to a side doc linked `→ [notes](…)`; a bare acknowledgement gets only the line | one line in the text; the reasoning a click away |
| 21 | parent | deletes a `→ [discussion]` link | drop its index entry; the side doc is unchanged | the link and the entry gone |
| 22 | parent | removes an index entry | nothing: reviewed | the entry gone; the link stays |
| 23 | chat, after 22 | edits the item whose answer doc they reviewed | append the follow-up to its answer doc; add the entry back | the entry back, at the end |
| 24 | session file | deletes an Operator instructions item | drop its answer doc's index entry (`tl-lead status`) | the item and the entry gone |
| 25 | parent | an ask whose marker matches a side doc whose link they deleted | relink that side doc (§4's reuse); add the entry back | the link and the entry back |
| 26 | side doc 02, holding 06's link | 🤖[fold in] by 06's link | fold 06 into 02 only | 02 changed |
| 27 | parent | renames `design.md` to `spec.md` in parley | (parley) move the folder to `spec.side/`; rewrite the side docs' backlinks, the parent's own links and its index; rename the registry entry | every link and entry still resolves |
| 28 | any | asks you to move or archive a document | the steps of §5 | the same; the reply lists the rewrites |
| 29 | any | a move whose target folder name is taken (an orphan `spec.side/`) | rename the orphan to `spec_1.side/` (then `_2`, …); the moving document takes `spec.side/` | the reply names where the orphan went |

## 7. Older documents

Documents with no `collaboration-mode:` are discussion, and nothing is migrated. In a chat section, an item that
ends in `→ done: …` (the TL's older form of an answered instruction) counts as answered, like a linked one. A document whose
`process-instruction:` free text says "answer the operator's 🤖 comments in place" still opens side docs for
questions: free text governs how edits are made, not where answers go, so it cannot reroute an answer. Give such a
document `collaboration-mode: collaboration` to keep answers in place.
