// Package judge wraps the "fresh-context LLM check against a diff"
// pattern that ariadne has historically run as `scripts/pre-merge-checks.sh`.
//
// The package provides:
//
//   - Categories — the named principle/sanity checks (dry, pure, plan,
//     specs, lessons) plus milestone-review for the post-milestone
//     fresh-eyes pass per AGENTS.md §3.
//   - Prompt construction per category, ported byte-faithfully from the
//     shell's build_prompt heredocs.
//   - Output classification (clean / info / failure) ported from
//     scripts/lib.sh's is_clean_check_output / is_info_check_output.
//   - Subprocess dispatch via an agent CLI (claude, codex, gemini).
//     The Run shim lets tests inject fakes; production execs the binary.
//
// Anti-collusion property (per pensive): every Run call spawns a fresh
// subprocess with no inherited session state. The doer cannot rationalize
// its own work; the judge sees only the diff + prompt.
package judge

import (
	"fmt"
	"strings"
)

// Category enumerates the supported judge checks. Names match the
// shell's CHECK_NAMES array verbatim so `make check-dry` and
// `sdlc judge dry` invoke the same prompt.
type Category string

const (
	DRY              Category = "dry"
	PURE             Category = "pure"
	Plan             Category = "plan"
	Specs            Category = "specs"
	Lessons          Category = "lessons"
	MilestoneReview  Category = "milestone-review"
)

// AllCategories returns every supported category in stable order. Used
// for --help enumeration and bulk-dispatch from push/merge in M5/M6.
func AllCategories() []Category {
	return []Category{DRY, PURE, Plan, Specs, Lessons, MilestoneReview}
}

// IsValid reports whether s names a known category.
func IsValid(s string) bool {
	for _, c := range AllCategories() {
		if string(c) == s {
			return true
		}
	}
	return false
}

// Label returns a human-readable description for the category, matching
// the shell's CHECK_LABELS entries.
func (c Category) Label() string {
	switch c {
	case DRY:
		return "Check DRY principle"
	case PURE:
		return "Check PURE principle"
	case Plan:
		return "Check issue plan completeness"
	case Specs:
		return "Check atlas/README sync"
	case Lessons:
		return "Check for lessons to capture"
	case MilestoneReview:
		return "Post-milestone code review (AGENTS.md §3)"
	}
	return string(c)
}

// NeedsAgent reports whether the category invokes the LLM. `lessons`
// is just a reminder ping — no diff, no agent.
func (c Category) NeedsAgent() bool {
	return c != Lessons
}

// AllowedTools returns the tool allowlist for this category's agent
// invocation. Most are read-only; `specs` may write documentation.
func (c Category) AllowedTools() string {
	if c == Specs {
		return "Edit,Read,Write,Grep,Glob,Bash"
	}
	return "Read,Grep,Glob,Bash"
}

// PromptInput is the data each category's prompt template consumes.
// Callers populate the fields relevant to the category they invoke;
// unused fields are ignored.
type PromptInput struct {
	Diff           string   // unified diff of the review window
	ChangedIssues  []string // paths to changed issue files (for `plan`)
	Base, Head     string   // refs that bound the window (for milestone-review)
	IssueRef       string   // e.g. "ariadne#31 M2" (for milestone-review)
}

