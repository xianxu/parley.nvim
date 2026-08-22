---
type: continuation
slug: fix-the-class-not-the-site
agent: claude
session_id: 698390c4-6ce7-4bc5-bdd3-374e85eaa428
created: 2026-08-22T10:41:44
branch: 000202-make-test-is-unreliable-specs-traverse-and-mutate-a-shared-test-tmp
worktree: /Users/xianxu/workspace/parley.nvim
issues: [000202, 000203]
---

# Continuation: fix-the-class-not-the-site

## NEXT ACTION

In **`/Users/xianxu/workspace/ariadne`**, on branch
`000203-gate-refusals-tell-the-fixer-to-address-findings-not-to-fix-the-class-they-belong-to`:
fix close-review findings **BR-1** and **BR-2** (both Important, both blocking),
then re-run `sdlc close --issue 203`. Verdict is already FIX-THEN-SHIP, so the
close finalizes once the ledger clears.

Why these two and not a patch each: they are the issue's own thesis turned back
on it. BR-1 says I enumerated the *code* class mechanically and the *doc* class
by hand; BR-2 says the guard's signature is narrower than the class it claims.
Fixing either one narrowly is the exact defect #203 exists to remove — so both
get the class treatment, and the doc class gets a mechanical guard rather than a
careful hand pass.

**BR-2 — four verified blind spots in `cmd/sdlc/gatefindings_test.go`:**

- (a) A message split across adjacent string literals slips through — I match
  per-literal, but the tree's prevailing style splits (`close.go:1194` is three
  literals; `changecode.go:554` became two *in this very diff*). Fix:
  concatenate a `cwarn`/`die` call's literals **before** matching.
- (b) A package-level `const` is invisible — pass 2 walks only `FuncDecl`
  bodies. Fix: walk all literals, attributing to the enclosing func when there
  is one; a match with no enclosing func is a violation unless excluded.
- (c) Directive verbs outside `fix `/`address `/`review above` slip through.
  Broaden the vocabulary (keep `finding|dispose` as the required other half —
  that is what keeps `migrate.go:308` and `boundaryledger.go:219` correctly out).
- (d) Pass 2 is function-granular, which pass 1's own comment declares
  insufficient — a second unrouted line inside an already-routing builder ships
  green. Fix: count-based (routing refs >= matching literals per func).

**BR-1 — three unrouted doc surfaces, already mechanically enumerated:**
`helptext/close.md:13` (POST-VERDICT PROTOCOL, twin of the routed
`close.go:1809`), `helptext/close.md:59` (the REFUSE-DESPITE-PASSING-VERDICT
bullet, twin of the routed `close.go:1194`), and `helptext/milestone-close.md:38`
(file untouched by the diff so far). Add the ARCH-PURPOSE citation to each, and
add a **doc-surface guard** so this class is enforced rather than re-checked by
hand — that also disposes BR-3 (unguarded helptext citations).

Doc-guard design already settled (see Live deliberations for why): paragraph
granularity; skip blocks indented >=6 spaces (quoted tool output, not prose
directives); a matching paragraph is routed if it **or the paragraph immediately
after** cites ARCH-PURPOSE.

Then: BR-5's two halves — one comment naming `cmd/sdlc/*.go` (subpackages
excluded) as the deliberate scan boundary, and the explicit in/out ruling on
`cmd/doc-review/review.go:125`. BR-4 is **already done** (`fixTheClassNote()`).

## State of play

- **parley.nvim#202** — `status: codecomplete`, estimate 1.64h / actual 1.89h
  (ratio 0.9x). Five commits on branch `000202-make-test-is-unreliable-...`,
  **committed but NOT pushed**. Remaining: `sdlc pr` then `sdlc merge`. Nothing
  is in-flight in the working tree.
- **ariadne#203** — `status: working`, branch created, three commits (the last is
  a WIP checkpoint). Full Go suite green at the checkpoint. Close review round 1
  ran: verdict FIX-THEN-SHIP, 6 findings, 2 blocking (BR-1, BR-2). Ledger at
  `workshop/plans/000203-*-close-gate.md`, prose at `...-close-review.md`.
- Cross-issue link: **#203 exists because of #202.** #202's ledger is the
  evidence base — it measured the patching tendency that #203 installs a guard
  against. Do not archive #202's gate ledger before #203 lands; its numbers are
  cited in #203's Problem section.
- Both repos: run `sdlc state` in each rather than trusting this summary.

## Thread arc & user model

Started as a plain "work on #202" — a flaky-test issue in parley.nvim. It ran
the full SDLC and took four boundary rounds against a cap of three. The user
then asked two questions in sequence that reframed the whole session: *"how many
rounds of milestone close/close rounds you need to do"*, and then, after I
answered that the signal is to stop patching sites and fix the rule, *"it seems
you have the tendencies to keep patching?"*

That second question is the hinge. It was not about #202 — it was using #202 as
evidence about **how the agent behaves**. The ledger confirmed it objectively
(two finding families surviving three rounds each). The user's next move was to
ask that the corrective be written into ariadne's sdlc prompt — i.e. **fix it in
the tooling, not in this session's behavior.**

Working model of the user's intention: they treat agent behavioral defects the
same way they treat code defects — find the class, install a mechanical guard,
single-source the rule. They are not looking for the agent to apologize or to
try harder; they are looking for the *system* to make the failure hard to repeat.
Two concrete confirmations this session: (1) they interrupted a tool call to ask
whether injecting the rule in two places meant it should instead reference
ARCH-PURPOSE once — ARCH-DRY applied to my own change, which I had missed; and
(2) they chose "Full SDLC" over "just make the edit" for a small prompt change,
i.e. the process applies to process changes too.

