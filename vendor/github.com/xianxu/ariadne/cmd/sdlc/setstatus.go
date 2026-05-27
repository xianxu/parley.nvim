// setstatus.go — `sdlc set-status --issue N <status>` subcommand.
//
// New verb (no Makefile equivalent today). Flips an issue file's
// status: frontmatter field with transition guards that match the
// xx-issues skill's contract:
//
//   - status → working requires estimate_hours: present + non-empty
//   - status → done routes to `sdlc close` (refused here so the
//     close-issue contract — ACTUAL + VERIFIED + atlas check — runs)
//   - done → anything-not-done (reopen) requires a fresh Log entry
//     dated today
//
// Each guard is bypassable with --force; the rationale belongs in
// the operator's commit message / log entry.
package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/xianxu/ariadne/cmd/sdlc/internal/issue"
)

// validStatuses is the closed set of statuses the binary understands.
// Open: not started. Working: actively in progress. Blocked: waiting on
// something. Done: completed (canonical close path goes through `sdlc
// close`). Wontfix: rejected by intent. Punt: deferred.
var validStatuses = []string{"open", "working", "blocked", "done", "wontfix", "punt"}

// setStatusFlags holds the parsed flag values for the set-status subcommand.
type setStatusFlags struct {
	Issue     int
	Status    string // positional arg
	Force     bool
	DryRun    bool
	IssuesDir string
}

// NewSetStatusCmd returns the cobra command for `sdlc set-status`.
// Note Use is "set-status" with a dash; the Go source file uses no dash.
func NewSetStatusCmd() *cobra.Command {
	f := setStatusFlags{}
	cmd := &cobra.Command{
		Use:           "set-status <status>",
		Short:         "Flip an issue's status: with transition guards",
		Long:          "Placeholder — replaced by helptext.MustGet(\"set-status\") in main.go.",
		Args:          cobra.ExactArgs(1),
		SilenceErrors: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			f.Status = args[0]
			return runSetStatus(cmd.OutOrStdout(), cmd.ErrOrStderr(), &f)
		},
	}
	cmd.Flags().IntVar(&f.Issue, "issue", 0, "ariadne workshop issue ID (required)")
	cmd.Flags().BoolVar(&f.Force, "force", false, "bypass transition guards")
	cmd.Flags().BoolVar(&f.DryRun, "dry-run", false, "print what would change; do not write")
	cmd.Flags().StringVar(&f.IssuesDir, "issues-dir", envOr("WF_ISSUES_DIR", "workshop/issues"), "directory holding issue files")
	return cmd
}

// runSetStatus is the entry point for the cobra RunE.
func runSetStatus(stdout, stderr io.Writer, f *setStatusFlags) error {
	// ── Input validation ────────────────────────────────────────────────────
	if f.Issue <= 0 {
		die(stderr, fmt.Sprintf("--issue is required and must be positive (got %d)", f.Issue))
	}
	if !isValidStatus(f.Status) {
		die(stderr, fmt.Sprintf("invalid status %q (valid: %s)", f.Status, strings.Join(validStatuses, ", ")))
	}

	// ── Locate issue file ───────────────────────────────────────────────────
	id := fmt.Sprintf("%06d", f.Issue)
	matches, err := filepath.Glob(filepath.Join(f.IssuesDir, id+"-*.md"))
	if err != nil {
		die(stderr, fmt.Sprintf("glob: %v", err))
	}
	sort.Strings(matches)
	if len(matches) == 0 {
		die(stderr, fmt.Sprintf("no issue file matches %s/%s-*.md", f.IssuesDir, id))
	}
	if len(matches) > 1 {
		die(stderr, fmt.Sprintf("multiple issue files match: %v", matches))
	}
	path := matches[0]

	raw, err := os.ReadFile(path)
	if err != nil {
		die(stderr, fmt.Sprintf("read %s: %v", path, err))
	}
	fm, body, err := issue.Parse(string(raw))
	if err != nil {
		die(stderr, fmt.Sprintf("parse frontmatter from %s: %v", path, err))
	}
	currentStatus, _ := issue.GetField(fm, "status")

	// ── Transition guards ───────────────────────────────────────────────────
	if !f.Force {
		if err := checkTransitionGuards(currentStatus, f.Status, fm, body); err != nil {
			die(stderr, err.Error())
		}
	}

	// No-op when already at the target status (after guards). Still
	// bumps `updated:` so commits show intent. Match `sdlc close`'s
	// posture of always emitting a `updated:` line.
	if currentStatus == f.Status {
		cwarn(stderr, fmt.Sprintf("status already '%s'; updating timestamp only", f.Status))
	}

	today := time.Now().Format("2006-01-02")
	newFM := issue.SetField(fm, "status", f.Status)
	newFM = issue.SetField(newFM, "updated", today)
	newText := issue.Compose(newFM, body)

	if f.DryRun {
		cinfo(stderr, "dry-run — no files written")
		fmt.Fprintf(stdout, "Would update %s: status %s → %s, updated %s\n",
			filepath.Base(path), valueOr(currentStatus, "(unset)"), f.Status, today)
		return nil
	}

	if newText == string(raw) {
		cok(stderr, fmt.Sprintf("no changes to %s", filepath.Base(path)))
		return nil
	}
	if err := os.WriteFile(path, []byte(newText), 0o644); err != nil {
		die(stderr, fmt.Sprintf("write %s: %v", path, err))
	}
	cok(stderr, fmt.Sprintf("%s: status %s → %s", filepath.Base(path),
		valueOr(currentStatus, "(unset)"), f.Status))
	fmt.Fprintln(stdout, path)
	return nil
}

