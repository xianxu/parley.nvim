-- Architectural fitness function for consolidations made in #205.
--
-- Each of these started as "sweep every consumer onto the single source", and a
-- sweep without a guard is a snapshot: it says nothing about the ninth copy.
-- Two of the three had already regressed or nearly did —
--   * free_port was promoted into tests/helpers/ready_port.lua while EIGHT specs
--     still defined their own, and the promotion's docstring claimed otherwise;
--   * three cliproxy integration specs lacked the data-dir redirect, and running
--     one of them outside `make` overwrote the operator's real rendered config
--     with a test port and api-key. Their live proxy reloaded it and began
--     rejecting their own bearer.
-- so the guards are the deliverable, not a nicety.

local function repo_files(pattern)
    local out = vim.fn.systemlist(pattern)
    assert.equals(0, vim.v.shell_error, "listing failed: " .. pattern)
    return out
end

local function read(path)
    local fd = assert(io.open(path, "r"))
    local body = fd:read("*a")
    fd:close()
    return body
end

--- ERE matching a DEFINITION of `name`, never a mention.
---
--- Grepping for the bare name let a spec COMMENT keep a deleted function's
--- table row green — the guard then certifies exactly the drift it exists to
--- catch. The two failure modes were hit in one sitting: a `%s *=` alternative
--- also matched `x == y` and `t.x = 1`, so a mention satisfied it; tightening
--- to `M.` only then missed the adapter form and string values.
---
--- What makes a name REAL, enumerated: a module function, a table-field
--- function (the adapter form, `cliproxyapi.pre_query = …`), a local, or a
--- quoted string — a table cell may legitimately name a VALUE like a strategy
--- rather than a symbol.
---
--- ERE, not Lua patterns: this string goes to `grep -E`, where `[%%w_]` would
--- be the literal characters % and w.
local function definition_pattern(name)
    return ("(function [A-Za-z0-9_.]*%s\\b|[A-Za-z0-9_.]*[.]%s *=[^=]|local function %s\\b|local %s *=[^=]|\"%s\")")
        :format(name, name, name, name, name)
end

--- Run the real matcher over synthetic text, so the injection cases below
--- exercise `grep -E` rather than a re-implementation of it.
local function defines(name, text)
    local tmp = vim.fn.tempname()
    local fd = assert(io.open(tmp, "w"))
    fd:write(text .. "\n")
    fd:close()
    local hit = vim.fn.systemlist(("grep -lE -- %s %s 2>/dev/null"):format(
        vim.fn.shellescape(definition_pattern(name)), vim.fn.shellescape(tmp)))
    os.remove(tmp)
    return #hit > 0
end

