-- #231: a log line is never an image. Every logger call that serializes a
-- request-shaped value (payload, messages, final_payload, raw_payload) must
-- pass it through assets.elide_image_data first. The first sweep enumerated
-- three sinks in chat_respond.lua and missed two in dispatcher.lua — a real
-- send wrote the base64 of the image into parley.log six times. This guard
-- is the enumeration, repo-wide, so the class cannot reopen: any new
-- `logger.<level>(… vim.inspect(<request>) …)` or `vim.json.encode(<request>)`
-- without the elision is a failure here.
local NAMES = { "payload", "final_payload", "raw_payload", "messages" }

--- Does this source line log a serialized request value without eliding it?
local function unelided_sink(line)
    if not line:find("logger%.%a+%(") then
        return false
    end
    for _, name in ipairs(NAMES) do
        if line:find("vim%.inspect%(" .. name .. "%)") or line:find("vim%.json%.encode%(" .. name .. "%)") then
            return not line:find("elide_image_data", 1, true)
        end
    end
    return false
end

describe("log sinks never serialize an image (#231)", function()
    it("the matcher flags an unelided sink and accepts an elided one (planted)", function()
        assert.is_true(unelided_sink('    logger.debug("payload: " .. vim.inspect(payload))'))
        assert.is_true(unelided_sink('logger.debug("query to send is: " .. vim.json.encode(payload))'))
        assert.is_false(unelided_sink('logger.debug("payload: " .. vim.inspect(require("parley.assets").elide_image_data(payload)))'))
        assert.is_false(unelided_sink('local x = vim.inspect(payload)'), "not a logger call")
        assert.is_false(unelided_sink('logger.debug("n=" .. #messages)'), "not a serialization")
    end)

    it("every serializing logger call under lua/parley elides first", function()
        local offenders = {}
        for _, file in ipairs(vim.fn.glob("lua/parley/**/*.lua", false, true)) do
            local n = 0
            for line in io.lines(file) do
                n = n + 1
                if unelided_sink(line) then
                    offenders[#offenders + 1] = file .. ":" .. n
                end
            end
        end
        assert.same({}, offenders, "wrap the value in assets.elide_image_data before logging it")
    end)
end)
