local Model

local function born()
    return { version = 1, state = "born", pid = 42, start = "1792471551.000001" }
end

describe("retained test process policy", function()
    before_each(function()
        Model = require("tests.helpers.test_process_model")
    end)

    it("requires exact start identity, preserving opaque numeric precision", function()
        local record = born()
        assert.equals("live", Model.classify(record, { kind = "live", start = record.start }))
        local status, reason = Model.classify(record, { kind = "live", start = "1792471551.000002" })
        assert.equals("gone", status)
        assert.matches("pid reused", reason)
        record.start = "9007199254740992"
        assert.equals("gone", Model.classify(record, { kind = "live", start = "9007199254740993" }))
        record.start = "000123"
        assert.equals("gone", Model.classify(record, { kind = "live", start = "123" }))
    end)

    it("accepts absence only after a complete birth record", function()
        assert.equals("gone", Model.classify(born(), { kind = "absent" }))
        for _, observation in ipairs({ { kind = "absent" }, { kind = "live", start = "1" } }) do
            assert.equals("unknown", Model.classify({ version = 1, state = "pending" }, observation))
        end
    end)

    it("rejects malformed record envelopes regardless of observation", function()
        local records = { false, true, 1, "record", {}, { version = 1 },
            { version = 1, state = "dead", pid = 42, start = "1" } }
        for _, record in ipairs(records) do
            for _, observation in ipairs({ { kind = "absent" }, { kind = "live", start = "1" } }) do
                assert.equals("unknown", Model.classify(record, observation))
            end
        end
        assert.equals("unknown", Model.classify(nil, { kind = "absent" }))
        for _, version in ipairs({ false, "1", 0, 2, 1.5 }) do
            local record = born()
            record.version = version
            assert.equals("unknown", Model.classify(record, { kind = "absent" }))
        end
    end)

    it("rejects invalid pids even when identity matches or appears absent", function()
        for _, pid in ipairs({ false, "42", 0, -1, 1.5, math.huge, -math.huge, 0 / 0, {} }) do
            local record = born()
            record.pid = pid
            assert.equals("unknown", Model.classify(record, { kind = "absent" }))
            assert.equals("unknown", Model.classify(record, { kind = "live", start = record.start }))
        end
        local record = born()
        record.pid = nil
        assert.equals("unknown", Model.classify(record, { kind = "absent" }))
    end)

    it("rejects malformed starts in either evidence source", function()
        local invalid = { false, 123, {}, "", " ", "1e3", "+1", "-1", ".1", "1.", "1.2.3", "1\n", "1 2", "nan", "inf" }
        for _, start in ipairs(invalid) do
            local record = born()
            record.start = start
            assert.equals("unknown", Model.classify(record, { kind = "absent" }))
            assert.equals("unknown", Model.classify(record, { kind = "live", start = start }))
            assert.equals("unknown", Model.classify(born(), { kind = "live", start = start }))
        end
        local record = born()
        record.start = nil
        assert.equals("unknown", Model.classify(record, { kind = "absent" }))
        assert.equals("unknown", Model.classify(born(), { kind = "live" }))
    end)

    it("keeps missing, unavailable and malformed observations unknown", function()
        assert.equals("unknown", Model.classify(born(), nil))
        for _, observation in ipairs({ false, true, "absent", 1, {}, { kind = "dead" },
            { kind = "unknown", reason = "permission denied" } }) do
            assert.equals("unknown", Model.classify(born(), observation))
        end
        local status, reason = Model.classify(born(), { kind = "unknown", reason = "permission denied" })
        assert.equals("unknown", status)
        assert.matches("permission denied", reason)
    end)

    it("accepts future fields without changing either input", function()
        local record = born()
        record.future = { nested = { "retained" } }
        local observation = { kind = "live", start = record.start, future = { "observed" } }
        local before_record, before_observation = vim.deepcopy(record), vim.deepcopy(observation)
        assert.equals("live", Model.classify(record, observation))
        assert.same(before_record, record)
        assert.same(before_observation, observation)
        record.state = "pending"
        before_record = vim.deepcopy(record)
        assert.equals("unknown", Model.classify(record, observation))
        assert.same(before_record, record)
        assert.same(before_observation, observation)
    end)
end)
