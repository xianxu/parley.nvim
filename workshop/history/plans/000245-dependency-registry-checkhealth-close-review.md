# Boundary Review — parley245-plan#245 (whole-issue close)

| field | value |
|-------|-------|
| issue | 245 — Dependency registry and honest install advice: managed cliproxyapi, platform tools, brew one-liners in checkhealth |
| repo | parley245-plan |
| issue file | workshop/issues/000245-dependency-registry-checkhealth.md |
| boundary | whole-issue close |
| milestone | — |
| window | da6f6dbff67da4ed5a813dd33c73a58fd9dd1968..04099abf34432707c86b78e43306aac543163c33 |
| command | sdlc close --issue 245 |
| reviewer | codex |
| timestamp | 2026-09-13T14:03:16-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

The implementation matches the issue’s revised scope. Registry advice reaches the existing consumers, health discovery is read-only, and README/atlas updates cover the new surface. No blocking defect found. Confidence is limited by sandbox restrictions preventing the download fixture from binding a local socket.

1. **Strengths**
   - Registry policy remains independent of Neovim and IO, with host/manager decision tests (`lua/parley/deps.lua:183`).
   - Managed version attribution follows actual discovery precedence; custom/PATH binaries cannot inherit the managed version (`lua/parley/deps_probe.lua:21`).
   - Clipboard tests exercise repeated absence, fresh probes, installation recovery, and setup reset (`tests/integration/paste_image_spec.lua:131`).
   - The advice-consumer sweep covers clipboard, shrink, exporter, and managed-binary guidance; architecture tests guard registry ownership.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings**
   - The Core concepts tables omit explicit PURE/INTEGRATION classifications. Their prose and “Wraps” column convey the distinction, but the requested greppable classification is missing.

5. **Test coverage notes**
   - **129 tests passed** across nine relevant spec files, including the architecture guard.
   - `make lint` and pinned-range `git diff --check` passed.
   - `make test-spec SPEC=infra/dependencies` stopped at the download fixture: four tests failed after requests targeted port 0. An independent socket check confirmed `bind()` fails with `Operation not permitted`. Download execution remains unverified in this review environment.
   - No prior findings required disposition. Repository files were unchanged.

6. **Architectural notes**
   - **ARCH-DRY — Pass:** Existing advice consumers derive from the registry; executable-alias advice is deduplicated.
   - **ARCH-PURE — Pass in code; minor documentation flag:** Policy and observation are separated; concept kinds should be explicit.
   - **ARCH-PURPOSE — Pass:** Current advice consumers are covered. The tracker explicitly approves the default package projection and #247 formula-parity handoff.
   - **ARCH-MOCK — Pass by inspection:** Existing stateful release and clipboard/shrink boundaries remain shared with production. Download execution has the limitation above.
   - **ARCH-CONSTRAINTS — Pass:** Finite local probes; no new network calls, subprocess launches, or asynchronous work.
   - **ARCH-SECURE — Pass:** Advice remains display text; malformed version records yield unknown; selected-source attribution is tested.
   - **ARCH-ORDER — Pass:** Notice suppression preserves fresh detection, and setup resets its generation. Recovery is exercised deterministically.
   - **ARCH-FUNERAL — Pass:** No new durable runtime artifacts; notice state is bounded and reset.

7. **Plan revision recommendation**
   - Add a `## Revisions` entry recording explicit concept classifications: registry/recipe data as PURE; observation, health, managed paths, notice state, and exporter integration as INTEGRATION.

```findings
findings:
  - id: new
    severity: Minor
    family: core-concept-classification
    title: |
      Add explicit PURE/INTEGRATION kinds to the Core concepts tables.
    detail: |
      workshop/plans/000245-dependency-registry-plan.md:30 and :53 omit the kind column required for the ARCH-PURE cross-check. Add classifications to every row and record the documentation correction under ## Revisions; no runtime change is needed.
```
