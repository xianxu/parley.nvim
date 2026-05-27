// fetch.go — `sdlc fetch --github-issue N` subcommand.
//
// Ports the `fetch:` Make target from Makefile.workflow (~lines 213-257):
// pulls a GitHub issue via `gh issue view`, writes a local issue file
// under workshop/issues/NNNNNN-<slug>.md with the standard frontmatter
// + sections, then exits.
//
// The Make target is a 40-line shell pipeline of gh + sed + awk. The Go
// port preserves the same semantics:
//   - next 6-digit ID = max(issues/, history/) + 1
//   - slug = lowercase title with non-alphanumerics → hyphens, collapsed
//   - frontmatter: id, status: open, deps: [], github_issue, created/updated
//   - body skeleton: # title, body, ## Done when, ## Plan (- [ ]), ## Log
package main

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/spf13/cobra"
)

// fetchFlags holds the parsed flag values for the fetch subcommand.
type fetchFlags struct {
	GitHubIssue int
	IssuesDir   string
	HistoryDir  string
	DryRun      bool
}

// NewFetchCmd returns the cobra command for `sdlc fetch`. Long is a
// placeholder; main.go overrides with helptext.MustGet("fetch").
func NewFetchCmd() *cobra.Command {
	f := fetchFlags{}
	cmd := &cobra.Command{
		Use:           "fetch",
		Short:         "Fetch a GitHub issue and create a local workshop/issues/ file",
		Long:          "Placeholder — replaced by helptext.MustGet(\"fetch\") in main.go.",
		Args:          cobra.NoArgs,
		SilenceErrors: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runFetch(cmd.OutOrStdout(), cmd.ErrOrStderr(), &f)
		},
	}
	cmd.Flags().IntVar(&f.GitHubIssue, "github-issue", 0, "GitHub issue number to fetch (required)")
	cmd.Flags().StringVar(&f.IssuesDir, "issues-dir", envOr("WF_ISSUES_DIR", "workshop/issues"), "directory holding issue files")
	cmd.Flags().StringVar(&f.HistoryDir, "history-dir", envOr("WF_HISTORY_DIR", "workshop/history"), "directory holding archived issues")
	cmd.Flags().BoolVar(&f.DryRun, "dry-run", false, "print would-be path + body; do not write")
	return cmd
}

// ghClient and the ghCaller interface live in ghclient.go (shared with
// pr.go and merge.go). M5 promoted them out of fetch.go once they had
// three+ consumers.

// runFetch is the entry point for the cobra RunE. Returns an error on
// "soft" failures (so cobra formatting kicks in for unit tests); calls
// die() directly on hard guardrail failures (gh missing, file exists).
func runFetch(stdout, stderr io.Writer, f *fetchFlags) error {
	if f.GitHubIssue <= 0 {
		die(stderr, fmt.Sprintf("--github-issue is required and must be positive (got %d)", f.GitHubIssue))
	}
	issueNum := strconv.Itoa(f.GitHubIssue)

	repo, err := detectRepo()
	if err != nil {
		die(stderr, err.Error())
	}

	title, body, err := ghClient.TitleAndBody(repo, issueNum)
	if err != nil {
		die(stderr, fmt.Sprintf("fetch GitHub issue %s: %v", issueNum, err))
	}
	if title == "" {
		die(stderr, fmt.Sprintf("GitHub issue %s returned empty title", issueNum))
	}

	slug := slugify(title)
	nextID, err := nextIssueID(f.IssuesDir, f.HistoryDir)
	if err != nil {
		die(stderr, err.Error())
	}

	today := time.Now().Format("2006-01-02")
	dest := filepath.Join(f.IssuesDir, fmt.Sprintf("%s-%s.md", nextID, slug))
	if _, err := os.Stat(dest); err == nil {
		die(stderr, fmt.Sprintf("issue file already exists: %s", dest))
	}

	rendered := renderFetchedIssue(nextID, issueNum, title, body, today)

	if f.DryRun {
		cinfo(stderr, "dry-run — no files written")
		fmt.Fprintf(stdout, "Would create: %s\n", dest)
		fmt.Fprintln(stdout, "─── body ───")
		fmt.Fprint(stdout, rendered)
		return nil
	}

	if err := os.MkdirAll(f.IssuesDir, 0o755); err != nil {
		die(stderr, fmt.Sprintf("mkdir %s: %v", f.IssuesDir, err))
	}
	if err := os.WriteFile(dest, []byte(rendered), 0o644); err != nil {
		die(stderr, fmt.Sprintf("write %s: %v", dest, err))
	}

	cok(stderr, fmt.Sprintf("Created %s (GitHub #%s)", dest, issueNum))
	fmt.Fprintln(stdout, dest)
	return nil
}

