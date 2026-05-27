// state.go — `sdlc state` subcommand. Read-only inspection of SDLC
// workflow state for the current repo. The compaction-recovery surface:
// after a session resume, an agent runs `sdlc state` instead of re-
// inferring from issue files.
//
// Scope (per workshop/issues/000031 M2):
//   - Issues in workshop/issues/ with status + plan progress
//   - Active git worktrees
//   - Recent commits on the current branch (main..HEAD)
//   - Structural drift checks (warn-only)
//
// No mutations. All mutating verbs (close, set-status, milestone-close)
// live elsewhere and funnel through internal/issue. This separation is
// the funnel-mutations-through-binary discipline that lets state surface
// drift instead of obscuring it.
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/xianxu/ariadne/cmd/sdlc/internal/gitx"
	"github.com/xianxu/ariadne/cmd/sdlc/internal/issue"
)

// ── flag struct ──────────────────────────────────────────────────────────────

type stateFlags struct {
	JSON       bool
	IssuesDir  string
	HistoryDir string
}

// ── public types (also the JSON schema) ──────────────────────────────────────

// IssueState is one row in `sdlc state`'s issues section. Field names are
// the JSON keys; rename with care, downstream tooling may grep them.
type IssueState struct {
	ID         string `json:"id"`
	Path       string `json:"path"`
	Status     string `json:"status"`
	Title      string `json:"title,omitempty"`
	PlanTotal  int    `json:"plan_total"`
	PlanTicked int    `json:"plan_ticked"`
	Updated    string `json:"updated,omitempty"`
}

// WorktreeState describes one entry from `git worktree list --porcelain`.
type WorktreeState struct {
	Path   string `json:"path"`
	Branch string `json:"branch"`
}

// CommitState is one entry from `git log main..HEAD` on the current
// branch. Subjects are surfaced (not bodies) to keep state output tight.
type CommitState struct {
	SHA     string `json:"sha"`
	Subject string `json:"subject"`
}

// DriftFinding is a single structural-consistency observation surfaced
// by state. Severity is advisory; state never refuses, only reports.
type DriftFinding struct {
	Severity string `json:"severity"` // "info" or "warn"
	Issue    string `json:"issue,omitempty"`
	Message  string `json:"message"`
}

// State is the full snapshot — the root JSON object when --json is set.
type State struct {
	Repo      string          `json:"repo"`
	Branch    string          `json:"branch"`
	Issues    []IssueState    `json:"issues"`
	Worktrees []WorktreeState `json:"worktrees"`
	Recent    []CommitState   `json:"recent_commits"`
	Drift     []DriftFinding  `json:"drift"`
}

// ── command constructor ─────────────────────────────────────────────────────

func NewStateCmd() *cobra.Command {
	f := stateFlags{}
	cmd := &cobra.Command{
		Use:           "state",
		Short:         "Inspect SDLC workflow state (read-only, JSON optional)",
		Long:          "Placeholder — replaced by helptext.MustGet(\"state\") in main.go.",
		Args:          cobra.NoArgs,
		SilenceErrors: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runState(cmd.OutOrStdout(), &f)
		},
	}
	cmd.Flags().BoolVar(&f.JSON, "json", false, "emit JSON instead of human-readable prose")
	cmd.Flags().StringVar(&f.IssuesDir, "issues-dir", "workshop/issues", "directory holding issue files")
	cmd.Flags().StringVar(&f.HistoryDir, "history-dir", "workshop/history", "directory holding archived issues")
	return cmd
}

// ── main flow ───────────────────────────────────────────────────────────────

func runState(stdout io.Writer, f *stateFlags) error {
	recent, baseRef := recentCommits()
	s := State{
		Repo:      gitx.Capture("rev-parse", "--show-toplevel"),
		Branch:    gitx.Capture("branch", "--show-current"),
		Worktrees: listWorktrees(),
		Recent:    recent,
	}

	issues, err := listIssues(f.IssuesDir)
	if err != nil {
		return fmt.Errorf("list issues: %w", err)
	}
	s.Issues = issues
	s.Drift = detectDrift(issues, f.HistoryDir)
	if baseRef == "" {
		s.Drift = append(s.Drift, DriftFinding{
			Severity: "info",
			Message:  "no main/origin/main detected — recent-commits unavailable",
		})
	}

	if f.JSON {
		enc := json.NewEncoder(stdout)
		enc.SetIndent("", "  ")
		return enc.Encode(s)
	}
	return renderProse(stdout, s)
}