Corollary for the resuming agent: **do not shortcut #203's remaining findings.**
Waiving them with `--no-ledger` would be exactly the behavior the issue exists
to prevent, in the issue that prevents it.

## Artifact map

- **parley.nvim** (this repo, `/Users/xianxu/workspace/parley.nvim`):
  - `workshop/issues/000202-make-test-is-unreliable-*.md` — read the `## Log`
    first; it carries the four review rounds, the corrected mechanism-2
    diagnosis, and all evidence.
  - `atlas/infra/test_harness.md` — new; the scratch-placement invariant, the
    destructive-recipe rule, and the fixture-readiness contract.
  - `workshop/lessons.md` — six entries added this session (four design, two
    from the reviews).
- **ariadne** (peer, `/Users/xianxu/workspace/ariadne`):
  - `workshop/issues/000203-gate-refusals-*.md` — Spec, the mechanical class
    enumeration (8 code sites + 7 reasoned exclusions), Non-goals, Estimate.
  - `workshop/plans/000203-*-close-gate.md` — **read this before fixing**; BR-1
    and BR-2 details are the authoritative statement, richer than this summary.
  - `cmd/sdlc/gatefindings.go` — the routing line + `fixTheClassNote()`; its
    header explains why it is a file and not eight strings.
  - `cmd/sdlc/gatefindings_test.go` — the two guards; **this is the file BR-2
    is about**.
  - `cmd/sdlc/internal/judge/architecture.md` — ARCH-PURPOSE, the single source
    everything routes to. Editing it re-captures four golden prompts.
  - `atlas/workflow/gate-state.md`, `atlas/workflow/architecture-principles.md`.
- Memory: `feedback_fix_the_class_not_the_site.md` in the parley.nvim project
  memory dir — the durable form of the user's observation.

## Live deliberations

- **Doc-guard granularity** was the open question when the session was parked.
  Rejected: file-level (too coarse — one citation would cover unrelated
  passages) and section-level (helptext sections are huge; `MODES` spans
  lines 21-122, so one citation would "cover" three distinct passages a reader
  never sees together). Settled on paragraph + next-paragraph, with >=6-space
  blocks excluded as quoted tool output. That last exclusion is what keeps
  `close.md:85` (the convergence-line examples) correctly out — it quotes the
  rule rather than directing the reader.
- **`cmd/doc-review/review.go:125`** ("triage each finding") needs its ruling
  written down. Current leaning: *in principle in-class, deliberately out of
  scope* — different binary, no family ledger, explicitly advisory/read-only,
  and ARCH-PURPOSE is not delivered to that tool. That is a legitimate
  ARCH-PURPOSE "separable extension", but it must be **stated**, not dropped.
  Consider filing it as a follow-up issue rather than only a Non-goal.

## Decisions & dead ends

- **#202: fixed the writer, not the readers.** First plan scoped one spec's
  traversal away and added an arch rule to police the rest; the plan gate showed
  the rule would fail three *legitimate* specs (`grep`'s "defaults missing path
  to cwd" cannot be written without traversing cwd). Moving the scratch root out
  of `$(CURDIR)` closed it at one site for every present and future spec.
- **#202 mechanism 2: the filed diagnosis was wrong.** Not a bind failure — the
  bind completes inside the `TCPServer` constructor before readiness is
  published. The real window is `open()` creating a zero-byte file before the
  digits flush. Retrying the bind would have changed nothing.
- **#203: extend ARCH-PURPOSE, don't coin a fifth marker.** A finding's named
  site *is* "the easy subset of the purpose", so it is that principle already.
- **#203: route, don't restate** — the user's correction. #128 is binding
  precedent: the constitution stopped restating ARCH-* definitions and now routes
  to `sdlc arch-principles`, guarded by
  `TestArchitecture_NarrativeRoutesToArchPrinciples`. This also made an
  `AGENTS.base.md` edit unnecessary: it already routes, so extending ARCH-PURPOSE
  reaches every downstream repo for free.
- **Dead end:** `eval set -- $args` to "split like the shell would". It parses
  *twice* — `sh` consumes the quotes parsing the eval line, then eval re-splits
  `"a b"`. Reported a false violation on a correctly quoted recipe. `set --` is
  the faithful model (make hands a recipe to `sh -c`, which parses once).

## Lessons learned

- **Fix the class, not the site** — the session's own subject, and it recurred
  at every level: two families surviving three rounds in #202; a hand
  enumeration in #203 that found seven sites where the mechanical scan found
  eight; and then BR-1, which caught me scanning the code class mechanically and
  the doc class by hand *in the issue about exactly this*.
- **A guard must assert the invariant it names, not a proxy.** #202's BR-17: my
  containment check passed `rm -rf "$(CURDIR)"` because `$(CURDIR)` is contained
  in `$(CURDIR)`. After writing a fitness function, ask what *else* satisfies it.
- **Verify a harness-sensitive spec through the harness.** #202's exact-set guard
  passed every hand-rolled `nvim` run and failed all ten `make test` runs
  (`/tmp` vs `/private/tmp`; make reports `$(CURDIR)` physically).
- **Before shipping any `rm -rf` in a recipe**, print the expansion under a path
  containing a space and under every documented override. Two Important findings
  came from that one line.
- **An enumeration written from memory is another instance.** Write the scan.
