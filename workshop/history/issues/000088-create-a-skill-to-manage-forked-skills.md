---
id: 000088
status: wontfix
deps: []
created: 2026-04-09
updated: 2026-06-29
---

# create a skill to manage forked skills

## Problem

My theory of AI coding is 42 shots, that context and incremental human input is the key to constraint the coding search space. This means I'll need to continuously observe how AI system is working, and apply patches to the workflow structure it is following, aka change skills it is using. 

I also want to stay current with all the good things skills other people created, at least as a base line, for example superpowers. 

The solution then is a system to manage skill evolution, instead of clone directly skills, we maintain a private fork, so we can record our changes. 

## Spec

We should periodically pull from upstream, and have a "skill-management" skill to merge while maintaining our distinctive improvements. 

Roughly, we'd clone our fork to the well-known location; clone upstream in not-well-known location, then some prompt file to describe that process. 

## Done when

- [x] Decide whether skill management belongs in parley or is superseded by a peer-repo system.

## Plan

- [x] Compare this issue's desired workflow against ariadne's Construct system.

## Log

### 2026-04-09

### 2026-06-29

Marked `wontfix`: this was superseded by ariadne's Construct. The live ariadne
construct skill now owns `/construct adapt`, `/construct promote`,
`/construct upgrade`, and rollback for upstream skill sources; adapted
superpowers skills live in `../ariadne/construct/adapted/` and parley inherits
them through ariadne's weave layer walk. Parley's `construct/base.manifest`
intentionally declares no skill rows, so this should not be a parley-local
feature.
