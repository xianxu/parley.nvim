-- The Couch fake's round (#383): `round PATH --json` answers what a seeded
-- round sidecar holds, and `Cleared` once a submit is recorded after it,
-- comparing instants, as Couch does (pair#661). A round's `at` is UTC (`Z`);
-- a submit's is local with an offset, so text order is not time order.
local arrival = require("tests.helpers.arrival")
local fake_couch = require("tests.helpers.fake_couch")

describe("fake couch round", function()
    local root, saved, file

    local function round(argv)
        local result
        require("parley.couch").run(argv or { "couch", "--session-sync", "round", file, "--json" },
            function(value) result = value end)
        assert.is_true(vim.wait(arrival.MS, function() return result ~= nil end, 10))
        return result, vim.json.decode(result.stdout, { luanil = { object = true, array = true } })
    end

    local function seeded(at)
        return { base_hash = "aaaaaaaaaaaaaaaa", result_hash = "bbbbbbbbbbbbbbbb", at = at,
            presentation = "highlight",
            spans = { { start = { 1, 0 }, ["end"] = { 1, 3 }, old = "old", new = "new", explain = "why" } } }
    end

    before_each(function()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
        fake_couch.write(root, root .. "/sent", root .. "/argv")
        saved = { path = vim.env.PATH, state = vim.env.FAKE_COUCH_REGISTRY }
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.FAKE_COUCH_REGISTRY = root .. "/registry.json"
        file = root .. "/doc.md"
        vim.fn.writefile({ "# Doc", "new text" }, file)
    end)

    after_each(function()
        vim.env.PATH, vim.env.FAKE_COUCH_REGISTRY = saved.path, saved.state
        vim.fn.delete(root, "rf")
    end)

    it("answers no round for a file without one", function()
        local result, reply = round()
        assert.equals(0, result.code, result.stderr)
        assert.same({ Code = "ok", Error = "", Cleared = false }, reply)
    end)

    it("answers the seeded round, cleared by a later submit", function()
        fake_couch.round(vim.env.FAKE_COUCH_REGISTRY, file, seeded("2020-01-01T00:00:00.123456789Z"))
        local _, reply = round()
        assert.equals("ok", reply.Code)
        assert.same(seeded("2020-01-01T00:00:00.123456789Z"), reply.Round)
        assert.is_false(reply.Cleared)
        fake_couch.owe(vim.env.FAKE_COUCH_REGISTRY, file, "msg-1")
        _, reply = round()
        assert.is_true(reply.Cleared)
        assert.equals("bbbbbbbbbbbbbbbb", reply.Round.result_hash)
    end)

    it("compares a local-offset submit with a UTC round as instants, never as text", function()
        -- 23:30 at -07:00 is 06:30 UTC the next day: earlier as text, later in time.
        fake_couch.round(vim.env.FAKE_COUCH_REGISTRY, file, seeded("2026-10-18T06:00:00Z"))
        fake_couch.submit_at(vim.env.FAKE_COUCH_REGISTRY, file, "2026-10-17T23:30:00.000000001-07:00")
        local _, reply = round()
        assert.is_true(reply.Cleared)
        -- 22:30 at -07:00 is 05:30 UTC: later as text, earlier in time.
        fake_couch.submit_at(vim.env.FAKE_COUCH_REGISTRY, file, "2026-10-17T22:30:00-07:00")
        _, reply = round()
        assert.is_false(reply.Cleared)
    end)

    it("keys a registered file's round by its registration", function()
        local registered
        require("parley.document_registry").request("register", { file, "ops:0" }, { path = file, generation = 1 },
            function(value) registered = value end)
        assert.is_true(vim.wait(arrival.MS, function() return registered ~= nil end, 10))
        require("parley.document_registry").shutdown()
        assert.equals("registered", registered.kind)
        fake_couch.round(vim.env.FAKE_COUCH_REGISTRY, file, seeded("2020-01-01T00:00:00Z"))
        local _, reply = round()
        assert.equals("why", reply.Round.spans[1].explain)
    end)

    it("refuses a round call without --json as usage", function()
        local result, reply = round({ "couch", "--session-sync", "round", file })
        assert.equals(1, result.code)
        assert.equals("usage", reply.Code)
    end)
end)
