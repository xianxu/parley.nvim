---
id: 000126
status: open
deps: []
github_issue:
created: 2026-06-08
updated: 2026-06-08
estimate_hours:
---

# study mode — per-subject note convention + course-material bridge + auto-quiz

## Problem

parley.nvim today is built around chats/posts/projects (the writing flow). A
**study mode** would generalize the same substrate into a note-taking-while-
learning tool — the operator's daughter (summer curriculum) is the first user,
but the pattern is general: anyone learning a subject jots minimal keyword notes
per lesson and later wants AI to bridge those notes to uploaded course material
and self-test.

The curriculum reframed the "I don't understand this yet" note as the *core
skill being taught*, not scaffolding: pair on the left, nvim notes on the right
split, jot the unknown, ask, watch it dissolve (or keep it as a note for later).
Study mode is the durable home for those notes.

## Spec

Sketch (to refine):
- **A `study` datatype / directory convention** — like chats/posts but organized
  by *subject* then *lesson*: e.g. `study/<subject>/<NNNN-lesson-slug>.md`. Each
  lesson note holds minimal keyword captures + a running "didn't-understand-yet"
  list + a "questions that unlocked something" list (the question-craft thread).
- **Course-material bridge** — later, raw course material (PDFs, slides, links)
  can be dropped alongside a subject; the agent bridges the learner's terse
  keyword notes to that material (expand, cross-link, fill gaps).
- **Auto-quiz** — generate a quick quiz over a lesson's topics from the notes
  (+ bridged material) to self-test retention.
- **Navigation/creation** — fits the existing descriptor-driven datatype nav
  (see #116) so `study` is a first-class artifact type, not a bolt-on.
- Eventual intent: the learner *extends this herself* — study mode is the
  consumer→contributor handoff point of the curriculum.

## Done when

- `study` artifacts are a recognized datatype (create + navigate like other
  parley artifacts)
- Per-subject / per-lesson directory convention documented
- Agent can bridge terse lesson notes to dropped-in course material
- Agent can generate a quiz for a lesson's topics

## Plan

- [ ] Pin the `study` directory + frontmatter convention (align with datatype/descriptor work, #116)
- [ ] Creation + navigation for `study` artifacts
- [ ] Course-material bridging prompt/flow
- [ ] Auto-quiz generation
- [ ] Dogfood against real curriculum lessons

## Log

### 2026-06-08
- Created from the summer "plug into the matrix" curriculum brainstorm in brain.
  Note-while-confused loop = the curriculum's core skill; this is its durable
  home. Related: brain bootstrap-mac.sh task (learner env), curriculum Unit 1.
