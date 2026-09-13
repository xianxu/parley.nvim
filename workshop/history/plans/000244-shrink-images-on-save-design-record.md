# Shrink images before saving (#244) Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every image that reaches `assets.save` (a `<M-v>` paste today, #239's
generated images next) is shrunk to a ≤1600 px JPEG when that pays, through the
first image tool the host has, and stored untouched when no tool exists or the
tool misbehaves.

**Architecture:** A new pure module `image_shrink` owns the policy (when to
shrink, to what edge), the recipes as data (`sips`, ImageMagick, ffmpeg, vips —
argv with `{in}`/`{out}`/`{max}` tokens), the outcome classification, and the
one-per-session probe/warn state. `assets.save` calls the step through its
injectable `io_` table before writing, so both writers get it (ARCH-DRY,
ARCH-PURPOSE). The spawn is the one seam; a stateful `fake_sips` fixture stands
in for the real tool through the same `config.assets.shrink_cmd` boundary
production uses (ARCH-MOCK). Dimension reading is pure: the PNG/JPEG walkers
`looks_like` already runs return width and height.

**Tech Stack:** Lua (Neovim 0.10 `vim.system`), plenary busted specs, a Python
fixture (same shape as `tests/fixtures/fake_clipboard`), `sips` on macOS.

---

## Decisions measured on this host (2026-09-13, macOS 26.6.2, sips-316)

These shape the design; each is a fact, not an assumption.

| Observation | Consequence |
|---|---|
| `sips --resampleHeightWidthMax 1600` on an 800×500 PNG produced 1600×1000 (it **upscales**) | The recipe never receives a fixed 1600. The policy computes `max_edge = min(1600, long edge of the source)` from `assets.dimensions` and the recipe carries a `{max}` token. |
| Missing input file, or an output directory that does not exist → **exit 0, nothing written** | "exit 0 + no output" is a kept-original outcome, never a success. |
| Junk input → exit 13, stderr `Error: Cannot extract image from file.` | Non-zero exit → kept, the note carries the tool's own words. |
| 2880×1800 RGB PNG (1.5 MB) → 1600×1000 JPEG q80 in **90 ms** | The step runs synchronously inside `save` (the paste path is already async up to that point); a `TIMEOUT_MS` bounds the worst case. |
| Output carries no ICC and a minimal APP1; a PNG with alpha is flattened (`hasAlpha: no`) | Source metadata does not survive; alpha is lost — acceptable for screenshots (a window capture with shadow is colour type 6 and is the main case). Documented, not guarded. |
| A high-entropy 393 KB 800×500 PNG re-encoded at q80/800 px was 360 KB | The output must be **strictly smaller** than the source or the original is kept (silently). |
| Under the agent sandbox `sips` fails: `Cannot write to file /var/folders/…/T/<uuid>` (its own scratch dir is denied) | The live spec must run outside the sandbox; the fixture spec runs anywhere. In production a sips that cannot write its scratch is exactly the "tool misbehaved → keep original, notify" path. |

Refinements to the issue Spec, for the operator to confirm at `change-code`:

1. **JPEG sources shrink only when over the edge cap.** Re-encoding a ≤1600 px
   JPEG for size alone is generation loss for little gain. PNG sources follow
   the Spec rule (over 300 KB *or* over 1600 px). GIF/WebP: never.
2. **Not-smaller → keep.** Stated above.
3. **The 10 MB cap is checked on the source, before the shrink** (unchanged
   order). The paste reads only `MAX_BYTES + 1` bytes, so a larger clipboard
   image is truncated already and shrinking it would be wasted work on a
   broken file.

## ARCH-* lenses

- **ARCH-PURE** — policy, recipes, argv substitution, classification,
  dimension parsing and the session transition table are pure and tested with
  decision tables. IO is two thin functions: `run` (temp files + spawn) and
  `shrink` (the session-bound step wired into `assets.default_io`).
