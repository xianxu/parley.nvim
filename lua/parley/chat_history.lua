-- Pure policy for guarding standard chat history keys while a response is pending.
local M = {}

local MAX_PROMPT_BYTES = 160
local PREFIX = "Parley is checking with "
local SUFFIX = ". Changing history will cancel this request. Proceed?"
local ELLIPSIS = "…"

local function truncate_utf8(text, max_bytes)
    if #text <= max_bytes then
        return text
    end
    local cut = max_bytes
    while cut > 0 do
        local next_byte = text:byte(cut + 1)
        if not next_byte or next_byte < 0x80 or next_byte > 0xBF then
            break
        end
        cut = cut - 1
    end
    return text:sub(1, cut)
end

function M.prompt(agent)
    local label = tostring(agent or "Parley")
        :gsub("[%c]+", " ")
        :gsub("%s+", " ")
        :match("^%s*(.-)%s*$")
    local available = MAX_PROMPT_BYTES - #PREFIX - #SUFFIX
    if #label > available then
        label = truncate_utf8(label, available - #ELLIPSIS) .. ELLIPSIS
    end
    return PREFIX .. label .. SUFFIX
end

function M.should_proceed(choice)
    return choice == 1
end

function M.confirm(message, buttons, default)
    return vim.fn.confirm(message, buttons, default)
end

function M.guard(opts)
    local identity = opts.pending_identity(opts.buf)
    if not identity then
        opts.native_history()
        return "native"
    end
    local choice = opts.confirm(M.prompt(identity.agent), "&Yes\n&No", 2)
    if not M.should_proceed(choice) then
        return "declined"
    end
    opts.cancel_for_history(opts.buf, opts.native_history)
    return "cancelled"
end

return M
