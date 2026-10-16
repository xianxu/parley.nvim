-- A completed test is progress; a noisy stdout stream is not. Keep incomplete
-- line storage bounded, including when a spec prints without a newline.
local M = {}
local MAX_LINE = 65536

function M.new(token, output, progress)
    local pending, passthrough = "", false
    local prefix = token .. " "
    local function line(text)
        local raw = text:gsub("\r$", "")
        local digits = raw:sub(1, #prefix) == prefix and raw:sub(#prefix + 1)
        if not passthrough and digits and digits:match("^[1-9]%d*$") then
            local sequence = tonumber(digits)
            if sequence and sequence < 2^53 then progress(sequence); return end
        end
        output(text .. "\n")
    end
    return {
        feed = function(chunk)
            pending = pending .. chunk
            while true do
                local ending = pending:find("\n", 1, true)
                if not ending then break end
                line(pending:sub(1, ending - 1))
                pending, passthrough = pending:sub(ending + 1), false
            end
            if #pending > MAX_LINE then
                output(pending)
                pending, passthrough = "", true
            end
        end,
        finish = function()
            if pending ~= "" then output(pending) end
            pending, passthrough = "", false
        end,
    }
end

return M
