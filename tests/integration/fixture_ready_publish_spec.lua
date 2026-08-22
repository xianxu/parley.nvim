-- The publisher half of the fixture-readiness contract (#202).
--
-- tests/unit/ready_port_spec.lua guards the consumer: it must not accept an
-- incomplete signal. This guards the producer, which is the actual fix — a
-- reader cannot tell partial digits from complete ones, so the ready path must
-- never be observable before it is finished. Reverting fake_sse_server to a
-- plain `open(READY_FILE, "w")` leaves the consumer guard absorbing the bug and
-- everything else green, which is exactly the blind spot this closes.
--
-- Deterministic by construction: PARLEY_PUBLISH_DELAY holds the publish window
-- open for a fixed span instead of hoping to win a microsecond race. The delay
-- is also asserted, so the hook cannot be deleted to make the spec pass.

local uv = vim.uv or vim.loop

local DELAY_MS = 300
local MIN_SAMPLES = 10

describe("fake SSE server readiness publish", function()
    local handle, exited

    after_each(function()
        if handle and not handle:is_closing() then
            pcall(handle.kill, handle, "sigterm")
        end
        vim.wait(1000, function() return exited end, 10)
    end)

    it("never exposes the ready path in an incomplete state", function()
        local dir = vim.fn.tempname() .. "-ready-publish"
        vim.fn.mkdir(dir, "p")
        local ready_file = dir .. "/ready"

        local env = {}
        for name, value in pairs(vim.fn.environ()) do
            table.insert(env, name .. "=" .. value)
        end
        table.insert(env, "PYTHONDONTWRITEBYTECODE=1")
        table.insert(env, ("PARLEY_PUBLISH_DELAY=%.3f"):format(DELAY_MS / 1000))

        exited = false
        local started = uv.hrtime()
        handle = uv.spawn(vim.fn.getcwd() .. "/tests/fixtures/fake_sse_server",
            { args = { "unauthorized", ready_file }, env = env },
            function()
                exited = true
                if handle and not handle:is_closing() then handle:close() end
            end)
        assert.is_not_nil(handle)

        -- Sample the ready path continuously across the whole publish window.
        local incomplete, absent_samples, published_ns = {}, 0, nil
        vim.wait(10000, function()
            if vim.fn.filereadable(ready_file) ~= 1 then
                absent_samples = absent_samples + 1
                return false
            end
            local content = (vim.fn.readfile(ready_file)[1] or ""):gsub("%s+$", "")
            if tonumber(content) == nil then
                table.insert(incomplete, ("size=%d content=%q"):format(
                    vim.fn.getfsize(ready_file), content))
                return false
            end
            published_ns = uv.hrtime()
            return true
        end, 1)

        assert.is_not_nil(published_ns, "fixture never published a port")
        assert.equals(0, #incomplete,
            "ready path was observed incomplete: " .. table.concat(incomplete, ", "))

        -- Without these two, the assertion above is vacuous: it would also pass
        -- if the hook were removed and the port appeared before sampling began.
        assert.is_true(absent_samples >= MIN_SAMPLES,
            ("only %d samples taken during the publish window"):format(absent_samples))
        local elapsed_ms = (published_ns - started) / 1e6
        assert.is_true(elapsed_ms >= DELAY_MS * 0.5,
            ("port appeared after %.0fms; PARLEY_PUBLISH_DELAY=%dms was not honored")
                :format(elapsed_ms, DELAY_MS))
    end)
end)
