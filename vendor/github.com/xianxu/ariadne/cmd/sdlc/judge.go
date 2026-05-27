// judge.go — `sdlc judge` subcommand. Wraps the fresh-context LLM-judge
// pattern that ariadne has historically run as `scripts/pre-merge-checks.sh`.
//
// One verb, one category per invocation. Parallel multi-category dispatch
// is deferred to M5/M6 (wired into `sdlc push` and `sdlc merge` pre-flight).
//
// Anti-collusion property: every dispatch spawns a fresh subprocess. The
// agent has no inherited session state. See the helptext + pensive for
// the design rationale.
package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/spf13/cobra"

	"github.com/xianxu/ariadne/cmd/sdlc/internal/gitx"
	"github.com/xianxu/ariadne/cmd/sdlc/internal/judge"
)

type judgeFlags struct {
	Base       string
	Head       string
	Agent      string
	Tools      string
	IssuesDir  string
	HistoryDir string
	DryRun     bool
	Sandbox    bool

	// Milestone-review-only flags. --issue is the ariadne workshop ID
	// (per the convention codified in the lift table), used to label
	// the review.
	Issue     int
	Milestone string
}

func NewJudgeCmd() *cobra.Command {
	f := judgeFlags{}
	cmd := &cobra.Command{
		Use:           "judge <category>",
		Short:         "Run an LLM-as-judge check against the current diff (fresh context, anti-collusion)",
		Long:          "Placeholder — replaced by helptext.MustGet(\"judge\") in main.go.",
		Args:          cobra.ExactArgs(1),
		SilenceErrors: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runJudge(cmd.OutOrStdout(), cmd.ErrOrStderr(), args[0], &f)
		},
	}
	cmd.Flags().StringVar(&f.Base, "base", "", "diff base ref (default: gitx.DiffBase auto-detect)")
	cmd.Flags().StringVar(&f.Head, "head", "", "diff head ref (default: working tree)")
	cmd.Flags().StringVar(&f.Agent, "agent", os.Getenv("AGENT_CMD"), "agent CLI: claude | codex | gemini (default $AGENT_CMD or claude)")
	cmd.Flags().StringVar(&f.Tools, "tools", "", "tool allowlist for claude (default: per-category, see --help)")
	cmd.Flags().StringVar(&f.IssuesDir, "issues-dir", envOr("WF_ISSUES_DIR", "workshop/issues"), "directory holding issue files")
	cmd.Flags().StringVar(&f.HistoryDir, "history-dir", envOr("WF_HISTORY_DIR", "workshop/history"), "directory holding archived issues")
	cmd.Flags().BoolVar(&f.DryRun, "dry-run", false, "print prompt + would-be command; do not invoke agent")
	cmd.Flags().BoolVar(&f.Sandbox, "sandbox", isSandbox(), "pass auto-approve flags to codex/gemini")
	cmd.Flags().IntVar(&f.Issue, "issue", 0, "ariadne workshop issue ID (milestone-review only)")
	cmd.Flags().StringVar(&f.Milestone, "milestone", "", "milestone tag e.g. M4 (milestone-review only)")
	return cmd
}