// listWorktrees parses `git worktree list --porcelain`. Each entry is
// three lines: "worktree <path>", "HEAD <sha>", "branch refs/heads/<name>"
// or "detached" or "bare". We surface (path, branch).
func listWorktrees() []WorktreeState {
	out := gitx.Capture("worktree", "list", "--porcelain")
	if out == "" {
		return nil
	}
	var wts []WorktreeState
	var cur WorktreeState
	for _, line := range strings.Split(out, "\n") {
		switch {
		case strings.HasPrefix(line, "worktree "):
			if cur.Path != "" {
				wts = append(wts, cur)
			}
			cur = WorktreeState{Path: strings.TrimPrefix(line, "worktree ")}
		case strings.HasPrefix(line, "branch refs/heads/"):
			cur.Branch = strings.TrimPrefix(line, "branch refs/heads/")
		case line == "detached":
			cur.Branch = "(detached)"
		case line == "bare":
			cur.Branch = "(bare)"
		}
	}
	if cur.Path != "" {
		wts = append(wts, cur)
	}
	return wts
}

// recentCommits returns the subjects of commits on the current branch
// since it diverged from origin/main (falls back to main if no upstream).
// Returns (commits, baseRef) where baseRef is the ref that was used; empty
// if neither origin/main nor main exists (fresh repo or master-only).
// Caller can surface a drift finding when baseRef is empty. Cap at 20
// entries to keep prose tight.
func recentCommits() ([]CommitState, string) {
	base := "origin/main"
	if gitx.Capture("rev-parse", "--verify", base) == "" {
		base = "main"
		if gitx.Capture("rev-parse", "--verify", base) == "" {
			return nil, ""
		}
	}
	out := gitx.Capture("log", base+"..HEAD", "--pretty=%H%x00%s")
	if out == "" {
		return nil, base
	}
	var cs []CommitState
	for _, line := range strings.Split(out, "\n") {
		parts := strings.SplitN(line, "\x00", 2)
		if len(parts) != 2 {
			continue
		}
		cs = append(cs, CommitState{SHA: parts[0], Subject: parts[1]})
		if len(cs) >= 20 {
			break
		}
	}
	return cs, base
}

// ── issue parsing ───────────────────────────────────────────────────────────

// titleRE matches the first `# Title` heading after the frontmatter.
var titleRE = regexp.MustCompile(`(?m)^# (.+)$`)

// issueFilenameRE matches workshop/issues/NNNNNN-slug.md. We extract the
// padded ID from the filename to keep the JSON consistent with how
// close-issue.py / sdlc close address issues.
var issueFilenameRE = regexp.MustCompile(`^(\d{6})-(.+)\.md$`)

