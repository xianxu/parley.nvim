# Parley

<!-- parley:introduction:start -->
Parley is a workspace for exploring ideas with AI. Conversations live in local
Markdown files that you can edit, search, and annotate. Ask different models in the
same conversation, revise earlier text, and add private notes as you learn. You can
tweak your questions and ask again if an answer is unsatisfactory; you can edit
the answer itself and delete AI slop, which improves subsequent answers. You
can start a side question anytime in a branched chat, and navigate back with the
outline without losing track.

The **Parley app** packages this workflow as a standalone Neovim app that is easy
to install. You do not need an existing Neovim setup; the built-in tutorials teach
the few editor controls needed to get started.
<!-- parley:introduction:end -->

[![Parley in action](docs/media/parley-nvim-v1.gif)](https://xianxu.dev/2026/09/parley-nvim-v1/)

*Parley in action. The full walkthrough is in [the launch post](https://xianxu.dev/2026/09/parley-nvim-v1/).*

## Install the app

The recommended starting point is the **Parley app for macOS**, installed with
[Homebrew](https://brew.sh/):

```sh
brew install xianxu/parley/parley
parley
```

Homebrew installs the pinned editor dependencies with the app. The bundled
starter opens the Welcome tutorial without downloading editor plugins; follow
it to connect an account, choose a model, and send your first question. Editor
startup and local Markdown preview work offline; provider login and AI requests
still need a connection. Existing edited profiles must adopt the new
`init.lua.new` starter to use bundled dependencies.

Your Parley editor settings and chats are separate from your existing Neovim
profile; provider logins are shared with other CLIProxyAPI clients.

See the [app guide](packaging/README.md) for updates and removal, or
[configuration and recovery](packaging/starter-config/README.md) for profile
paths and settings. Existing Neovim users can use the
[plugin setup guide](atlas/infra/config.md#install-as-a-neovim-plugin), on
Neovim 0.11 or newer (an older editor gets a clear refusal; see
[supported versions](atlas/infra/test_harness.md)):
`require('parley').setup({})` works as is; see
[minimal config](atlas/infra/config.md#minimal-config) for typical overrides.

In a Couch pane, the first Alt+Return in any named Markdown document saves,
registers and submits it to the pane's agent, without changing its frontmatter.
The winbar confirms the destination and time after submission succeeds, until
your next edit or the agent's write; failures show an error there. Unchanged
content shows `nothing to submit` instead of sending again. Press Alt+Return
a second time within two seconds to resend explicitly.
The editor never waits on a submit: the winbar shows `submitting…`. If Couch
hasn't confirmed it within `agentic_submit_timeout_ms` (default 15000), or the
registry failed, it turns red with `not confirmed: submit again`. Alt+Return then
completes it, and it never delivers twice: a press while a send is still out
joins it. Moves and renames never wait on Couch: a registered document moves at
once while Couch confirms in the background, and one parley doesn't know yet
says to run the move again (rerun within a minute: the background answer then
expires). Only `:saveas!` onto an existing file asks first,
within `agentic_move_timeout_ms` (default 5000), and on that deadline says to
rename back first.
An explicit `couch-owner:` overrides the default; a business `owner:` does not
(`owner:` remains a fallback only for legacy `type: session-sync` files).
[Agentic documents](atlas/modes/session_sync.md) use the existing turn engine:
once registration is known, entering insert mode confirms your turn with Couch
before typing, then checks
for and silently reloads a newer clean copy. Acquisition waits at most 500 ms.
An uncached background lookup keeps editing available until identity is known;
attachment reconciles edits made during that interval.
A namespace/store failure or timeout allows editing with `not locked: Couch
unreachable; edits may conflict`; conflicting versions are kept through the
existing clobber-copy path. A held-lock refusal or invalid acknowledgment blocks
edits with a notice that keys were not applied. Leave insert, then press `i`
to retry when protection is available (`a`, `o`, `I`, `A`, and `O` also retry),
or use `:ParleySessionRetry`. These local mappings exist only during refusal. A stopped Couch supervisor does not prevent these
local acquire/release commands. Leaving unchanged (Escape or Ctrl-C) releases
an owned turn. Normal-mode edits also take the turn before auto-save.
Undo back to the acquisition baseline releases it outside insert mode, and redo
takes it again. Saves never move that baseline.
While viewing a registered session file or side doc, external writes reload a
clean buffer silently with cursor and view retained. Conflicting local work uses
the same copy-and-notice path without Neovim's file-changed prompt. Unregistered
files retain Neovim's default handling.
Leaving a document with an unsubmitted turn gives three short red winbar pulses
and a file-named `unsubmitted: Alt+Return to submit` reminder. Navigation stays
free; after a same-window file switch the destination bar names the file left
behind. Undo back to the baseline suppresses the reminder, while auto-save does
not count as submission.
Quiet owners with owed deliveries are pinged after `session_sync_ping_minutes`
(default 15); unsent edits become stale after `session_sync_stale_minutes`
(default 5). Unknown offline membership stays editable with `Couch unavailable:
agentic state unknown`, while known attached/cached documents keep turn
protection. Supported moves retain identity, carry their `.side/` folder, and
update the parent's links/discussions index and side-doc backlinks. If the new
name has an orphan `.side/` folder and no document, the orphan is retained at the
first free `_N.side/` name; a notice gives its path. The loaded parent receives
the rewritten references before Couch confirms the move. A move is moving,
done, or interrupted: an interrupted move names the reason and asks you to
reopen to finish. Changed or unknown bytes are preserved; reopening never
forces an overwrite. Outside a Couch pane, the existing
[document review](atlas/modes/review.md) flow remains.

A long-running editor watches its own open files. The first time it holds more
than `fd_watchdog_threshold` (default 200; macOS stops a process at 256), it
writes the open files (`lsof`) and the names of its running child programs to
`<state_dir>/fd-captures/` and warns once, naming the file. Child arguments are
never recorded. The newest five captures are kept; `0` turns the watchdog off.
See [the open-descriptor watchdog](atlas/infra/fd_watchdog.md).

In a Couch pane, **Alt+Return** sends only `submitted: ABSOLUTE_PATH` through
the registered document flow. The agent's shared `xx-universal-review` skill
reads the file's `process-instruction:` and changes since its last read.
Outside Couch, the same shortcut runs Parley's inline review using the bundled
canonical round, marker grammar, collaboration modes (when exported) and review
modes with its local editing tool.
Local review answers discussion (the default) and collaboration in place.
It leaves chat sections untouched and reports that the hub agent answers chat.
Unknown collaboration modes or conflicting heading assignments stop the round.
Side documents, chat answer files and changes since the last read remain with
the agent-side skill in Couch.

When the agent answers, Parley shows what its write changed the way the
document's `presentation:` frontmatter asks. Under `highlight` (the default),
each changed span is highlighted, and its diagnostic gives the agent's reason
(or "changed by the agent"). The highlights follow your edits and clear on your
next confirmed Alt+Return. Under `propose`, the agent writes per-line
accept/reject markers instead, and a rewrite too large for them arrives as a
`→ [proposal](…)` side-doc link that Alt+o follows. Under `direct`, nothing is
drawn. A round past 200 changes highlights the first 200 and says so. This
needs a Couch with the `round` verb (pair#661). An older one shows nothing.
Added text gets a faint green background, changed text a faint blue one. Both
are tinted from your theme's own background, so they stay quiet in any color
scheme, and a deletion leaves no mark. To restyle them, set
`highlight.edit_add` and `highlight.edit_change`. In Markdown
documents, 🤖 markers and links show in full. In chats, Parley still hides its
own branch links and model params. Markdown links there show in full too,
unless you set `chat_treesitter = true`, which conceals them.

Press **Alt+Shift+O** in Normal or Insert mode to return to the previous file
in the current window, restoring its cursor position. Follow links with Alt+o,
then use Alt+Shift+O repeatedly to return through answer and side documents to
your session file. A split or tab opened by a user command or Parley's openers
inherits the focused window's history and keeps its own later visits. Windows
created through APIs or RPC start with empty history. File-entry events begin
their history; Back can also establish the displayed file as their root.
See [file navigation](atlas/ui/keybindings.md#file-history-back)
for the command and configuration.

Press **Alt+Space** or **Ctrl+Y Space** (`:ParleyAttention`) to list files you submitted with
Alt+Return, newest first: **waiting** while the agent still owes it, **answered**
once the agent has folded the submit, and **seen**, dimmed, once you have looked
at it after the answer: opened it from the finder, or focused, moved or scrolled
in a window showing it. The file in your current window is left out. New side docs the agent writes in a listed file's `.side/`
folder appear too, as answered (`↳`). Opening an entry restores the trail of
files it had when you submitted it. A seen entry leaves the list `attention.seen_grace_minutes` later
(default 60); a new submit makes it waiting again. See the
[attention finder](atlas/ui/attention_finder.md).

In Couch, the list defaults to submits from this pane’s slot. **Ctrl+A** toggles current/all slots
(`attention_finder_mappings.toggle_scope`); the title shows the scope. Legacy entries without a slot appear everywhere,
and outside Couch the finder shows all slots. A file belongs to its latest submitting slot; new side docs inherit their parent’s slot.
Side docs appear beneath their parents, indented two spaces per level. Searching a child keeps its parent chain visible; children whose parents are absent appear at the top level.
**Ctrl+R** clears every shown row immediately, including parent context, respecting the scope and typed filter. Hidden entries stay; a later submit brings a cleared file back. The finder reports the count without a confirmation prompt. Configure `attention_finder_mappings.clear_shown`; inside this finder, Ctrl+R replaces native register paste.

## Learn by chatting

These tutorials open as editable chats in the app. You can also read their
bundled originals here.

1. [Welcome](packaging/tutorials/welcome.md) — editor essentials, connecting an
   account, choosing a model, and sending a question.
2. [Basics](packaging/tutorials/basics.md) — finding conversations, navigating the
   outline, and branching into a side question.
3. [Advanced](packaging/tutorials/advanced.md) — what the model sees, project
   folders, local tools, chat-history search, and images.
4. [VIM Basics](packaging/tutorials/vim-basics.md) — modes, Back/Forward navigation,
   undo/redo, smart search, selection, clipboard editing, and saving.

As an AI-enhanced learning tool, Parley can teach you about Parley itself: it
ships its own help and points the model at it. Try asking Parley about a feature as you work. Its documentation tool reads the
README, tutorials, and [atlas](atlas/index.md) from your installed version.

## Contribute to Parley

For local verification, run `./parley_app` from your checkout. It caches the pinned
dependencies on first launch; `--nuke` clears those dependencies while retaining
chats, settings and login. See [local launcher instructions](TOOLING.md) and the
[recording workspace guide](demo/README.md) for `--demo`.

Parley is built entirely by AI agents, so contributing works a little differently.
It uses `ariadne` as its base development layer, and everything is managed inside
this GitHub repo. For example, issue tracking is in
`./workshop/issues`. Check out [Ariadne](https://github.com/xianxu/ariadne) for
development processes. Roughly:

1. Clone this repo.
2. Run `weave compile`, which pulls the necessary base layers and compiles binaries that
   support the AI native development processes. `weave refresh` will update local clone 
   of ariadne dependencies, and current repo, then run `weave comple`.
3. Start your favorite AI coding tool: `claude`, `codex`, etc.
   I use [pair and couch](https://github.com/xianxu/pair), which provides a much
   stronger local development environment while leveraging other coding agents.

CI builds weave from the exact Ariadne commit in `.sdlc/weave-compiler-ref`
(one lowercase 40-character SHA plus newline). Compiler updates use a reviewed
PR and require the operator’s `local-gates-verified` label. See the
[CI compiler guide](atlas/infra/ci_compiler.md) for validation and recovery.

Maintainers can exercise private editor endpoint publication with
`python3 scripts/check-couch-registry-conformance.py --editor-endpoints --fake-only`.
This runs two disposable native editors through the production client and checks
a deliberately corrupted reply. For real-producer acceptance, build the supported
isolated harness bridge with `make couch-conformance-bridge` in a Pair checkout
containing the Couch endpoint producer (pair#758) and bridge (pair#801), then run
from this checkout:

```sh
python3 scripts/check-couch-registry-conformance.py --editor-endpoints --bridge /absolute/path/to/couch-conformance-bridge
```

`--bridge` must name an absolute executable path. Put the desired native `nvim`
first on the invocation `PATH`; optionally add `--couch /absolute/path/to/couch`
to select a Couch candidate. The bridge supplies the isolated producer environment;
the real run also exercises the fake and corrupted-reply controls. Fake-only
qualification does not establish real-producer acceptance. See
[endpoint ownership](atlas/modes/remote_session.md).

Before sending pull request, you should file an issue first, focusing on the feature
you want to create and getting alignment with maintainer first. All pull request without
agreement won't be checked. After all, in the era of AI coding, it's easy to write 
code; it's harder to agree what feature should be created.

## Report issues

Use [GitHub issues](https://github.com/xianxu/parley.nvim/issues) for feature requests
and bug reports.

## Acknowledgement

Parley was adapted from [gp.nvim](https://github.com/Robitx/gp.nvim) and has since
been redesigned so thoroughly that it bears little resemblance to it. See [LICENSE](LICENSE).

All sorts of AI coding agents were used to create Parley.


## Follow links from a question

Press **Alt+o** in a Markdown heading, numbered question or bullet item to open
its sole reference, including a link on a continuation line. Tight and nested
bullet lists keep each item’s links separate. Local `file.md#heading` links jump
to a matching Markdown ATX heading (levels 1–6), using bundled treesitter for
inline heading text and raw text if the parser is unavailable.
Keys lowercase/keep ASCII letters and digits, drop other ASCII and U+2000–206F/U+3000–303F, and preserve all other non-ASCII codepoints unchanged, on both sides.
Repeated keys use `-1`, `-2`, etc.; a full numeric heading takes priority.
HTML headings and character-reference decoding are outside this feature.
An empty or unmatched key opens the file at the top with a notice; an anchor
that strips other non-ASCII symbols may therefore miss.
Several references show a picker; cancel leaves the source alone. A reference
directly under the cursor takes priority. With no reference in the entity,
Parley uses its existing artifact resolver and Vim file navigation.
Markdown link labels can wrap across lines within a paragraph; Alt+o on either
line opens the link, and the entity picker retains it as one reference.

## Paste screenshots into Markdown

Press **Alt+i** in Normal or Insert mode to paste a clipboard image after the
current line in any named Markdown file. Parley inserts an image link and saves
it beside that file at `assets/<file-stem>/<timestamp>.<png|jpg>`. Chat files keep
their existing timestamp asset folders. Spaces and punctuation in stems are
percent-escaped in links; the on-disk folder keeps the stem.

The existing image shrink step runs before saving: large PNGs become smaller
JPEGs within the maximum edge. `assets.shrink` and `assets.shrink_cmd` retain
their configured behavior; the paste notice reports any retained original.
Deleting a link leaves its asset on disk. The Markdown file's owner handles
sidecar moves and sweeps unreferenced assets (the TL for session and QA files).


The document winbar combines a fixed-width edit-lock indicator with where the file is: a side doc's tree path (its `parent:` chain up to the root), otherwise the file's own path relative to its repository. Alt+o links never change what it shows; Alt+Shift+O still walks earlier file visits. Submission feedback remains visible beside the lock; long paths shorten in the middle to fit the window. The band replaces any winbar of your own in file windows; set `breadcrumb = { enable = false }` to turn it off there (lock states still show). See [breadcrumb behavior and snapshots](atlas/ui/breadcrumb.md).
