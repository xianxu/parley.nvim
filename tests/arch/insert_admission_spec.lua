-- #442: in session_sync_native_spec, mode i is reached while the InsertEnter
-- admission still awaits Couch, so neither mode i nor a vim.schedule barrier
-- proves the admission finished. An insert entry followed by a schedule barrier
-- goes through the spec's insert() helper, which waits for the admission itself.
local FILE = "tests/integration/session_sync_native_spec.lua"
local WINDOW = 2 -- lines after the entry where a barrier would stand in for admission

describe("arch: native session-sync insert entry waits for admission (#442)", function()
    it("never proves admission with a schedule barrier after keys('i')", function()
        local lines = vim.fn.readfile(FILE)
        local entries, violations = 0, {}
        for n, line in ipairs(lines) do
            if line:find('keys%("i') then
                entries = entries + 1
                for k = n + 1, math.min(n + WINDOW, #lines) do
                    if lines[k]:find("vim.schedule", 1, true) then
                        table.insert(violations, FILE .. ":" .. n .. ": " .. vim.trim(line))
                        break
                    end
                end
            end
        end
        -- A floor, so a pattern that stopped matching cannot pass vacuously.
        assert.is_true(entries >= 10, "found only " .. entries .. " insert entries")
        assert.are.same({}, violations, "use insert(): a schedule barrier is not admission proof")
    end)
end)
