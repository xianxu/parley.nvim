-- #261 M4 W15: a Stop's cleanups are independent. A topic or batch cancel that
-- throws is logged and must not skip the session's own cancel, which is what
-- releases the generation. Each case makes the callee throw.
local root = vim.fn.tempname() .. "-cancel-entry"
local parley = require("parley")
parley.setup({ chat_dir = root, state_dir = root .. "/state", providers = {}, api_keys = {} })
local Respond = require("parley.chat_respond")
local Stub = require("tests.helpers.stub")

describe("a Stop's cleanups", function()
    local function boom() error("cancel exploded") end
    local function run(entry)
        local cancelled, returned = {}, nil
        Stub.with_stub(require("parley.response_topic"), "cancel", boom, function()
            Stub.with_stub(require("parley.batch_response"), "cancel", boom, function()
                Stub.with_stub(require("parley.response_session"), "cancel", function(session)
                    cancelled[#cancelled + 1] = session
                end, function()
                    returned = Respond._cancel_entry(entry)
                end)
            end)
        end)
        return cancelled, returned
    end
    it("still cancel the session when the topic cancel throws", function()
        local cancelled, returned = run({ topic = {}, session = "S" })
        assert.same({ "S" }, cancelled); assert.equals(1, returned)
    end)
    it("still cancel the session when the batch cancel throws", function()
        local cancelled, returned = run({ batch = {}, topic = {}, session = "S" })
        assert.same({ "S" }, cancelled); assert.equals(1, returned)
    end)
    it("guard the topic cancel the terminal handler shares", function()
        local ok = true
        Stub.with_stub(require("parley.response_topic"), "cancel", boom, function()
            ok = Respond._cancel_topic({}, "origin response stopped")
        end)
        assert.is_false(ok)
    end)
end)
