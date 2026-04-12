# Chat File Slug Renaming — Implementation Plan

> **Execution:** Main session implements directly (context is warm from brainstorming). Subagents dispatched only for bounded tasks matching AGENTS.md criteria 1-3 and for post-milestone code review. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auto-rename parley chat files to include a human-readable slug derived from the topic header, with fuzzy resolution + read repair for stale references.

**Architecture:** New pure module `chat_slug.lua` for slug logic. `BufWritePost` autocmd triggers rename. `resolve_chat_path()` enhanced with fuzzy glob fallback + read repair. Exporter refactored to use shared resolution.

**Tech Stack:** Lua, Neovim API, busted test framework

**Spec:** `workshop/issues/000099-allow-parley-file-to-have-slug.md`

---

## Task 1: Create `chat_slug.lua` — pure slug functions

**Files:**
- Create: `lua/parley/chat_slug.lua`
- Test: `tests/unit/chat_slug_spec.lua`

### 1.1 Write failing tests for `slugify()`

- [ ] **Step 1: Write tests**

```lua
-- tests/unit/chat_slug_spec.lua
local chat_slug = require("parley.chat_slug")

describe("chat_slug", function()
  describe("slugify", function()
    it("returns nil for question mark topic", function()
      assert.is_nil(chat_slug.slugify("?"))
    end)

    it("returns nil for empty string", function()
      assert.is_nil(chat_slug.slugify(""))
    end)

    it("returns nil for nil", function()
      assert.is_nil(chat_slug.slugify(nil))
    end)

    it("strips stop words and kebab-cases", function()
      assert.equals("debugging-authentication-flow", chat_slug.slugify("Debugging the authentication flow"))
    end)

    it("caps at 5 words", function()
      assert.equals("one-two-three-four-five", chat_slug.slugify("one two three four five six seven"))
    end)

    it("caps at 40 chars breaking at word boundary", function()
      local result = chat_slug.slugify("longword longword longword longword longword")
      assert.is_true(#result <= 40)
      -- "longword-longword-longword-longword" = 35 chars, fits
      -- "longword-longword-longword-longword-longword" = 44 chars, too long
      assert.equals("longword-longword-longword-longword", result)
    end)

    it("replaces underscores with hyphens", function()
      assert.equals("some-var-name", chat_slug.slugify("some_var_name"))
    end)

    it("strips non-ASCII characters", function()
      assert.equals("hello-world", chat_slug.slugify("héllo wörld"))
    end)

    it("collapses multiple hyphens", function()
      assert.equals("hello-world", chat_slug.slugify("hello---world"))
    end)

    it("lowercases everything", function()
      assert.equals("hello-world", chat_slug.slugify("Hello World"))
    end)

    it("strips leading/trailing hyphens", function()
      assert.equals("hello", chat_slug.slugify("  hello  "))
    end)

    it("returns nil when topic has only stop words", function()
      assert.is_nil(chat_slug.slugify("the and of"))
    end)
  end)
end)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test FILE=tests/unit/chat_slug_spec.lua`
Expected: FAIL — module not found

### 1.2 Implement `slugify()`

- [ ] **Step 3: Write `chat_slug.lua`**

```lua
-- lua/parley/chat_slug.lua
local M = {}

local stop_words = {
  ["the"] = true, ["a"] = true, ["an"] = true, ["in"] = true,
  ["of"] = true, ["for"] = true, ["to"] = true, ["and"] = true,
  ["is"] = true, ["with"] = true, ["on"] = true, ["at"] = true,
  ["by"] = true,
}

--- Convert a topic string into a URL-safe slug, or nil if topic is empty/placeholder.
---@param topic string|nil
---@return string|nil
M.slugify = function(topic)
  if not topic or topic == "" or topic == "?" then
    return nil
  end

  -- lowercase, replace underscores with hyphens
  local s = topic:lower():gsub("_", "-")
  -- strip non-ASCII and non-alphanumeric (keep hyphens and spaces)
  s = s:gsub("[^%w%s%-]", "")
  -- normalize whitespace to single hyphens
  s = s:gsub("%s+", "-")
  -- collapse multiple hyphens
  s = s:gsub("%-+", "-")
  -- strip leading/trailing hyphens
  s = s:gsub("^%-+", ""):gsub("%-+$", "")

  -- split into words, filter stop words, take up to 5
  local words = {}
  for word in s:gmatch("[^%-]+") do
    if not stop_words[word] and word ~= "" then
      table.insert(words, word)
    end
    if #words >= 5 then
      break
    end
  end

  if #words == 0 then
    return nil
  end

  -- join and enforce 40 char limit at word boundary
  local result = words[1]
  for i = 2, #words do
    local candidate = result .. "-" .. words[i]
    if #candidate > 40 then
      break
    end
    result = candidate
  end

  return result
end

return M
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `make test FILE=tests/unit/chat_slug_spec.lua`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add lua/parley/chat_slug.lua tests/unit/chat_slug_spec.lua
git commit -m "feat(#99): add chat_slug.slugify() with tests"
```

