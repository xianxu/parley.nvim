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