// listIssues scans issuesDir for NNNNNN-*.md files, parses frontmatter,
// counts plan items. Returns issues sorted by numeric ID.
func listIssues(issuesDir string) ([]IssueState, error) {
	entries, err := os.ReadDir(issuesDir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	var out []IssueState
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := e.Name()
		m := issueFilenameRE.FindStringSubmatch(name)
		if m == nil {
			continue
		}
		path := filepath.Join(issuesDir, name)
		data, err := os.ReadFile(path)
		if err != nil {
			// Don't drop silently — surface as an unreadable entry so
			// detectDrift can warn. The whole point of state is to be
			// the single source of truth post-compaction; shrinking
			// inventory on transient permission/symlink errors
			// undermines that. M2 review C2.
			out = append(out, IssueState{
				ID:     m[1],
				Path:   path,
				Status: "unreadable",
			})
			continue
		}
		text := string(data)
		fm, body, ferr := issue.Parse(text)
		if ferr != nil {
			// Issue file without frontmatter — surface with empty status
			// so drift detection notices.
			out = append(out, IssueState{ID: m[1], Path: path, Status: ""})
			continue
		}
		status, _ := issue.GetField(fm, "status")
		updated, _ := issue.GetField(fm, "updated")
		total, ticked := issue.CountPlanItems(body)
		title := ""
		if tm := titleRE.FindStringSubmatch(body); tm != nil {
			title = tm[1]
		}
		out = append(out, IssueState{
			ID:         m[1],
			Path:       path,
			Status:     status,
			Title:      title,
			PlanTotal:  total,
			PlanTicked: ticked,
			Updated:    updated,
		})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}

// ── drift detection ─────────────────────────────────────────────────────────

// detectDrift surfaces structural inconsistencies. Warn-only — state
// reports drift but never refuses (refusal lives on mutating verbs).
//
// Checks (per workshop/issues/000031):
//  1. Issue with status=done is still in workshop/issues/ (should be
//     archived to workshop/history/).
//  2. Issue with status=working has zero plan items ticked — likely
//     stale state.
//  3. Issue file with no frontmatter — broken state.
//
// "Working but no recent commits" is intentionally omitted from M2 to
// avoid expensive cross-referencing; M4's set-status will be the right
// place to enforce that.
func detectDrift(issues []IssueState, historyDir string) []DriftFinding {
	var out []DriftFinding
	for _, i := range issues {
		switch i.Status {
		case "":
			out = append(out, DriftFinding{
				Severity: "warn",
				Issue:    i.ID,
				Message:  "no frontmatter or missing status: field",
			})
		case "unreadable":
			out = append(out, DriftFinding{
				Severity: "warn",
				Issue:    i.ID,
				Message:  fmt.Sprintf("could not read %s — check permissions / symlinks", i.Path),
			})
		case "done", "wontfix", "punt":
			out = append(out, DriftFinding{
				Severity: "warn",
				Issue:    i.ID,
				Message:  fmt.Sprintf("status=%s but still in workshop/issues/ — move to %s/", i.Status, historyDir),
			})
		case "working":
			if i.PlanTotal > 0 && i.PlanTicked == 0 {
				out = append(out, DriftFinding{
					Severity: "info",
					Issue:    i.ID,
					Message:  fmt.Sprintf("working with %d plan item(s), none ticked yet", i.PlanTotal),
				})
			}
		}
	}
	return out
}

// ── prose rendering ─────────────────────────────────────────────────────────

func renderProse(w io.Writer, s State) error {
	fmt.Fprintf(w, "Repo:    %s\n", s.Repo)
	fmt.Fprintf(w, "Branch:  %s\n", s.Branch)
	fmt.Fprintln(w)

	fmt.Fprintln(w, "Issues:")
	if len(s.Issues) == 0 {
		fmt.Fprintln(w, "  (none)")
	}
	for _, i := range s.Issues {
		// "#000031  status: working  3/8 ticked  — title"
		fmt.Fprintf(w, "  #%s  status: %-8s  %d/%d ticked", i.ID, valueOr(i.Status, "?"), i.PlanTicked, i.PlanTotal)
		if i.Title != "" {
			fmt.Fprintf(w, "  — %s", truncate(i.Title, 60))
		}
		fmt.Fprintln(w)
	}
	fmt.Fprintln(w)

	fmt.Fprintln(w, "Worktrees:")
	if len(s.Worktrees) == 0 {
		fmt.Fprintln(w, "  (none)")
	}
	for _, wt := range s.Worktrees {
		fmt.Fprintf(w, "  %s  (%s)\n", wt.Path, valueOr(wt.Branch, "(detached)"))
	}
	fmt.Fprintln(w)

	fmt.Fprintln(w, "Recent commits (main..HEAD):")
	if len(s.Recent) == 0 {
		fmt.Fprintln(w, "  (branch is at base)")
	}
	for _, c := range s.Recent {
		fmt.Fprintf(w, "  %s  %s\n", c.SHA[:8], truncate(c.Subject, 80))
	}
	fmt.Fprintln(w)

	fmt.Fprintln(w, "Drift:")
	if len(s.Drift) == 0 {
		fmt.Fprintln(w, "  (no inconsistencies detected)")
	}
	for _, d := range s.Drift {
		tag := fmt.Sprintf("[%s]", d.Severity)
		if d.Issue != "" {
			fmt.Fprintf(w, "  %s #%s — %s\n", tag, d.Issue, d.Message)
		} else {
			fmt.Fprintf(w, "  %s %s\n", tag, d.Message)
		}
	}

	// Footer: timestamp so output is reproducible-ish for logging.
	fmt.Fprintf(w, "\n(captured at %s)\n", time.Now().Format(time.RFC3339))
	return nil
}

// valueOr and truncate live in term.go (shared across the sdlc verbs).
// M2 review I1's rune-aware truncate is preserved verbatim there.