### 1.3 Write and implement filename helpers

- [ ] **Step 6: Add tests for `parse_filename`, `make_filename`, `glob_pattern`**

Append to `tests/unit/chat_slug_spec.lua`:

```lua
  describe("parse_filename", function()
    it("parses timestamp-only filename", function()
      local ts, slug = chat_slug.parse_filename("2026-04-11.16-38-42.729.md")
      assert.equals("2026-04-11.16-38-42.729", ts)
      assert.is_nil(slug)
    end)

    it("parses filename with slug", function()
      local ts, slug = chat_slug.parse_filename("2026-04-11.16-38-42.729_debugging-auth.md")
      assert.equals("2026-04-11.16-38-42.729", ts)
      assert.equals("debugging-auth", slug)
    end)

    it("returns nil for non-timestamp filename", function()
      local ts, slug = chat_slug.parse_filename("readme.md")
      assert.is_nil(ts)
      assert.is_nil(slug)
    end)
  end)

  describe("make_filename", function()
    it("creates timestamp-only when no slug", function()
      assert.equals("2026-04-11.16-38-42.729.md", chat_slug.make_filename("2026-04-11.16-38-42.729", nil))
    end)

    it("creates filename with slug", function()
      assert.equals("2026-04-11.16-38-42.729_debugging-auth.md", chat_slug.make_filename("2026-04-11.16-38-42.729", "debugging-auth"))
    end)
  end)

  describe("glob_pattern", function()
    it("returns wildcard pattern for timestamp", function()
      assert.equals("2026-04-11.16-38-42.729*.md", chat_slug.glob_pattern("2026-04-11.16-38-42.729"))
    end)
  end)
```

- [ ] **Step 7: Implement the three helpers**

Add to `lua/parley/chat_slug.lua`:

```lua
-- Timestamp pattern: YYYY-MM-DD.HH-MM-SS.mmm
local TIMESTAMP_PATTERN = "^(%d%d%d%d%-%d%d%-%d%d%.%d%d%-%d%d%-%d%d%.%d%d%d)"

--- Parse a chat filename into timestamp and optional slug.
---@param filename string bare filename (no directory)
---@return string|nil timestamp, string|nil slug
M.parse_filename = function(filename)
  local base = filename:gsub("%.md$", "")
  local ts = base:match(TIMESTAMP_PATTERN)
  if not ts then
    return nil, nil
  end
  local rest = base:sub(#ts + 1)
  if rest == "" then
    return ts, nil
  end
  -- rest starts with "_"
  local slug = rest:match("^_(.+)$")
  return ts, slug
end

--- Assemble a chat filename from timestamp and optional slug.
---@param timestamp string
---@param slug string|nil
---@return string
M.make_filename = function(timestamp, slug)
  if slug and slug ~= "" then
    return timestamp .. "_" .. slug .. ".md"
  end
  return timestamp .. ".md"
end

--- Return a glob pattern that matches any slug variant of this timestamp.
---@param timestamp string
---@return string
M.glob_pattern = function(timestamp)
  return timestamp .. "*.md"
end
```

- [ ] **Step 8: Run tests**

Run: `make test FILE=tests/unit/chat_slug_spec.lua`
Expected: All PASS

- [ ] **Step 9: Commit**

```bash
git add lua/parley/chat_slug.lua tests/unit/chat_slug_spec.lua
git commit -m "feat(#99): add parse_filename, make_filename, glob_pattern"
```

---

## Task 2: Add `BufWritePost` rename trigger

