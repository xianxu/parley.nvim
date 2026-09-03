---
id: 000214
status: open
deps: [#212]
github_issue:
created: 2026-09-02
updated: 2026-09-02
estimate_hours:
---

# audit and curate the default keybinding surface

## Problem

Parley claims a large share of the user's keyspace by default, and the claim was
never curated — bindings accumulated as features were added. Today
`lua/parley/config.lua` ships **65 default shortcuts** across six prefix
families:

| Family | Count | Keys |
|---|---|---|
| `<C-g>` chat/parley | 24 | the core chat surface |
| `<C-n>` notes | 4 | `c f h r` |
| `<C-y>` issues | 6 | `c f g i s x` — ariadne |
| `<C-j>` vision | 6 | `ec ed f n o v` — ariadne |
| `<leader>` | 6 | `cc cC cf cl cL` **plus `fo`, which maps oil.nvim** — a plugin parley never requires |
| other | 19 | `gf`, `gP`, `<M-CR>`, `<M-o>`, and finder-local keys |

Three separate defects sit underneath that count.

**1. Ten bindings cannot be rebound or disabled at all.** The registry
(`keybinding_registry.lua`) holds 78 entries, 68 with a `config_key` the user can
override and **10 registry-only**:

```
interview_start         <C-n>i            note
interview_stop          <C-n>I            note
note_template           <C-n>t            note
outline                 <C-g>t, <M-t>     parley_buffer
branch_ref              <C-g>i            parley_buffer
chat_toggle_web_search  <C-g>w            chat
chat_drill_in           <C-g>q, <M-q>     parley_buffer
chat_accept_drill_in    <M-a>             parley_buffer
chat_reject_drill_in    <M-r>             parley_buffer
md_delete_file          <C-g>d            markdown
```

`<M-q>` is a headline feature and `md_delete_file` **deletes a file** — neither
can be moved off a colliding key.

**2. Four bindings are made outside the registry entirely**, so they appear in no
audit surface, in no `<C-g>?` help, and in no config:

- `u` and `<C-r>` are shadowed in chat buffers (`init.lua:2213,2216`)
- `<CR>` is rebound in insert mode by spell typeahead (`spell.lua:168`) and again
  by interview mode (`interview.lua:85`) — colliding with cmp/blink, which nearly
  every Neovim user has on `<CR>`

**3. The core/peripheral line was never drawn.** Ariadne workflow keys
(`<C-y>*`, `<C-j>*`), the `<leader>` copy helpers, and an oil.nvim mapping all
ship with the same default status as `<C-g>c`.

## Spec

Draw an explicit line between the bindings parley claims by default and the ones
a user opts into, and make everything it does claim rebindable and visible.

**Policy to decide and then encode:**

- **Core default set** — small enough to justify itself key by key. The
  candidates are the `<C-g>` chat surface plus `<M-CR>` and `<M-q>`; each survives
  only if it is defensible as a *chat product* binding.
- **Opt-in set** — everything a user should turn on deliberately. Per the
  operator's direction, ariadne bindings (`<C-y>*`, `<C-j>*`) are configured
  explicitly rather than defaulted, **even inside an ariadne repo** — this goes
  further than #212, which only stops binding them where the feature cannot work.
  The `<leader>` maps belong here too: `<leader>` is the user's namespace, and
  `<leader>fo` maps a plugin parley does not depend on.
- **Never-claimed set** — keys parley should not shadow at all, or should shadow
  only with an explicit opt-in: `u`, `<C-r>`, and `<CR>` in insert mode.

**Structural work, independent of where the policy lands:**

- Every binding parley registers must have a `config_key`, so it can be
  rebound or disabled. Ten currently cannot (`ARCH-PURPOSE`: the registry is the
  single source only if *every* binding derives from it — ten exceptions make it
  a partial source).
- Move the four off-registry bindings into the registry, or document why they
  cannot be. A binding invisible to `<C-g>?` and to config is the worst case: it
  shadows a core Vim key, and the user has no way to find or change it
  (`ARCH-DRY`).
- Provide one documented switch to disable the whole default keymap for users who
  bind everything themselves.
- Resolve the redundant doubles (`<C-g>t`/`<M-t>`, `<C-g>q`/`<M-q>`) — keep both
  deliberately or drop one.
- Review the `<M-*>` family for terminal portability; alt-chords are the least
  reliable class shipped, and `<M-CR>` is already split across two registry
  entries because one entry could not express its key/mode matrix
  (`config.lua:326-329`).

Ordering: this depends on #212, which establishes context-filtered registration.
This issue sets the *policy* that mechanism enforces; doing them in the other
order means reworking the same call sites twice.

## Done when

- The default keymap is enumerated in one place with a written rationale per
  family, and the enumeration is what the code registers — not a parallel list.
- Every binding parley registers is rebindable and disableable through config;
  a test asserts no registry entry lacks a `config_key`, and has been seen red.
- `u`, `<C-r>` and insert-mode `<CR>` are either not shadowed by default, or are
  shadowed only behind an opt-in that is documented and testable.
- No binding exists that `<C-g>?` cannot show — asserted in both directions, so
  help and reality agree.
- A single documented switch disables the entire default keymap, verified by
  `:map` showing no parley mapping afterwards.
- With the opt-in set unconfigured, a fresh install claims no `<leader>` key and
  no `<C-y>`/`<C-j>` key in any context.

## Plan

- [ ] Enumerate all 65 defaults + 4 off-registry bindings; classify core / opt-in / never-claimed with a rationale each.
- [ ] Review the classification with the operator before changing code — this is a policy decision, not a refactor.
- [ ] Give all 10 registry-only entries a `config_key`; pin with a test seen red.
- [ ] Bring the 4 off-registry bindings into the registry, or record why not.
- [ ] Apply the classification; add the master disable switch.
- [ ] Assert help/reality agreement in both directions; assert a bare install claims no opt-in key.

## Log

### 2026-09-02

Raised by the operator while reviewing the parley-v1-release breakdown: the
audit had catalogued the keybinding *land-grab* as blocker B9, but treated it
purely as a gating problem. The operator's framing is the missing half — even
where a feature works, a default binding is a claim on the user's keyspace that
has to be justified, and ariadne bindings should be explicitly configured rather
than defaulted.

Distinct from #212 on purpose. #212 asks "can this feature work in this context?"
and stops binding it where it cannot. This issue asks "even where it works, does
it deserve a default key?" — a curation judgment, not a mechanical one. #212 is a
launch blocker; this is quality work that rides on the mechanism #212 builds.

Counts current as of this date: 78 registry entries (68 rebindable, 10 not, 18
help-only, 3 with no default key), 65 default shortcuts in `config.lua`, and 4
bindings made outside the registry.
