package judge

import (
	"regexp"
	"strings"
)

// Outcome classifies an agent's output for a check. Mirrors
// scripts/lib.sh's three-way split: clean (no violations), info
// (informational reminder, e.g. REMINDER:), and failure (everything
// else — there's content that demands attention).
type Outcome int

const (
	Clean Outcome = iota
	Info
	Failure
)

func (o Outcome) String() string {
	switch o {
	case Clean:
		return "clean"
	case Info:
		return "info"
	case Failure:
		return "failure"
	}
	return "unknown"
}

// cleanRE matches the well-known "no findings" sentinels emitted by
// our prompt templates. Case-insensitive. Ported from
// scripts/lib.sh's is_clean_check_output grep.
var cleanRE = regexp.MustCompile(`(?i)no (DRY|PURE) violations found|all tests pass|no changes needed|in sync|no issue files changed`)

// infoRE matches reminder-style output (the lessons category) — not
// a failure, but worth surfacing.
var infoRE = regexp.MustCompile(`(?i)REMINDER:`)

// Classify returns the Outcome for a single agent's output. Empty
// output is treated as failure (the agent should have said *something*).
func Classify(output string) Outcome {
	s := strings.TrimSpace(output)
	if s == "" {
		return Failure
	}
	if cleanRE.MatchString(s) {
		return Clean
	}
	if infoRE.MatchString(s) {
		return Info
	}
	return Failure
}

// Verdict names the discrete outcomes the milestone-review prompt is
// instructed to emit on its first line. The string values are the
// canonical labels — used both in git-trailer values (Review-Verdict:)
// and in the human-mirror log line — so any addition here must also
// land in the prompt template (prompts.go MilestoneReview branch) and
// in the verifier helper (close.go's milestone-verdict guard).
type Verdict string

const (
	VerdictShip          Verdict = "SHIP"
	VerdictFixThenShip   Verdict = "FIX-THEN-SHIP"
	VerdictRework        Verdict = "REWORK"
	VerdictNotRun        Verdict = "not-run"   // judge skipped or errored
	VerdictUnknown       Verdict = "unknown"   // judge ran, first line unparseable
)

// verdictRE matches the milestone-review prompt's first-line verdict
// shape:
//
//	SHIP | FIX-THEN-SHIP | REWORK   (confidence: high | medium | low)
//
// Tolerant on whitespace around the pipes and on the confidence
// parenthetical (the prompt asks for it but we don't punish drift).
// Anchored at start-of-line of the first non-empty line; the prompt
// instructs the agent to emit this as line 1 of the response.
var verdictRE = regexp.MustCompile(`(?m)^\s*(SHIP|FIX-THEN-SHIP|REWORK)\b`)

// ParseVerdict extracts the verdict label from the agent's milestone-
// review output. Returns one of VerdictShip / VerdictFixThenShip /
// VerdictRework if the first non-empty line opens with one of those
// tokens, else VerdictUnknown.
//
// Pure: no IO, deterministic on its input. Lives in the judge package
// alongside Classify so the prompt + parser sit next to each other.
func ParseVerdict(output string) Verdict {
	// Walk to the first non-empty line. The prompt promises line 1,
	// but reviewers sometimes preface with a blank line or banner —
	// don't be brittle about it.
	for _, line := range strings.Split(output, "\n") {
		t := strings.TrimSpace(line)
		if t == "" {
			continue
		}
		m := verdictRE.FindStringSubmatch(t)
		if m == nil {
			return VerdictUnknown
		}
		switch m[1] {
		case "SHIP":
			return VerdictShip
		case "FIX-THEN-SHIP":
			return VerdictFixThenShip
		case "REWORK":
			return VerdictRework
		}
		return VerdictUnknown
	}
	return VerdictUnknown
}