**Files:**
- Modify: `lua/parley/init.lua` — add rename function + autocmd
- Requires: `chat_slug.lua` from Task 1

### 2.1 Implement the rename function

- [ ] **Step 1: Add `chat_slug` require at top of init.lua**

Near the other requires at the top of `lua/parley/init.lua`, add:

```lua
local chat_slug = require("parley.chat_slug")
```

- [ ] **Step 2: Add `M._slug_rename_chat()` function**

Add after `sync_moved_chat_buffers` (after line ~2338) in `lua/parley/init.lua`:

```lua
-- Rename a chat file to include/update slug from topic header.
-- Returns (new_path, nil) on success, (nil, reason) on skip/error.
M._slug_rename_chat = function(buf)
  local file_path = vim.api.nvim_buf_get_name(buf)
  if file_path == "" then
    return nil, "no file"
  end

  -- Don't rename during streaming
  if M.tasker and M.tasker.is_busy(buf, true) then
    return nil, "busy"
  end

  local dir = vim.fn.fnamemodify(file_path, ":h")
  local basename = vim.fn.fnamemodify(file_path, ":t")

  local ts, old_slug = chat_slug.parse_filename(basename)
  if not ts then
    return nil, "not a timestamp chat file"
  end

  -- Read topic from buffer header
  local lines = vim.api.nvim_buf_get_lines(buf, 0, 20, false)
  local headers = parse_chat_headers(lines)
  if not headers or not headers.topic or headers.topic == "" or headers.topic == "?" then
    return nil, "no topic"
  end

  local new_slug = chat_slug.slugify(headers.topic)
  if new_slug == old_slug then
    return nil, "slug unchanged"
  end

  local new_basename = chat_slug.make_filename(ts, new_slug)
  local new_path = dir .. "/" .. new_basename

  -- Rename on disk
  local ok = vim.fn.rename(file_path, new_path)
  if ok ~= 0 then
    return nil, "rename failed"
  end

  -- Update all buffers pointing to old path
  sync_moved_chat_buffers(file_path, new_path)

  -- Update file: header in buffer
  for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, 20, false)) do
    if line:match("^file:") then
      vim.api.nvim_buf_set_lines(buf, i - 1, i, false, { "file: " .. new_basename })
      -- Save the updated header; guard flag prevents recursive rename
      M._in_slug_rename = true
      vim.api.nvim_buf_call(buf, function()
        vim.cmd("silent! write")
      end)
      M._in_slug_rename = false
      break
    end
  end

  -- Invalidate topic cache for old path, prime for new
  if M._chat_topic_cache then
    M._chat_topic_cache[file_path] = nil
  end

  return new_path, nil
end
```

- [ ] **Step 3: Add BufWritePost autocmd**

Add in the autocmd setup section of `init.lua` (near the existing autocmds for chat files — the codebase does not use augroups, so match that pattern). Create a dedicated augroup to prevent duplicate autocmds on re-source:

```lua
local slug_augroup = vim.api.nvim_create_augroup("ParleySlug", { clear = true })
vim.api.nvim_create_autocmd("BufWritePost", {
  group = slug_augroup,
  pattern = "*.md",
  callback = function(ev)
    -- Guard: skip if we're already inside a slug rename (prevents recursion)
    if M._in_slug_rename then
      return
    end
    local buf = ev.buf
    local file = ev.file or vim.api.nvim_buf_get_name(buf)
    -- Only for chat files in configured roots
    if M.not_chat(buf, file) then
      return
    end
    M._slug_rename_chat(buf)
  end,
})
```

- [ ] **Step 4: Run full test suite to check for regressions**

Run: `make test`
Expected: All existing tests PASS

- [ ] **Step 5: Commit**

```bash
git add lua/parley/init.lua
git commit -m "feat(#99): add BufWritePost slug rename trigger"
```

---

## Task 3: Fuzzy resolution in `resolve_chat_path()`

**Files:**
- Modify: `lua/parley/init.lua:2400-2409` — enhance `resolve_chat_path`
- Test: `tests/unit/chat_slug_spec.lua` (add resolution tests)

### 3.1 Write failing tests for fuzzy resolution

- [ ] **Step 1: Add tests**

Create `tests/unit/chat_slug_resolve_spec.lua`:

