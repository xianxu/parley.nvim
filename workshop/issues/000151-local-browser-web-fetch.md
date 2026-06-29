---
id: 000151
status: open
deps: []
github_issue:
created: 2026-06-29
updated: 2026-06-29
estimate_hours:
---

# local browser-backed web fetch tool

## Problem

Parley has two context paths today:

- `@@...@@` references are resolved locally before submit and embedded into the model request as content snapshots.
- Agent tool calls can read local filesystem paths, while URL fetching is mostly provider-side web search/fetch when the selected provider supports it.

The missing capability is a local web-fetch tool for URLs reachable from Parley chat. Provider-side fetch cannot see pages that require the user's local authenticated browser session: SSO docs, paywalled pages, private dashboards, local dev apps, and sites where login/navigation must happen interactively.

## Spec

Add a Parley-owned local web-fetch workflow for reference URIs in chat. When the agent proposes to visit a URL through the local tool, Parley should open that URL in a local browser session, wait while the user interacts with the page, then capture the final page state once the user returns to Parley and indicates that browsing is done.

The guiding UX invariant is: content the user can reach in their local browser can be made available to the agent as an explicit, auditable snapshot. Parley should not silently browse arbitrary pages in the background or rely only on provider-side web fetch for authenticated content.

Initial design questions to resolve when this issue is claimed:

- Browser choice: use the system default browser, require Chrome/Chromium for automation APIs, or support both with capability-dependent behavior?
- Completion signal: should Parley ever auto-proceed when the page finishes loading, or should the user always explicitly confirm completion? If auto-proceed exists, define what "finished loading" means for modern SPAs.
- Navigation scope: if the user logs in, redirects, or intentionally navigates within the opened tab, should Parley capture the final destination rather than the original URL? Default expectation: yes, because the user-mediated browsing session is the source of truth.
- Capture format: send screenshot, extracted readable text, raw HTML, DOM snapshot, or a bundle? Screenshot is robust for JS-heavy/authenticated pages, raw HTML may be noisy, and text extraction is token-efficient but can lose visual state.
- Annotation flow: should Parley offer a screenshot review/markup step, for example opening the macOS screenshot editor or another local annotation UI, before sending the capture to the agent?
- Cache model: captured screenshots/page extracts must be cached locally with metadata such as original URL, final URL, title, fetched/captured timestamp, capture method, and chat/tool-call provenance.

## Done when

- There is a designed local web-fetch tool workflow for URL references in Parley chat.
- The design specifies browser integration strategy, user confirmation behavior, navigation semantics, capture format, annotation support, and cache metadata.
- The resulting implementation records browser-fetched content as explicit transcript/tool-result evidence, not hidden context.

## Plan

- [ ] Brainstorm browser integration options and choose the first supported target.
- [ ] Decide the user confirmation and navigation semantics.
- [ ] Design the capture artifact model: screenshot, extracted text/HTML, metadata, cache path, and transcript rendering.
- [ ] Plan the local tool interface exposed to agents.
- [ ] Add implementation plan and tests after the spec is approved.

## Log

### 2026-06-29

- Created as the follow-up to #85. The staleness/reload framing was rejected as too much UX cost; the real missing capability is local browser-mediated web fetch for authenticated or otherwise user-reachable web content.
