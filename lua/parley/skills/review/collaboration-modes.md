# Collaborative editing

The operator and the agent edit one document together, and the goal is a document that stands on its own. There is
**one mode**: the operator's direct edits are content, and a `🤖` marker is a question or a command that the agent
classifies. One carve-out, a `@@chat@@` tag above a heading, makes a section a chat whose items always get an answer
doc. No document key selects a mode; the old mode keys are read as §7 says and never written.

This file is harness-neutral, like round.md: it says what a round decides. How files are read and written is the
adapter's job. The marker grammar is [review-convention.md](review-convention.md); this file uses its terms and
restates none of it.

## 1. The model

- **Direct edits by the operator are content**, never instructions. Read them in the changes since your last read;
  they are the document now. A submit with only direct edits gets the reply "read your edits; no asks".
- **A ready 🤖 marker is a question or a command; you decide which.** It is never content: answering it removes it.

| The ask | Is a | What you do |
|---|---|---|
| "why…?", "what if…?", "is this number right?", "let's think about…", anything ending in `?` that asks for knowledge | **question** | open a **side doc** (§4) and replace the marker with `→ [discussion](<name>.side/YYYY-MM/YYYY-MM-DD-NN-slug.md)` |
| an imperative change to the text: "tighten this", "give an example", "copy edit this section", "can you shorten this?" | **command** | make the edit (round.md §5) within its scope (§2), and remove the marker |
| a command you cannot carry out without a choice: two readings, a missing fact | **command, unclear** | open a side doc asking what you need, replace the marker with its link, and index it |
| an approval or a decision: "ok", "go with 2", "first in the section", "yes, Friday" | **command** | record it in one line and carry it out (below) |
| an action elsewhere: "file this as a parley issue", "tell parley.nvim:4" | **command** | do it, remove the marker, and record what was done (below) |
| "fold this discussion in" (any fold-in wording) beside a `→ [discussion](…)` link | **command** | fold the side doc into the document (below) |
| anything you are unsure about: "the retry story feels off" | **question** | open a side doc that proposes what is off |

- **When unsure, it is a question.** A side doc costs the operator one link; a wrong edit rewrites their content. A
  trailing `?` is a strong question signal, and an imperative is a command, even when phrased politely with a `?`
  ("can you shorten this?").
- **Every question branches**, even a small factual one. Never answer a question in the document's prose: the
  operator phrases a command ("check this number and fix it") to get an edit, and folds a discussion in when it is
  settled.
- **Processing comes from the instruction.** "Copy edit", "proofread", "make it satire": infer the kind of edit from
  what the operator wrote. When an instruction names one of the [briefs](briefs/) (copy-editing, line-editing,
  proofreading, developmental, fact-check), load it and follow it. No document key selects one, and there is no
  standing instruction: the operator repeats an instruction where it applies.
- **Presentation is highlight.** Your own edits are shown as the adapter highlights the last machine edit; the
  operator's are never marked. There is no direct or propose setting.

