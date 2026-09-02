---
id: 000207
status: open
deps: ['#206']
github_issue:
created: 2026-09-01
updated: 2026-09-01
estimate_hours:
---

# Produce Parley introduction video

## Problem

Text documentation can make Parley understandable and operable, but it does not
show the interaction rhythm that makes an editable, branching Neovim chat
workspace different from a stock chatbot. Parley needs a concise introduction
that demonstrates the core workflow without turning the documentation rewrite
into an open-ended media-production project.

## Spec

Using the reviewed narrative and script/storyboard from #206, produce and
publish one concise introduction video for prospective Parley users.

- Demonstrate the real released product in a clean, non-private environment:
  installation/configuration at the appropriate level, starting a chat,
  receiving a response, editing the Markdown transcript, branching/drilling
  into a related thought, finding prior chats, and where to go next.
- Center the core chat experience. Ariadne-specific development workflows and
  exhaustive feature enumeration are out of scope; they may be mentioned only
  as optional extensions (`ARCH-PURPOSE`).
- Record from the approved #206 script so the video and written onboarding tell
  one story. Product facts should point back to maintained documentation rather
  than creating a second reference manual in narration (`ARCH-DRY`). Changes to
  product facts or narrative return to a recorded #206 revision rather than
  silently diverging during editing.
- Before capture, record an operator-approved production decision covering the
  publication host/account and authority to publish, target and maximum
  duration, resolution/container, caption format, transcript location, asset
  ownership/license, and repository-versus-external source storage with a size
  budget. No external publication occurs before that approval.
- Preserve editable source assets or a reproducible recording recipe under the
  approved storage policy so a small product change does not require
  reverse-engineering the original (`ARCH-CONSTRAINTS`).
- Provide captions and a text transcript in the approved accessible formats.
  Scrub local paths, credentials,
  account data, chat history, notifications, and other private information from
  the recording and source assets using a named review checklist.
- This is a documentation/media deliverable with no new runtime architecture or
  external product dependency (`ARCH-PURE`: N/A, `ARCH-MOCK`: N/A).

## Done when

- The operator-approved production decision is recorded before capture or
  publication, and all external writes use only its named host/account and
  authority.
- The published introduction covers every approved #206 storyboard scene and
  demonstrates the current core Parley workflow using only public or synthetic
  data within the approved duration and media constraints.
- The published URL works anonymously; captions and the linked text transcript
  are available in the approved formats.
- The publication location, source assets/recording recipe, version/date, and
  update procedure are recorded in the repository.
- The README and user-documentation entry point link to the published video,
  and the video points viewers back to the maintained docs.
- A reviewer replays the exact storyboard against the #206 clean setup, checks
  every scene and expected state, and records the completed privacy checklist;
  no stale command or material divergence remains.

## Plan

- [ ] Obtain the operator-approved production decision and rehearse the #206
  storyboard against a clean, synthetic demo environment.
- [ ] Capture and edit the walkthrough, captions, and transcript.
- [ ] Review for technical accuracy, privacy, pacing, and accessibility.
- [ ] Publish it and connect the durable documentation and update instructions.

## Log

### 2026-09-01

Split from #206 so media production cannot block the documentation foundation.
The video begins only after #206 stabilizes the public narrative and provides a
reviewed script/storyboard.
