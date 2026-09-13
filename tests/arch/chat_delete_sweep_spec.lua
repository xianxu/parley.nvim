-- tests/arch/chat_delete_sweep_spec.lua
--
-- #231: a chat is deleted through ONE door. `helpers.delete_file` on a chat
-- path orphans `assets/<ts>/`, so exactly one call may exist under
-- lua/parley/**: the one inside `M.delete_chat_file` in init.lua. A count
-- assertion, not an allow-list — tests/arch/arch_helper.lua's
-- assert_pattern_scoping is file-granular and cannot say "one call inside one
-- function". There is NO comment-marker exemption: a call is a call.
--
-- Seen red before the sweep: six hits (delete_chat_tree, cmd.ChatDelete x2,
-- md_delete_file, and the finder's two handlers) — memory: fix the class.
--
-- Enumerated and excluded, by file, each for a reason:
local EXCLUDED = {
    ["lua/parley/dispatcher.lua"] = "removes query-cache JSON, never a chat",
    ["lua/parley/issue_finder.lua"] = "removes issue files under workshop/issues, never a chat",
    ["lua/parley/note_finder.lua"] = "removes notes, never a timestamp-named chat",
}
-- Also enumerated and excluded: init.lua's legacy `os.remove(last)` of the
-- <chat_dir>/last.md state file — not a helpers.delete_file call and not a
-- chat, so the count below never sees it.

local DOOR_FILE = "lua/parley/init.lua"

describe("chat deletion goes through delete_chat_file (#231)", function()
    it("exactly one helpers.delete_file call exists, inside M.delete_chat_file", function()
        local hits = {}
        for _, file in ipairs(vim.fn.glob("lua/parley/**/*.lua", false, true)) do
            if not EXCLUDED[file] then
                local n, inside_door = 0, false
                for line in io.lines(file) do
                    n = n + 1
                    if line:match("^M%.delete_chat_file = function") then
                        inside_door = true
                    end
                    if line:find("helpers.delete_file(", 1, true) then
                        hits[#hits + 1] = { site = file .. ":" .. n, in_door = inside_door and file == DOOR_FILE }
                    end
                    if inside_door and line:match("^end%s*$") then
                        inside_door = false
                    end
                end
            end
        end
        local sites = vim.tbl_map(function(h) return h.site end, hits)
        assert.equals(1, #hits, "helpers.delete_file sites: " .. vim.inspect(sites)
            .. " — call M.delete_chat_file / _parley.delete_chat_file instead")
        assert.is_true(hits[1].in_door, "the one call must be inside M.delete_chat_file: " .. hits[1].site)
    end)
end)