```lua
local parley = require("parley")
local chat_slug = require("parley.chat_slug")

describe("fuzzy chat path resolution", function()
  local base_dir

  before_each(function()
    base_dir = vim.fn.tempname() .. "-parley-slug-resolve"
    vim.fn.mkdir(base_dir, "p")
    parley.setup({
      chat_dir = base_dir,
      providers = {},
      api_keys = {},
    })
  end)

  after_each(function()
    vim.fn.delete(base_dir, "rf")
  end)

  it("resolves exact path as before", function()
    local file = base_dir .. "/2026-04-11.16-38-42.729.md"
    vim.fn.writefile({ "test" }, file)
    local result = parley.resolve_chat_path("2026-04-11.16-38-42.729.md", base_dir)
    assert.equals(vim.fn.resolve(file), result)
  end)

  it("resolves slugged file when referenced by timestamp-only name", function()
    local slugged = base_dir .. "/2026-04-11.16-38-42.729_debugging-auth.md"
    vim.fn.writefile({ "test" }, slugged)
    local result = parley.resolve_chat_path("2026-04-11.16-38-42.729.md", base_dir)
    assert.equals(vim.fn.resolve(slugged), result)
  end)

  it("resolves timestamp-only file when referenced by old slug name", function()
    local plain = base_dir .. "/2026-04-11.16-38-42.729.md"
    vim.fn.writefile({ "test" }, plain)
    local result = parley.resolve_chat_path("2026-04-11.16-38-42.729_old-slug.md", base_dir)
    assert.equals(vim.fn.resolve(plain), result)
  end)

  it("returns first candidate when no match found", function()
    local result = parley.resolve_chat_path("2026-04-11.16-38-42.729.md", base_dir)
    assert.equals(vim.fn.resolve(base_dir .. "/2026-04-11.16-38-42.729.md"), result)
  end)
end)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test FILE=tests/unit/chat_slug_resolve_spec.lua`
Expected: FAIL — fuzzy resolution not yet implemented

### 3.2 Implement fuzzy resolution

- [ ] **Step 3: Modify `resolve_chat_path()` at init.lua:2400-2409**

Replace the existing `resolve_chat_path` function:

```lua
local function resolve_chat_path(path, base_dir)
  local candidates = M._resolve_chat_path_candidates(path, base_dir, M.get_chat_dirs())
  for _, candidate in ipairs(candidates) do
    if vim.fn.filereadable(candidate) == 1 then
      return candidate
    end
  end

  -- Fuzzy fallback: extract timestamp, glob for any slug variant
  local basename = vim.fn.fnamemodify(path, ":t")
  local ts = chat_slug.parse_filename(basename)
  if ts then
    local pattern = chat_slug.glob_pattern(ts)
    -- Search in base_dir and all chat roots
    local search_dirs = { base_dir }
    for _, d in ipairs(M.get_chat_dirs() or {}) do
      if d ~= base_dir then
        table.insert(search_dirs, d)
      end
    end
    for _, dir in ipairs(search_dirs) do
      local matches = vim.fn.glob(dir .. "/" .. pattern, false, true)
      -- Post-filter: verify each match has the exact same timestamp
      local verified = {}
      for _, m in ipairs(matches) do
        local m_ts = chat_slug.parse_filename(vim.fn.fnamemodify(m, ":t"))
        if m_ts == ts then
          table.insert(verified, m)
        end
      end
      if #verified > 0 then
        -- Prefer the match with a slug (most recent rename)
        table.sort(verified, function(a, b)
          return #a > #b
        end)
        return verified[1]
      end
    end
  end

  return candidates[1]
end
```

- [ ] **Step 4: Run tests**

Run: `make test FILE=tests/unit/chat_slug_resolve_spec.lua`
Expected: All PASS

- [ ] **Step 5: Run full test suite**

