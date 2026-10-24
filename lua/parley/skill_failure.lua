-- Pure public reason for skill failures. Never display raw bodies, stderr,
-- headers, recovery diagnoses (which can contain account data), or requests.
local M = {}
function M.reason(failure)
    failure = type(failure) == 'table' and failure or {}
    local status = failure.http_status
    local prefix = type(status) == 'number' and status >= 100 and status <= 599
        and ('HTTP ' .. tostring(status) .. ': ') or ''
    local fallback = failure.exit and 'provider transport failed' or 'provider request failed'
    local body = failure.body
    local detail
    if not failure.exit and type(body) == 'string' and #body <= 16384 then
        local ok, decoded = pcall(vim.json.decode, body)
        local err = ok and type(decoded) == 'table' and decoded.error
        if type(err) == 'table' and type(err.message) == 'string' then detail = err.message end
    end
    if detail then
        -- Fail closed on credential/request-bearing diagnostics rather than
        -- attempting to recognize every possible secret's spelling.
        local lower = detail:lower()
        for _, marker in ipairs({'bearer', 'authorization', 'api_key', 'api-key', 'api key',
            'token', 'password', 'secret', 'https://', 'http://', 'request', 'prompt',
            'content', 'header', 'sk-', '{', '}'}) do
            if lower:find(marker, 1, true) then detail = nil; break end
        end
    end
    if detail then
        detail = detail:gsub('[%c]', ' '):gsub('%s+', ' ')
        -- Quoted provider enum names are useful; arbitrary quoted values may
        -- be echoed document text. Keep only the tool-choice enum vocabulary.
        detail = detail:gsub('"([^"\n]*)"', function(value)
            if value == 'tool' or value == 'any' or value == 'auto' or value == 'none' then
                return '"' .. value .. '"'
            end
            return '[redacted]'
        end):gsub("'[^']*'", '[redacted]'):gsub('`[^`]*`', '[redacted]')
        if not detail:match('%S') then detail = nil end
    end
    local output = ''
    for _, unit in ipairs(require('parley.display_text').units(prefix .. (detail or fallback))) do
        if #output + #unit > 240 then break end
        output = output .. unit
    end
    return output
end
return M
