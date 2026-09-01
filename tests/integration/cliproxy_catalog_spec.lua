-- Integration tests for the model catalog IO seam (issue #205).
-- Exercises fetch + cache against the process-level fake
-- (tests/fixtures/fake_cliproxy), not function mocks — the join spans two HTTP
-- routes, which a mock would assert rather than prove.

local uv = vim.uv or vim.loop
local ready_port = require("tests.helpers.ready_port")

local FAKE = vim.fn.getcwd() .. "/tests/fixtures/fake_cliproxy"

-- Redirect the derived-artifact dir so this spec never touches the operator's
-- real ~/.local/share/nvim, even run bare.
local SPEC_DATA_DIR = vim.fn.tempname()
require("parley.cliproxy")._set_data_dir(SPEC_DATA_DIR)

local started = {}

local function start_fake(port)
    local handle, pid = uv.spawn(FAKE, { args = { "--port", tostring(port) } }, function() end)
    assert(handle, "failed to spawn fake_cliproxy")
    table.insert(started, { handle = handle, pid = pid })
    assert(ready_port.wait_listening(port), "fake never came up")
    return pid
end

describe("cliproxy model catalog", function()
    local parley = require("parley")
    local cliproxy = require("parley.cliproxy")
    local saved_providers, saved_path

    local function set_endpoint(port)
        parley.dispatcher = parley.dispatcher or {}
        parley.dispatcher.providers = parley.dispatcher.providers or {}
        parley.dispatcher.providers.cliproxyapi = {
            endpoint = ("http://127.0.0.1:%d/v1/chat/completions"):format(port),
        }
        require("parley.vault").add_secret("cliproxyapi", "testkey")
    end

    local function fetch()
        local models, done = nil, false
        cliproxy.fetch_catalog(function(m)
            models, done = m, true
        end)
        vim.wait(8000, function() return done end, 20)
        assert(done, "fetch_catalog never resolved (hang!)")
        return models
    end

    before_each(function()
        saved_providers = parley.dispatcher and parley.dispatcher.providers
        saved_path = vim.env.PATH
        -- Without /opt/homebrew/bin, so nothing here can discover and spawn the
        -- operator's REAL cliproxy against their live credential (#197).
        vim.env.PATH = "/usr/bin:/bin:/usr/sbin:/sbin"
        os.remove(cliproxy._catalog_path())
    end)

    after_each(function()
        if parley.dispatcher then
            parley.dispatcher.providers = saved_providers
        end
        vim.env.PATH = saved_path
        for _, p in ipairs(started) do
            pcall(function() uv.kill(p.pid, "sigkill") end)
        end
        started = {}
    end)

    it("joins both routes and caches the result to disk", function()
        local port = ready_port.free_port()
        start_fake(port)
        set_endpoint(port)

        local models = fetch()
        assert.is_true(#models > 0)

        local by_id = {}
        for _, m in ipairs(models) do by_id[m.id] = m end
        -- the join landed: display comes from /v1beta, created from /v1
        assert.equals("Claude Opus 5", by_id["claude-opus-5"].display)
        assert.equals(1784038800, by_id["claude-opus-5"].created)
        -- and the created-less shape survives the round trip
        assert.is_nil(by_id["gemini-pro-agent"].created)
        assert.equals("Gemini 3.1 Pro (High)", by_id["gemini-pro-agent"].display)

        assert.equals(1, vim.fn.filereadable(cliproxy._catalog_path()))
    end)

    it("serves the cached catalog with the proxy gone", function()
        local port = ready_port.free_port()
        start_fake(port)
        set_endpoint(port)
        fetch()

        for _, p in ipairs(started) do pcall(function() uv.kill(p.pid, "sigkill") end) end
        started = {}
        vim.wait(300, function() return not ready_port.is_listening(port) end, 20)

        local cached = cliproxy.catalog_cached()
        assert.is_true(#cached > 0, "cache should outlive the proxy")
    end)

    it("does not start a proxy when none is running", function()
        -- The #131 dormancy contract: opening a picker refreshes the catalog,
        -- and that must never spawn a daemon. Point at a port nothing holds and
        -- assert it is STILL free once the fetch settles.
        local port = ready_port.free_port()
        set_endpoint(port)

        local models = fetch()
        assert.same({}, models)
        assert.is_false(ready_port.is_listening(port),
            "fetch_catalog started a proxy — the dormancy contract is broken")
    end)

    it("leaves the existing cache intact when the proxy is unreachable", function()
        local port = ready_port.free_port()
        start_fake(port)
        set_endpoint(port)
        local warm = fetch()

        for _, p in ipairs(started) do pcall(function() uv.kill(p.pid, "sigkill") end) end
        started = {}
        fetch() -- fails; must not blank the cache

        assert.equals(#warm, #cliproxy.catalog_cached())
    end)

    it("does not erase a good catalog when the proxy answers 401", function()
        -- The failure this pins: a rejected bearer returns a perfectly readable
        -- body that parses to an EMPTY model list. Gating the write on curl's
        -- exit code (or on the body being non-nil) writes that empty list over
        -- a good catalog, and every provider then renders "(logged out)".
        local port = ready_port.free_port()
        start_fake(port)
        set_endpoint(port)
        local warm = fetch()
        assert.is_true(#warm > 0)

        for _, p in ipairs(started) do pcall(function() uv.kill(p.pid, "sigkill") end) end
        started = {}
        local handle, pid = uv.spawn(FAKE, {
            args = { "--port", tostring(port), "--mode", "client_key_mismatch" },
        }, function() end)
        assert(handle, "failed to spawn the fake in 401 mode")
        table.insert(started, { handle = handle, pid = pid })
        assert(ready_port.wait_listening(port), "401-mode fake never came up")

        fetch()
        assert.equals(#warm, #cliproxy.catalog_cached(),
            "a 401 wiped the cached catalog")
    end)

    it("records a genuinely empty catalog, which is real news", function()
        -- The other side of the same gate: when the proxy answers 200 with an
        -- empty registry (nothing authenticated), that MUST reach the cache —
        -- the picker's logged-out rows are derived from it.
        local port = ready_port.free_port()
        local handle, pid = uv.spawn(FAKE, {
            args = { "--port", tostring(port), "--mode", "needs_login" },
        }, function() end)
        assert(handle)
        table.insert(started, { handle = handle, pid = pid })
        assert(ready_port.wait_listening(port))
        set_endpoint(port)
        cliproxy._write_catalog({ { id = "stale-1", owner = "openai" } })

        fetch()
        assert.same({}, cliproxy.catalog_cached())
    end)

    it("drops malformed rows so a corrupt cache cannot crash the picker", function()
        -- catalog.json sits on disk between sessions: it can be truncated,
        -- hand-edited, or written by an older parley. A row without a string id
        -- makes _view_for concatenate nil and _build_items render nil — i.e. the
        -- agent picker throws on open. Sanitized at this one boundary, which
        -- every consumer reads through.
        local fd = assert(io.open(cliproxy._catalog_path(), "w"))
        fd:write(vim.json.encode({ fetched_at = os.time(), models = {
            { id = "good-1", owner = "openai", display = "Good 1" },
            { owner = "openai", display = "no id at all" },
            { id = "", owner = "openai" },
            { id = "no-display", owner = "openai" },
            "not even a table",
        } }))
        fd:close()

        local rows = cliproxy.catalog_cached()
        assert.equals(2, #rows)
        assert.equals("good-1", rows[1].id)
        -- a missing display falls back to the id rather than staying nil
        assert.equals("no-display", rows[2].display)
        for _, m in ipairs(rows) do
            assert.is_string(m.id)
            assert.is_string(m.display)
            assert.is_string(m.series)
        end

        -- and the picker survives it end to end
        local ap = require("parley.agent_picker")
        assert.has_no.errors(function()
            ap._build_items({ _agents = {}, agents = {}, _state = { agent = "x" } },
                ap._view_for(rows, { providers = { "codex" }, per_provider = 3 }, {}))
        end)
    end)

    it("does not let a foreign 200 wipe a warm catalog", function()
        -- Something else holding the port answers 200 with a body that is not
        -- cliproxy's model list. It parses to an empty list, and an HTTP-200-only
        -- gate would write that over a good catalog.
        local port = ready_port.free_port()
        start_fake(port)
        set_endpoint(port)
        local warm = fetch()
        assert.is_true(#warm > 0)

        -- A FRESH port: reusing the one just killed lets the dying process
        -- answer the next probe, and the test then proves nothing. (It did
        -- exactly that on first writing — reverting the fix left it green.)
        local foreign_port = ready_port.free_port()
        local handle, pid = uv.spawn(FAKE, {
            args = { "--port", tostring(foreign_port), "--mode", "foreign" },
        }, function() end)
        assert(handle)
        table.insert(started, { handle = handle, pid = pid })
        assert(ready_port.wait_listening(foreign_port), "foreign fake never came up")
        set_endpoint(foreign_port)

        fetch()
        assert.equals(#warm, #cliproxy.catalog_cached(), "a foreign 200 wiped the catalog")
    end)

    it("resolves its callback on every exit path", function()
        -- A picker opened while a refresh is in flight must still repaint; the
        -- in-flight fetch's callback belongs to an earlier, possibly closed one.
        local port = ready_port.free_port()
        start_fake(port)
        set_endpoint(port)
        fetch() -- warm the cache

        local first, second = false, false
        cliproxy.fetch_catalog(function() first = true end)
        cliproxy.fetch_catalog(function(models)      -- lands on the in-flight path
            second = models ~= nil
        end)
        vim.wait(8000, function() return first and second end, 20)
        assert.is_true(second, "the second caller was never resolved")
    end)

    it("reports staleness from the cache's own timestamp", function()
        cliproxy._write_catalog({ { id = "x", owner = "openai" } }, os.time())
        assert.is_false(cliproxy.catalog_stale())
        cliproxy._write_catalog({ { id = "x", owner = "openai" } }, os.time() - 3600)
        assert.is_true(cliproxy.catalog_stale())
    end)
end)