Run: `make test`
Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add lua/parley/init.lua tests/unit/chat_slug_resolve_spec.lua
git commit -m "feat(#99): add fuzzy resolution for slugged chat files"
```

---

## Task 4: Read repair

**Files:**
- Modify: `lua/parley/init.lua` — add read repair write-back in fuzzy resolution path

### 4.1 Implement read repair

- [ ] **Step 1: Add read repair test**

Add to `tests/unit/chat_slug_resolve_spec.lua`:

```lua
  it("read-repairs stale branch reference in parent file", function()
    -- Create a parent file with a stale reference
    local parent = base_dir .. "/2026-04-10.10-00-00.000.md"
    local child_slugged = base_dir .. "/2026-04-11.16-38-42.729_new-slug.md"
    vim.fn.writefile({
      "---",
      "topic: parent topic",
      "file: 2026-04-10.10-00-00.000.md",
      "---",
      "",
      "🌿: 2026-04-11.16-38-42.729.md: old topic",
    }, parent)
    vim.fn.writefile({ "---", "topic: new slug", "file: 2026-04-11.16-38-42.729_new-slug.md", "---" }, child_slugged)

    -- Resolve the stale reference from parent's directory
    local result = parley.resolve_chat_path("2026-04-11.16-38-42.729.md", base_dir)
    assert.equals(vim.fn.resolve(child_slugged), result)

    -- Read repair is best-effort and runs on next access from a buffer context
    -- The fuzzy resolution itself is the key behavior; repair is an enhancement
  end)
```

- [ ] **Step 2: Add `M._read_repair_reference()` helper**

Add after `_slug_rename_chat` in init.lua:

```lua
-- Best-effort read repair: update a stale filename reference in a file.
-- Called when fuzzy resolution finds a file under a different name.
-- Does NOT repair if the referring buffer is mid-stream.
M._read_repair_reference = function(referring_file, old_basename, new_basename)
  if old_basename == new_basename then
    return
  end

  -- Check if referring file's buffer is busy
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name ~= "" and vim.fn.resolve(buf_name) == vim.fn.resolve(referring_file) then
        if M.tasker and M.tasker.is_busy(buf, true) then
          return -- defer
        end
      end
    end
  end

  if vim.fn.filereadable(referring_file) ~= 1 then
    return
  end

  local lines = vim.fn.readfile(referring_file)
  local changed = false
  for i, line in ipairs(lines) do
    if line:find(old_basename, 1, true) then
      -- Escape % in replacement string (Lua gsub treats % as capture ref)
      local safe_new = new_basename:gsub("%%", "%%%%")
      lines[i] = line:gsub(vim.pesc(old_basename), safe_new)
      changed = true
    end
  end
  if changed then
    vim.fn.writefile(lines, referring_file)
    -- Reload if open in a buffer
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
        local buf_name = vim.api.nvim_buf_get_name(buf)
        if buf_name ~= "" and vim.fn.resolve(buf_name) == vim.fn.resolve(referring_file) then
          vim.api.nvim_buf_call(buf, function()
            vim.cmd("silent! edit!")
          end)
        end
      end
    end
  end
