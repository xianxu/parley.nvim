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

describe("arch: single-source sweeps stay swept", function()
    it("the plan's Core-concepts tables name every entity THIS issue added", function()
        -- The other direction of the referent sweep, and scoped to the issue's
        -- own diff. A first version listed two files and could not fire on the
        -- instances the finding named; a second listed four and fired on
        -- everything those modules had ever exported. What must be tabled is the
        -- surface this issue ADDS, in any definition form.
        local plan = vim.fn.glob("workshop/plans/000205-*-plan.md")
        if plan == "" then
            pending("plan not present")
            return
        end
        local base = vim.fn.systemlist(
            "git log --grep '^#205' --reverse --format=%H -- workshop/issues | head -1")[1]
        if not base or base == "" then
            pending("issue base commit not found")
            return
        end
        -- `git diff <base>` — NOT `<base>..HEAD`. Diffing to HEAD ignores the
        -- working tree, so a new entity was invisible until the commit AFTER it
        -- appeared: `make test` passed pre-commit and the same run failed once
        -- committed, which is a guard that reports one commit late. Comparing
        -- against the working tree flags it while it is still being written.
        local diff = vim.fn.system(("git diff %s~1 -- lua/ scripts/"):format(base))
        if vim.v.shell_error ~= 0 then
            pending("git diff unavailable")
            return
        end
        -- Only the Core-concepts TABLES, which is what the assertion message
        -- claims. Searching the whole document let a name mentioned anywhere —
        -- a Revisions entry, a commit recipe, a code block — satisfy a guard
        -- about table rows.
        local whole = read(plan)
        local plan_body = whole:match("## Core concepts(.-)\n## ") or whole
        local table_rows = {}
        for line in plan_body:gmatch("[^\n]+") do
            if line:match("^| ") then
                table_rows[#table_rows + 1] = line
            end
        end
        plan_body = table.concat(table_rows, "\n")
        local missing = {}
        for line in diff:gmatch("[^\n]+") do
            -- Public FUNCTIONS, in either definition form. Deliberately not
            -- data: `M.AGENT = { … }` is a constant belonging to a module the
            -- tables already name by path, and demanding a row per constant
            -- floods the table without adding a check. A new FUNCTION in an
            -- already-listed module still needs its row — that is the case the
            -- guard exists for. A bare `fn = function()` is a field in a local
            -- table literal (a picker mapping), not exported surface.
            local name = line:match("^%+function M%.([%w_]+)%(")
            if not name then
                -- `M.x = <rhs>`: an export, in any of the forms this repo uses.
                -- Narrowing this to `= function` (the first attempt) dropped the
                -- 41-site `M._x = local_fn` seam-export idiom — excluding by
                -- SYNTAX rather than by what the right-hand side actually is.
                -- Data constants are what should be excluded, and they are
                -- literals: a table, a string, a number.
                local n, rhs = line:match("^%+M%.([%w_]+) = (.+)$")
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
        -- The plan→code direction. The other test walks code→table; this one
        -- catches a document naming a function that was renamed or never
        -- written, which happened three times on this issue (`catalog_write`,
        -- `provider_states`, `M._logged_out_providers`).
        local docs = {
            vim.fn.glob("workshop/plans/000205-*-plan.md"),
            vim.fn.glob("workshop/issues/000205-*.md"),
        }
        local missing = {}
        for _, doc in ipairs(docs) do
            if doc ~= "" then
                local body = read(doc)
                -- table rows only: prose may legitimately discuss removed names
                for line in body:gmatch("[^\n]+") do
                    if line:match("^| `") then
                        for name in line:gmatch("`([%w_]+)`") do
                            if #name > 3 and not name:match("^lua$") then
                                local hit = vim.fn.systemlist(
                                    ("grep -rl -- %s lua/ tests/ 2>/dev/null"):format(
                                        vim.fn.shellescape(name)))
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