// ── transition guards ────────────────────────────────────────────────────────

// checkTransitionGuards enforces the xx-issues skill's status-transition
// contract. Returns nil if the transition is allowed (or --force is the
// caller's responsibility). Returns an error describing the refusal
// otherwise — message is the exact text presented to the operator.
func checkTransitionGuards(current, next, fm, body string) error {
	// Guard 1: → done routes to `sdlc close`. Always refused (mutating
	// done close requires ACTUAL + VERIFIED + atlas check; those live
	// in `sdlc close`, not here).
	if next == "done" {
		return fmt.Errorf(
			"refusing to flip → done directly; use:\n" +
				"  sdlc close --issue <N> --actual <hours> --verified '<evidence>'\n" +
				"(closes through the AGENTS.md §5 contract instead of bypassing it)")
	}

	// Guard 2: → working requires estimate_hours: non-empty.
	if next == "working" {
		est, _ := issue.GetField(fm, "estimate_hours")
		if est == "" {
			return fmt.Errorf(
				"refusing to flip → working without estimate_hours.\n" +
					"  Add an estimate to the frontmatter first, e.g.:\n" +
					"    estimate_hours: 2.5\n" +
					"  Per the xx-issues skill: starting work without an estimate\n" +
					"  breaks velocity calibration.")
		}
	}

	// Guard 3: reopen (done → not-done) requires a fresh Log entry
	// dated today. The xx-issues skill puts the reason for reopening
	// in that entry.
	if current == "done" && next != "done" {
		today := time.Now().Format("2006-01-02")
		if !logHasEntryToday(body, today) {
			return fmt.Errorf(
				"refusing to reopen (done → %s) without a fresh Log entry.\n"+
					"  Add an entry dated %s under ## Log explaining the reopen:\n"+
					"    - %s: reopened — <reason>\n"+
					"  (Reopens carry a rationale; the log is where it lands.)",
				next, today, today)
		}
	}

	return nil
}

// logHasEntryToday returns true if the body's ## Log section contains a
// line that starts with today's date (loose check: "- 2026-05-25: ...",
// "### 2026-05-25", or simply containing today's date string after the
// ## Log header line).
//
// We scan from the header to either the next ## or EOF. This is the
// same posture as close-issue.py's insertLogLine — content-based, not
// strictly schema-anchored.
func logHasEntryToday(body, today string) bool {
	loc := logHeaderRE.FindStringIndex(body)
	if loc == nil {
		return false
	}
	tail := body[loc[1]:]
	if next := strings.Index(tail, "\n## "); next >= 0 {
		tail = tail[:next]
	}
	return strings.Contains(tail, today)
}

var logHeaderRE = regexp.MustCompile(`(?m)^## Log\s*$`)

// isValidStatus returns whether s is one of the six recognized status values.
func isValidStatus(s string) bool {
	for _, v := range validStatuses {
		if s == v {
			return true
		}
	}
	return false
}