-- #214 (M1 review item 5, M2 review item 4): these two guards were hardwired to
-- `000205-*`, so every issue after it added surface with no table-vs-code
-- cross-check at all. Derive the issue from the branch instead, and accept the
-- Core-concepts table wherever this repo's §1 hierarchy puts it — a durable
-- plan for complex work, the issue file itself for issue-only designs.
local function current_issue_docs()
    local branch = vim.fn.systemlist("git rev-parse --abbrev-ref HEAD")[1] or ""
    local id = branch:match("^(%d%d%d%d%d%d)%-")
    -- No fallback id. An earlier version fell back to `000205` and claimed it
    -- "keeps its historical coverage" — but on main `git merge-base HEAD main`
    -- is HEAD, so the diff is empty and the guard passed vacuously while
    -- asserting it had not (#214 BR-40, same family). Report instead.
    local docs = {}
    if not id then
        return nil, docs
    end
    for _, pat in ipairs({ "workshop/plans/" .. id .. "-*-plan.md",
                           "workshop/issues/" .. id .. "-*.md" }) do
        for _, hit in ipairs(vim.fn.glob(pat, false, true)) do
            docs[#docs + 1] = hit
        end
    end
    return id, docs
end

describe("arch: single-source sweeps stay swept", function()
    it("the plan's Core-concepts tables name every entity THIS issue added", function()
        -- The other direction of the referent sweep, and scoped to the issue's
        -- own diff. A first version listed two files and could not fire on the
        -- instances the finding named; a second listed four and fired on
        -- everything those modules had ever exported. What must be tabled is the
        -- surface this issue ADDS, in any definition form.
        local id, docs = current_issue_docs()
        if not id then
            pending("not on an issue branch — this guard is scoped to a branch's own diff")
            return
        end
        if #docs == 0 then
            pending("no plan or issue document for " .. id)
            return
        end
        -- The BRANCH point, not the issue's first commit. Those coincided for
        -- #205, so the original worked; on a branch cut from a main that has
        -- moved on, diffing from the issue commit attributes every unrelated
        -- merge to this issue and demands table rows for other issues' work.
        local base = vim.fn.systemlist("git merge-base HEAD main")[1]
        if not base or base == "" then
            pending("branch point not found")
            return
        end
        -- `git diff <base>` — NOT `<base>..HEAD`. Diffing to HEAD ignores the
        -- working tree, so a new entity was invisible until the commit AFTER it
        -- appeared: `make test` passed pre-commit and the same run failed once
        -- committed, which is a guard that reports one commit late. Comparing
        -- against the working tree flags it while it is still being written.
        local diff = vim.fn.system(("git diff %s -- lua/ scripts/"):format(base))
        if vim.v.shell_error ~= 0 then
            pending("git diff unavailable")
            return
        end
        -- Only the Core-concepts TABLES, which is what the assertion message
        -- claims. Searching the whole document let a name mentioned anywhere —
        -- a Revisions entry, a commit recipe, a code block — satisfy a guard
        -- about table rows.
        local table_rows = {}
        for _, doc in ipairs(docs) do
            local whole = read(doc)
            local section = whole:match("## Core concepts(.-)\n## ") or ""
            for line in section:gmatch("[^\n]+") do
                if line:match("^| ") then
                    table_rows[#table_rows + 1] = line
                end
            end
        end
        local plan_body = table.concat(table_rows, "\n")

        -- A module's export table is whatever it returns. Reading it from the
        -- file beats hardcoding `M`, which is what made this guard inert over
        -- helper.lua's `_H.` idiom.
        local alias_cache = {}
        local function alias_for(file)
            if not file then return nil end
            if alias_cache[file] ~= nil then return alias_cache[file] or nil end
            local found = false
            if vim.fn.filereadable(file) == 1 then
                for l in io.lines(file) do
                    local a = l:match("^return ([%w_]+)%s*$")
                    if a then alias_cache[file] = a found = true break end
                end
            end
            if not found then alias_cache[file] = false end
            return alias_cache[file] or nil
        end

        local missing = {}
        local current_file = nil
        for line in diff:gmatch("[^\n]+") do
            local hdr = line:match("^%+%+%+ b/(.+)$")
            if hdr then current_file = hdr end
            -- Public FUNCTIONS, in either definition form. Deliberately not
            -- data: `M.AGENT = { … }` is a constant belonging to a module the
            -- tables already name by path, and demanding a row per constant
            -- floods the table without adding a check. A new FUNCTION in an
            -- already-listed module still needs its row — that is the case the
            -- guard exists for. A bare `fn = function()` is a field in a local
            -- table literal (a picker mapping), not exported surface.
            -- The module ALIAS, not the literal `M`. helper.lua exports through
            -- `_H.`, so a guard hardcoded to `M` was inert across that whole
            -- file — and five of #225's seven new entities live behind `_H.`,
            -- which is to say the guard was blind exactly where the work was
            -- (#225 round 4 I2). `alias_for(file)` derives it from the module's
            -- own `return <X>`, so `_S.` and friends are covered too.
            local alias = alias_for(current_file) or "M"
            local esc = vim.pesc(alias)
            local name = line:match("^%+function " .. esc .. "%.([%w_]+)%(")
            if not name then
                -- `<alias>.x = <rhs>`: an export, in any of the forms this repo
                -- uses. Narrowing this to `= function` (the first attempt)
                -- dropped the 41-site `M._x = local_fn` seam-export idiom —
                -- excluding by SYNTAX rather than by what the right-hand side
                -- actually is. Data constants are what should be excluded, and
                -- they are literals: a table, a string, a number.
                local n, rhs = line:match("^%+" .. esc .. "%.([%w_]+) = (.+)$")
                if n and rhs and not rhs:match('^[{"\'%d]') then
                    name = n
                end
            end
            if name and not plan_body:find("`" .. name .. "`", 1, true) then
                missing[name] = true
            end
        end
        local names = {}
        for name in pairs(missing) do
            names[#names + 1] = name
        end
        table.sort(names)
        assert.same({}, names,
            "these are added by this issue but appear in no Core-concepts table row")
    end)

    it("every symbol the Spec and plan tables name exists in the tree", function()
        -- unlike its sibling this one needs no diff, so it runs on any branch
        -- The plan→code direction. The other test walks code→table; this one
        -- catches a document naming a function that was renamed or never
        -- written, which happened three times on this issue (`catalog_write`,
        -- `provider_states`, `M._logged_out_providers`).
        local id, docs = current_issue_docs()
        if not id then
            pending("not on an issue branch")
            return
        end
        local missing = {}
        local survived = {}
        for _, doc in ipairs(docs) do
            if doc ~= "" then
                local body = read(doc)
                -- table rows only: prose may legitimately discuss removed names
                for line in body:gmatch("[^\n]+") do
                    -- A `deleted` row names a symbol that by definition no
                    -- longer exists — that is the whole content of the row.
                    -- `deleted` is in the writing-plans status legend alongside
                    -- new/modified, so demanding a definition for it makes the
                    -- legend unusable. It inverts rather than exempts: skipping
                    -- outright would let a plan claim a deletion that never
                    -- happened (#225 review), so the row asserts the symbol is
                    -- GONE with the same matcher.
                    local deleted_row = line:match("^| `") and line:match("|%s*deleted%s*|")
                    if deleted_row then
                        for name in line:gmatch("`([%w_]+)`") do
                            if #name > 3 and not name:match("^lua$") then
                                local hit = vim.fn.systemlist(
                                    ("grep -rlE -- %s lua/ scripts/ 2>/dev/null"):format(
                                        vim.fn.shellescape(definition_pattern(name))))
                                if #hit > 0 then
                                    survived[#survived + 1] = doc .. ": " .. name
                                        .. " (still defined in " .. hit[1] .. ")"
                                end
                            end
                        end
                    end
                    if line:match("^| `") and not deleted_row then
                        -- A row names either a SYMBOL or a MODULE. A module is
                        -- checked as a file (its row carries the path in another
                        -- cell); a symbol must have a DEFINITION, not a mention.
                        local names = {}
                        for name in line:gmatch("`([%w_]+)`") do
                            names[#names + 1] = name
                        end
                        local paths = {}
                        for path in line:gmatch("`([%w_/%.%-]+%.lua)`") do
                            paths[#paths + 1] = vim.fn.fnamemodify(path, ":t:r")
                        end
                        for _, modname in ipairs(paths) do
                            for i = #names, 1, -1 do
                                if names[i] == modname then
                                    table.remove(names, i)
                                end
                            end
                        end
                        for _, name in ipairs(names) do
                            if #name > 3 and not name:match("^lua$") then
                                local hit = vim.fn.systemlist(
                                    ("grep -rlE -- %s lua/ tests/ scripts/ 2>/dev/null"):format(
                                        vim.fn.shellescape(definition_pattern(name))))
                                if #hit == 0 then
                                    missing[#missing + 1] = doc .. ": " .. name
                                end
                            end
                        end
                    end
                end
            end
        end
        assert.same({}, missing,
            "these are named in a Core-concepts table but exist nowhere in the tree")
        assert.same({}, survived,
            "these are marked `deleted` in a Core-concepts table but are still defined")
    end)

    it("the definition matcher accepts every real definition form", function()
        assert.is_true(defines("warm_catalog", "function M.warm_catalog()"),
            "module function")
        assert.is_true(defines("pre_query", "cliproxyapi.pre_query = function() end"),
            "table-field function — the adapter form")
        assert.is_true(defines("bound_candidates", "local function bound_candidates(t)"),
            "file-local function")
        assert.is_true(defines("healthiest", "local healthiest = reduce"),
            "file-local value")
        assert.is_true(defines("anthropic_tools_route", 'strategy = "anthropic_tools_route",'),
            "a quoted string — a table cell may name a VALUE, not a symbol")
    end)

    it("the definition matcher rejects a mere mention (planted false positive)", function()
        -- The direction that actually matters. A guard asserted only against
        -- shapes it SHOULD find cannot be shown to reject anything, and this one
        -- shipped twice with a matcher loose enough to certify the drift it
        -- exists to catch.
        assert.is_false(defines("resolve_login_provider",
            "-- resolve_login_provider used to answer this"),
            "a comment naming the symbol is not a definition")
        assert.is_false(defines("resolve_channel", "if resolve_channel == nil then"),
            "a comparison is not a definition")
        assert.is_false(defines("catalog_stale", "local t = { catalog_stale = other }"),
            "binding some OTHER value to a like-named key is not a definition")
        assert.is_false(defines("warm_catalog", "cliproxy.warm_catalog()"),
            "a call site is not a definition")
    end)

    it("no spec re-defines free_port; they use tests/helpers/ready_port", function()
        local offenders = {}
        for _, path in ipairs(repo_files("ls tests/integration/*.lua tests/unit/*.lua 2>/dev/null")) do
            if read(path):find("local function free_port", 1, true) then
                offenders[#offenders + 1] = path
            end
        end
        assert.same({}, offenders,
            "these specs re-declare free_port instead of requiring tests.helpers.ready_port")
    end)

    it("every cliproxy integration spec redirects its own derived-artifact dir", function()
        -- `make` redirects XDG_DATA_HOME, but a bare PlenaryBustedFile run does
        -- not, and cliproxy's rendered config lives under stdpath('data'). A
        -- spec without this writes the operator's REAL config — and the running
        -- proxy's file watcher reloads it.
        local offenders = {}
        for _, path in ipairs(repo_files("ls tests/integration/cliproxy_*.lua 2>/dev/null")) do
            if not read(path):find("_set_data_dir", 1, true) then
                offenders[#offenders + 1] = path
            end
        end
        assert.same({}, offenders,
            "these specs can write the operator's real ~/.local/share/nvim; add "
                .. "require('parley.cliproxy')._set_data_dir(vim.fn.tempname())")
    end)

    -- #218. A triple-backtick predicate belongs in exactly two places: the prose
    -- grammar (highlight_structure.is_fence_delim) and the tool-body grammar
    -- (fence.lua). Hand-rolled copies drifted three separate times in this one
    -- issue — the review skill matched only column-zero backticks and so missed
    -- every fence the default prompt now asks models to indent, and the HTML
    -- exporter required the closer to follow a newline directly and swallowed
    -- whole turns. Inspection kept missing them; this makes a new copy fail.
    --
    -- Measured allowances, not aspirational ones. The list may shrink, never grow.
    --   chat_respond.lua  1  matches a SPECIFIC info string, ```yaml {"type":"request"},
    --                        which is a typed request envelope rather than a fence
    --                        predicate — it must not become "any fence".
    it("the triple-backtick predicate lives only in its two owners", function()
        local OWNERS = {
            ["lua/parley/highlight_structure.lua"] = true, -- prose grammar
            ["lua/parley/fence.lua"] = true,               -- tool-body grammar
        }
        local ALLOWANCES = { ["lua/parley/chat_respond.lua"] = 1 }
        local offenders = {}
        for _, path in ipairs(repo_files("git ls-files 'lua/**/*.lua'")) do
            if not OWNERS[path] then
                local text = read(path)
                -- MATCHING a fence is the invariant; EMITTING one is fine and
                -- common (log_emit, render_buffer and the review journal all
                -- write fences, and defaults.lua describes them in prose). So
                -- flag a triple backtick only where it is a pattern argument.
                --
                -- Scanned over a comment-stripped WINDOW, not line-by-line: the
                -- first version required the backtick and the match call to
                -- share a line, so wrapping the pattern onto its own line
                -- silently escaped the guard (BR-23).
                local scrubbed = text:gsub("\n%s*%-%-[^\n]*", "\n")
                local n = 0
                for call in scrubbed:gmatch("[:%.]g?match%b()") do
                    if call:find("```", 1, true) then n = n + 1 end
                end
                for call in scrubbed:gmatch("[:%.]gsub%b()") do
                    if call:find("```", 1, true) then n = n + 1 end
                end
                for call in scrubbed:gmatch("[:%.]find%b()") do
                    if call:find("```", 1, true) then n = n + 1 end
                end
                local allowed = ALLOWANCES[path] or 0
                if n > allowed then
                    offenders[#offenders + 1] = path .. " (" .. n .. " > " .. allowed .. ")"
                end
            end
        end
        assert.are.same({}, offenders,
            "hand-rolled fence matcher(s); use highlight_structure.is_fence_delim "
            .. "for prose or parley.fence for tool bodies (#218)")
    end)

    -- #218 BR-15: the convention is only load-bearing if EVERY shipped prompt
    -- carries it. Stripping it from the four non-default prompts left five
    -- specs green.
    -- The rule, not the instance: EVERY prompt string in shipped config that
    -- agent_info.resolve can select must carry the convention, enumerated FROM
    -- config rather than hand-picked. resolve falls back to agent.system_prompt
    -- (agent_info.lua:48-50) and config.lua calls that field mandatory, so a
    -- guard over config.system_prompts alone covered one of two arms (BR-21).
    --
    -- The third arm is not enforceable here: a user-merged system_prompts entry
    -- or a chat header `system_prompt:` replaces the prompt wholesale. That is
    -- documented in README instead — see "Custom system prompts".
    it("every selectable shipped prompt carries the fence indentation convention", function()
        local defaults = dofile("lua/parley/defaults.lua")
        local config = dofile("lua/parley/config.lua")
        assert.is_truthy(defaults.fence_indent_convention)
        local missing = {}
        local function check(label, prompt)
            if type(prompt) == "string" and prompt ~= ""
                and not prompt:find(defaults.fence_indent_convention, 1, true) then
                missing[#missing + 1] = label
            end
        end
        for _, entry in ipairs(config.system_prompts or {}) do
            check("system_prompts:" .. tostring(entry.name), entry.system_prompt)
        end
        for _, agent in ipairs(config.agents or {}) do
            check("agents:" .. tostring(agent.name), agent.system_prompt)
        end
        assert.are.same({}, missing,
            "selectable prompt(s) missing defaults.fence_indent_convention — "
            .. "switching prompt or agent would silently change how malformed "
            .. "output renders (#218)")
    end)

    it("picker keys come from the keybinding registry, not literals", function()
        -- A hardcoded key is neither discoverable in <C-g>? nor rebindable. The
        -- pre-#205 keys in root_dir_picker and system_prompt_picker are listed
        -- as known debt so the invariant can hold for new code without silently
        -- expanding this issue into two unrelated pickers: the list may shrink,
        -- never grow.
        -- Measured allowances, not aspirational ones: an allowance below the
        -- real count makes the guard assert a falsehood, which is how it passed
        -- while three files restated the registry's `<C-g>?` default.
        --   agent_picker         1  the <C-g>? help default (its <C-a> is registry-bound)
        --   root_dir_picker      4  three picker keys + the same <C-g>? default
        --   system_prompt_picker 5  four picker keys + the same <C-g>? default
        -- The numbers may shrink, never grow.
        local LEGACY_UNREGISTERED = {
            ["lua/parley/agent_picker.lua"] = 1,
            ["lua/parley/root_dir_picker.lua"] = 4,
            ["lua/parley/system_prompt_picker.lua"] = 5,
        }
        -- float_picker is the WIDGET, not a caller: its <CR>/<Esc>/<C-j> and
        -- friends are its own built-in interaction, documented in its header and
        -- deliberately not per-picker rebindable. The guard is about the keys a
        -- picker passes IN through `mappings`.
        for _, path in ipairs(repo_files("ls lua/parley/*_picker.lua | grep -v float_picker")) do
            -- Enumerate the FORMS the duplicated value can take, not one of
            -- them. Three forms have shipped in this repo already:
            --   key = "<C-a>"                        a direct literal
            --   key_for(...) or "<C-a>"              a fallback copy
            --   (config.x or { shortcut = "<C-g>?" })  a default-table copy
            -- and a guard that saw only the first two is why the third survived
            -- a round whose comment claimed it counted "any bracketed literal".
            -- Count every bracketed key literal in the file, whatever holds it.
            local body = read(path)
            local literals = 0
            for _ in body:gmatch('"<[^"]+>[^"]*"') do
                literals = literals + 1
            end
            local allowed = LEGACY_UNREGISTERED[path] or 0
            assert.is_true(literals <= allowed, ("%s has %d hardcoded picker key(s), "
                .. "allowed %d — bind through keybinding_registry.key_for(id, config) "
                .. "so the key is discoverable and rebindable")
                :format(path, literals, allowed))
        end
    end)
end)

-- #214 BR-5: the branch-ref line format was hand-inlined in SEVEN places across
-- init.lua, chat_finder.lua and highlighter.lua. Consolidating the two obvious
-- ones left five, and the review had to find them twice. One owner, and a guard
-- so the next inline copy fails instead of being caught by a reviewer.
describe("arch: the branch-ref line has one formatter (#214)", function()
    it("no module hand-builds a 🌿: line", function()
        local offenders = {}
        for _, path in ipairs(repo_files("git ls-files 'lua/**/*.lua'")) do
            if path ~= "lua/parley/branch_ref.lua" then
                for _, line in ipairs(vim.split(read(path), "\n")) do
                    if not line:match("^%s*%-%-")
                        and line:find('branch_prefix .. " " ..', 1, true) then
                        offenders[#offenders + 1] = path .. ": " .. vim.trim(line)
                    end
                end
            end
        end
        assert.are.same({}, offenders,
            "hand-built branch-ref line; use branch_ref.format_ref_line (#214)")
    end)
end)

-- #214 BR-21 / BR-34: a runtime string as gsub's SECOND argument is a silent
-- corruption bug under LuaJIT, which — unlike standard Lua — does not raise.
-- Measured in this repo's nvim: "50% off" -> "50 off", "%1 x" -> the pattern
-- itself, "100%" -> a NUL byte written into the file. Found twice, so it gets a
-- guard rather than a third review round.
describe("arch: no runtime string is a gsub replacement (#214)", function()
    it("gsub/sub replacements are literals, functions, or explicitly escaped", function()
        -- A bare identifier as gsub's replacement argument. Literals and inline
        -- `function` replacements are fine. Anything else must carry an explicit
        -- `-- gsub-safe: <why>` on the line or the one above — an annotation,
        -- not a guess from the variable's NAME, so the exception is greppable
        -- and reviewable instead of inferred.
        -- gsub ONLY: string.sub takes numeric indices, not a replacement, so
        -- matching :sub( floods this with false positives.
        local pat = ":gsub%b()"
        local offenders = {}
        for _, path in ipairs(repo_files("git ls-files 'lua/**/*.lua'")) do
            local lines = vim.split(read(path), "\n")
            for n, line in ipairs(lines) do
                if not line:match("^%s*%-%-") then
                    for call in line:gmatch(pat) do
                        local second = call:match("^:gsub%(.-,%s*([%a_][%w_%.%[%]]*)%s*%)$")
                        local annotated = line:find("gsub%-safe")
                            or (lines[n - 1] or ""):find("gsub%-safe")
                        if second and not second:match("^function") and not annotated then
                            offenders[#offenders + 1] = ("%s:%d  %s"):format(path, n, second)
                        end
                    end
                end
            end
        end
        assert.are.same({}, offenders,
            "runtime string used as a gsub replacement — use a function "
            .. "replacement, or escape %% first (#214 BR-34)")
    end)
end)

-- #214 C1. M2 gave the registry three guarantees — rebinding, `shortcut = ""`
-- disabling, and the `default_keymaps` master switch — and every one of them
-- attaches to `resolve_keys`. Any code that turns config into a key WITHOUT
-- going through it silently opts out of all three. That was not hypothetical:
-- the review skill and ~20 picker sites read `config.X.shortcut` directly, so
-- `default_keymaps = false` left four maps live on every markdown buffer and a
-- `shortcut = ""` disable raised "Invalid (empty) LHS" on every markdown
-- BufEnter. A sweep without a guard is a snapshot.
describe("arch: every key derives from the keybinding registry (#214)", function()
    it("no module outside the registry reads a config `.shortcut` field", function()
        local offenders = {}
        for _, path in ipairs(repo_files("git ls-files 'lua/**/*.lua'")) do
            if not path:match("keybinding_registry%.lua$") then
                -- `[^\n]*` yields an empty match after every line, which doubles
                -- every reported line number (a planted violation at :121 was
                -- reported as :223). `(.-)\n` over a newline-terminated body does not.
                local lineno = 0
                for line in (read(path) .. "\n"):gmatch("(.-)\n") do
                    lineno = lineno + 1
                    -- comments are documentation, not derivation; and a read
                    -- that inspects the USER's opts (rather than deriving a key
                    -- to bind) opts out explicitly, never by inference
                    local code = line:match("^%s*%-%-") and "" or line
                    if code:find("shortcut%-read%-ok") then code = "" end
                    if code:find("%.shortcut") then
                        offenders[#offenders + 1] = path .. ":" .. lineno .. " " .. vim.trim(line)
                    end
                end
            end
        end
        assert.same({}, offenders,
            "resolve a key with keybinding_registry.key_for/resolve_keys instead of "
            .. "reading config.<key>.shortcut — a raw read bypasses rebinding, "
            .. "`shortcut = \"\"` and `default_keymaps = false`")
    end)

    it("registry entries marked help_only are installed by a resolver-based path", function()
        -- `help_only` means "shown in <C-g>?, registered elsewhere". That is the
        -- exemption the shadow installs hid behind, so the surviving ones must be
        -- picker mappings — which now resolve via key_for — and nothing else.
        local reg = require("parley.keybinding_registry")
        local unexpected = {}
        for _, e in ipairs(reg.entries) do
            if e.help_only and not e.config_key:find("_mappings%.") then
                unexpected[#unexpected + 1] = e.id .. " (" .. e.config_key .. ")"
            end
        end
        assert.same({}, unexpected,
            "a help_only entry outside a picker mappings table means a hand-rolled "
            .. "install path again — register it through kb_registry.register_buffer")
    end)
end)

-- #214 review (Minor): native_map's contract used to be a production error()
-- raised from prep_chat, AFTER _prepared_bufs was set — a mis-registered key
-- left the buffer permanently half-prepared with no retry. The contract belongs
-- here, where it costs a red test instead of a broken buffer.
describe("arch: native key overrides are declared (#214)", function()
    it("every literal native_map key carries a rationale in the registry", function()
        local reg = require("parley.keybinding_registry")
        local src = read("lua/parley/init.lua")
        local undeclared = {}
        for key in src:gmatch('native_map%("([^"]+)"') do
            if not reg.native_overrides[key] then
                undeclared[#undeclared + 1] = key
            end
        end
        assert.same({}, undeclared,
            "add the key to keybinding_registry.native_overrides with its rationale")
        -- the loop-driven ones (*/#/g*/g#) come from a literal table beside it
        for key in src:gmatch('{ key = "([^"]+)", back = ') do
            if not reg.native_overrides[key] then
                undeclared[#undeclared + 1] = key
            end
        end
        assert.same({}, undeclared)
    end)

    -- #214 BR-50: `feature_gated` is trusted by both leak tests and had NEITHER
    -- of the guards `native_overrides` carries. An allowance list is an oracle's
    -- second unverified input; adding a key to it silently widens what the leak
    -- guard forgives.
    it("every feature_gated key carries a gate and a location", function()
        local reg = require("parley.keybinding_registry")
        local bad = {}
        for key, meta in pairs(reg.feature_gated) do
            if not (meta.gate and #meta.gate > 0) then bad[#bad + 1] = key .. ": no gate" end
            if not (meta.where and #meta.where > 0) then bad[#bad + 1] = key .. ": no where" end
        end
        assert.same({}, bad)
    end)

    it("no feature_gated key is bound by the SHIPPED config", function()
        -- If it resolves under the shipped defaults it is a default, not a
        -- feature-gated map, and belongs in the registry rather than the
        -- allowance list.
        local reg = require("parley.keybinding_registry")
        local shipped = dofile("lua/parley/config.lua")
        local leaked = {}
        for key in pairs(reg.feature_gated) do
            for _, e in ipairs(reg.entries) do
                for _, k in ipairs(reg.resolve_keys(e, shipped) or {}) do
                    if k == key then leaked[#leaked + 1] = key .. " via " .. e.id end
                end
            end
        end
        assert.same({}, leaked)
    end)

    it("no declared override is stale — each is still installed somewhere", function()
        local reg = require("parley.keybinding_registry")
        local src = read("lua/parley/init.lua")
        local stale = {}
        for key, meta in pairs(reg.native_overrides) do
            local literal = src:find('native_map("' .. key .. '"', 1, true)
            local tabled = src:find('{ key = "' .. key .. '", back = ', 1, true)
            if not literal and not tabled then
                stale[#stale + 1] = key .. " (" .. meta.where .. ")"
            end
        end
        assert.same({}, stale, "declared in native_overrides but never installed")
    end)
end)

-- #214 BR-42. `atlas/traceability.yaml` maps each atlas doc to the code and
-- tests that realise it, and `make test-changed` runs off it — but nothing
-- enforced it, which is exactly why it drifted: this milestone's headline spec
-- and M1's whole pure module were absent, so editing the very atlas doc M2
-- rewrote ran neither. An index nobody checks is a list of what someone
-- remembered.
describe("arch: traceability.yaml lists every file it claims to map (#214)", function()
    local function traceability_paths()
        local paths = {}
        for line in (read("atlas/traceability.yaml") .. "\n"):gmatch("(.-)\n") do
            local path = line:match("^%s*%-%s+([%w_%-/%.]+%.lua)%s*$")
            if path then paths[#paths + 1] = path end
        end
        return paths
    end

    it("every path it names exists", function()
        local missing = {}
        for _, path in ipairs(traceability_paths()) do
            if vim.fn.filereadable(path) == 0 then missing[#missing + 1] = path end
        end
        assert.same({}, missing,
            "traceability.yaml points at files that are not in the tree")
    end)

    it("every spec this branch ADDED is routed somewhere", function()
        -- Same trap the 000205 fallback had (#214 BR-40/BR-50): on `main`,
        -- merge-base IS head, the diff is empty, and this passes while asserting
        -- nothing. Report instead of passing.
        local branch = vim.fn.systemlist("git rev-parse --abbrev-ref HEAD")[1] or ""
        if not branch:match("^%d%d%d%d%d%d%-") then
            pending("not on an issue branch — this guard is scoped to a branch's own diff")
            return
        end
        local base = vim.fn.systemlist("git merge-base HEAD main")[1]
        if not base or base == "" then
            pending("branch point not found")
            return
        end
        local added = vim.fn.systemlist(
            ("git diff --name-only --diff-filter=A %s -- tests/"):format(base))
        if vim.v.shell_error ~= 0 then
            pending("git diff unavailable")
            return
        end
        -- UNTRACKED specs too. `git diff` cannot see them, so a new spec was
        -- invisible to this guard until it was staged — and it then failed the
        -- run AFTER the one you checked. That is BR-13, twice, one commit late
        -- each time (#225). The sibling guard above already carries this exact
        -- lesson for entities ("comparing against the working tree flags it
        -- while it is still being written"); it had not been applied here.
        for _, p in ipairs(vim.fn.systemlist(
            "git ls-files --others --exclude-standard -- tests/")) do
            added[#added + 1] = p
        end
        local listed = {}
        for _, p in ipairs(traceability_paths()) do listed[p] = true end
        local unrouted = {}
        for _, spec in ipairs(added) do
            if spec:match("_spec%.lua$") and not listed[spec] then
                unrouted[#unrouted + 1] = spec
            end
        end
        assert.same({}, unrouted,
            "a new spec routes nowhere under `make test-changed` — add it to "
            .. "atlas/traceability.yaml under the doc it verifies")
    end)
end)

-- #214 M3. `vim.fn.writefile` encodes a `\n` INSIDE a list element as a NUL byte
-- rather than rejecting it, and `readfile` turns that NUL back into `\n` — so a
-- caller that composes a line cannot discover the mistake by round-tripping in
-- Lua. It shipped, and the operator found it in a real transcript.
--
-- Every writefile whose lines are COMPOSED (as opposed to read straight from a
-- buffer) routes through `helper.flatten_lines`. This is a source-level
-- assertion on purpose: the guard is currently unreachable through
-- create_child_chat's own paths (the template is split after the gsub, the
-- question is split at the call site), so no behavioural test can distinguish
-- it from its own absence. What it protects against is the NEXT caller.
describe("arch: composed writefile lines are flattened (#214 M3)", function()
    it("create_child_chat's writefile is guarded", function()
        local src = read("lua/parley/init.lua")
        local body = src:match("M%.create_child_chat = function.-\nend")
        assert.is_truthy(body, "create_child_chat not found")
        assert.is_truthy(body:find("flatten_lines", 1, true),
            "create_child_chat composes lines (a back-link and a question turn) "
            .. "and writes them with writefile — route them through "
            .. "helper.flatten_lines, or a multi-line element becomes NUL on disk")
    end)

    it("flatten_lines exists and is exported", function()
        assert.is_function(require("parley.helper").flatten_lines)
    end)
end)
