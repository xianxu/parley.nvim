# Finder help and aliases (#251)

The operator approved the three corrections from the help audit. Preserve the existing configuration API and make its full shortcut list effective.

## Core concepts

| Name | Lives in | Status |
|---|---|---|
| `keys_for` | `lua/parley/keybinding_registry.lua` | new |
| Resolved shortcut list | lua/parley/keybinding_registry.lua | modified: expose keys_for by ID |
| Picker extra mapping | lua/parley/float_picker.lua | modified: key accepts string or list |

One registry entry owns one ordered list of shortcuts. Primary-key helpers stay unchanged for labels. Finder help combines contextual registry entries with the fixed prompt controls, which are picker-owned rather than optional registry defaults.

## Integration points

| Name | Lives in | Status | Wraps |
|---|---|---|---|
| Extra mapping installer | lua/parley/float_picker.lua | modified | Neovim buffer mappings |
| Picker callers | chat/note/issue_finder, agent/outline/system_prompt/root_dir pickers | modified | registry resolution and picker options |

Use the existing callback and focus lifecycle for every alias. Expand aliases before the existing normalization/reserved-key checks. This is setup-time work proportional to configured shortcut count, with no added per-key work (ARCH-CONSTRAINTS). No service or durable runtime artifact is introduced (ARCH-SECURE/FUNERAL); tests use isolated local profiles. ARCH-DRY: resolution stays in the registry, binding stays in the picker. ARCH-ORDER: alias installation does not change callback scheduling or confirmation ownership.

## Implementation

- Add failing help/keys_for tests and picker tests for alias dispatch, empty lists, and reserved aliases mixed with allowed keys.
- Add registry keys_for; update branch wording and finder prompt controls. Leave key_for/key_label primary behavior intact.
- Allow extra mapping key arrays; normalize/filter each alias through existing code. Convert registry-backed picker callers from key_for to keys_for (all call sites that install keys; keep title/prose uses unchanged).
- Adapt tests that inspect captured mapping descriptors to accept their new array shape; assert actual mappings/effects where practical.
- Run focused help/picker/finder tests and the exact starter override smoke with F8/F9 both invoking deletion confirmation, then full make test and lint. Update atlas/ui/keybindings.md with supported overrides and fixed picker controls.
- Commit, run sdlc close fresh review, resolve findings, and publish a PR. No merge without operator direction.

## Revisions

### 2026-09-14 — Plan review PQ-1/PQ-2/PQ-3

- PQ-1 addressed: `keys_for` adversarial inputs include absent IDs, disabled overrides, scalar and multi-alias overrides; oracle is the full ordered resolve_keys result and nil preservation. `help_lines` receives enabled/disabled/custom aliases under plugin and starter configurations; oracle is expected key membership/absence and descriptions, with fixed controls independent of optional defaults. `float_picker.open` receives scalar/list/empty keys and a list mixing normalized reserved aliases with allowed keys; inspect actual prompt i/n and results n mappings, invoke each permitted alias, and assert item/callback counts and unchanged confirmation/cancellation behavior. Finder integration uses configured alias lists through real ChatFinder and asserts native confirmation for both aliases, never merely captured descriptor shape. Existing descriptor tests only keep their earlier action/table assertions; they are not the alias acceptance evidence.
- PQ-2 addressed: expected configuration is 1–3 shortcuts per action (matching shipped aliases), with dozens of actions. Larger user lists remain accepted and cost linear setup-time mapping installations; no new cap or per-keystroke scan.
- PQ-3 addressed: collision precedence, configuration API redesign, and confirmation/focus lifecycle redesign are outside this correction. Existing last-installed precedence and reserved-key rejection remain in force; alias acceptance applies to non-reserved keys.

### 2026-09-14 — Name the exported helper explicitly

The full-suite architecture check requires the exported function name in the core-concepts table, not only its descriptive noun above. This records the same planned helper; scope is unchanged.

| Name | Lives in | Status |
|---|---|---|
| `keys_for` | `lua/parley/keybinding_registry.lua` | new |