// ── helpers ──────────────────────────────────────────────────────────────────

// originRE captures owner/repo from either git@github.com:owner/repo.git
// or https://github.com/owner/repo[.git]. The Makefile target uses sed
// with two patterns; this single Go regex covers both shapes.
//
// Lazy capture so deeper-path hosts (rare) still parse owner/...rest;
// the shell's sed pipeline does the same via greedy `.*\.git` stripping.
// Review M4 I1.
var originRE = regexp.MustCompile(`github\.com[:/]([^/].*?)(?:\.git)?(?:\n|$)`)

// detectRepo returns the "owner/repo" slug for the current repo's
// `origin` remote. Errors if origin is not configured or doesn't look
// like a github.com URL.
func detectRepo() (string, error) {
	out, err := exec.Command("git", "remote", "get-url", "origin").Output()
	if err != nil {
		return "", fmt.Errorf("git remote get-url origin: %w", err)
	}
	url := strings.TrimSpace(string(out)) + "\n"
	m := originRE.FindStringSubmatch(url)
	if m == nil {
		return "", fmt.Errorf("origin URL %q does not look like a github.com URL", strings.TrimSpace(url))
	}
	return m[1], nil
}

// slugify lowercases, replaces non-alphanumeric with hyphens, collapses
// hyphen runs, trims leading/trailing hyphens. Matches the Makefile sed
// pipeline:
//
//	tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//'
func slugify(title string) string {
	var b strings.Builder
	for _, r := range strings.ToLower(title) {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
		} else {
			b.WriteRune('-')
		}
	}
	// Collapse hyphen runs.
	out := regexp.MustCompile(`-+`).ReplaceAllString(b.String(), "-")
	return strings.Trim(out, "-")
}

// nextIssueID scans issuesDir + historyDir for filenames starting with
// 6 digits, returns the next ID zero-padded to 6 chars. Missing dirs
// are treated as empty (matches the Make target's `ls ... 2>/dev/null`).
func nextIssueID(issuesDir, historyDir string) (string, error) {
	max := 0
	idRE := regexp.MustCompile(`^(\d{6})-`)
	for _, dir := range []string{issuesDir, historyDir} {
		entries, err := os.ReadDir(dir)
		if err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return "", fmt.Errorf("read %s: %w", dir, err)
		}
		for _, e := range entries {
			m := idRE.FindStringSubmatch(e.Name())
			if m == nil {
				continue
			}
			n, _ := strconv.Atoi(m[1])
			if n > max {
				max = n
			}
		}
	}
	return fmt.Sprintf("%06d", max+1), nil
}

// renderFetchedIssue assembles the issue-file content for a freshly-
// fetched GitHub issue. Mirrors the printf block in Makefile.workflow's
// `fetch:` target. Trailing newline included.
func renderFetchedIssue(id, ghNum, title, body, today string) string {
	var b strings.Builder
	b.WriteString("---\n")
	fmt.Fprintf(&b, "id: %s\n", id)
	b.WriteString("status: open\n")
	b.WriteString("deps: []\n")
	fmt.Fprintf(&b, "github_issue: %s\n", ghNum)
	fmt.Fprintf(&b, "created: %s\n", today)
	fmt.Fprintf(&b, "updated: %s\n", today)
	b.WriteString("---\n")
	b.WriteString("\n")
	fmt.Fprintf(&b, "# %s\n", title)
	b.WriteString("\n")
	b.WriteString(body)
	b.WriteString("\n")
	b.WriteString("\n")
	b.WriteString("## Done when\n")
	b.WriteString("\n")
	b.WriteString("-\n")
	b.WriteString("\n")
	b.WriteString("## Plan\n")
	b.WriteString("\n")
	b.WriteString("- [ ]\n")
	b.WriteString("\n")
	b.WriteString("## Log\n")
	b.WriteString("\n")
	fmt.Fprintf(&b, "### %s\n", today)
	b.WriteString("\n")
	return b.String()
}
