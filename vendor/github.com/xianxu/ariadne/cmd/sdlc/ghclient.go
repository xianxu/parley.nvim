// ghclient.go — shared `gh` CLI shim. Extracted in M5 so fetch / pr /
// merge can all stub `gh issue view` / `gh pr list` / `gh pr create` /
// `gh pr merge` through one seam.
//
// The interface intentionally enumerates the exact calls our verbs make
// rather than exposing a generic Run(args...). That lets each method's
// argv shape be tested in isolation; the production realGH wires the
// concrete `gh` flags. If a future verb needs a new gh call, add a
// method here rather than reaching for a generic Run.
package main

import (
	"fmt"
	"os/exec"
	"strings"
)

// ghCaller is the shared interface fetch/pr/merge use to talk to the
// gh CLI. realGH below is the production implementation; tests
// substitute stubGH (in fetch_test.go) or richer fakes per-verb.
type ghCaller interface {
	// TitleAndBody returns the title + body of GitHub issue issueNum
	// in repo (owner/repo slug). Used by `sdlc fetch`.
	TitleAndBody(repo, issueNum string) (title, body string, err error)

	// IssueClose closes GitHub issue issueNum in repo with the given
	// comment. Used by `sdlc push` after archiving done issues.
	IssueClose(repo, issueNum, comment string) error

	// PRCreate opens a pull request and returns the URL of the new
	// PR. baseRef and headRef are git refs; body is the body text
	// (empty allowed). If body == "" we pass --fill (commit-derived
	// body); otherwise --fill-first plus --body. Mirrors the shell
	// pull-request: target's branching.
	PRCreate(repo, baseRef, headRef, body string) (url string, err error)

	// PRListForBranch returns the GitHub PR number for the open PR
	// targeting `headRef` (the branch name without origin/) in repo,
	// or "" if there is none. Used by `sdlc merge` to find an existing PR.
	PRListForBranch(repo, headRef string) (number string, err error)

	// PRMerge merges PR for branch on repo via the GitHub API
	// (--merge --delete-branch). Used by `sdlc merge`.
	PRMerge(repo, branch string) error
}

// ghClient is the package-level instance every verb resolves through.
// Tests swap it; production keeps the realGH default.
var ghClient ghCaller = realGH{}

// realGH dispatches to the gh CLI on PATH.
type realGH struct{}

func (realGH) TitleAndBody(repo, issueNum string) (string, string, error) {
	if _, err := exec.LookPath("gh"); err != nil {
		return "", "", fmt.Errorf("gh CLI not on PATH: %w", err)
	}
	titleOut, err := exec.Command("gh", "issue", "view", issueNum,
		"--repo", repo, "--json", "title", "--jq", ".title").Output()
	if err != nil {
		return "", "", fmt.Errorf("gh issue view --jq .title: %w", err)
	}
	bodyOut, err := exec.Command("gh", "issue", "view", issueNum,
		"--repo", repo, "--json", "body", "--jq", ".body // \"\"").Output()
	if err != nil {
		return "", "", fmt.Errorf("gh issue view --jq .body: %w", err)
	}
	title := strings.TrimRight(string(titleOut), "\n")
	body := strings.TrimRight(string(bodyOut), "\n")
	return title, body, nil
}

func (realGH) IssueClose(repo, issueNum, comment string) error {
	if _, err := exec.LookPath("gh"); err != nil {
		return fmt.Errorf("gh CLI not on PATH: %w", err)
	}
	args := []string{"issue", "close", issueNum, "--repo", repo}
	if comment != "" {
		args = append(args, "--comment", comment)
	}
	out, err := exec.Command("gh", args...).CombinedOutput()
	if err != nil {
		return fmt.Errorf("gh issue close %s: %w\n%s", issueNum, err, string(out))
	}
	return nil
}

func (realGH) PRCreate(repo, baseRef, headRef, body string) (string, error) {
	if _, err := exec.LookPath("gh"); err != nil {
		return "", fmt.Errorf("gh CLI not on PATH: %w", err)
	}
	args := []string{"pr", "create", "--repo", repo, "--base", baseRef, "--head", headRef}
	if body != "" {
		// --fill-first prefills title from the first commit subject, then
		// our --body overrides the body. Matches the shell pull-request
		// target's `gh pr create ... --fill-first --body "$body"` path.
		args = append(args, "--fill-first", "--body", body)
	} else {
		// No collected body (no touched issues, no commits) → let gh
		// derive title + body from the commit history.
		args = append(args, "--fill")
	}
	out, err := exec.Command("gh", args...).CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("gh pr create: %w\n%s", err, string(out))
	}
	return strings.TrimSpace(string(out)), nil
}

func (realGH) PRListForBranch(repo, headRef string) (string, error) {
	if _, err := exec.LookPath("gh"); err != nil {
		return "", fmt.Errorf("gh CLI not on PATH: %w", err)
	}
	out, err := exec.Command("gh", "pr", "list",
		"--repo", repo, "--head", headRef,
		"--json", "number", "--jq", ".[0].number // \"\"",
	).Output()
	if err != nil {
		// `gh pr list` errors when not authed or repo missing; the shell
		// target treats this as "no PR" (`|| true`). Mirror it.
		return "", nil
	}
	return strings.TrimSpace(string(out)), nil
}

func (realGH) PRMerge(repo, branch string) error {
	if _, err := exec.LookPath("gh"); err != nil {
		return fmt.Errorf("gh CLI not on PATH: %w", err)
	}
	out, err := exec.Command("gh", "pr", "merge",
		"--repo", repo, "--merge", "--delete-branch", branch,
	).CombinedOutput()
	if err != nil {
		return fmt.Errorf("gh pr merge: %w\n%s", err, string(out))
	}
	return nil
}