// BuildPrompt renders the prompt for one category. Returns "" for
// categories that don't invoke an agent (lessons).
//
// Wording is preserved byte-faithfully from pre-merge-checks.sh's
// build_prompt heredocs so the agent behavior matches the shell version.
// Drift between this prompt and the shell version is a bug — they
// describe one contract.
func BuildPrompt(category Category, in PromptInput) string {
	switch category {
	case DRY:
		return fmt.Sprintf(`You are a code reviewer. Review the following diff for DRY (Don't Repeat Yourself) violations.
Look for: duplicated logic, copy-pasted code blocks, functions that could be consolidated,
repeated patterns that should be extracted into shared helpers.

Report any violations you find with file paths and line numbers. Suggest how to fix them.
Do NOT modify any files. Only report.

If the code is already DRY, say "No DRY violations found."

Diff:
%s
`, in.Diff)

	case PURE:
		return fmt.Sprintf(`You are a code reviewer. Review the following diff for PURE principle adherence.
The PURE principle means: write the majority of code as pure functions (no side effects, deterministic),
then use minimal "glue" code to integrate with UI and IO.

Look for: business logic mixed with IO, functions that could be pure but aren't,
side effects that could be moved to the boundary.

Report any violations with file paths and line numbers. Suggest how to refactor.
Do NOT modify any files. Only report.

If the code is clean, say "No PURE violations found."

Diff:
%s
`, in.Diff)

	case Plan:
		changedList := strings.Join(in.ChangedIssues, "\n")
		return fmt.Sprintf(`You are a project management reviewer (TPM). You don't know technical details.
Only review the issue files that changed in this diff — do NOT review other issues.

For each changed issue file, check:
1. Does it have a filled-in Plan section with checklist items?
2. Are plan checklist items that appear done (based on the diff and git log) still unchecked?
3. Does the Log section have entries documenting what was done?
4. Is the status frontmatter correct (should it be "done")?

Report any issues you find. Do NOT modify any files.
If a checklist item looks completed based on the diff, say so and recommend checking it off.

Changed issue files:
%s

Diff:
%s
`, changedList, in.Diff)

	case Specs:
		return fmt.Sprintf(`You are a documentation reviewer. Compare the code changes in the diff below against:
1. The spec files in atlas/
2. README.md

Those files do not meant to be comprehensive. Synthesize what we just built into reusable spec document. DO NOT over specify — atlas/ is a practical pointer for future developers and agents to know the sketch of functionalities, history and intention behind them. Details should live in the code.

Update any stale documentation. Incorrect information is bad. If everything is in sync, say so and make no changes.

Only update documentation that is actually out of sync. Do not rewrite documentation that is fine.

Diff:
%s
`, in.Diff)

	case Lessons:
		// No agent invocation — just a reminder ping. Caller emits the
		// REMINDER: line directly so output classification recognizes it
		// as info, not failure.
		return ""

	case MilestoneReview:
		ref := in.IssueRef
		if ref == "" {
			ref = "<unknown>"
		}
		return fmt.Sprintf(`You are conducting a post-milestone code review for %s.
Base: %s   Head: %s

Read the diff against the issue's plan + spec. Focus on:

  Critical (must fix before next milestone)
    - correctness bugs
    - behavior drift from stated contracts (look for ports of existing
      scripts where byte-faithfulness was promised)
    - crashes / panics on unexpected input
    - silent error swallowing where the source raised

  Important (fix before next milestone if cheap)
    - API design of newly-introduced internal packages (downstream
      milestones will consume them; surface stable?)
    - missing test coverage that would catch the kind of bug shipped
    - inconsistent error handling philosophy across the diff

  Minor (note for future)
    - style nits, naming, comment density
    - performance only if hot-path

  Core concepts cross-check (if the plan has a Core concepts table):
    The plan should list entities in a greppable table — name, kind
    (PURE/INTEGRATION), file location, status (new/modified/deleted).
    For each row:
      - Verify the entity exists at the stated path (grep the diff or
        filesystem).
      - PURE: tests run without IO (no exec, net, mutable fs). If tests
        need mocks to run, it isn't really PURE — flag Critical and
        recommend promoting it to INTEGRATION.
      - INTEGRATION: injected into pure callers, not invoked directly
        from business logic.
      - "modified" / "deleted" status: the diff shows the expected
        change/removal at the stated location.
    Any contradiction between table and code = Critical finding, plus
    a plan-revision recommendation (a "## Revisions" entry on the plan
    so it stops claiming what the code doesn't deliver).

  Atlas update gate (per AGENTS.md §8):
    The milestone should update atlas/ entries for any new architectural
    surface, flow, or terminology introduced. Scan the diff for evidence
    of new surface — new entity types, new subcommands, new conventions,
    new file-tree locations. Any present without corresponding atlas/
    changes in the same range = Important finding ("atlas update appears
    missing for <surface>").

Produce a structured report:
  1. Verdict (first line, sharp + parseable):
       SHIP | FIX-THEN-SHIP | REWORK   (confidence: high | medium | low)
     Followed by a 1-paragraph summary explaining the verdict — what
     worked, what blocks the verdict from being SHIP if it isn't.
  2. Strengths: 2-5 specific things done well (file:line where useful).
     Affirm the validated approaches so the operator knows what's
     confirmed-good ground. Empty acceptable for trivial milestones.
  3. Critical findings (file:line + fix sketch); empty if none.
  4. Important findings (same format).
  5. Minor findings (terse one-liners).
  6. Test coverage notes.
  7. Architectural notes for upcoming work.
  8. Plan revision recommendations: list specific "## Revisions" entries
     the plan needs (empty if the plan still matches the code).

You have no prior session context — that is the anti-collusion property.
Verify behavior against documented contracts directly; do not take the
implementor's word in commit messages or docs at face value.

Tools: read-only. Do not modify code.

Diff:
%s
`, ref, in.Base, in.Head, in.Diff)
	}
	return ""
}

// LessonsReminder is the line `sdlc judge lessons` emits in place of an
// agent invocation. Matches pre-merge-checks.sh's emit_check_message
// for `lessons` so the output classifier picks it up as info.
const LessonsReminder = "REMINDER: Review workshop/lessons.md — capture any non-obvious patterns from this session."
