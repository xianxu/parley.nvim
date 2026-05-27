// preflight.go — shared judge auto-dispatch used by `sdlc push` and
// `sdlc merge` as their pre-merge gate (per the issue's M3 spec).
//
// Each push/merge invocation runs `sdlc judge plan|specs|lessons` as
// pre-flight before the irreversible action. This is the answer to
// AGENTS.md's "checks aren't run consistently today" — embed them in
// the checkpoint verb that already has to run.
//
// Categories are passed in (not hardcoded) so the caller can tune. M5
// runs Plan + Specs + Lessons by default; future verbs may add DRY and
// PURE if they want the broader sweep.
package main

import (
	"context"
	"fmt"
	"io"
	"strings"

	"github.com/xianxu/ariadne/cmd/sdlc/internal/gitx"
	"github.com/xianxu/ariadne/cmd/sdlc/internal/judge"
)

// preflightOptions configures one preflight run.
type preflightOptions struct {
	// Categories to run. Empty defaults to {Plan, Specs, Lessons}.
	Categories []judge.Category

	// Diff window. Base empty → gitx.DiffBase(); Head empty → working tree.
	Base string
	Head string

	// IssuesDir / HistoryDir for diff filters (passed through to
	// collectDiff). Default: WF_ISSUES_DIR / WF_HISTORY_DIR with the
	// usual workshop/ fallback.
	IssuesDir  string
	HistoryDir string

	// IssueRef labels milestone-review prompts (e.g. "ariadne#31 M5").
	// Unused for push's preflight (which doesn't run milestone-review)
	// but kept here in case merge wants to pre-flight a milestone-review
	// in a later pass.
	IssueRef string

	// Agent / Tools / Sandbox mirror judge.DispatchOptions's fields.
	// Empty Agent → claude. Empty Tools → category.AllowedTools().
	Agent   judge.AgentCLI
	Tools   string
	Sandbox bool

	// DryRun: skip actual agent dispatch; just print the prompts +
	// would-be command lines. Mirrors `sdlc judge --dry-run`.
	DryRun bool

	// Stdout for the agent's output; Stderr for cinfo/cwarn/cok status
	// lines. The caller supplies these so push/merge tests can capture.
	Stdout io.Writer
	Stderr io.Writer
}

// runPreflightJudges invokes each category in order and returns the
// first error encountered. A category that classifies as Failure
// returns an error; Clean and Info pass through.
//
// On error, the caller (push / merge) should refuse the action. The
// agent output has already been streamed to Stdout, so the operator
// has the findings on screen.
//
// If opts.DryRun is true, no agents are dispatched — we print prompts
// + would-be command lines and return nil regardless of category. This
// matches `sdlc judge --dry-run`.
func runPreflightJudges(opts preflightOptions) error {
	cats := opts.Categories
	if len(cats) == 0 {
		cats = []judge.Category{judge.Plan, judge.Specs, judge.Lessons}
	}

	base := opts.Base
	if base == "" {
		base = gitx.DiffBase()
	}
	head := opts.Head

	cinfo(opts.Stderr, fmt.Sprintf("running pre-merge judges (%s) against %s..%s",
		categoryList(cats), base, headLabel(head)))

	for _, cat := range cats {
		if err := runOnePreflight(opts, cat, base, head); err != nil {
			return err
		}
	}
	cok(opts.Stderr, "all pre-merge judges passed")
	return nil
}

// runOnePreflight runs one category and returns an error iff its outcome
// is Failure (or an unrecoverable dispatch error happened).
func runOnePreflight(opts preflightOptions, cat judge.Category, base, head string) error {
	// Lessons is the no-agent reminder ping — emit + carry on.
	if !cat.NeedsAgent() {
		fmt.Fprintln(opts.Stdout, judge.LessonsReminder)
		cinfo(opts.Stderr, fmt.Sprintf("%s: info", cat.Label()))
		return nil
	}

	diff, changed, err := collectDiff(cat, base, head, opts.IssuesDir, opts.HistoryDir)
	if err != nil {
		return fmt.Errorf("%s: collect diff: %w", cat.Label(), err)
	}
	// Plan category short-circuit: no changed issue files → skip with
	// the same "no issue files changed" message judge.go emits, then
	// continue (clean outcome, not failure).
	if cat == judge.Plan && len(changed) == 0 {
		fmt.Fprintln(opts.Stdout, "No issue files changed — skipping plan check.")
		cok(opts.Stderr, fmt.Sprintf("%s: clean", cat.Label()))
		return nil
	}

	in := judge.PromptInput{
		Diff:          diff,
		ChangedIssues: changed,
		Base:          base,
		Head:          headLabel(head),
	}
	if cat == judge.MilestoneReview && opts.IssueRef != "" {
		in.IssueRef = opts.IssueRef
	}
	prompt := judge.BuildPrompt(cat, in)

	agent := judge.AgentCLI(orStr(string(opts.Agent), string(judge.AgentClaude)))
	tools := opts.Tools
	if tools == "" {
		tools = cat.AllowedTools()
	}
	dispatchOpts := judge.DispatchOptions{
		Agent:        agent,
		Prompt:       prompt,
		AllowedTools: tools,
		IsSandbox:    opts.Sandbox,
		Stdout:       opts.Stdout,
		Stderr:       opts.Stderr,
	}

	if opts.DryRun {
		cmdLine, err := judge.FormatCommandLine(dispatchOpts)
		if err != nil {
			return fmt.Errorf("%s: format command line: %w", cat.Label(), err)
		}
		fmt.Fprintln(opts.Stdout, "── prompt ──")
		fmt.Fprintln(opts.Stdout, prompt)
		fmt.Fprintln(opts.Stdout, "── command (would invoke) ──")
		fmt.Fprintln(opts.Stdout, cmdLine)
		cinfo(opts.Stderr, fmt.Sprintf("%s: dry-run", cat.Label()))
		return nil
	}

	cinfo(opts.Stderr, fmt.Sprintf("invoking %s for %s …", agent, cat.Label()))
	output, dispatchErr := judge.Dispatch(context.Background(), dispatchOpts)
	if dispatchErr != nil {
		return fmt.Errorf("%s: dispatch failed: %w", cat.Label(), dispatchErr)
	}
	fmt.Fprint(opts.Stdout, output)
	if !strings.HasSuffix(output, "\n") {
		fmt.Fprintln(opts.Stdout)
	}
	outcome := judge.Classify(output)
	switch outcome {
	case judge.Clean:
		cok(opts.Stderr, fmt.Sprintf("%s: clean", cat.Label()))
		return nil
	case judge.Info:
		cinfo(opts.Stderr, fmt.Sprintf("%s: info", cat.Label()))
		return nil
	case judge.Failure:
		cwarn(opts.Stderr, fmt.Sprintf("%s: findings reported — review above", cat.Label()))
		return fmt.Errorf("%s: failure", cat.Label())
	}
	return nil
}

// categoryList renders cats as a comma-joined list of category names,
// used in cinfo headers.
func categoryList(cats []judge.Category) string {
	names := make([]string, 0, len(cats))
	for _, c := range cats {
		names = append(names, string(c))
	}
	return strings.Join(names, ",")
}

// headLabel returns "HEAD (working tree, including uncommitted)" when
// head is empty (matches judge.go's I2 fix); otherwise returns head as-is.
// Shared so the cinfo log and the prompt's Head field stay in sync.
func headLabel(head string) string {
	if head == "" {
		return "HEAD (working tree, including uncommitted)"
	}
	return head
}