- **ARCH-DRY** — the clipboard and shrink recipes share one argv-token helper
  (`argv_recipe`: whole-argument substitution, token presence, config-wins
  selection). Both writers (`paste_image`, #239) get the step because it lives
  in `assets.save`, not in a caller. `assets.human_size` is the one byte
  formatter for the notice; `too_big`'s sentence is unchanged (tests pin it).
- **ARCH-PURPOSE** — the purpose is "images are small in git and on the wire
  for every writer"; the plan lands the shared step, the macOS recipe verified
  live, the fixture, and the docs. The other three recipes are data verified
  only by the opt-in live spec on hosts that have the tool (none here); a wrong
  one degrades to "kept + note", never to a broken asset.
- **ARCH-MOCK** — `tests/fixtures/fake_sips` is a stateful executable behind
  the `shrink_cmd` seam: states `ok` / `fail` / `empty` / `garbage` / `slow`
  (modelled on the measured sips behaviour above) plus a call log so specs
  assert argv tokens and call counts. Live conformance: `PARLEY_LIVE_SHRINK=1`
  runs every recipe whose tool is executable against a generated 1800×1200
  PNG and asserts dimensions through the tool's own probe and `looks_like`.
- **ARCH-CONSTRAINTS** — path: UI response (once per user-initiated paste, or
  per generated image part). Budget: ≤200 ms typical (90 ms measured, sips,
  2880×1800), bounded by `TIMEOUT_MS = 5000` → kept original with a note.
  Input ≤ `MAX_BYTES` (10 MB); transient disk = source + output temp files;
  memory = source bytes + output bytes. Concurrency: one shrink at a time
  (`paste_image` already refuses a second paste per buffer; #239's stream
  callbacks serialize on the main loop). CPU/network: N/A beyond the one
  subprocess.
- **ARCH-SECURE** — clipboard bytes are untrusted: `dimensions` reads header
  fields only, through the bounded walkers `looks_like` already trusts, and
  returns nil for anything malformed (→ no shrink). Argv arrays with
  whole-token substitution; the path never enters a shell string. The tool's
  output replaces the original **only** after `looks_like("image/jpeg")`
  passes; stderr is trimmed into a notification (no credential can appear —
  the tool sees only two temp paths). `config.assets.shrink_cmd` is
  operator-trusted, the same as `clipboard_cmd`. No credentials.
- **ARCH-ORDER** — the module holds state between events: which recipe was
  found (probed once) and whether the missing-tool warning was shown. Modelled
  as one tagged field, `session.resolved`:
  `nil` (unprobed) | `{ recipe = R }` | `{ missing = hint, warned = bool }`.
  Table (event → next, effect):

  | state | `configure(cfg)` | `shrink` with policy=no | `shrink` with policy=yes |
  |---|---|---|---|
  | `nil` | `nil` | `nil`, kept silently | probe → `{recipe}` then run; or `{missing, warned=true}` + note "no image shrink tool found: install …" |
  | `{recipe}` | `nil` | same, kept | run → ok / kept+note |
  | `{missing, warned=true}` | `nil` | same, kept | kept, silent |

  The event most likely to be mishandled: `setup()` called again mid-session
  with a different `shrink_cmd` — `configure` resets to `nil`, so the new
  command is probed and a fresh warning is allowed. Nothing runs concurrently
  with the step (synchronous `wait`); process death mid-run leaves two temp
  files under `tempname()`, which the OS temp sweep owns, and no asset.
- **ARCH-FUNERAL** — creates nothing durable of its own: the two temp files
  are removed on every path of `run` (pcall-guarded); the shrunk bytes replace
  the source in memory before `save` writes one file. The assets folder itself
  keeps its existing lifecycle (removed with the chat); this issue lowers its
  growth per paste from megabytes to hundreds of kilobytes and documents the
  commit-vs-ignore choice in the README.

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `substitute` | `lua/parley/argv_recipe.lua` | new |
| `has_token` | `lua/parley/argv_recipe.lua` | new |
| `select` | `lua/parley/argv_recipe.lua` | new |
| `dimensions` | `lua/parley/assets.lua` | new |
| `human_size` | `lua/parley/assets.lua` | new |
| `is_png` / `is_jpeg` walkers (`png_ihdr`, `jpeg_sof` return width, height) | `lua/parley/assets.lua` | modified |
| `RECIPES`, `IN`, `OUT`, `MAX`, `MAX_EDGE`, `MIN_BYTES`, `QUALITY`, `OUT_EXT`, `TIMEOUT_MS` | `lua/parley/image_shrink.lua` | new |
| `decide` | `lua/parley/image_shrink.lua` | new |
| `argv_for` | `lua/parley/image_shrink.lua` | new |
| `classify` | `lua/parley/image_shrink.lua` | new |
| `resolve` | `lua/parley/image_shrink.lua` | new |
| `outcome_suffix` | `lua/parley/image_shrink.lua` | new |
| `argv_for` (delegates to `argv_recipe.substitute`), `select` (delegates to `argv_recipe.select`) | `lua/parley/clipboard_image.lua` | modified |
| `png_bytes` | `tests/helpers/png_gen.lua` | new |

- **`argv_recipe`** — the recipe-as-data grammar both external-tool modules
  share: an argv whose whole-argument tokens stand for paths/values.
  - `substitute(argv, map)` → a new argv with every argument that IS a key of
    `map` replaced by its value (`{ ["{out}"] = path }`); embedded tokens are
    never touched. `has_token(argv, token)` → boolean (whole-argument).
    `select(config_cmd, candidates, executable, words)` → `recipe | nil, err`:
    a configured argv wins verbatim when it carries every token in
    `words.tokens` (else `err = words.config_key .. " must contain the " ..
    <missing token> .. " token (as its own argument) " .. words.purpose`);
    otherwise the first candidate whose `tool` is `executable` (else
    `err = words.none .. ": " .. hints joined by " or "`).
  - **Relationships:** 1 helper : 2 consumers (`clipboard_image`,
    `image_shrink`); #245's registry will supply the `install` hints later.
  - **DRY rationale:** `clipboard_image.select`/`argv_for`/`has_out_token`
    would otherwise be copied with one more token. The existing clipboard
    messages are preserved verbatim by passing them as `words` (its spec pins
    them).
  - **Future extensions:** #245 replaces `install` strings with registry
    entries; a `{quality}` token needs no change.

- **`dimensions(media_type, bytes)`** → `width, height` or `nil`. PNG: from
  IHDR; JPEG: from the first SOF. Only when the whole walk succeeds (the same
  rule as `looks_like`), so a truncated or corrupt file has no dimensions and
  is never shrunk. GIF/WebP → nil (their walkers stay boolean; the policy
  never shrinks them).
  - **Relationships:** 1:1 with the `VALIDATORS` entry per media type.
  - **DRY rationale:** the walkers already read width/height to validate them;
    returning them avoids a second header parser.
  - **Future extensions:** GIF/WebP dimensions are two more return statements
    if a future policy wants them.

- **`human_size(n)`** → `"512 B"`, `"180 KB"`, `"4.1 MB"` (KB/MB with one
  decimal under 10, none above; 1024-based). Used by the paste notice and
  `outcome_suffix`.

- **`image_shrink` constants** — `MAX_EDGE = 1600`, `MIN_BYTES = 300 * 1024`,
  `QUALITY = 80`, `OUT_EXT = "jpg"`, `TIMEOUT_MS = 5000`, tokens `IN = "{in}"`,
  `OUT = "{out}"`, `MAX = "{max}"`. `RECIPES` is an **ordered list** (first
  executable wins) of `{ tool, argv, install }`:
  1. `sips`: `{ "sips", "-s", "format", "jpeg", "-s", "formatOptions", "80", "--resampleHeightWidthMax", "{max}", "{in}", "--out", "{out}" }`, install `"sips ships with macOS"` — verified live above.
  2. `magick`: `{ "magick", "{in}", "-auto-orient", "-resize", "{max}x{max}>", "-quality", "80", "-strip", "{out}" }`, install `"install ImageMagick (brew install imagemagick)"`. ImageMagick infers JPEG from the `.jpg` output path. `{max}x{max}>` is not a whole token: `argv_for` substitutes whole tokens first, then replaces `{max}` **inside** arguments too, because `{max}` is a number the policy computed, not a path (the whole-argument rule exists for paths). `{in}`/`{out}` stay whole-argument only.
  3. `convert` (ImageMagick 6): same argv with `convert` as tool.
  4. `ffmpeg`: `{ "ffmpeg", "-y", "-loglevel", "error", "-i", "{in}", "-vf", "scale='min({max},iw)':'min({max},ih)':force_original_aspect_ratio=decrease", "-q:v", "4", "-f", "image2", "{out}" }`, install `"install ffmpeg (brew install ffmpeg)"`.
  5. `vipsthumbnail`: `{ "vipsthumbnail", "{in}", "--size", "{max}x{max}>", "-o", "{out}[Q=80,strip]" }` — embeds `{out}`; vips needs the option suffix on the filename. Whole-argument-only substitution cannot express it, so this recipe is `{ "sh", "-c", 'exec vipsthumbnail "$1" --size "$3x$3>" -o "$2[Q=80,strip]"', "sh", "{in}", "{out}", "{max}" }` — paths as `$1`/`$2`, the same pattern the Linux clipboard recipes use (ARCH-SECURE), install `"install libvips (brew install vips)"`.
  Recipes 2–5 are unverified on this host (tools absent); the live spec covers them where present and the outcome contract makes a wrong one harmless.

- **`decide(size, width, height, media_type)`** → `max_edge | nil`. Table:

  | media_type | size | long edge | → |
  |---|---|---|---|
  | png | > 300 KB | any | `min(1600, long)` |
  | png | ≤ 300 KB | > 1600 | 1600 |
  | png | ≤ 300 KB | ≤ 1600 | nil |
  | jpeg | any | > 1600 | 1600 |
  | jpeg | any | ≤ 1600 | nil |
  | gif / webp / other / nil dims | any | any | nil |

- **`argv_for(recipe, in_path, out_path, max_edge)`** → argv: whole-token
  substitution of `{in}`/`{out}`/`{max}` via `argv_recipe.substitute`, then
  `{max}` replaced inside any argument (`gsub` with a plain pattern).

- **`classify(code, stderr, out_bytes, in_size, tool)`** → `"ok" | "kept", note|nil`:

  | code | out_bytes | → |
  |---|---|---|
  | ≠ 0 | any | kept, `"<tool> exit <code>: <stderr trimmed>"` (124 → `"<tool> timed out after 5000 ms"` when stderr is empty) |
  | 0 | nil / "" | kept, `"<tool> wrote nothing"` |
  | 0 | not `looks_like("image/jpeg")` | kept, `"<tool> wrote something that is not a JPEG"` |
  | 0 | `#out_bytes >= in_size` | kept, nil (silent) |
  | 0 | smaller valid JPEG | ok |

- **`resolve(session, cfg, env)`** → `recipe|nil, note|nil` and the next
  `session.resolved` per the ARCH-ORDER table. `env = { executable }`.
  `cfg.shrink == false` short-circuits before `resolve` (in `shrink`).

- **`outcome_suffix(outcome)`** → `""` when no outcome; `" (4.1 MB → 180 KB)"`
  when shrunk; `" — original kept: <note>"` when a note exists. Shared by the
  paste notice and #239's answer note.

- **`png_bytes(width, height, rgb)`** (`tests/helpers/png_gen.lua`) — a PNG
  of any size in pure Lua: stored (uncompressed) deflate blocks, real CRC32
  and Adler-32, so `sips` and `looks_like` both accept it. Gives the unit
  tests a 1700×3 PNG, the integration spec a >1600 px paste, and the live
  spec a 1800×1200 image without a binary fixture in git.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `run` | `lua/parley/image_shrink.lua` | new | `vim.system(...):wait()`, temp files |
| `default_deps` | `lua/parley/image_shrink.lua` | new | `vim.system`, `vim.fn.tempname`, `assets.default_io.read/write`, `os.remove` |
| `configure` | `lua/parley/image_shrink.lua` | new | session state (config + probe cache) |
| `shrink` | `lua/parley/image_shrink.lua` | new | the step `assets.default_io.shrink` calls |
| `save` (4th return `outcome`; calls `io_.shrink` when present) | `lua/parley/assets.lua` | modified | disk |
| `default_io.shrink` | `lua/parley/assets.lua` | new | `image_shrink.shrink` |
| `paste` (notice carries `outcome_suffix`) | `lua/parley/paste_image.lua` | modified | `vim.notify` |
| `setup` (calls `image_shrink.configure(M.config.assets)`) | `lua/parley/init.lua` | modified | config |
| `fake_sips` | `tests/fixtures/fake_sips` | new | stands in for `sips` behind `shrink_cmd` |

- **`run(recipe, bytes, ext, max_edge, deps)`** → `code, stderr, out_bytes`.
  Writes `bytes` to `deps.tempname() .. "." .. ext`, computes the out path
  `deps.tempname() .. ".jpg"`, `deps.exec(argv, TIMEOUT_MS)`, reads the out
  file (bounded to `#bytes`, since a larger output is kept-original anyway),
  removes both files, every path under pcall so a throwing exec settles as
  `code = 1, stderr = "could not start <tool>: …"`.
  - **Injected into:** `shrink`. Unit tests inject `deps` with an in-memory
    exec that writes a chosen output (or nothing, or throws).
- **`shrink(bytes, ext)`** → `bytes, ext, outcome|nil`. `cfg.shrink == false`
  → originals, nil. `decide(...)` nil → originals, nil. `resolve` → no recipe
  → originals, `{ from = n, note = <first time only> }`. Else `run` +
  `classify` → `ok`: `out_bytes, "jpg", { from = n, to = m }`; `kept`:
  originals, `{ from = n, note }`.
  - **Injected into:** `assets.save` via `io_.shrink`; unit tests of `save`
    pass a fake `shrink` on `fake_io`.
- **`save`** — after the folder and `MAX_BYTES` checks, `if io_.shrink then
  bytes, ext, outcome = io_.shrink(bytes, ext) end`; the rest is unchanged;
  returns `rel, abs, nil, outcome`.
- **`fake_sips`** — Python, `sys.argv` = the sips argv shape (`… --resampleHeightWidthMax <max> <in> --out <out>`); reads `PARLEY_FAKE_SIPS`:
  `ok:<path>` copy that file to `<out>`, exit 0 · `fail` exit 13 + the measured
  stderr · `empty` exit 0, nothing written · `garbage` exit 0, writes `"not a
  jpeg"` · `slow` sleeps `PARLEY_FAKE_SIPS_DELAY_MS` (default 6000) then `ok:`.
  Appends `"<state>\t<max>\t<in>\t<out>"` to `PARLEY_FAKE_SIPS_LOG`. Configured
  through `assets.shrink_cmd = { fake_sips, "--resampleHeightWidthMax", "{max}", "{in}", "--out", "{out}" }`.

## Chunk 1: pure foundations (Tasks 1–3)

### Task 1: `argv_recipe` — the shared recipe grammar, clipboard delegates

**Files:**
- Create: `lua/parley/argv_recipe.lua`
- Modify: `lua/parley/clipboard_image.lua:95-141` (`has_out_token`, `select`, `argv_for`)
- Test: `tests/unit/argv_recipe_spec.lua`; existing `tests/unit/clipboard_image_spec.lua` stays green

- [ ] **Step 1: Write the failing spec**

```lua
-- tests/unit/argv_recipe_spec.lua
-- Decision tables for the recipe grammar both external-tool modules share.
local ar = require("parley.argv_recipe")

describe("argv_recipe: substitute / has_token", function()
    it("replaces whole-argument tokens only and never mutates the input", function()
        local argv = { "tool", "{in}", "x{in}y", "{out}", "{max}x{max}>" }
        local out = ar.substitute(argv, { ["{in}"] = "/a", ["{out}"] = "/b" })
        assert.same({ "tool", "/a", "x{in}y", "/b", "{max}x{max}>" }, out)
        assert.same({ "tool", "{in}", "x{in}y", "{out}", "{max}x{max}>" }, argv)
    end)
    it("has_token is whole-argument", function()
        assert.is_true(ar.has_token({ "a", "{out}" }, "{out}"))
        assert.is_false(ar.has_token({ "a", "x{out}" }, "{out}"))
        assert.is_false(ar.has_token({}, "{out}"))
    end)
end)

describe("argv_recipe: select", function()
    local words = { config_key = "assets.clipboard_cmd", tokens = { "{out}" },
        purpose = "for the PNG path to write", none = "no clipboard image tool found" }
    local candidates = {
        { tool = "one", argv = { "one", "{out}" }, install = "install one" },
        { tool = "two", argv = { "two", "{out}" }, install = "install two" },
    }
    local function exe(set) return function(t) return set[t] == true end end

    it("a configured argv wins verbatim when it carries every token", function()
        local r = ar.select({ "mine", "{out}" }, candidates, exe({}), words)
        assert.same({ tool = "mine", argv = { "mine", "{out}" }, install = nil }, r)
    end)
    it("a configured argv missing a token names the token, key and purpose", function()
        local r, err = ar.select({ "mine" }, candidates, exe({ one = true }), words)
        assert.is_nil(r)
        assert.equals("assets.clipboard_cmd must contain the {out} token (as its own argument) for the PNG path to write", err)
    end)
    it("an empty or non-table config falls through to the candidates", function()
        assert.equals(candidates[2], ar.select({}, candidates, exe({ two = true }), words))
        assert.equals(candidates[1], ar.select(nil, candidates, exe({ one = true, two = true }), words))
    end)
    it("no executable candidate → hints in order", function()
        local r, err = ar.select(nil, candidates, exe({}), words)
        assert.is_nil(r)
        assert.equals("no clipboard image tool found: install one or install two", err)
    end)
    it("several required tokens: the first missing one is named", function()
        local w = vim.tbl_extend("force", words, { tokens = { "{in}", "{out}" }, config_key = "assets.shrink_cmd", purpose = "for the image paths" })
        local _, err = ar.select({ "t", "{out}" }, candidates, exe({}), w)
        assert.equals("assets.shrink_cmd must contain the {in} token (as its own argument) for the image paths", err)
    end)
end)
```

- [ ] **Step 2: Run it to see it fail**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/argv_recipe_spec.lua" -c "qa!"`
Expected: FAIL — `module 'parley.argv_recipe' not found`

- [ ] **Step 3: Write the module**

```lua
-- lua/parley/argv_recipe.lua
--
-- The recipe-as-data grammar shared by every module that runs an external
-- tool (#231 clipboard_image, #244 image_shrink): a recipe is
-- `{ tool, argv, install }` where argv carries TOKENS as WHOLE arguments
-- standing for paths or values the caller fills in. A path never enters a
-- shell string: it is substituted as its own argv element, or handed to
-- `sh -c` as `$1` (ARCH-SECURE). PURE.

local M = {}

--- argv with every argument that IS a key of `map` replaced by map[arg].
--- An embedded token inside a longer argument is left alone (paths are only
--- ever whole arguments). The input is not mutated.
--- @param argv string[]
--- @param map table<string,string>
--- @return string[]
function M.substitute(argv, map)
    local out = {}
    for i, a in ipairs(argv) do
        local v = map[a]
        out[i] = v ~= nil and v or a
    end
    return out
end

--- True when some element of argv IS the token.
--- @param argv string[]
--- @param token string
--- @return boolean
function M.has_token(argv, token)
    for _, a in ipairs(argv) do
        if a == token then
            return true
        end
    end
    return false
end

--- Pick a recipe. A configured argv list wins verbatim when it carries every
--- required token; otherwise the first candidate whose tool is executable.
--- `words` carries the caller's vocabulary so its messages stay its own:
---   { config_key, tokens = { "{out}", … }, purpose, none }
--- @param config_cmd string[]|nil
--- @param candidates table[]  ordered { tool, argv, install }
--- @param executable fun(tool: string): boolean
--- @param words table
--- @return table|nil recipe, string|nil err
function M.select(config_cmd, candidates, executable, words)
    if type(config_cmd) == "table" and #config_cmd > 0 then
        for _, token in ipairs(words.tokens) do
            if not M.has_token(config_cmd, token) then
                return nil, words.config_key .. " must contain the " .. token
                    .. " token (as its own argument) " .. words.purpose
            end
        end
        return { tool = config_cmd[1], argv = config_cmd, install = nil }
    end
    local hints = {}
    for _, recipe in ipairs(candidates) do
        if executable(recipe.tool) then
            return recipe
        end
        hints[#hints + 1] = recipe.install
    end
    return nil, words.none .. ": " .. table.concat(hints, " or ")
end

return M
```

- [ ] **Step 4: Make `clipboard_image` delegate (behaviour unchanged)**

Replace `has_out_token`, the body of `select`, and `argv_for` in
`lua/parley/clipboard_image.lua`:

```lua
local argv_recipe = require("parley.argv_recipe")
-- (delete local function has_out_token)

local SELECT_WORDS = {
    config_key = "assets.clipboard_cmd",
    tokens = { M.OUT },
    purpose = "for the PNG path to write",
    none = "no clipboard image tool found",
}

function M.select(config_cmd, env)
    local ordered = {}
    for _, key in ipairs(platform_order(env)) do
        ordered[#ordered + 1] = M.RECIPES[key]
    end
    return argv_recipe.select(config_cmd, ordered, env.executable, SELECT_WORDS)
end

function M.argv_for(recipe, out_path)
    return argv_recipe.substitute(recipe.argv, { [M.OUT] = out_path })
end
```

Update the module header's sentence about "the same seam and contract" to
name `argv_recipe` as the shared grammar.

- [ ] **Step 5: Run both specs**

Run: `for s in argv_recipe clipboard_image; do nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/${s}_spec.lua" -c "qa!"; done`
Expected: both PASS with no failures (the clipboard messages are byte-identical).

- [ ] **Step 6: Commit**

```bash
git add lua/parley/argv_recipe.lua lua/parley/clipboard_image.lua tests/unit/argv_recipe_spec.lua
git commit -m "#244: argv_recipe: one recipe grammar for clipboard and shrink tools"
```

### Task 2: `assets.dimensions`, `assets.human_size`, and the PNG generator

**Files:**
- Modify: `lua/parley/assets.lua:229-243` (`png_ihdr`), `:244-283` (`is_png`), `:307-318` (`jpeg_sof`), `:320-372` (`is_jpeg`), after `looks_like` (new `dimensions`), after `too_big` (new `human_size`)
- Create: `tests/helpers/png_gen.lua`
- Test: `tests/unit/assets_spec.lua` (new describe blocks)

- [ ] **Step 1: Write the PNG generator (test helper, pure)**

```lua
-- tests/helpers/png_gen.lua
--
-- A structurally valid PNG of any size without zlib: stored (uncompressed)
-- deflate blocks with a real Adler-32 and per-chunk CRC-32, so both
-- `assets.looks_like` and the real `sips` accept it. Truecolour, 8-bit,
-- every pixel `rgb` (default a flat grey). PURE.
local M = {}

local CRC = {}
for i = 0, 255 do
    local c = i
    for _ = 1, 8 do
        c = (c % 2 == 1) and bit.bxor(bit.rshift(c, 1), 0xEDB88320) or bit.rshift(c, 1)
    end
    CRC[i] = c
end
local function crc32(s)
    local c = 0xFFFFFFFF
    for i = 1, #s do
        c = bit.bxor(CRC[bit.band(bit.bxor(c, s:byte(i)), 0xFF)], bit.rshift(c, 8))
    end
    return bit.band(bit.bnot(c), 0xFFFFFFFF)
end
local function adler32(s)
    local a, b = 1, 0
    for i = 1, #s do
        a = (a + s:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end
local function u32be(n)
    return string.char(bit.band(bit.rshift(n, 24), 0xFF), bit.band(bit.rshift(n, 16), 0xFF), bit.band(bit.rshift(n, 8), 0xFF), bit.band(n, 0xFF))
end
local function chunk(kind, data)
    return u32be(#data) .. kind .. data .. u32be(crc32(kind .. data))
end
-- zlib stream of stored blocks (BFINAL on the last, ≤ 65535 bytes each).
local function stored_zlib(raw)
    local parts = { "\120\1" }
    local pos, n = 1, #raw
    repeat
        local len = math.min(65535, n - pos + 1)
        local final = (pos + len > n) and 1 or 0
        parts[#parts + 1] = string.char(final, len % 256, math.floor(len / 256), 255 - len % 256, 255 - math.floor(len / 256))
        parts[#parts + 1] = raw:sub(pos, pos + len - 1)
        pos = pos + len
    until pos > n
    parts[#parts + 1] = u32be(adler32(raw))
    return table.concat(parts)
end

--- @param width integer
--- @param height integer
--- @param rgb string|nil  three bytes; default "\128\128\128"
--- @return string png
function M.png_bytes(width, height, rgb)
    local row = "\0" .. string.rep(rgb or "\128\128\128", width)
    local raw = string.rep(row, height)
    local ihdr = u32be(width) .. u32be(height) .. string.char(8, 2, 0, 0, 0)
    return "\137PNG\r\n\26\n" .. chunk("IHDR", ihdr) .. chunk("IDAT", stored_zlib(raw)) .. chunk("IEND", "")
end

return M
```

(`bit` is LuaJIT's, available in Neovim.)

- [ ] **Step 2: Write the failing specs** (append to `tests/unit/assets_spec.lua`)

```lua
describe("assets: dimensions (#244 — pure, from the headers looks_like already walks)", function()
    local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
    local function fixture(name)
        local f = assert(io.open(repo .. "/tests/fixtures/" .. name, "rb"))
        local b = f:read("*a")
        f:close()
        return b
    end
    local png_gen = require("tests.helpers.png_gen")

    it("reads PNG and JPEG dimensions", function()
        assert.same({ 1, 1 }, { assets.dimensions("image/png", fixture("one_pixel.png")) })
        assert.same({ 1, 1 }, { assets.dimensions("image/jpeg", fixture("one_pixel.jpg")) })
        assert.same({ 1700, 3 }, { assets.dimensions("image/png", png_gen.png_bytes(1700, 3)) })
    end)
    it("generated PNGs are structurally valid (the generator is trusted by the other specs)", function()
        assert.is_true(assets.looks_like("image/png", png_gen.png_bytes(2, 2)))
        assert.is_true(assets.looks_like("image/png", png_gen.png_bytes(300, 300)))
    end)
    it("is nil for GIF/WebP, for a mismatched type, and for anything malformed", function()
        assert.is_nil(assets.dimensions("image/gif", fixture("one_pixel.gif")))
        assert.is_nil(assets.dimensions("image/webp", fixture("one_pixel.webp")))
        assert.is_nil(assets.dimensions("image/png", fixture("one_pixel.jpg")))
        local png = fixture("one_pixel.png")
        assert.is_nil(assets.dimensions("image/png", png:sub(1, 24)), "IHDR only")
        assert.is_nil(assets.dimensions("image/png", png:sub(1, #png - 1)), "truncated trailer")
        assert.is_nil(assets.dimensions("image/jpeg", fixture("one_pixel.jpg"):sub(1, 40)))
        assert.is_nil(assets.dimensions(nil, png))
        assert.is_nil(assets.dimensions("image/png", nil))
    end)
end)

describe("assets: human_size", function()
    it("formats bytes, KB and MB", function()
        assert.equals("0 B", assets.human_size(0))
        assert.equals("512 B", assets.human_size(512))
        assert.equals("1.0 KB", assets.human_size(1024))
        assert.equals("180 KB", assets.human_size(180 * 1024 + 300))
        assert.equals("4.1 MB", assets.human_size(4.1 * 1024 * 1024))
        assert.equals("12 MB", assets.human_size(12 * 1024 * 1024))
    end)
end)
```

The spec file requires `tests.helpers.png_gen`; check how other specs load
helpers (`grep -rn "tests.helpers" tests/unit | head -3`) and use the same
form.

- [ ] **Step 3: Run to see them fail**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/assets_spec.lua" -c "qa!" 2>&1 | tail -20`
Expected: the new blocks FAIL (`dimensions` / `human_size` are nil); everything else PASS.

- [ ] **Step 4: Implement**

In `assets.lua`:

```lua
-- png_ihdr: return ok, colour, width, height
local function png_ihdr(bytes, pos)
    local width, height = u32be(bytes, pos), u32be(bytes, pos + 4)
    -- (unchanged validation)
    return ok, colour, width, height
end

-- is_png: capture and return them. Returns ok, width, height.
local pos, first, colour, plte, idat_bytes, width, height = 9, true, nil, false, 0, nil, nil
-- in the IHDR branch:
ok, colour, width, height = png_ihdr(bytes, pos + 8)
-- in the IEND branch:
if len == 0 and nxt == n + 1 and idat_bytes >= 1 and (colour ~= 3 or plte) then
    return true, width, height
end
return false

-- jpeg_sof: return nf, width, height
local h, w = u16be(bytes, pos + 5), u16be(bytes, pos + 7)
if h < 1 or w < 1 then return nil end
return nf, w, h

-- is_jpeg: track width/height from the SOF; the SOS branch returns
-- `ok, width, height` when ok, else false.
```

Then:

```lua
--- Width and height of a PNG or JPEG, read from the header the format's
--- walker validates; nil unless the WHOLE walk succeeds (the looks_like
--- rule), so a truncated or corrupt file has no dimensions. GIF and WebP
--- are not measured — the shrink policy never touches them. PURE.
---@param media_type string|nil
---@param bytes string|nil
---@return integer|nil width
---@return integer|nil height
function M.dimensions(media_type, bytes)
    local valid = media_type and VALIDATORS[media_type]
    if not valid or type(bytes) ~= "string" then
        return nil
    end
    local ok, w, h = valid(bytes)
    if ok == true and w and h then
        return w, h
    end
    return nil
end

--- "512 B", "180 KB", "4.1 MB": one decimal under 10 units, none above.
---@param n number
---@return string
function M.human_size(n)
    local function unit(v, u)
        if v < 10 then
            return ("%.1f %s"):format(v, u)
        end
        return ("%d %s"):format(math.floor(v + 0.5), u)
    end
    if n >= 1024 * 1024 then
        return unit(n / (1024 * 1024), "MB")
    elseif n >= 1024 then
        return unit(n / 1024, "KB")
    end
    return ("%d B"):format(n)
end
```

`looks_like` keeps `valid(bytes) == true` — the extra returns are ignored.

- [ ] **Step 5: Run the spec — all green**

Run: same command. Expected: PASS, including every pre-existing `looks_like` block.

- [ ] **Step 6: Commit**

```bash
git add lua/parley/assets.lua tests/unit/assets_spec.lua tests/helpers/png_gen.lua
git commit -m "#244: assets: dimensions from the validated headers, human_size, PNG generator"
```

### Task 3: `image_shrink` pure half — recipes, policy, argv, classify, session table

**Files:**
- Create: `lua/parley/image_shrink.lua` (pure half; Task 4 adds the IO half)
- Test: `tests/unit/image_shrink_spec.lua`

- [ ] **Step 1: Write the failing spec**

```lua
-- tests/unit/image_shrink_spec.lua
-- Decision tables for the pure half of parley.image_shrink: policy (decide),
-- recipes as data, argv_for, classify, the session transition table
-- (resolve), and outcome_suffix. Task 4 appends the run/shrink seam cases.
local shrink = require("parley.image_shrink")
local assets = require("parley.assets")
local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
local function fixture(name)
    local f = assert(io.open(repo .. "/tests/fixtures/" .. name, "rb"))
    local b = f:read("*a")
    f:close()
    return b
end
local JPG = fixture("one_pixel.jpg")

describe("image_shrink: constants and recipes", function()
    it("exposes the policy constants", function()
        assert.equals(1600, shrink.MAX_EDGE)
        assert.equals(300 * 1024, shrink.MIN_BYTES)
        assert.equals("jpg", shrink.OUT_EXT)
        assert.equals(5000, shrink.TIMEOUT_MS)
        assert.same({ "{in}", "{out}", "{max}" }, { shrink.IN, shrink.OUT, shrink.MAX })
    end)
    it("recipes are an ordered list, sips first; each carries {in} and {out} whole and a {max}", function()
        assert.equals("sips", shrink.RECIPES[1].tool)
        for _, r in ipairs(shrink.RECIPES) do
            assert.is_string(r.tool, "tool")
            assert.is_string(r.install, r.tool .. ".install")
            local whole = 0
            local max_seen = false
            for _, a in ipairs(r.argv) do
                if a == shrink.IN or a == shrink.OUT then
                    whole = whole + 1
                elseif a:find("{in}", 1, true) or a:find("{out}", 1, true) then
                    error(r.tool .. ": a path token is embedded in " .. a)
                end
                if a:find("{max}", 1, true) then max_seen = true end
            end
            assert.equals(2, whole, r.tool .. ": exactly one {in} and one {out}")
            assert.is_true(max_seen, r.tool .. ": carries {max}")
        end
    end)
    it("the sips recipe is the measured one", function()
        assert.same({ "sips", "-s", "format", "jpeg", "-s", "formatOptions", "80",
            "--resampleHeightWidthMax", "{max}", "{in}", "--out", "{out}" }, shrink.RECIPES[1].argv)
    end)
end)

describe("image_shrink: decide", function()
    local KB = 1024
    local cases = {
        { "png over size, small edge → its own edge",   400 * KB, 800, 500, "image/png", 800 },
        { "png over size, big edge → cap",              400 * KB, 2880, 1800, "image/png", 1600 },
        { "png under size, over edge → cap",            90 * KB, 1700, 100, "image/png", 1600 },
        { "png under size, under edge → nil",           120 * KB, 1600, 900, "image/png", nil },
        { "png exactly at size → nil",                  300 * KB, 100, 100, "image/png", nil },
        { "jpeg over size, under edge → nil",           900 * KB, 1600, 1200, "image/jpeg", nil },
        { "jpeg over edge → cap",                       50 * KB, 4000, 3000, "image/jpeg", 1600 },
        { "gif never",                                  5000 * KB, 4000, 3000, "image/gif", nil },
        { "webp never",                                 5000 * KB, 4000, 3000, "image/webp", nil },
        { "unknown type never",                         5000 * KB, 4000, 3000, nil, nil },
        { "png with no dimensions → nil (unparseable)", 5000 * KB, nil, nil, "image/png", nil },
        { "portrait uses the long edge",                400 * KB, 500, 900, "image/png", 900 },
    }
    for _, c in ipairs(cases) do
        it(c[1], function()
            assert.equals(c[6], shrink.decide(c[2], c[3], c[4], c[5]))
        end)
    end
end)

describe("image_shrink: argv_for", function()
    it("substitutes whole tokens, and {max} inside arguments too", function()
        local r = { tool = "t", argv = { "t", "{in}", "-resize", "{max}x{max}>", "--max", "{max}", "{out}" } }
        assert.same({ "t", "/i.png", "-resize", "1600x1600>", "--max", "1600", "/o.jpg" },
            shrink.argv_for(r, "/i.png", "/o.jpg", 1600))
        assert.equals("{in}", r.argv[2], "not mutated")
    end)
    it("never expands a path token inside an argument", function()
        local r = { tool = "t", argv = { "t", "x{in}", "{out}" } }
        assert.same({ "t", "x{in}", "/o" }, shrink.argv_for(r, "/i", "/o", 800))
    end)
end)

describe("image_shrink: classify", function()
    local IN = 1000
    it("non-zero exit → kept with the tool's words", function()
        assert.same({ "kept", "sips exit 13: Error: Cannot extract image from file." },
            { shrink.classify(13, "Error: Cannot extract image from file.\n", nil, IN, "sips") })
    end)
    it("timeout with empty stderr → kept, names the budget", function()
        assert.same({ "kept", "sips timed out after 5000 ms" }, { shrink.classify(124, "", nil, IN, "sips") })
    end)
    it("exit 0 and nothing written → kept", function()
        assert.same({ "kept", "sips wrote nothing" }, { shrink.classify(0, "", nil, IN, "sips") })
        assert.same({ "kept", "sips wrote nothing" }, { shrink.classify(0, "", "", IN, "sips") })
    end)
    it("exit 0 and not a JPEG → kept", function()
        assert.same({ "kept", "sips wrote something that is not a JPEG" }, { shrink.classify(0, "", "not a jpeg", IN, "sips") })
    end)
    it("exit 0, valid JPEG, not smaller → kept silently", function()
        local status, note = shrink.classify(0, "", JPG, #JPG, "sips")
        assert.equals("kept", status)
        assert.is_nil(note)
    end)
    it("exit 0, valid smaller JPEG → ok", function()
        assert.same({ "ok" }, { shrink.classify(0, "", JPG, #JPG + 1, "sips") })
    end)
end)

describe("image_shrink: resolve (the session table)", function()
    local function env(tools) return { executable = function(t) return tools[t] == true end } end
    it("unprobed + tool present → {recipe}, no note; a second call does not probe again", function()
        local s = {}
        local probes = 0
        local e = { executable = function(t) probes = probes + 1; return t == "sips" end }
        local r, note = shrink.resolve(s, {}, e)
        assert.equals(shrink.RECIPES[1], r)
        assert.is_nil(note)
        assert.equals(shrink.RECIPES[1], s.resolved.recipe)
        local before = probes
        shrink.resolve(s, {}, e)
        assert.equals(before, probes, "probed once per session")
    end)
    it("unprobed + no tool → {missing, warned}, note names what to install; then silent", function()
        local s = {}
        local r, note = shrink.resolve(s, {}, env({}))
        assert.is_nil(r)
        assert.matches("^no image shrink tool found: ", note)
        assert.matches("sips ships with macOS", note)
        assert.matches("imagemagick", note)
        assert.is_true(s.resolved.warned)
        local r2, note2 = shrink.resolve(s, {}, env({}))
        assert.is_nil(r2)
        assert.is_nil(note2)
    end)
    it("a configured shrink_cmd wins and is not probed", function()
        local s = {}
        local r = shrink.resolve(s, { shrink_cmd = { "/x/fake", "{max}", "{in}", "{out}" } }, env({}))
        assert.same({ "/x/fake", "{max}", "{in}", "{out}" }, r.argv)
    end)
    it("a configured shrink_cmd missing a token is a note, once", function()
        local s = {}
        local r, note = shrink.resolve(s, { shrink_cmd = { "/x/fake", "{in}" } }, env({}))
        assert.is_nil(r)
        assert.equals("assets.shrink_cmd must contain the {out} token (as its own argument) for the image paths and the {max} edge", note)
        local _, again = shrink.resolve(s, { shrink_cmd = { "/x/fake", "{in}" } }, env({}))
        assert.is_nil(again)
    end)
end)

describe("image_shrink: outcome_suffix", function()
    it("renders shrunk, kept-with-note, and nothing", function()
        assert.equals("", shrink.outcome_suffix(nil))
        assert.equals(" (4.1 MB → 180 KB)", shrink.outcome_suffix({ from = 4.1 * 1024 * 1024, to = 180 * 1024 }))
        assert.equals(" — original kept: sips exit 13: boom", shrink.outcome_suffix({ from = 10, note = "sips exit 13: boom" }))
    end)
end)
```

- [ ] **Step 2: Run to see it fail**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/image_shrink_spec.lua" -c "qa!"`
Expected: FAIL — module not found.

- [ ] **Step 3: Write the pure half**

```lua
-- lua/parley/image_shrink.lua
--
-- Shrink an image before it is stored (#244). A macOS screenshot is a 2–6 MB
-- Retina PNG; every provider downscales above ~1600 px anyway, so the bytes
-- cost git space and tokens for nothing. Neovim has no image codec, so this
-- is a per-platform RECIPE like the clipboard read (#231): argv as data with
-- `{in}` / `{out}` (whole arguments — paths never enter a shell string) and
-- `{max}` (a number the policy computed; it may sit inside an argument such
-- as ImageMagick's "1600x1600>"). Shared grammar: parley.argv_recipe.
--
-- POLICY (decide) is tool-independent and pure: shrink only when it pays —
-- a PNG over MIN_BYTES or over MAX_EDGE on its long edge, a JPEG over
-- MAX_EDGE (re-encoding a small JPEG is generation loss for little gain);
-- never a GIF or WebP (animation, alpha); never without dimensions (a file
-- looks_like rejects is stored as it came and refused later at read). The
-- target edge is min(MAX_EDGE, the source's long edge) because sips UPSCALES
-- to --resampleHeightWidthMax (measured 2026-09-13: 800×500 → 1600×1000).
--
-- OUTCOME (classify): the shrunk file replaces the original ONLY when the
-- tool exited 0, wrote a structurally valid JPEG (assets.looks_like), and
-- that JPEG is strictly smaller than the source. Anything else keeps the
-- original: a non-zero exit or a timeout carries the tool's words in a note;
-- exit 0 with nothing written (sips does this for a missing input or output
-- directory) and non-JPEG output are notes too; not-smaller is silent.
--
-- SESSION (resolve): the recipe is probed once per session and the missing-
-- tool warning is shown once. One tagged field, `session.resolved`:
--   nil                          unprobed
--   { recipe = R }               found (configured shrink_cmd, or first executable)
--   { missing = why, warned = true }  none; the note was returned exactly once
-- `configure` (called by parley.setup) resets it, so a new shrink_cmd is
-- probed and may warn again (ARCH-ORDER).
--
-- The spawn is the one seam (`run`, Task 4): synchronous vim.system():wait()
-- bounded by TIMEOUT_MS — 90 ms measured for a 2880×1800 PNG — with both
-- temp files removed on every path (ARCH-FUNERAL). tests/fixtures/fake_sips
-- stands in for sips through `config.assets.shrink_cmd`, the boundary
-- production uses (ARCH-MOCK). PURE above `run`.

local argv_recipe = require("parley.argv_recipe")
local assets = require("parley.assets")

local M = {}

M.IN, M.OUT, M.MAX = "{in}", "{out}", "{max}"
M.MAX_EDGE = 1600
M.MIN_BYTES = 300 * 1024
M.QUALITY = 80
M.OUT_EXT = "jpg"
M.TIMEOUT_MS = 5000

--- Ordered: the first executable wins. Only sips is verified on a real host
--- (macOS 26.6, sips-316); the others follow their documentation and are
--- checked by the opt-in live spec where the tool exists.
M.RECIPES = {
    {
        tool = "sips",
        argv = { "sips", "-s", "format", "jpeg", "-s", "formatOptions", tostring(M.QUALITY),
            "--resampleHeightWidthMax", "{max}", "{in}", "--out", "{out}" },
        install = "sips ships with macOS",
    },
    {
        tool = "magick",
        argv = { "magick", "{in}", "-auto-orient", "-resize", "{max}x{max}>", "-quality", tostring(M.QUALITY), "-strip", "{out}" },
        install = "install ImageMagick (brew install imagemagick)",
    },
    {
        tool = "convert",
        argv = { "convert", "{in}", "-auto-orient", "-resize", "{max}x{max}>", "-quality", tostring(M.QUALITY), "-strip", "{out}" },
        install = "install ImageMagick 6 (convert)",
    },
    {
        tool = "ffmpeg",
        argv = { "ffmpeg", "-y", "-loglevel", "error", "-i", "{in}", "-vf",
            "scale='min({max},iw)':'min({max},ih)':force_original_aspect_ratio=decrease",
            "-q:v", "4", "-f", "image2", "{out}" },
        install = "install ffmpeg (brew install ffmpeg)",
    },
    {
        -- vips wants its options as a filename suffix, so the paths go to sh
        -- as $1/$2 and the edge as $3 — never inside the -c string.
        tool = "vipsthumbnail",
        argv = { "sh", "-c", 'exec vipsthumbnail "$1" --size "$3x$3>" -o "$2[Q=' .. M.QUALITY .. ',strip]"', "sh", "{in}", "{out}", "{max}" },
        install = "install libvips (brew install vips)",
    },
}

local SELECT_WORDS = {
    config_key = "assets.shrink_cmd",
    tokens = { M.IN, M.OUT, M.MAX },
    purpose = "for the image paths and the {max} edge",
    none = "no image shrink tool found",
}

--- The policy. Returns the target long edge, or nil to keep the bytes.
--- @param size integer
--- @param width integer|nil
--- @param height integer|nil
--- @param media_type string|nil
--- @return integer|nil max_edge
function M.decide(size, width, height, media_type)
    if not width or not height then
        return nil
    end
    local long = math.max(width, height)
    if media_type == "image/png" then
        if size > M.MIN_BYTES or long > M.MAX_EDGE then
            return math.min(M.MAX_EDGE, long)
        end
    elseif media_type == "image/jpeg" then
        if long > M.MAX_EDGE then
            return M.MAX_EDGE
        end
    end
    return nil
end

--- argv for one run: whole-token paths, then {max} anywhere.
function M.argv_for(recipe, in_path, out_path, max_edge)
    local edge = tostring(max_edge)
    local argv = argv_recipe.substitute(recipe.argv, { [M.IN] = in_path, [M.OUT] = out_path, [M.MAX] = edge })
    for i, a in ipairs(argv) do
        if a:find(M.MAX, 1, true) and a ~= in_path and a ~= out_path then
            argv[i] = a:gsub("{max}", edge)
        end
    end
    return argv
end

--- The outcome rule (module header).
--- @return "ok"|"kept" status, string|nil note
function M.classify(code, stderr, out_bytes, in_size, tool)
    local words = (stderr or ""):gsub("%s+$", "")
    if code ~= 0 then
        if code == 124 and words == "" then
            return "kept", tool .. " timed out after " .. tostring(M.TIMEOUT_MS) .. " ms"
        end
        return "kept", tool .. " exit " .. tostring(code) .. ": " .. words
    end
    if not out_bytes or out_bytes == "" then
        return "kept", tool .. " wrote nothing"
    end
    if not assets.looks_like("image/jpeg", out_bytes) then
        return "kept", tool .. " wrote something that is not a JPEG"
    end
    if #out_bytes >= in_size then
        return "kept", nil
    end
    return "ok"
end

--- The session transition (module header). Mutates `session.resolved`.
--- @param session table
--- @param cfg table  config.assets
--- @param env table  { executable }
--- @return table|nil recipe, string|nil note
function M.resolve(session, cfg, env)
    local r = session.resolved
    if r == nil then
        local recipe, err = argv_recipe.select(cfg.shrink_cmd, M.RECIPES, env.executable, SELECT_WORDS)
        if recipe then
            session.resolved = { recipe = recipe }
            return recipe
        end
        session.resolved = { missing = err, warned = true }
        return nil, err
    end
    return r.recipe
end

--- The notice suffix both writers append: sizes when shrunk, the note when kept.
--- @param outcome table|nil  { from, to?, note? }
function M.outcome_suffix(outcome)
    if not outcome then
        return ""
    end
    if outcome.note then
        return " — original kept: " .. outcome.note
    end
    if outcome.to then
        return " (" .. assets.human_size(outcome.from) .. " → " .. assets.human_size(outcome.to) .. ")"
    end
    return ""
end

return M
```

- [ ] **Step 4: Run the spec — green**

Run: same command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/image_shrink.lua tests/unit/image_shrink_spec.lua
git commit -m "#244: image_shrink: recipes as data, pure policy, outcome rule, session table"
```

## Chunk 2: the seam, the writer, the paste (Tasks 4–6)

### Task 4: `image_shrink` IO half — `run`, `default_deps`, `configure`, `shrink`

**Files:**
- Modify: `lua/parley/image_shrink.lua` (append)
- Test: `tests/unit/image_shrink_spec.lua` (append)

- [ ] **Step 1: Append the failing seam specs**

```lua
describe("image_shrink: run (the seam, with fake deps)", function()
    local png_gen = require("tests.helpers.png_gen")
    local SRC = png_gen.png_bytes(1700, 3)

    -- In-memory deps: exec is a function(argv) the case chooses; files are a table.
    local function deps_with(exec)
        local files, removed, names = {}, {}, 0
        local d = {
            files = files, removed = removed,
            tempname = function() names = names + 1; return "/tmp/t" .. names end,
            write = function(p, b) files[p] = b; return true end,
            read = function(p) return files[p] end,
            remove = function(p) removed[#removed + 1] = p; files[p] = nil end,
            exec = function(argv, timeout_ms) return exec(argv, timeout_ms, files) end,
        }
        return d
    end

    it("writes the source, runs the argv with the edge, reads the output, removes both", function()
        local seen
        local d = deps_with(function(argv, timeout_ms, files)
            seen = { argv = argv, timeout_ms = timeout_ms, in_bytes = files[argv[10]] }
            files[argv[12]] = JPG
            return 0, ""
        end)
        local code, stderr, out = shrink.run(shrink.RECIPES[1], SRC, "png", 1600, d)
        assert.equals(0, code)
        assert.equals("", stderr)
        assert.equals(JPG, out)
        assert.equals("1600", seen.argv[9])
        assert.equals("/tmp/t1.png", seen.argv[10])
        assert.equals("/tmp/t2.jpg", seen.argv[12])
        assert.equals(SRC, seen.in_bytes, "the tool saw the source bytes")
        assert.equals(shrink.TIMEOUT_MS, seen.timeout_ms)
        assert.same({ "/tmp/t1.png", "/tmp/t2.jpg" }, d.removed)
        assert.same({}, d.files, "nothing left behind")
    end)
    it("a tool that writes nothing → nil output; both paths still removed", function()
        local d = deps_with(function() return 0, "" end)
        local code, _, out = shrink.run(shrink.RECIPES[1], SRC, "png", 1600, d)
        assert.equals(0, code)
        assert.is_nil(out)
        assert.same({ "/tmp/t1.png", "/tmp/t2.jpg" }, d.removed)
    end)
    it("an exec that throws settles as code 1 with 'could not start'", function()
        local d = deps_with(function() error("ENOENT: no such file") end)
        local code, stderr = shrink.run(shrink.RECIPES[1], SRC, "png", 1600, d)
        assert.equals(1, code)
        assert.matches("^could not start sips: .*ENOENT", stderr)
        assert.same({ "/tmp/t1.png", "/tmp/t2.jpg" }, d.removed)
    end)
    it("a failed source write is a code 1 with the reason; nothing is run", function()
        local ran = false
        local d = deps_with(function() ran = true; return 0, "" end)
        d.write = function() return false, "ENOSPC" end
        local code, stderr = shrink.run(shrink.RECIPES[1], SRC, "png", 1600, d)
        assert.equals(1, code)
        assert.matches("ENOSPC", stderr)
        assert.is_false(ran)
    end)
    it("default_deps.exec runs a real argv through vim.system with the timeout (sh)", function()
        local code, stderr = shrink.default_deps.exec({ "sh", "-c", "echo oops >&2; exit 3" }, 2000)
        assert.equals(3, code)
        assert.matches("oops", stderr)
        local tcode = shrink.default_deps.exec({ "sh", "-c", "sleep 5" }, 100)
        assert.equals(124, tcode)
    end)
end)

describe("image_shrink: shrink (the step assets.save calls)", function()
    local png_gen = require("tests.helpers.png_gen")
    local BIG = png_gen.png_bytes(1700, 3)     -- over the edge, tiny in bytes
    local SMALL = png_gen.png_bytes(10, 10)
    local calls

    local function fake_env(tools)
        return { executable = function(t) return tools[t] == true end }
    end
    local function deps_ok()
        calls = {}
        return {
            tempname = function() return "/tmp/x" end,
            write = function() return true end,
            read = function() return JPG end,
            remove = function() end,
            exec = function(argv) calls[#calls + 1] = argv; return 0, "" end,
        }
    end

    it("shrinks a PNG over the edge: jpg ext, sizes in the outcome", function()
        shrink.configure({}, fake_env({ sips = true }), deps_ok())
        local bytes, ext, outcome = shrink.shrink(BIG, "png")
        assert.equals(JPG, bytes)
        assert.equals("jpg", ext)
        assert.same({ from = #BIG, to = #JPG }, outcome)
        assert.equals(1, #calls)
    end)
    it("keeps a small PNG byte-identical without running the tool", function()
        shrink.configure({}, fake_env({ sips = true }), deps_ok())
        local bytes, ext, outcome = shrink.shrink(SMALL, "png")
        assert.equals(SMALL, bytes)
        assert.equals("png", ext)
        assert.is_nil(outcome)
        assert.equals(0, #calls)
    end)
    it("shrink = false keeps everything, no probe, no run", function()
        local probed = false
        shrink.configure({ shrink = false }, { executable = function() probed = true; return true end }, deps_ok())
        local bytes, ext, outcome = shrink.shrink(BIG, "png")
        assert.equals(BIG, bytes)
        assert.equals("png", ext)
        assert.is_nil(outcome)
        assert.is_false(probed)
    end)
    it("no tool: original kept, one note naming what to install, second call silent", function()
        shrink.configure({}, fake_env({}), deps_ok())
        local bytes, ext, outcome = shrink.shrink(BIG, "png")
        assert.equals(BIG, bytes)
        assert.equals("png", ext)
        assert.matches("no image shrink tool found", outcome.note)
        local _, _, again = shrink.shrink(BIG, "png")
        assert.is_nil(again)
    end)
    it("a tool that misbehaves: original kept, note names the tool, every time", function()
        local d = deps_ok()
        d.exec = function() return 13, "Error: Cannot extract image from file." end
        shrink.configure({}, fake_env({ sips = true }), d)
        local _, ext, outcome = shrink.shrink(BIG, "png")
        assert.equals("png", ext)
        assert.equals("sips exit 13: Error: Cannot extract image from file.", outcome.note)
        local _, _, again = shrink.shrink(BIG, "png")
        assert.equals(outcome.note, again.note)
    end)
    it("garbage output: original kept with the not-a-JPEG note", function()
        local d = deps_ok()
        d.read = function() return "not a jpeg" end
        shrink.configure({}, fake_env({ sips = true }), d)
        local bytes, _, outcome = shrink.shrink(BIG, "png")
        assert.equals(BIG, bytes)
        assert.equals("sips wrote something that is not a JPEG", outcome.note)
    end)
    it("configure resets the session: a tool appearing later is found", function()
        shrink.configure({}, fake_env({}), deps_ok())
        shrink.shrink(BIG, "png")
        shrink.configure({}, fake_env({ sips = true }), deps_ok())
        local _, ext = shrink.shrink(BIG, "png")
        assert.equals("jpg", ext)
    end)
    it("an unknown extension is kept untouched", function()
        shrink.configure({}, fake_env({ sips = true }), deps_ok())
        local bytes, ext, outcome = shrink.shrink("GIF89a…", "gif")
        assert.equals("GIF89a…", bytes)
        assert.equals("gif", ext)
        assert.is_nil(outcome)
        assert.equals(0, #calls)
    end)
end)
```

- [ ] **Step 2: Run — the new blocks fail** (`run`, `configure`, `shrink`, `default_deps` are nil).

- [ ] **Step 3: Append the IO half**

```lua
--------------------------------------------------------------------------------
-- IO: the one seam
--------------------------------------------------------------------------------

--- Production deps. `exec` is synchronous: vim.system(...):wait(timeout)
--- kills the tool at the budget and reports 124. Main-loop only (tempname
--- and assets.default_io use vim.fn), which is where save runs.
M.default_deps = {
    tempname = function()
        return vim.fn.tempname()
    end,
    write = function(p, bytes)
        return assets.default_io.write(p, bytes)
    end,
    read = function(p, max)
        return assets.default_io.read(p, max)
    end,
    remove = function(p)
        os.remove(p)
    end,
    exec = function(argv, timeout_ms)
        local res = vim.system(argv, { text = true, timeout = timeout_ms }):wait()
        return res.code or 1, res.stderr or ""
    end,
}

--- Run one recipe over `bytes`. Never raises; both temp files are removed on
--- every path. The output read is bounded to #bytes: anything larger is a
--- kept-original outcome anyway.
--- @return integer code, string stderr, string|nil out_bytes
function M.run(recipe, bytes, ext, max_edge, deps)
    deps = deps or M.default_deps
    local in_path = deps.tempname() .. "." .. ext
    local out_path = deps.tempname() .. "." .. M.OUT_EXT
    local code, stderr, out = 1, "", nil
    local ok, err = pcall(function()
        local wok, werr = deps.write(in_path, bytes)
        if not wok then
            stderr = "could not write the source for " .. recipe.tool .. ": " .. tostring(werr)
            return
        end
        local eok, c, s = pcall(deps.exec, M.argv_for(recipe, in_path, out_path, max_edge), M.TIMEOUT_MS)
        if not eok then
            stderr = "could not start " .. recipe.tool .. ": " .. tostring(c)
            return
        end
        code, stderr = c, s or ""
        out = deps.read(out_path, #bytes)
    end)
    if not ok then
        code, stderr = 1, "shrink failed: " .. tostring(err)
    end
    pcall(deps.remove, in_path)
    pcall(deps.remove, out_path)
    return code, stderr, out
end

-- Session: config + probe state + the deps the step runs with (tests inject).
local session = { cfg = {}, resolved = nil, env = nil, deps = nil }

local function host_env()
    return {
        executable = function(tool)
            return vim.fn.executable(tool) == 1
        end,
    }
end

--- Bind the session to `config.assets` (parley.setup calls this). Resets the
--- probe/warn state so a new shrink_cmd is probed and may warn again.
--- @param cfg table|nil  config.assets
--- @param env table|nil  { executable } — tests only
--- @param deps table|nil  run() deps — tests only
function M.configure(cfg, env, deps)
    session = { cfg = cfg or {}, resolved = nil, env = env, deps = deps }
end

--- The step. Returns the bytes and extension to store, and an outcome for
--- the caller's notice (nil when nothing was attempted or worth saying).
--- @param bytes string
--- @param ext string
--- @return string bytes, string ext, table|nil outcome
function M.shrink(bytes, ext)
    local cfg = session.cfg
    if cfg.shrink == false then
        return bytes, ext, nil
    end
    local media_type = assets.media_type("x." .. ext)
    local w, h = assets.dimensions(media_type, bytes)
    local max_edge = M.decide(#bytes, w, h, media_type)
    if not max_edge then
        return bytes, ext, nil
    end
    local recipe, note = M.resolve(session, cfg, session.env or host_env())
    if not recipe then
        return bytes, ext, note and { from = #bytes, note = note } or nil
    end
    local code, stderr, out = M.run(recipe, bytes, ext, max_edge, session.deps)
    local status, why = M.classify(code, stderr, out, #bytes, recipe.tool)
    if status == "ok" then
        return out, M.OUT_EXT, { from = #bytes, to = #out }
    end
    return bytes, ext, why and { from = #bytes, note = why } or nil
end
```

- [ ] **Step 4: Run the spec — green.** Also `luacheck lua/parley/image_shrink.lua lua/parley/argv_recipe.lua` (`make lint` if luacheck is installed).

- [ ] **Step 5: Commit**

```bash
git add lua/parley/image_shrink.lua tests/unit/image_shrink_spec.lua
git commit -m "#244: image_shrink: the spawn seam, session step, temp files removed on every path"
```

### Task 5: `assets.save` runs the step

**Files:**
- Modify: `lua/parley/assets.lua:895-996` (`default_io`), `:997-1024` (`save`), module header
- Test: `tests/unit/assets_spec.lua` (`assets: save and read_bounded` block)

- [ ] **Step 1: Failing specs** (append inside the save block; `fake_io` gets an optional `shrink` in `opts`)

```lua
    it("save runs io_.shrink before writing: stored bytes, ext and link follow the outcome", function()
        local io_ = fake_io()
        local seen
        io_.shrink = function(bytes, ext)
            seen = { bytes = bytes, ext = ext }
            return "JPEGBYTES", "jpg", { from = #bytes, to = 9 }
        end
        local rel, abs, err, outcome = assets.save(CHAT, "PNGBYTESPNGBYTES", "png", io_)
        assert.is_nil(err)
        assert.same({ bytes = "PNGBYTESPNGBYTES", ext = "png" }, seen)
        assert.matches("%.jpg$", rel)
        assert.equals("JPEGBYTES", io_.files[abs])
        assert.same({ from = 16, to = 9 }, outcome)
    end)
    it("save without a shrink step (older io_) behaves as before", function()
        local io_ = fake_io()
        local rel, _, err, outcome = assets.save(CHAT, "PNG", "png", io_)
        assert.is_nil(err)
        assert.matches("%.png$", rel)
        assert.is_nil(outcome)
    end)
    it("save refuses an over-cap source BEFORE the shrink step runs", function()
        local io_ = fake_io()
        local ran = false
        io_.shrink = function(b, e) ran = true; return b, e, nil end
        local rel, _, err = assets.save(CHAT, string.rep("x", assets.MAX_BYTES + 1), "png", io_)
        assert.is_nil(rel)
        assert.equals(assets.too_big(assets.MAX_BYTES + 1), err)
        assert.is_false(ran)
    end)
    -- (the default_io.shrink delegation case is given in Step 3 below)
```

- [ ] **Step 2: Run — fail** (4th return nil; `default_io.shrink` nil).

- [ ] **Step 3: Implement**

In `default_io` add a LAZY binding — `image_shrink` requires `assets`, so a
top-level require from `assets.lua` would re-enter the module while it is
still loading (a require cycle):

```lua
    -- #244: the shrink step. Resolved at call time: image_shrink requires
    -- assets, so binding it while assets.lua is still loading would cycle.
    shrink = function(bytes, ext)
        return require("parley.image_shrink").shrink(bytes, ext)
    end,
```

and make the spec's last case behavioural rather than identity-based:

```lua
    it("default_io.shrink delegates to image_shrink.shrink", function()
        local shrink = require("parley.image_shrink")
        local saved = shrink.shrink
        local seen
        shrink.shrink = function(b, e) seen = { b, e }; return b, e, nil end
        assets.default_io.shrink("B", "png")
        shrink.shrink = saved
        assert.same({ "B", "png" }, seen)
    end)
```

Then in `save`, after the `MAX_BYTES` check:

```lua
    -- #244: shrink when it pays (image_shrink policy); the stored bytes, the
    -- extension and therefore the link follow the outcome. The cap above is
    -- the SOURCE's: a paste past it was truncated at read anyway.
    local outcome
    if io_.shrink then
        bytes, ext, outcome = io_.shrink(bytes, ext)
    end
```

and return `M.relative_path(...), abs, nil, outcome`. Update the docstring
(`@return table|nil outcome  { from, to?, note? }`) and the module header's
ONE WRITER paragraph: "…and `save` shrinks through `io_.shrink` (#244) so
every writer's images are small."

- [ ] **Step 4: Run `assets_spec` — green.** Then the whole unit dir quickly:
`for f in tests/unit/*_spec.lua; do …PlenaryBustedFile $f…; done | grep -c FAIL` → `0`.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/assets.lua tests/unit/assets_spec.lua
git commit -m "#244: assets.save runs the shrink step; outcome returned to the writer's caller"
```

### Task 6: paste notice, setup wiring, config comment, `fake_sips`, integration spec

**Files:**
- Modify: `lua/parley/paste_image.lua:124-137`, `lua/parley/init.lua:545` (after `M.config = …`), `lua/parley/config.lua:576-584`
- Create: `tests/fixtures/fake_sips` (chmod +x)
- Test: `tests/integration/paste_image_spec.lua` (new describe block)

- [ ] **Step 1: The fixture**

```python
#!/usr/bin/env python3
"""A stand-in for `sips` as the shrink recipe runs it (#244).

Argv shape: ... --resampleHeightWidthMax <max> <in> --out <out>. Behaviour
measured on macOS 26.6 (sips-316), 2026-09-13, chosen by PARLEY_FAKE_SIPS:
    ok:<path>  copy that file to <out>, exit 0          (a real shrink)
    fail       exit 13, "Error: Cannot extract image from file." on stderr
    empty      exit 0, write nothing (sips on a missing input / output dir)
    garbage    exit 0, write "not a jpeg" to <out>
    slow:<path> sleep PARLEY_FAKE_SIPS_DELAY_MS (default 6000), then as ok:
Every call appends "<state>\t<max>\t<in>\t<out>" to $PARLEY_FAKE_SIPS_LOG when
set, so a spec can assert the edge it was asked for and count runs.
"""
import os
import shutil
import sys
import time

sys.dont_write_bytecode = True  # never write __pycache__ into the repo (#202)

state = os.environ.get("PARLEY_FAKE_SIPS", "fail")
args = sys.argv[1:]
max_edge = args[args.index("--resampleHeightWidthMax") + 1] if "--resampleHeightWidthMax" in args else ""
out = args[args.index("--out") + 1] if "--out" in args else ""
src = args[args.index("--out") - 1] if "--out" in args else ""
log = os.environ.get("PARLEY_FAKE_SIPS_LOG")
if log:
    with open(log, "a") as fh:
        fh.write("\t".join([state, max_edge, src, out]) + "\n")

if state.startswith("slow:"):
    time.sleep(int(os.environ.get("PARLEY_FAKE_SIPS_DELAY_MS", "6000")) / 1000.0)
    state = "ok:" + state[5:]
if state.startswith("ok:"):
    shutil.copyfile(state[3:], out)
    sys.exit(0)
if state == "empty":
    sys.exit(0)
if state == "garbage":
    with open(out, "wb") as fh:
        fh.write(b"not a jpeg")
    sys.exit(0)
sys.stderr.write("Error: Cannot extract image from file.\n")
sys.exit(13)
```

`chmod +x tests/fixtures/fake_sips`.

- [ ] **Step 2: Failing integration cases** (append to `tests/integration/paste_image_spec.lua`; the file's `parley.setup` gains `shrink_cmd = { fake_sips, "--resampleHeightWidthMax", "{max}", "{in}", "--out", "{out}" }` and the block sets `PARLEY_FAKE_SIPS`; `setup` is re-run per case that changes it — see Step 4)

```lua
describe("paste image: shrink on save (#244)", function()
    local png_gen = require("tests.helpers.png_gen")
    local fake_sips = repo .. "/tests/fixtures/fake_sips"
    local jpg = repo .. "/tests/fixtures/one_pixel.jpg"
    local slog = root .. "/sips.log"
    local big_png = root .. "/big.png"

    local function shrink_runs()
        return vim.fn.filereadable(slog) == 1 and vim.fn.readfile(slog) or {}
    end
    local function setup_with(assets_cfg)
        parley.setup({
            chat_dir = root, state_dir = vim.fn.tempname() .. "-parley-paste-state",
            providers = {}, api_keys = {},
            assets = vim.tbl_extend("force", { clipboard_cmd = { fake_clipboard, "{out}" } }, assets_cfg),
        })
    end
    local function paste_and_wait(buf)
        parley.paste_image(buf, { notify = notify })
        assert.is_true(wait_for(function() return #notices > 0 end), "a notice arrived")
        return notices[#notices]
    end

    before_each(function()
        notices = {}
        os.remove(slog)
        vim.env.PARLEY_FAKE_SIPS_LOG = slog
        vim.fn.mkdir(root, "p")
        assets.default_io.write(big_png, png_gen.png_bytes(1800, 4)) -- over the edge, small in bytes
        vim.env.PARLEY_FAKE_CLIPBOARD = "png:" .. big_png
    end)
    after_each(function()
        vim.env.PARLEY_FAKE_SIPS = nil
        setup_with({})
    end)

    it("a PNG over the edge lands as .jpg with both sizes in the notice; the tool got the capped edge", function()
        setup_with({ shrink_cmd = { fake_sips, "--resampleHeightWidthMax", "{max}", "{in}", "--out", "{out}" } })
        vim.env.PARLEY_FAKE_SIPS = "ok:" .. jpg
        local buf = open_chat(TS .. "_big.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 8, 0 })
        local n = paste_and_wait(buf)
        assert.matches("pasted assets/.*%.jpg %(", n.msg)
        assert.matches("→", n.msg)
        assert.equals("info", n.level)
        local att = assets.parse_attachment(vim.api.nvim_buf_get_lines(buf, 8, 9, false)[1])
        assert.equals(bytes_of(jpg), bytes_of(root .. "/" .. att.path))
        local runs = shrink_runs()
        assert.equals(1, #runs)
        assert.equals("1600", vim.split(runs[1], "\t")[2])
    end)

    it("a small PNG is stored byte-identical and the tool is never run", function()
        setup_with({ shrink_cmd = { fake_sips, "--resampleHeightWidthMax", "{max}", "{in}", "--out", "{out}" } })
        vim.env.PARLEY_FAKE_SIPS = "ok:" .. jpg
        vim.env.PARLEY_FAKE_CLIPBOARD = "png:" .. png -- the 69-byte fixture
        local buf = open_chat(TS .. "_small.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 8, 0 })
        local n = paste_and_wait(buf)
        assert.matches("pasted assets/.*%.png$", n.msg)
        local att = assets.parse_attachment(vim.api.nvim_buf_get_lines(buf, 8, 9, false)[1])
        assert.equals(bytes_of(png), bytes_of(root .. "/" .. att.path))
        assert.same({}, shrink_runs())
    end)

    it("a tool that returns garbage keeps the original PNG and says which tool", function()
        setup_with({ shrink_cmd = { fake_sips, "--resampleHeightWidthMax", "{max}", "{in}", "--out", "{out}" } })
        vim.env.PARLEY_FAKE_SIPS = "garbage"
        local buf = open_chat(TS .. "_garbage.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 8, 0 })
        local n = paste_and_wait(buf)
        assert.matches("pasted assets/.*%.png — original kept: .*fake_sips wrote something that is not a JPEG", n.msg)
        assert.equals("warn", n.level)
        local att = assets.parse_attachment(vim.api.nvim_buf_get_lines(buf, 8, 9, false)[1])
        assert.equals(bytes_of(big_png), bytes_of(root .. "/" .. att.path))
    end)

    it("no tool at all: original stored, one warning names what to install, the next paste is quiet", function()
        setup_with({ shrink_cmd = nil })
        -- Hide every real tool from the probe for this case.
        require("parley.image_shrink").configure(parley.config.assets, { executable = function() return false end })
        local buf = open_chat(TS .. "_notool.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 8, 0 })
        local n1 = paste_and_wait(buf)
        assert.matches("original kept: no image shrink tool found: sips ships with macOS or install ImageMagick", n1.msg)
        assert.equals("warn", n1.level)
        notices = {}
        vim.api.nvim_win_set_cursor(0, { 8, 0 })
        local n2 = paste_and_wait(buf)
        assert.matches("pasted assets/.*%.png$", n2.msg)
        assert.equals("info", n2.level)
    end)
end)
```

- [ ] **Step 3: Run — fail** (no `.jpg`, no suffix, `configure` not called by setup).

- [ ] **Step 4: Wire it**

`lua/parley/init.lua`, right after `M.config = vim.deepcopy(config)` and the
config merge that follows it (find where `M.config.assets` is final — after
the `for k, v in pairs(opts)` merge loop; place the call just before setup
returns or where other per-setup module resets live):

```lua
	-- #244: bind the shrink step to this setup's assets config (resets the
	-- once-per-session probe and warning).
	require("parley.image_shrink").configure(M.config.assets)
```

`lua/parley/paste_image.lua` — the save call and the final notice:

```lua
            local rel, abs, save_err, outcome = assets.save(chat_now, bytes, "png")
            …
            local suffix = image_shrink.outcome_suffix(outcome)
            finish("Parley: pasted " .. rel .. suffix, (outcome and outcome.note) and "warn" or "info")
```

with `local image_shrink = require("parley.image_shrink")` at the top, and a
header sentence: "The saved bytes may be a shrunk JPEG (#244, `assets.save`);
the notice carries the sizes, or the reason the original was kept."

`lua/parley/config.lua:576-584` — extend the comment:

```lua
	-- #244: `assets.shrink = false` stores images as they come; `assets.shrink_cmd`
	-- overrides the shrink recipe (sips / magick / convert / ffmpeg / vipsthumbnail,
	-- first found): an argv list with "{in}", "{out}" (whole arguments) and
	-- "{max}" (the target long edge; may sit inside an argument). Contract: exit 0
	-- and a smaller, valid JPEG at {out} replaces the original; anything else
	-- keeps the original and the paste notice says why.
```

- [ ] **Step 5: Run the integration spec and the unit specs — green**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/paste_image_spec.lua" -c "qa!"`
Expected: PASS, every pre-existing #231 case included.

- [ ] **Step 6: Commit**

```bash
git add lua/parley/paste_image.lua lua/parley/init.lua lua/parley/config.lua tests/fixtures/fake_sips tests/integration/paste_image_spec.lua
git commit -m "#244: paste notice carries the shrink outcome; setup binds the step; fake_sips"
```

## Chunk 3: conformance and docs (Tasks 7–8)

### Task 7: live conformance, opt-in, per recipe

**Files:**
- Create: `tests/integration/image_shrink_live_spec.lua`

- [ ] **Step 1: Write the spec**

```lua
-- #244 conformance: every shrink recipe whose tool this host has, against a
-- generated 1800×1200 PNG. Opt-in (PARLEY_LIVE_SHRINK=1): it spawns real
-- tools. Asserts through the tool-independent contract — a structurally
-- valid JPEG, strictly smaller, long edge ≤ the requested cap — and, where
-- sips exists, through sips' own probe (`sips -g pixelWidth`).
--
-- Under an agent sandbox sips cannot write its scratch dir (/var/folders/…)
-- and reports exit 13; run this spec from a normal shell.
local shrink = require("parley.image_shrink")
local assets = require("parley.assets")
local png_gen = require("tests.helpers.png_gen")

describe("image_shrink recipe conformance (live, opt-in)", function()
    local live = os.getenv("PARLEY_LIVE_SHRINK") == "1"
    local src = live and png_gen.png_bytes(1800, 1200, "\40\90\160") or nil
    local any = false

    for _, recipe in ipairs(shrink.RECIPES) do
        it(recipe.tool .. " shrinks a 1800×1200 PNG to a ≤1600 px JPEG that is smaller", function()
            if not live then
                pending("set PARLEY_LIVE_SHRINK=1 to run the real recipes")
                return
            end
            if vim.fn.executable(recipe.tool) ~= 1 then
                pending(recipe.tool .. " is not installed here (" .. recipe.install .. ")")
                return
            end
            any = true
            local code, stderr, out = shrink.run(recipe, src, "png", 1600)
            local status, note = shrink.classify(code, stderr, out, #src, recipe.tool)
            assert.equals("ok", status, note)
            local w, h = assets.dimensions("image/jpeg", out)
            assert.is_true(w ~= nil and math.max(w, h) <= 1600, ("long edge %s"):format(tostring(w and math.max(w, h))))
            assert.equals(1600, w, "1800×1200 scales to 1600×1067")
            assert.is_true(#out < #src / 4, ("expected a real reduction, got %d of %d"):format(#out, #src))
            if vim.fn.executable("sips") == 1 then
                local tmp = vim.fn.tempname() .. ".jpg"
                assets.default_io.write(tmp, out)
                local probe = vim.fn.system({ "sips", "-g", "pixelWidth", "-g", "pixelHeight", tmp })
                os.remove(tmp)
                assert.matches("pixelWidth: 1600", probe)
                assert.matches("pixelHeight: 1067", probe)
            end
        end)
    end

    it("a small PNG asked for its own edge is not upscaled (the {max} contract)", function()
        if not live or vim.fn.executable("sips") ~= 1 then
            pending("live + sips only")
            return
        end
        local small = png_gen.png_bytes(800, 500)
        local code, stderr, out = shrink.run(shrink.RECIPES[1], small, "png", 800)
        assert.equals(0, code, stderr)
        local w, h = assets.dimensions("image/jpeg", out)
        assert.same({ 800, 500 }, { w, h })
    end)

    it("reports which recipes ran", function()
        if not live then pending("opt-in") return end
        assert.is_true(any, "no recipe tool installed; nothing was conformance-checked")
    end)
end)
```

- [ ] **Step 2: Run it opt-in from a normal shell** (not the sandbox):

Run: `PARLEY_LIVE_SHRINK=1 nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/image_shrink_live_spec.lua" -c "qa!"`
Expected: sips case PASS; magick/convert/ffmpeg/vipsthumbnail pending (not installed); the no-upscale case PASS. Record the output in the issue Log.

- [ ] **Step 3: Run without the flag** — all pending, exit 0.

- [ ] **Step 4: Commit**

```bash
git add tests/integration/image_shrink_live_spec.lua
git commit -m "#244: live conformance for every shrink recipe the host has (opt-in)"
```

### Task 8: atlas, README, traceability, issue

**Files:**
- Modify: `atlas/chat/attachments.md` (Surface, Model, Lifecycle, Tests), `README.md:189-200`, `atlas/traceability.yaml` (`chat/attachments` code + tests), `workshop/issues/000244-shrink-images-on-save.md` (Plan ticks + Log)

- [ ] **Step 1: Atlas** — in `attachments.md`:
  - Surface, under `<M-v>`: "The saved file is a ≤1600 px JPEG when the source
    is a PNG over 300 KB or over 1600 px, or a JPEG over 1600 px (#244); the
    notice shows `(4.1 MB → 180 KB)`, or `— original kept: <why>` when no tool
    is installed (once per session) or the tool misbehaved. `assets.shrink =
    false` disables it; `assets.shrink_cmd` is an argv with `{in}`, `{out}`,
    `{max}`."
  - Model: a bullet for `lua/parley/image_shrink.lua` — "policy, recipes as
    data (sips, magick, convert, ffmpeg, vipsthumbnail; first executable),
    the outcome rule (exit 0 + smaller valid JPEG replaces; else kept), the
    once-per-session probe/warn state; the spawn is synchronous and bounded
    (5 s)". A bullet for `lua/parley/argv_recipe.lua` — "the recipe grammar
    the clipboard and shrink recipes share". Amend the `assets.lua` line:
    "`save` runs the shrink step through `io_.shrink` and returns the
    outcome; `dimensions` reads PNG/JPEG size from the validated headers".
  - Lifecycle: "Shrink temp files live under `tempname()` for the length of
    the run and are removed on every path."
  - Tests: add `argv_recipe_spec.lua`, `image_shrink_spec.lua`,
    `tests/fixtures/fake_sips` (models sips through `shrink_cmd`),
    `tests/helpers/png_gen.lua`, `image_shrink_live_spec.lua` (opt-in
    `PARLEY_LIVE_SHRINK=1`).
- [ ] **Step 2: README** — after the `<M-v>` paragraph's clipboard sentence add:
  "Large images are shrunk before they are stored (a Retina screenshot
  becomes a ≤1600 px JPEG, typically under 300 KB) using `sips` on macOS or
  ImageMagick / ffmpeg / libvips where installed; with none of them the
  original is stored and parley says so once. `assets.shrink = false` keeps
  originals; `assets.shrink_cmd` supplies your own recipe." And the
  commit-vs-ignore note: "Assets are write-once binaries: committing
  `assets/` alongside the chats costs their size exactly once and keeps a
  chat readable from any clone; ignoring the folder keeps the repo small at
  the price of dangling links elsewhere. Either is a per-repo `.gitignore`
  choice; Git LFS on the same fixed path is a later switch."
- [ ] **Step 3: Traceability** — add `lua/parley/image_shrink.lua`,
  `lua/parley/argv_recipe.lua` to `chat/attachments.code` and the four new
  spec/helper files to `.tests` (check whether the file lists helpers; if the
  schema is specs only, list the three specs).
- [ ] **Step 4: Issue** — tick the five Plan rows; Log: the measured facts
  table (upscaling, exit-0-no-output, 90 ms, sandbox scratch denial), the
  three Spec refinements and their ARCH citations, the live-spec output.
- [ ] **Step 5: Full suite** — `make test` (from a normal shell if the sandbox
  bites), expect 0 failures; `make lint` if luacheck exists.
- [ ] **Step 6: Commit**

```bash
git add atlas/chat/attachments.md README.md atlas/traceability.yaml workshop/issues/000244-shrink-images-on-save.md
git commit -m "#244: atlas + README: images shrink on save; commit-vs-ignore note for assets/"
```

Then `sdlc close --issue 244 --verified '<make test summary + live spec line>'`.

## Out of scope (stated so it is a decision, not an omission)

- Reading install advice from a registry — #245 owns it; the `install`
  strings here are the interim copies it will replace.
- Async shrinking / a progress indicator — measured 90 ms; revisit only if a
  real tool measures over ~300 ms on a real screenshot.
- Preserving PNG alpha (a transparent source becomes an opaque JPEG) and
  EXIF orientation from the source (screenshots carry none; `-auto-orient` is
  passed where the tool supports it).
- Shrinking images already in `assets/` (a one-off migration, if ever wanted,
  would be a script, not plugin code).