func runJudge(stdout, stderr io.Writer, categoryArg string, f *judgeFlags) error {
	if !judge.IsValid(categoryArg) {
		die(stderr, fmt.Sprintf("unknown category %q (valid: %s)",
			categoryArg, strings.Join(categoryNames(), ", ")))
	}
	cat := judge.Category(categoryArg)

	// Special-case lessons: no agent, just the reminder.
	if !cat.NeedsAgent() {
		fmt.Fprintln(stdout, judge.LessonsReminder)
		cinfo(stderr, fmt.Sprintf("%s: info", cat.Label()))
		return nil
	}

	// Resolve diff window.
	base := f.Base
	if base == "" {
		base = gitx.DiffBase()
	}
	head := f.Head // empty → working tree, matches shell

	diff, changed, err := collectDiff(cat, base, head, f.IssuesDir, f.HistoryDir)
	if err != nil {
		die(stderr, fmt.Sprintf("collect diff: %v", err))
	}
	if cat == judge.Plan && len(changed) == 0 {
		// Match shell behavior: emit_check_message "No issue files changed — skipping plan check."
		fmt.Fprintln(stdout, "No issue files changed — skipping plan check.")
		cok(stderr, fmt.Sprintf("%s: clean", cat.Label()))
		return nil
	}

	// Build prompt input. When --head is omitted the diff includes the
	// working tree (uncommitted changes), so the prompt label must say
	// so — "Head: HEAD" alone misleads the agent about what it's reviewing
	// (review I2).
	headLabel := head
	if headLabel == "" {
		headLabel = "HEAD (working tree, including uncommitted)"
	}
	in := judge.PromptInput{
		Diff:          diff,
		ChangedIssues: changed,
		Base:          base,
		Head:          headLabel,
	}
	if cat == judge.MilestoneReview && f.Issue > 0 {
		ref := fmt.Sprintf("ariadne#%d", f.Issue)
		if f.Milestone != "" {
			ref += " " + f.Milestone
		}
		in.IssueRef = ref
	}
	prompt := judge.BuildPrompt(cat, in)

	// Resolve agent + tools.
	agent := judge.AgentCLI(orStr(f.Agent, "claude"))
	tools := f.Tools
	if tools == "" {
		tools = cat.AllowedTools()
	}
	opts := judge.DispatchOptions{
		Agent:        agent,
		Prompt:       prompt,
		AllowedTools: tools,
		IsSandbox:    f.Sandbox,
		Stdout:       stdout,
		Stderr:       stderr,
	}

	// Dry-run: print and exit without invoking.
	if f.DryRun {
		cmdLine, err := judge.FormatCommandLine(opts)
		if err != nil {
			die(stderr, err.Error())
		}
		fmt.Fprintln(stdout, "── prompt ──")
		fmt.Fprintln(stdout, prompt)
		fmt.Fprintln(stdout, "── command (would invoke) ──")
		fmt.Fprintln(stdout, cmdLine)
		return nil
	}

	// Dispatch.
	cinfo(stderr, fmt.Sprintf("invoking %s for %s …", agent, cat.Label()))
	output, dispatchErr := judge.Dispatch(context.Background(), opts)
	if dispatchErr != nil {
		die(stderr, fmt.Sprintf("dispatch failed: %v", dispatchErr))
	}

	// Surface output + classify.
	fmt.Fprint(stdout, output)
	if !strings.HasSuffix(output, "\n") {
		fmt.Fprintln(stdout)
	}
	outcome := judge.Classify(output)
	label := cat.Label()
	switch outcome {
	case judge.Clean:
		cok(stderr, fmt.Sprintf("%s: clean", label))
	case judge.Info:
		cinfo(stderr, fmt.Sprintf("%s: info", label))
	case judge.Failure:
		cwarn(stderr, fmt.Sprintf("%s: findings reported — review above", label))
		os.Exit(1)
	}
	return nil
}

// ── diff collection ─────────────────────────────────────────────────────────

// collectDiff returns the unified diff between base..head (or base..HEAD
// + worktree if head is empty), plus the list of changed issue files
// when the category needs them.
//
// Path filters honor WF_ISSUES_DIR / WF_HISTORY_DIR overrides (review I1).
// For dry/pure/specs/milestone-review: excludes both directories so prose
// churn doesn't dominate the review. For Plan: includes only issuesDir's
// markdown files.
func collectDiff(cat judge.Category, base, head, issuesDir, historyDir string) (diff string, changedIssues []string, err error) {
	args := []string{"diff", base}
	if head != "" {
		args = append(args, head)
	}
	switch cat {
	case judge.Plan:
		args = append(args, "--", issuesDir+"/*.md")
	default:
		args = append(args, "--", ":!"+issuesDir+"/", ":!"+historyDir+"/")
	}
	out, runErr := gitx.RunGit(args...)
	if runErr != nil {
		return "", nil, runErr
	}
	diff = string(out)

	if cat == judge.Plan {
		// Names-only pass for the list of files. Reuse the same path
		// filter as the diff so they stay consistent.
		nameArgs := []string{"diff", "--name-only", base}
		if head != "" {
			nameArgs = append(nameArgs, head)
		}
		nameArgs = append(nameArgs, "--", issuesDir+"/*.md")
		nameOut, nameErr := gitx.RunGit(nameArgs...)
		if nameErr != nil {
			return diff, nil, nameErr
		}
		for _, line := range strings.Split(strings.TrimSpace(string(nameOut)), "\n") {
			if line != "" {
				changedIssues = append(changedIssues, line)
			}
		}
	}
	return diff, changedIssues, nil
}

// ── helpers ─────────────────────────────────────────────────────────────────

// orStr / envOr / isSandbox moved to term.go in M4 (shared with the
// fetch / start / lock / set-status verbs).

func categoryNames() []string {
	out := make([]string, 0, len(judge.AllCategories()))
	for _, c := range judge.AllCategories() {
		out = append(out, string(c))
	}
	return out
}