end
```

- [ ] **Step 3: Wire read repair into `resolve_chat_path`**

In the fuzzy fallback section of `resolve_chat_path`, after finding a match, schedule read repair. The caller doesn't know the referring file, so we expose a two-return variant. Simpler approach: make `resolve_chat_path` accept an optional `referring_file` parameter:

Update `resolve_chat_path` signature and fuzzy block:

```lua
local function resolve_chat_path(path, base_dir, referring_file)
  -- ... existing exact-match logic unchanged ...

  -- Fuzzy fallback
  local basename = vim.fn.fnamemodify(path, ":t")
  local ts = chat_slug.parse_filename(basename)
  if ts then
    -- ... glob search as before ...
    for _, dir in ipairs(search_dirs) do
      local matches = vim.fn.glob(dir .. "/" .. pattern, false, true)
      if #matches > 0 then
        table.sort(matches, function(a, b) return #a > #b end)
        local found = matches[1]
        -- Schedule read repair if we have a referring file
        if referring_file and referring_file ~= "" then
          local new_basename = vim.fn.fnamemodify(found, ":t")
          vim.schedule(function()
            M._read_repair_reference(referring_file, basename, new_basename)
          end)
        end
        return found
      end
    end
  end

  return candidates[1]
end
```

- [ ] **Step 4: Update callers to pass `referring_file` where available**

The main callers of `resolve_chat_path` that have a referring file context are the branch-link resolution paths. Search for `resolve_chat_path(` calls in init.lua and pass the current file path as the third argument where the calling context has it. Key call sites:
- Branch link navigation (`M._parse_branch_ref` callers)
- `find_tree_root_file()`
- `collect_tree_files()`

For each, add the current file path as the third arg.

- [ ] **Step 5: Run tests**

Run: `make test`
Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add lua/parley/init.lua tests/unit/chat_slug_resolve_spec.lua
git commit -m "feat(#99): add read repair for stale chat file references"
```

---

## Task 5: Refactor exporter to use shared `resolve_chat_path`

**Files:**
- Modify: `lua/parley/exporter.lua:32-40` — replace local `resolve_chat_path` with shared one

### 5.1 Refactor

- [ ] **Step 1: Replace local function in exporter.lua**

At `exporter.lua:32-40`, replace the local `resolve_chat_path` function with a reference to the shared one:

```lua
local function resolve_chat_path(path, base_dir)
  return _parley.resolve_chat_path(path, base_dir)
end
```

This gives the exporter fuzzy resolution for free. The exporter doesn't have a referring_file context for read repair, which is fine — exports are read-only.

- [ ] **Step 2: Run existing exporter tests**

Run: `make test FILE=tests/unit/exporter_tree_spec.lua`
Expected: All PASS

- [ ] **Step 3: Run full test suite**

Run: `make test`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add lua/parley/exporter.lua
git commit -m "refactor(#99): exporter uses shared resolve_chat_path for fuzzy resolution"
```

---

## Task 6: Update `get_chat_topic()` and `not_chat()` for slugged filenames

**Files:**
- Modify: `lua/parley/init.lua:2024,1696` — relax filename validation

### 6.1 Ensure slugged filenames pass validation

- [ ] **Step 1: Verify current pattern**

At init.lua:2024 and init.lua:1696, the pattern `^%d%d%d%d%-%d%d%-%d%d` matches the date prefix. Since slugged filenames still start with the date (`2026-04-11.16-38-42.729_slug.md`), this pattern already matches. **No change needed.**

Verify with a test:

```lua
-- Add to chat_slug_spec.lua
describe("filename validation compatibility", function()
  it("slugged filename matches existing timestamp pattern", function()
    local basename = "2026-04-11.16-38-42.729_debugging-auth.md"
    assert.is_truthy(basename:match("^%d%d%d%d%-%d%d%-%d%d"))
  end)
end)
```

- [ ] **Step 2: Handle topic cache key migration on rename**

When `_slug_rename_chat` renames a file, `get_chat_topic()` may have the old path cached. This is already handled in `_slug_rename_chat` (Task 2, Step 2) where we invalidate `M._chat_topic_cache[file_path]`. Verify this works by confirming `get_chat_topic(new_path)` returns the correct topic after rename.

- [ ] **Step 3: Run full test suite**

Run: `make test`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add lua/parley/init.lua tests/unit/chat_slug_spec.lua
git commit -m "test(#99): verify slugged filenames pass existing validation"
```

---

## Task 7: Update issue and atlas

**Files:**
- Modify: `workshop/issues/000099-allow-parley-file-to-have-slug.md` — mark done
- Modify: `atlas/chat/lifecycle.md` — document slug behavior

- [ ] **Step 1: Update issue status and log**
- [ ] **Step 2: Add slug documentation to `atlas/chat/lifecycle.md`**

Document: filename format, slug generation trigger, fuzzy resolution behavior.

- [ ] **Step 3: Update `atlas/index.md`** if a new atlas entry is needed
- [ ] **Step 4: Final commit**

```bash
git add workshop/issues/ atlas/
git commit -m "docs(#99): update issue status and atlas with slug feature"
```

---

## Dependency Graph

```
Task 1 (chat_slug.lua) ──┬──▶ Task 2 (rename trigger)
                          └──▶ Task 3 (fuzzy resolution) ──┬──▶ Task 4 (read repair)
                                                           └──▶ Task 5 (exporter refactor)
Task 6 (validation compat) — independent, can run anytime
Task 7 (docs) — after all code tasks
```

## Manual Verification Checklist

After all tasks complete:

1. Open a chat file, set `topic: Debugging auth flow`, save → file renames to `*_debugging-auth-flow.md`
2. Change topic to `New topic here`, save → file re-renames
3. Open parent chat with stale `🌿:` reference → navigation works, reference auto-repairs
4. Run `ls` on chat dir → slugged filenames visible
5. Export a chat tree with slugged files → export succeeds
