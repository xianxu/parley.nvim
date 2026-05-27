package issue

import "regexp"

// Plan-section parsing — shared between cmd/sdlc/close (which refuses an
// issue close if Plan has unticked items) and cmd/sdlc/state (which
// counts ticked vs total for the inspection surface).
//
// Moved here from cmd/sdlc package-level so both callers reference one
// source of truth — per M2 review I5, the cross-file coupling via package
// vars was an implicit dependency the next refactor could break.

// PlanSectionRE captures the body of the `## Plan` section, stopping at
// the next top-level `##` heading or end-of-text. Submatch 1 is the body.
var PlanSectionRE = regexp.MustCompile(`(?ms)^## Plan\s*\n(.*?)(?:^## |\z)`)

// PlanItemRE matches one `- [s] ...` plan item where `s` is the state
// char (space, `x`, or `.`). The captured state char lets callers count
// total vs ticked in a single pass.
var PlanItemRE = regexp.MustCompile(`(?m)^- \[([ x.])\] `)

// PlanUncheckedRE matches one `- [ ] ...` or `- [.] ...` plan item line
// (i.e., NOT a ticked `[x]`). Used by close to refuse an issue close
// when the Plan still has open items.
var PlanUncheckedRE = regexp.MustCompile(`(?m)^- \[[ .]\] .*$`)

// CountPlanItems counts total and ticked plan items inside the `## Plan`
// section of an issue body. Returns (0, 0) if no Plan section exists.
func CountPlanItems(body string) (total, ticked int) {
	m := PlanSectionRE.FindStringSubmatchIndex(body)
	if m == nil {
		return 0, 0
	}
	section := body[m[2]:m[3]]
	for _, mm := range PlanItemRE.FindAllStringSubmatch(section, -1) {
		total++
		if mm[1] == "x" {
			ticked++
		}
	}
	return total, ticked
}
