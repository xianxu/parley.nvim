Yes, that’s the intended OpenSpec workflow: progressively refine artifacts (proposal → specs → design → tasks), then let a coding agent implement tasks. OpenSpec formalizes this as a repo-local structure under openspec/ with specs/ as source-of-truth and changes/ as proposed deltas.  ￼

Below is a concrete “rewrite a vibe-coded repo into a rigorous setup” playbook for xianxu/parley.nvim (Lua Neovim plugin; repo already has .github, doc/, lua/parley, and a root CLAUDE.md).  ￼

⸻

Step 0 — Pick the scope of “rigorous”

Don’t start by “refactor everything.” Start by making the repo measurably safer to change:
	•	Build/run invariants (how to run minimal checks)
	•	Formatting + lint
	•	A minimal test harness (even 5–10 “golden” tests)
	•	CI that runs the above
	•	Optional: module boundaries + internal API rules

You’ll encode these as specs + tasks so the agent can’t “improvise.”

⸻

Step 1 — Install OpenSpec and initialize it in the repo
	1.	Install OpenSpec (requires Node ≥ 20.19.0).  ￼

npm install -g @fission-ai/openspec@latest

	2.	In the repo root:

cd parley.nvim
openspec init --tools claude,opencode

	•	openspec init creates openspec/specs/ and openspec/changes/ scaffolding.  ￼
	•	With --tools claude, it can also generate .claude/skills/ scaffolding for Claude Code.  ￼

Human role: run init, commit the new OpenSpec scaffolding as “chore: add openspec”.

⸻

Step 2 — Create baseline “source-of-truth” specs for current behavior

OpenSpec’s core idea is: openspec/specs/ describes how the system currently behaves, so future changes are expressed as deltas in change folders.  ￼

For parley.nvim, don’t spec everything. Create 3–6 thin specs that cover stable external behavior. Example structure:

openspec/specs/
  install/spec.md
  config/spec.md
  commands/spec.md
  providers/spec.md
  sessions/spec.md
  chatfinder/spec.md

Each spec should be “behavior contracts” (requirements + scenarios), not implementation.  ￼

How you use the agent here (recommended):
	•	Ask the agent to draft these baseline specs by reading README.md and browsing lua/parley/ and doc/, but you review for correctness.

Example prompt to Claude Code / OpenCode (Plan mode is fine):

“Draft baseline OpenSpec specs for current behavior of parley.nvim: install/config/commands/providers/sessions. Use RFC2119 language and Given/When/Then scenarios. Do not change code.”

Human role: sanity-check the spec statements against reality; delete anything you’re not sure is true. Baseline specs must be conservative.

⸻

Step 3 — Start the first “rigorization” change as an OpenSpec change folder

Create a change folder like:

openspec/changes/rigorize-devx/
  proposal.md
  design.md
  tasks.md
  specs/...

This matches the canonical change structure.  ￼

3a) Proposal (human-led, agent-assisted)

Proposal answers: “why / what / scope.”  ￼

Write something like:
	•	Intent: “make repo safe to modify; reduce regressions”
	•	Scope: formatter, lint, minimal tests, CI; no feature behavior changes
	•	Non-goals: refactor architecture, new features

Ask the agent to draft, you tighten.

3b) Delta specs (what behavior changes)

For “rigorization,” the external plugin behavior might not change. Your delta specs can instead specify:
	•	“Repo SHALL have a reproducible check command”
	•	“CI MUST run formatting/lint/tests”
These are still “system behavior” (developer-facing behavior), which is fine.

Delta format uses ADDED/MODIFIED/REMOVED sections.  ￼

3c) Design (technical approach)

Design captures choices like:
	•	formatter (e.g., stylua)
	•	lint (e.g., luacheck)
	•	test harness (e.g., Neovim headless tests via plenary.nvim / busted)
	•	GitHub Actions workflow

Human role: approve the tool choices and the minimal standard (what counts as “done”).

3d) Tasks (small, checkable steps)

Tasks are a checkbox list with numbered sub-steps.  ￼

Example task outline:
	1.	Add formatter config + make fmt / npm run fmt (whatever you prefer)
	2.	Add lint config + make lint
	3.	Add minimal test harness + 5 smoke tests
	4.	Add CI workflow to run fmt/lint/test on PR
	5.	Document “Contributing / Dev” section in README

Human role: enforce that each task is reviewable and doesn’t smuggle in refactors.

⸻

Step 4 — Use OpenCode Plan Mode as a “spec-to-repo translation check”

Now that your change folder exists, use Plan Mode to ensure the agent’s implementation plan is aligned.

Prompt:

“Plan Mode: implement openspec/changes/rigorize-devx/tasks.md exactly, respecting proposal/design. List files you will touch and commands to validate.”

Human role: review plan for:
	•	unnecessary refactors
	•	surprising file changes
	•	missing validation commands
If you see these, fix tasks.md / design.md first. This is where OpenSpec is strongest.

⸻

Step 5 — Execute one task at a time, with hard verification

Switch to execution (Claude Code or OpenCode) and do:
	•	“Implement task 1.1–1.4 only; stop; run checks; show diff summary.”
	•	Repeat.

Human role:
	•	review diffs (especially CI YAML + tooling configs)
	•	run the validation commands locally
	•	keep scope tight

⸻

Step 6 — Archive the change (merge deltas into source-of-truth specs)

When tasks are done and checks pass, archive:
	•	Archiving merges delta specs into openspec/specs/ and moves the change folder into openspec/changes/archive/....  ￼

This keeps changes/ clean and leaves an audit trail.

⸻

Step 7 — Repeat with a second change: “architecture cleanup” (optional)

Only after you have fmt/lint/tests/CI, do the deeper rewrite:
	•	module boundaries
	•	public vs internal APIs
	•	dependency inversion (providers, session storage, UI)
	•	refactor large files into components

Same pipeline:
proposal → delta specs (behavior changes, if any) → design → tasks → plan → implement → archive.

⸻

One practical tweak for your repo

Your repo already has a root CLAUDE.md.  ￼
Add a small, explicit rule at the top:
	•	“When openspec/ exists, treat openspec/specs/ as source-of-truth; implement only from openspec/changes/<active>/tasks.md; do not invent requirements.”

This reduces agent drift immediately.

⸻

If you follow the steps above, you’ll get a repo where future refactors become easy, because you have:
	•	explicit behavior contracts (specs)
	•	small, reviewable changes (tasks)
	•	mechanical enforcement (CI)

If you want, I can propose a first “rigorize-devx” change folder outline (proposal/spec/design/tasks skeleton) tailored specifically to parley.nvim’s structure (lua/parley, doc/, no tests currently).  ￼