**Fold-in is asked from the parent:** a 🤖[fold this discussion in] at or beside a `→ [discussion](…)` link is the
one trigger. Edit the parent at the link's spot from what the side doc settled (its `Decided (operator): …` line, or
its single proposal), through the parent's own write; mark the link `(folded <date>)`; and add a closing note at the
end of the side doc, `Folded into the parent on <date>: <what was applied>.` The fold adds no index entry (§4, "The
index"): the parent's changed text is its record.
- **A fold-in beside an already-folded link** is honored again, so a fold whose result the operator undid can be
  redone.
- **One level per fold:** a 🤖[fold in] by 06's link in side doc 02 folds 06 into 02 only; folding 02 into its own
  parent takes a 🤖[fold in] by 02's link there.
- **Ask instead of guessing**, in a linked side doc that replaces the operator's ready marker: when the side doc
  settled nothing (no Decided line and no single proposal), when the text around the link has changed so much that
  the outcome no longer fits, or when the link is an `→ [answer](…)`: a chat item is the operator's text and an
  answer doc never folds into it.

**Commands that only act are honored, never branched.** These usually appear in a side doc:

| The operator writes (in a side doc) | You do |
|---|---|
| **an edit to this doc** ("shorten point 2") | edit the side doc |
| **an approval** ("ok", "accept", "go with 2", "agreed") | replace the marker with its Decided line (below). The parent is not touched: the reply says to fold in from the parent, with a 🤖[fold in] by its link to this side doc |
| **an action elsewhere** ("file this", "tell parley.nvim:4") | do it, remove the marker, and add a closing record at the end of the side doc: what was done and where (the issue filed, the message sent) |

- **Unclear what an approval approves** (the side doc proposed two things): open a further side doc under the same
  side root in the round's month folder, linked and indexed from this one, to ask which proposal; do not guess or
  append a marker turn.

**A decision is recorded in one line.** Wherever the operator writes a decision or an approval, replace the marker
with one line at its spot, `Decided (operator): <the decision, restated>.`, and carry it out when it asks for an edit
in this document. The line is the record, and it keeps the text clean:
- **Anything you add beyond the decision** (why it works, a consequence, a caveat, what you filed or dispatched)
  goes in a new side doc (§4) linked from that line: `Decided (operator): … → [notes](<path>)`. Its `marker:` is the
  operator's decision as written.
- **A bare acknowledgement** ("ok", "sounds good", with nothing for you to add) gets the one line and nothing else:
  no side doc, and no reply prose about it.
- **A decision in a side doc stays in the side doc.** It is what a later fold-in from the parent applies.

What every ask keeps from round.md §5:
- Proposals already in an older document (`🤖~D~`, `🤖~D~{N}`, `🤖<X>{N}`, `🤖{N}`) are never ready by themselves.
- A pending marker (its last turn is an agent turn) is left for the operator.
- Every marker written is a single line with at most one commentary turn. Old chains remain readable; resolve a ready
  one by its final human turn.

## 2. Scope of an edit

A command edits only what it is about:

| Rule | The marker | Edits |
|---|---|---|
| **s1** (the default) | an anchored `🤖<X>[…]` or `🤖~D~[…]`, or a bare `🤖[…]` | the anchor's text; for a bare marker, the current or preceding paragraph (round.md §5) |
| **s2** | an instruction that names a wider scope: "edit this section", "copy edit the document" | that section (to the next heading of the same or a higher level) or the document |
| **s3** | a marker before the first heading | the whole document, unless it names a narrower scope |

A brief never widens the scope by itself: "copy edit this paragraph" loads the copy-editing brief and edits one
paragraph. A question has no scope: it only opens a side doc.

## 3. The chat carve-out

A **`@@chat@@`** line directly above a heading makes that section chat:

```markdown
@@chat@@
## Operator instructions
1. Why use retries?
2. Move #353 to :2.
```

- **The tag** is a line holding only `@@chat@@` (surrounding spaces allowed), on the line directly above an ATX
  (`#`) heading, outside fenced or indented code. A line above a setext heading is part of that heading's text in
  CommonMark, so a tag there is misplaced. Its section runs from the heading to the next heading of the same or a higher
  level, subsections included. A tag or heading inside a closed leading `---` header declares nothing, even when the
  header cannot be read as frontmatter (§7's notice says so); the body after it is read as usual (#581).
- **A misplaced tag** (a blank line or text between it and the heading, or no heading after it) is ordinary text.
  Name it in the reply: "`@@chat@@` at line 12 is not directly above a heading". Other `@@tag@@` lines are parley's
  (outline labels, file references) and not review's.
- **Each item of the section is an ask**, not each marker. An item is a numbered `N.` line at the section's
  shallowest list indent. It runs over its sub-items and continuation lines until the next such line, or until a
  blank line followed by prose indented no deeper than that indent: prose in the section belongs to no item and is
  ignored. Fenced code starts no item, and a tab indents to the next multiple of four. A section a legacy form covers
  (§7) also takes `-` and `*` items, as it always did, even when a `@@chat@@` tag names it too. Chat sections nest
  but never partially overlap; a line belongs to the innermost one, whose grammar governs it. An item is **linked** by a ` → [answer](…)` ending any of its lines
  outside fenced code: the link is appended to the item's last line, and a follow-up added after it later leaves the
  item linked. The link's destination must be one a round could write: nonempty, with no whitespace and no
  parentheses (`pkg/sidedoc` `ValidAnswerTarget`, #581). `→ [answer](broken path)` or `→ [answer]()` links nothing,
  so the item is still a new ask. Its **extent** is all of the item except that link.
- **A new ask:** an item with no `→ [answer](…)` link. Write an answer doc (§4) and append ` → [answer](<path>)`
  to the item's last line. For a question the doc answers it. For an instruction you carry it out, and the doc
  records what was done and where. An item always gets an answer doc, whether it is a question or a command.
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
- **A 🤖 marker inside a chat section** is an ordinary ask (§1). The answer docs themselves are ordinary
  collaborative documents, not chat.

## 4. Side docs and answer docs

A question's side doc and a chat item's answer doc are both **side docs**; only their names and link text differ.
Side docs are ordinary collaborative documents: every rule of this file applies inside them, and a question asked in
one opens a further side doc.

**Lifetime:** a side doc is one small file per ask, and it has no closed state. No round deletes, marks or locks
one: only its references in the parent come and go (below, "The index"). The folder grows by one file per question
or chat item, and moves with its document (§5).

**Where:** create every new side doc or answer doc of `<name>.md` under
`<name>.side/YYYY-MM/YYYY-MM-DD-NN-slug.md`, beside the owning document. The year-month directory and full filename
date use the round's date; retaining the full date keeps a file meaningful when linked, grepped or moved.
A side doc opened from another side doc uses the **same owning .side root**, in the current round's month folder,
with `parent:` naming the actual side doc it came from. Never create a `.side/` inside a `.side/`.
For example, a question in `design.side/2026-09/2026-09-30-01-cache.md` on 2026-10-23 creates
`design.side/2026-10/2026-10-23-01-retry.md`, whose parent is `../2026-09/2026-09-30-01-cache.md`.

**No migration:** readers accept both the new month layout and existing flat `NN-slug.md` or
`YYYY-MM-DD-NN-slug.md` names. Leave existing files, links and frontmatter where they are. Search both layouts for
reuse before creating anything; a follow-up extends its linked file, even in an older flat or qa/ location.

**Names:**

| Kind | Name | Number |
|---|---|---|
| side doc (discussion) | `YYYY-MM/YYYY-MM-DD-NN-slug.md` | the next free number among that date's side and answer docs under this side root |
| answer doc (chat) | `YYYY-MM/YYYY-MM-DD-NN-slug.md` | the same daily sequence; count taken dated names in the flat and month layouts |

- The **slug** names the question in a few words (`lock-granularity`, `s4-cost`): lowercase ASCII letters, digits
  and single hyphens, at most 40 characters; `question` if nothing is left.
- Numbers start at `01`, widening as needed (`99`, then `100`); never rename an existing file to make room.
  Undated legacy names remain valid and do not consume the new daily sequence. Never read a date's year as its number.

**Frontmatter**, in this order:

```yaml
---
type: side-doc
parent: ../../design.md                      # from the month folder; plain relative path, no #anchor
marker: "why do we lock per file, not per section?"
---
```

- `marker:` is the ask, verbatim, on one line: a marker's human turn without its brackets, or a chat item's first
  line without its list number or bullet and without a link. Write it as a YAML double-quoted string:
  escape `\` as `\\` and `"` as `\"`. A `<br>` stays as written. It is untrusted text, and quoting it is what keeps it
  from becoming other frontmatter.
- Those three keys are all a new side doc carries. Never copy a parent's legacy mode keys into it (§7); an
  existing side doc's frontmatter is left as it is.

**Body:** a `# ` title that is the question (or the item, shortened); a first line that links back to the parent and
names the section, as `_From [<parent title>](<parent path>), section "<heading>"._` (the parent's `# ` title, or
its file name when it has none); then the answer. The backlink is
a plain relative path with no `#anchor`, like `parent:`: an editor that opens links as files reads `#` as part of
the name.

**In the parent:** a question replaces the marker with `→ [discussion](<path>)` at the marker's own spot, and a
decision's notes are linked as `→ [notes](<path>)` at the end of its Decided line. Chat appends ` → [answer](<path>)`
to the item's last line. The path is relative to the parent. Swapping a marker for its
link is an edit through `apply`. For a side doc opened by that ask, include its
matching `discussions:` index entry in the same `apply` batch as the link, so both
land atomically; check that the entry's path matches the link, since Pair does not
verify that pairing for you. An older document may hold a pending `🤖{…}` link
proposal from the retired propose presentation: it still counts as linked, so
neither relink nor answer its ask again; if the operator rejects it, remove its
`discussions:` entry in the next round and keep the side doc as an orphan.

**Writes and retries.** Each document a round changes gets one write, through the adapter. A fold-in changes two:
the parent it folds into, and the side doc that gets the closing note. A new side doc's index entry rides the
parent's write, in the same round as its link. Write in this order:
1. Before allocating a name, look for a side doc to reuse: one under the owning side root, across flat and month
   layouts, whose resolved `parent:` and `marker:` equal
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
| **the link** | `→ [discussion](…)`, `→ [answer](…)` or `→ [notes](…)` in the parent's text (`→ [proposal](…)` in older documents) | where the thread sits | by the operator; you then drop its entry |
| **the index entry** | the parent's `discussions:` frontmatter | the side doc waits for the operator's review | by the operator: reviewed; the link stays |

```yaml
discussions:
  - doc: design.side/2026-10/2026-10-23-07-s3-side-docs.md
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
- **A side doc keeps its name for life:** links and entries point at its original path. Don't rename one inside the
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
| 2 | any | 🤖[tighten this paragraph] | a command: apply the clean paragraph edit (s1) and remove the marker | the changed paragraph, highlighted |
| 3 | any | 🤖[why do we lock per file, not per section?] | a question: create `<name>.side/YYYY-MM/YYYY-MM-DD-NN-lock-granularity.md` holding the question and its answer; replace the marker with `→ [discussion](…)` | the link where the marker was; the text otherwise unchanged |
| 4 | any | 🤖[add the numbers], with two readings | an unclear command: open a side doc asking which numbers; replace the marker with its link and index the doc | the link and an indexed question |
| 5 | any, unsure | 🤖[the retry story feels off] | treat it as a question: a side doc proposing what is off | a `→ [discussion]` link |
| 6 | side doc | 🤖[a follow-up question] | open a further side doc under the same side root in the round's month folder, `parent:` naming this one, and link it here | a link in the side doc; the parent untouched |
| 7 | side doc | 🤖[ok] or 🤖[go with 2] | replace the marker with `Decided (operator): …`; leave the parent; the reply says to fold in from the parent's link | the one Decided line in the side doc |
| 8 | side doc | 🤖[ok], when it proposed two things | open a further side doc asking which proposal; replace the marker with its link and index the doc | a link under the same side root, in the round's month folder |
| 9 | side doc | 🤖[file this as a parley issue] | file it; add a closing record at the end of the side doc | the side doc's record |
| 10 | parent, after a discussion | 🤖[fold this discussion in] by the link | edit the parent from what the side doc settled, through the parent's write; mark the link `(folded <date>)`; add a closing note to the side doc; add no entry | the folded text and the folded link |
| 11 | any | 🤖[copy edit this section] | a command with scope s2: load the copy-editing brief and edit that section only | the section's changes, highlighted |
| 12 | any | 🤖[give an example] before the first heading | scope s3: edit the whole document as asked | the document's changes, highlighted |
| 13 | `@@chat@@` section | adds item `5. what does S4 cost?` | create `<name>.side/YYYY-MM/YYYY-MM-DD-NN-s4-cost.md`; append ` → [answer](…)` to item 5 | the link at item 5's end |
| 14 | `@@chat@@` section | adds item `6. move #353 to :2` | do it; the answer doc records what was done and where; append the link | the link; the reply says it was done |
| 15 | `@@chat@@` section | edits a linked item, or one of its sub-items | append the follow-up and its answer to the item's answer doc; leave the link | the reply names the doc it extended |
| 16 | `@@chat@@` section | deletes an item | drop its answer doc's index entry; the doc stays | the item and the entry gone; the doc kept |
| 17 | any | a `@@chat@@` line with a blank line before its heading | treat the section as ordinary; name the misplaced tag in the reply | the reply line |
| 18 | any | holds the lock past your write | defer to their next submit (the adapter's exit 3) | the locked state; past 30 minutes, a one-line ping |
| 19 | any | (a previous round's write was refused) | link the side docs that round wrote, found by `parent:`, `marker:` and section among the unlinked ones; create no duplicates | the links, as if the first write had landed |
| 20 | any | 🤖[why?] in a section, when an earlier 🤖[why?] elsewhere already has its linked side doc | open a new side doc: a linked doc is never reused | a new `→ [discussion]` link; the earlier discussion untouched |
| 21 | any | 🤖[first in the section] answering a question in the text, or a bare 🤖[ok] | replace the marker with `Decided (operator): <the decision, restated>.` and carry it out; anything you add goes to a side doc linked `→ [notes](…)`; a bare acknowledgement gets only the line | one line in the text; the reasoning a click away |
| 22 | parent | deletes a `→ [discussion]` link | drop its index entry; the side doc is unchanged | the link and the entry gone |
| 23 | parent | removes an index entry | nothing: reviewed | the entry gone; the link stays |
| 24 | chat, after 23 | edits the item whose answer doc they reviewed | append the follow-up to its answer doc; add the entry back | the entry back, at the end |
| 25 | session file | deletes an Operator instructions item | drop its answer doc's index entry (`tl-lead status`) | the item and the entry gone |
| 26 | parent | an ask whose marker matches a side doc whose link they deleted | relink that side doc (§4's reuse); add the entry back | the link and the entry back |
| 27 | side doc 02, holding 06's link | 🤖[fold in] by 06's link | fold 06 into 02 only | 02 changed |
| 28 | parent | renames `design.md` to `spec.md` in parley | (parley) move the folder to `spec.side/`; rewrite the side docs' backlinks, the parent's own links and its index; rename the registry entry | every link and entry still resolves |
| 29 | any | asks you to move or archive a document | the steps of §5 | the same; the reply lists the rewrites |
| 30 | any | a move whose target folder name is taken (an orphan `spec.side/`) | rename the orphan to `spec_1.side/` (then `_2`, …); the moving document takes `spec.side/` | the reply names where the orphan went |
| 31 | any | a document carrying legacy mode keys (§7) | read chat from them where they meant chat; ignore the rest; write no key | one notice line in the reply |

## 7. Legacy mode keys

Documents written before #575 carry mode keys. They stay readable and never break a round; **nothing new writes
them**, and a round never deletes or rewrites one of their lines.

| Legacy key or form | Read as |
|---|---|
| `collaboration-mode: chat` (frontmatter scalar) | the whole document is a chat section: every top-level item, in any section, is an ask |
| a section map, `collaboration-mode: {chat: [names], default: …}` (block or flow form) | each named section is chat. Names match headings at any level after lowercasing, collapsing whitespace, trimming and dropping one trailing parenthesised annotation (`### Operator instructions (open)` matches `"operator instructions"`); a name that matches no heading is named in the notice. A `default: chat` makes the whole document chat |
| a heading comment `<!-- collaboration-mode: chat -->` on the line directly under a heading | that section is chat |
| `collaboration-mode: discussion` or `collaboration-mode: collaboration` (scalar, map default or heading comment) | nothing: the one mode applies. Questions get side docs and commands act, in issues, plans and projects too |
| `presentation-mode`, `presentation`, `processing-mode`, `processing-instruction`, `process-instruction`, in frontmatter or a heading comment | nothing |
| an unknown, empty or malformed value of any of these | nothing |

- A legacy chat section keeps its old item grammar: `-`, `*` and `N.` items. A `@@chat@@` tag and a legacy form on
  the same heading are one chat section, not a conflict, and it keeps the legacy grammar (`ChatSections` reports
  it with `Source` "tag" and `Legacy` true).
- **Report, never fail.** The reply carries the notice lines `pkg/sidedoc`'s `ChatSections` produces for the
  document as submitted, word for word, one per legacy form (for example "retired keys ignored: presentation-mode,
  processing-mode"); a line number in a notice counts lines of the submitted document, frontmatter included. A
  mode key never fails a round and never makes it write nothing. Frontmatter that cannot be read (CR line endings,
  a `...` or `%` line inside it, YAML that does not parse) is read as having no keys, and its notice says so.
- In a chat section, an item that ends in `→ done: …` (the TL's older form of an answered instruction) counts as
  answered, like a linked one.
